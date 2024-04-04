/- Utilities for interacting with LLMlean API endpoints. -/
import Lean
open Lean

namespace LLMlean


inductive APIKind : Type
  | Ollama
  | TogetherAI
  deriving Inhabited, Repr


inductive PromptKind : Type
  | FewShot
  | Instruction
  deriving Inhabited, Repr


structure API where
  model : String
  baseUrl : String
  kind : APIKind := APIKind.Ollama
  promptKind := PromptKind.FewShot
  key : String := ""
deriving Inhabited, Repr


structure GenerationOptions where
  temperature : Float := 0.3
  numSamples : Nat := 10
  «stop» : List String := ["\n", "[/TAC]"]
deriving ToJson

structure OllamaGenerationOptions where
  temperature : Float := 0.3
  «stop» : List String := ["\n", "[/TAC]"]
deriving ToJson

structure OllamaTacticGenerationRequest where
  model : String
  prompt : String
  options : OllamaGenerationOptions
  raw : Bool := true
  stream : Bool := false
deriving ToJson

structure OllamaTacticGenerationResponse where
  response : String
deriving FromJson

structure TogetherAITacticGenerationRequest where
  model : String
  prompt : String
  n : Nat := 5
  temperature : Float := 0.3
  max_tokens : Nat := 100
  stream : Bool := false
  «stop» : List String := ["\n", "[/TAC]"]
deriving ToJson

structure TogetherAIChoice where
  text : String
deriving FromJson

structure TogetherAITacticGenerationResponse where
  id : String
  choices : List TogetherAIChoice
deriving FromJson

def getOllamaAPI : IO API := do
  let url        := (← IO.getEnv "LLMLEAN_ENDPOINT").getD "http://localhost:11434/api/generate"
  let model      := (← IO.getEnv "LLMLEAN_MODEL").getD "solobsd/llemma-7b"
  let promptKind := (← IO.getEnv "LLMLEAN_PROMPT").getD "fewshot"
  let apiKey     := (← IO.getEnv "LLMLEAN_API_KEY").getD ""
  let api : API := {
    model := model,
    baseUrl := url,
    kind := APIKind.Ollama,
    promptKind := (if promptKind == "fewshot" then PromptKind.FewShot else PromptKind.Instruction),
    key := apiKey
  }
  return api

def getTogetherAPI : IO API := do
  let url        := (← IO.getEnv "LLMLEAN_ENDPOINT").getD "https://api.together.xyz/v1/completions"
  let model      := (← IO.getEnv "LLMLEAN_MODEL").getD "deepseek-ai/deepseek-coder-33b-instruct"
  let promptKind := (← IO.getEnv "LLMLEAN_PROMPT").getD "instruction"
  let apiKey     := (← IO.getEnv "LLMLEAN_API_KEY").getD ""
  let api : API := {
    model := model,
    baseUrl := url,
    kind := APIKind.TogetherAI,
    promptKind := (if promptKind == "fewshot" then PromptKind.FewShot else PromptKind.Instruction),
    key := apiKey
  }
  return api

def getAPI : IO API := do
  let apiKind  := (← IO.getEnv "LLMLEAN_API").getD "ollama"
  match apiKind with
  | "ollama" => getOllamaAPI
  | _ => getTogetherAPI



def post {α β : Type} [ToJson α] [FromJson β] (req : α) (url : String) (apiKey : String): IO β := do
  let out ← IO.Process.output {
    cmd := "curl"
    args := #[
      "-X", "POST", url,
      "-H", "accept: application/json",
      "-H", "Content-Type: application/json",
      "-H", "Authorization: Bearer " ++ apiKey,
      "-d", (toJson req).pretty UInt64.size]
  }
  if out.exitCode != 0 then
     throw $ IO.userError s!"Request failed. If running locally, ensure that ollama is running, and that the ollama server is up at `{url}`. If the ollama server is up at a different url, set LLMLEAN_URL to the proper url. If using a cloud API, ensure that LLMLEAN_API_KEY is set."
  let some json := Json.parse out.stdout |>.toOption
    | throw $ IO.userError out.stdout
  let some res := (fromJson? json : Except String β) |>.toOption
    | throw $ IO.userError out.stdout
  return res


def makePromptsFewShot (context : String) (state : String) (pre: String) : List String :=
  let p1 := "Given the Lean 4 tactic state, suggest a next tactic.
Here are some examples:

Tactic state:
---
α : Type u_1
r : α → α → Prop
inst✝¹ : DecidableEq α
inst✝ : IsIrrefl α r
⊢ CutExpand r ≤ InvImage (Finsupp.Lex (rᶜ ⊓ fun x x_1 => x ≠ x_1) fun x x_1 => x < x_1) ↑toFinsupp
---
Next tactic:
---
rintro s t ⟨u, a, hr, he⟩
---

Tactic state:
---
ι : Type u_1
I✝ J✝ : Box ι
x y : ι → ℝ
I J : WithBot (Box ι)
⊢ ↑I = ↑J ↔ I = J
---
Next tactic:
---
simp only [Subset.antisymm_iff, ← le_antisymm_iff, withBotCoe_subset_iff]
---

Tactic state:
---
m n : ℕ
h : Nat.coprime m n
⊢ Nat.gcd m n = 1
---
Next tactic:
---
rw [← h.gcd_eq_one]
---

Tactic state:
---
" ++ state ++ "
---
Next tactic:
---
" ++ pre
  let p2 := match pre with
  | "" => context
  | _  => p1

  [p1, p2]

def makePromptsInstruct (context : String) (state : String) (pre: String) : List String :=
  let p1 := "/- You are proving a theorem in Lean 4.
You are given the following information:
- The file contents up to the current tactic, inside [CTX]...[/CTX]
- The current proof state, inside [STATE]...[/STATE]

Your task is to generate the next tactic in the proof.
Put the next tactic inside [TAC]...[/TAC]
-/
[CTX]
" ++ context ++ "
[/CTX]
[STATE]
" ++ state ++ "
[/STATE]
[TAC]
" ++ pre
  [p1]


def makePrompts (promptKind : PromptKind) (context : String) (state : String) (pre: String) : List String :=
  match promptKind with
  | PromptKind.FewShot => makePromptsFewShot context state pre
  | _ => makePromptsInstruct context state pre


def filterTactics (s: String) : Bool :=
  let banned := ["sorry", "admit"]
  !(banned.any fun s' => s == s')

def splitTac (text : String) : String :=
  match (text.splitOn "[/TAC]").head? with
  | some s => s
  | none => text

def parseResponseOllama (res: OllamaTacticGenerationResponse) : String :=
  splitTac res.response

def parseResponseTogetherAI (res: TogetherAITacticGenerationResponse) (pfx : String) : Array String :=
  (res.choices.map fun x => pfx ++ (splitTac x.text)).toArray

def tacticGenerationOllama (pfx : String) (prompts : List String)
(api : API) (options : GenerationOptions) : IO $ Array (String × Float) := do
  let mut results : HashSet String := HashSet.empty
  for prompt in prompts do
    for i in List.range options.numSamples do
      let temperature := if i == 1 then 0.0 else options.temperature
      let req : OllamaTacticGenerationRequest := {
        model := api.model,
        prompt := prompt,
        stream := false,
        options := { temperature := temperature }
      }
      let res : OllamaTacticGenerationResponse ← post req api.baseUrl api.key
      results := results.insert (pfx ++ (parseResponseOllama res))

  let finalResults := (results.toArray.filter filterTactics).map fun x => (x, 1.0)
  return finalResults


def tacticGenerationTogetherAI (pfx : String) (prompts : List String)
(api : API) (options : GenerationOptions) : IO $ Array (String × Float) := do
  let mut results : HashSet String := HashSet.empty
  for prompt in prompts do
    let req : TogetherAITacticGenerationRequest := {
      model := api.model,
      prompt := prompt,
      n := options.numSamples,
      temperature := options.temperature
    }

    let res : TogetherAITacticGenerationResponse ← post req api.baseUrl api.key
    for result in (parseResponseTogetherAI res pfx) do
      results := results.insert result

  let finalResults := (results.toArray.filter filterTactics).map fun x => (x, 1.0)
  return finalResults


def getGenerationOptions (api : API):  IO GenerationOptions := do
  let defaultSamples := match api.kind with
  | APIKind.Ollama => 5
  | _ => 10

  let defaultSamplesStr := match api.kind with
  | APIKind.Ollama => "5"
  | _ => "10"

  let numSamples := match ((← IO.getEnv "LLMLEAN_NUMSAMPLES").getD defaultSamplesStr).toInt? with
  | some n => n.toNat
  | none => defaultSamples

  let options : GenerationOptions := {
    numSamples := numSamples
  }
  return options


def API.tacticGeneration
  (api : API) (tacticState : String) (context : String)
  («prefix» : String) : IO $ Array (String × Float) := do

  let prompts := makePrompts api.promptKind context tacticState «prefix»
  let options ← getGenerationOptions api
  match api.kind with
  | APIKind.Ollama =>
    tacticGenerationOllama «prefix» prompts api options
  | APIKind.TogetherAI =>
    tacticGenerationTogetherAI «prefix» prompts api options


end LLMlean
