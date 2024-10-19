/- Utilities for interacting with LLMlean API endpoints. -/
import Lean
open Lean

namespace LLMlean


inductive APIKind : Type
  | Ollama
  | TogetherAI
  | OpenAI
  deriving Inhabited, Repr


inductive PromptKind : Type
  | FewShot
  | Instruction
  | Detailed
  deriving Inhabited, Repr


structure API where
  model : String
  baseUrl : String
  kind : APIKind := APIKind.Ollama
  promptKind := PromptKind.FewShot
  key : String := ""
deriving Inhabited, Repr


structure GenerationOptionsOllama where
  temperature : Float := 0.7
  «stop» : List String := ["[/TAC]"]
  /-- Maximum number of tokens to generate. `-1` means no limit. -/
  num_predict : Int := 100
deriving ToJson

structure GenerationOptions where
  temperature : Float := 0.7
  numSamples : Nat := 10
  «stop» : List String := ["\n", "[/TAC]"]
deriving ToJson

structure GenerationOptionsQed where
  temperature : Float := 0.7
  numSamples : Nat := 10
  «stop» : List String := ["\n\n"]
deriving ToJson

structure OllamaTacticGenerationRequest where
  model : String
  prompt : String
  options : GenerationOptionsOllama
  raw : Bool := false
  stream : Bool := false
deriving ToJson

structure OllamaQedRequest where
  model : String
  prompt : String
  options : GenerationOptionsOllama
  raw : Bool := false
  stream : Bool := false
deriving ToJson

structure OllamaResponse where
  response : String
deriving FromJson

structure OpenAIMessage where
  role : String
  content : String
deriving FromJson, ToJson

structure OpenAIQedRequest where
  model : String
  messages : List OpenAIMessage
  n : Nat := 5
  temperature : Float := 0.7
  max_tokens : Nat := 512
  stream : Bool := false
  «stop» : List String := ["\n\n", "[/PROOF]"]
deriving ToJson

structure OpenAITacticGenerationRequest where
  model : String
  messages : List OpenAIMessage
  n : Nat := 5
  temperature : Float := 0.7
  max_tokens : Nat := 100
  stream : Bool := false
  «stop» : List String := ["[/TAC]"]
deriving ToJson

structure OpenAIChoice where
  message : OpenAIMessage
deriving FromJson

structure OpenAIResponse where
  id : String
  choices : List OpenAIChoice
deriving FromJson

def getPromptKind (stringArg: String) : PromptKind :=
  match stringArg with
  | "fewshot" => PromptKind.FewShot
  | "detailed" => PromptKind.Detailed
  | _ => PromptKind.Instruction

def getOllamaAPI : IO API := do
  let url        := (← IO.getEnv "LLMLEAN_ENDPOINT").getD "http://localhost:11434/api/generate"
  let model      := (← IO.getEnv "LLMLEAN_MODEL").getD "wellecks/ntpctx-llama3-8b"
  let promptKind := (← IO.getEnv "LLMLEAN_PROMPT").getD "instruction"
  let apiKey     := (← IO.getEnv "LLMLEAN_API_KEY").getD ""
  let api : API := {
    model := model,
    baseUrl := url,
    kind := APIKind.Ollama,
    promptKind := getPromptKind promptKind,
    key := apiKey
  }
  return api

def getTogetherAPI : IO API := do
  let url        := (← IO.getEnv "LLMLEAN_ENDPOINT").getD "https://api.together.xyz/v1/chat/completions"
  let model      := (← IO.getEnv "LLMLEAN_MODEL").getD "Qwen/Qwen2.5-72B-Instruct-Turbo"
  let promptKind := (← IO.getEnv "LLMLEAN_PROMPT").getD "detailed"
  let apiKey     := (← IO.getEnv "LLMLEAN_API_KEY").getD ""
  let api : API := {
    model := model,
    baseUrl := url,
    kind := APIKind.TogetherAI,
    promptKind := getPromptKind promptKind,
    key := apiKey
  }
  return api


def getOpenAIAPI : IO API := do
  let url        := (← IO.getEnv "LLMLEAN_ENDPOINT").getD "https://api.openai.com/v1/chat/completions"
  let model      := (← IO.getEnv "LLMLEAN_MODEL").getD "gpt-4o"
  let promptKind := (← IO.getEnv "LLMLEAN_PROMPT").getD "detailed"
  let apiKey     := (← IO.getEnv "LLMLEAN_API_KEY").getD ""
  let api : API := {
    model := model,
    baseUrl := url,
    kind := APIKind.OpenAI,
    promptKind := getPromptKind promptKind,
    key := apiKey
  }
  return api

def getAPI : IO API := do
  let apiKind  := (← IO.getEnv "LLMLEAN_API").getD "openai"
  match apiKind with
  | "ollama" => getOllamaAPI
  | "together" => getTogetherAPI
  | _ => getOpenAIAPI

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
Put the next tactic inside [TAC]...[/TAC].
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

def makePromptsDetailed (context : String) (state : String) (pre: String) : List String :=
  makePromptsInstruct context state pre

def makeQedPromptsFewShot (context : String) (state : String) : List String :=
  let p1 := context
  [p1]

def makeQedPromptsInstruct (context : String) (state : String) : List String :=
  let p1 := "/- You are proving a theorem in Lean 4.
You are given the following information:
- The current file contents up to and including the theorem statement, inside [CTX]...[/CTX]

Your task is to generate the proof.
Put the proof inside [PROOF]...[/PROOF]
-/
[CTX]
" ++ context ++ "
[/CTX]
[PROOF]"
  [p1]

def makeQedPromptsDetailed (context : String) (state : String) : List String :=
  let p1 := "/- You are proving a theorem in Lean 4.
You are given the following information:
- The file contents up to the current tactic, inside [CTX]...[/CTX]
- The current proof state, inside [STATE]...[/STATE]

Your task is to generate the rest of the proof.
Put the generation inside [PROOF]...[/PROOF].
If you find it helpful, you can precede the proof with brief thoughts inside [THOUGHTS]...[/THOUGHTS]
In summary, your output should be of the form:
[THOUGHTS]
...
[/THOUGHTS]
[PROOF]
...
[/PROOF]
Your proof will be checked by combining each line with a ; combinator and checking
the resulting combined tactic.
Therefore, make sure the proof is formatted as one tactic per line,
with no additional comments or text.
-/
[CTX]
" ++ context ++ "
[/CTX]
[STATE]
" ++ state ++ "
[/STATE]
"
  [p1]


def makePrompts (promptKind : PromptKind) (context : String) (state : String) (pre: String) : List String :=
  match promptKind with
  | PromptKind.FewShot => makePromptsFewShot context state pre
  | PromptKind.Detailed => makePromptsDetailed context state pre
  | _ => makePromptsInstruct context state pre


def makeQedPrompts (promptKind : PromptKind) (context : String) (state : String) : List String :=
  match promptKind with
  | PromptKind.FewShot => makeQedPromptsFewShot context state
  | PromptKind.Detailed => makeQedPromptsDetailed context state
  | _ => makeQedPromptsInstruct context state


def filterGeneration (s: String) : Bool :=
  let banned := ["sorry", "admit", "▅"]
  !(banned.any fun s' => (s.splitOn s').length > 1)

def splitTac (text : String) : String :=
  let text := text.replace "[TAC]" ""
  match (text.splitOn "[/TAC]").head? with
  | some s => s.trim
  | none => text.trim

def parseResponseOllama (res: OllamaResponse) : String :=
  splitTac res.response

def parseTacticResponseOpenAI (res: OpenAIResponse) (pfx : String) : Array String :=
  (res.choices.map fun x => pfx ++ (splitTac x.message.content)).toArray

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
      let res : OllamaResponse ← post req api.baseUrl api.key
      results := results.insert (pfx ++ (parseResponseOllama res))

  let finalResults := (results.toArray.filter filterGeneration).map fun x => (x, 1.0)
  return finalResults

def tacticGenerationOpenAI (pfx : String) (prompts : List String)
(api : API) (options : GenerationOptions) : IO $ Array (String × Float) := do
  let mut results : HashSet String := HashSet.empty
  for prompt in prompts do
    let req : OpenAITacticGenerationRequest := {
      model := api.model,
      messages := [
        {
          role := "user",
          content := prompt
        }
      ],
      n := options.numSamples,
      temperature := options.temperature
    }
    let res : OpenAIResponse ← post req api.baseUrl api.key
    for result in (parseTacticResponseOpenAI res pfx) do
      results := results.insert result

  let finalResults := (results.toArray.filter filterGeneration).map fun x => (x, 1.0)
  return finalResults

def splitProof (text : String) : String :=
  let text := ((text.splitOn "[PROOF]").tailD [text]).headD text
  match (text.splitOn "[/PROOF]").head? with
  | some s => s.trim
  | none => text.trim

def parseResponseQedOllama (res: OllamaResponse) : String :=
  splitProof res.response

def parseResponseQedOpenAI (res: OpenAIResponse) : Array String :=
  (res.choices.map fun x => (splitProof x.message.content)).toArray

def qedOllama (prompts : List String)
(api : API) (options : GenerationOptionsQed) : IO $ Array (String × Float) := do
  let mut results : HashSet String := HashSet.empty
  for prompt in prompts do
    for i in List.range options.numSamples do
      let temperature := if i == 1 then 0.0 else options.temperature
      let req : OllamaQedRequest := {
        model := api.model,
        prompt := prompt,
        stream := false,
        options := { temperature := temperature, stop := options.stop }
      }
      let res : OllamaResponse ← post req api.baseUrl api.key
      results := results.insert ((parseResponseQedOllama res))

  let finalResults := (results.toArray.filter filterGeneration).map fun x => (x, 1.0)
  return finalResults

def qedOpenAI (prompts : List String)
(api : API) (options : GenerationOptionsQed) : IO $ Array (String × Float) := do
  let mut results : HashSet String := HashSet.empty
  for prompt in prompts do
    let req : OpenAIQedRequest := {
      model := api.model,
      messages := [
        {
          role := "user",
          content := prompt
        }
      ],
      n := options.numSamples,
      temperature := options.temperature
    }
    let res : OpenAIResponse ← post req api.baseUrl api.key
    for result in (parseResponseQedOpenAI res) do
      results := results.insert result

  let finalResults := (results.toArray.filter filterGeneration).map fun x => (x, 1.0)
  return finalResults

def getGenerationOptions (api : API):  IO GenerationOptions := do
  let defaultSamples := match api.kind with
  | APIKind.Ollama => 5
  | _ => 32

  let defaultSamplesStr := match api.kind with
  | APIKind.Ollama => "5"
  | _ => "32"

  let numSamples := match ((← IO.getEnv "LLMLEAN_NUMSAMPLES").getD defaultSamplesStr).toInt? with
  | some n => n.toNat
  | none => defaultSamples

  let options : GenerationOptions := {
    numSamples := numSamples
  }
  return options

def getQedGenerationOptions (api : API): IO GenerationOptionsQed := do
  let options ← getGenerationOptions api
  let options : GenerationOptionsQed := {
    numSamples := options.numSamples
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
    tacticGenerationOpenAI «prefix» prompts api options
  | APIKind.OpenAI =>
    tacticGenerationOpenAI «prefix» prompts api options

def API.proofCompletion
  (api : API) (tacticState : String) (context : String) : IO $ Array (String × Float) := do
  let prompts := makeQedPrompts api.promptKind context tacticState
  let options ← getQedGenerationOptions api
  match api.kind with
  | APIKind.Ollama =>
    qedOllama prompts api options
  | APIKind.TogetherAI =>
    qedOpenAI prompts api options
  | APIKind.OpenAI =>
    qedOpenAI prompts api options

end LLMlean
