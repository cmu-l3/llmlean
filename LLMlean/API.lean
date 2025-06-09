/- Utilities for interacting with LLMlean API endpoints. -/
import Lean
import LLMlean.Config

open Lean LLMlean.Config

namespace LLMlean

structure GenerationOptionsOllama where
  /-- Temperature represents the level of randomness/creativity in the model output, higher being more random. -/
  temperature : Float := 0.7
  «stop» : List String := ["[/TAC]"]
  /-- Maximum number of tokens to generate. `-1` means no limit. -/
  num_predict : Int := 200
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

structure AnthropicQedRequest where
  model : String
  messages : List OpenAIMessage
  temperature : Float := 0.7
  max_tokens : Nat := 512
  stream : Bool := false
  stop_sequences : List String := ["[/PROOF]"]
deriving ToJson

structure AnthropicTacticGenerationRequest where
  model : String
  messages : List OpenAIMessage
  temperature : Float := 0.7
  max_tokens : Nat := 100
  stream : Bool := false
  stop_sequences : List String := ["[/TAC]"]
deriving ToJson

structure OpenAIChoice where
  message : OpenAIMessage
deriving FromJson

structure OpenAIResponse where
  id : String
  choices : List OpenAIChoice
deriving FromJson

structure AnthropicContent where
  text : String
deriving FromJson

structure AnthropicResponse where
  id : String
  content : List AnthropicContent
deriving FromJson

def getPromptKind (stringArg: String) : PromptKind :=
  match stringArg with
  | "fewshot" => PromptKind.FewShot
  | "detailed" => PromptKind.Reasoning
  | "reasoning" => PromptKind.Reasoning
  | "markdown" => PromptKind.MarkdownReasoning
  | _ => PromptKind.Instruction

def getResponseFormat (stringArg: String) : ResponseFormat :=
  match stringArg with
  | "markdown" => ResponseFormat.Markdown
  | _ => ResponseFormat.Standard


/-- Gets an Ollama API, with details coming either from environment variables or the contents of the `config.toml` file. -/
def getConfiguredOllamaAPI : CoreM API := do
  let url        := (← Config.getEndpoint).getD "http://localhost:11434/api/generate"
  let model      := (← Config.getModel).getD "wellecks/ntpctx-llama3-8b"
  let promptKind := (← Config.getPromptKind).getD "instruction"
  let apiKey     := (← Config.getApiKey).getD ""
  -- Get response format from config, or auto-detect based on model
  let responseFormatStr := (← Config.getResponseFormat).getD ""
  let responseFormat := if responseFormatStr != "" then
    getResponseFormat responseFormatStr
  else if model.startsWith "BoltonBailey/Kimina-Prover-Preview" then
    ResponseFormat.Markdown
  else
    ResponseFormat.Standard
  let api : API := {
    model := model,
    baseUrl := url,
    kind := APIKind.Ollama,
    promptKind := getPromptKind promptKind,
    responseFormat := responseFormat,
    key := apiKey
  }
  return api

/-- Gets a TogetherAI API, with details coming either from environment variables or the contents of the `config.toml` file. -/
def getConfiguredTogetherAPI : CoreM API := do
  let url        := (← Config.getEndpoint).getD "https://api.together.xyz/v1/chat/completions"
  let model      := (← Config.getModel).getD "Qwen/Qwen2.5-72B-Instruct-Turbo"
  let promptKind := (← Config.getPromptKind).getD "detailed"
  let apiKey     := (← Config.getApiKey).getD ""
  let api : API := {
    model := model,
    baseUrl := url,
    kind := APIKind.TogetherAI,
    promptKind := getPromptKind promptKind,
    key := apiKey
  }
  return api

/-- Gets an OpenAI API, with details coming either from environment variables or the contents of the `config.toml` file. -/
def getConfiguredOpenAIAPI : CoreM API := do
  let url        := (← Config.getEndpoint).getD "https://api.openai.com/v1/chat/completions"
  let model      := (← Config.getModel).getD "gpt-4o"
  let promptKind := (← Config.getPromptKind).getD "detailed"
  let apiKey     := (← Config.getApiKey).getD ""
  let api : API := {
    model := model,
    baseUrl := url,
    kind := APIKind.OpenAI,
    promptKind := getPromptKind promptKind,
    key := apiKey
  }
  return api

/-- Gets an Anthropic API, with details coming either from environment variables or the contents of the `config.toml` file. -/
def getConfiguredAnthropicAPI : CoreM API := do
  let url        := (← Config.getEndpoint).getD "https://api.anthropic.com/v1/messages"
  let model      := (← Config.getModel).getD "claude-3-7-sonnet-20250219"
  let promptKind := (← Config.getPromptKind).getD "detailed"
  let apiKey     := (← Config.getApiKey).getD ""
  let api : API := {
    model := model,
    baseUrl := url,
    kind := APIKind.Anthropic,
    promptKind := getPromptKind promptKind,
    key := apiKey
  }
  return api

/-- Gets the configured API, with details coming either from environment variables or the contents of the `config.toml` file. -/
def getConfiguredAPI : CoreM API := do
  let apiKind := (← Config.getApiKind).getD "ollama"
  match apiKind with
  | "ollama" => getConfiguredOllamaAPI
  | "together" => getConfiguredTogetherAPI
  | "anthropic" => getConfiguredAnthropicAPI
  | "openai" => getConfiguredOpenAIAPI
  | _ => getConfiguredOllamaAPI -- TODO: This should throw an error of some kind.

def post {α β : Type} [ToJson α] [FromJson β] (req : α) (url : String) (apiKey : String): IO β := do
  let out ← IO.Process.output {
    cmd := "curl"
    args := #[
      "-X", "POST", url,
      "-H", "accept: application/json",
      "-H", "Content-Type: application/json",
      "-H", "Authorization: Bearer " ++ apiKey,
      "-H", "x-api-key: " ++ apiKey,
      "-H", "anthropic-version: 2023-06-01",
      "-d", (toJson req).pretty UInt64.size]
  }
  if out.exitCode != 0 then
     throw $ IO.userError s!"Request failed. If running locally, ensure that ollama is running, and that the ollama server is up at `{url}`. If the ollama server is up at a different url, set LLMLEAN_URL to the proper url. If using a cloud API, ensure that LLMLEAN_API_KEY is set."
  let some json := Json.parse out.stdout |>.toOption
    | throw $ IO.userError out.stdout
  let some res := (fromJson? json : Except String β) |>.toOption
    | throw $ IO.userError out.stdout
  return res

/--
See `makePrompts`.
-/
def makePromptsFewShot (context : String) (state : String) (pre: String) : List String :=
  let p1 := s!"Given the Lean 4 tactic state, suggest a next tactic.
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
{state}
---
Next tactic:
---
{pre}"
  let p2 := match pre with
  | "" => context
  | _  => p1

  [p1, p2]

/--
See `makePrompts`.
-/
def makePromptsInstruct (context : String) (state : String) (pre: String) : List String :=
  let p1 := s!"/- You are proving a theorem in Lean 4.
You are given the following information:
- The file contents up to the current tactic, inside [CTX]...[/CTX]
- The current proof state, inside [STATE]...[/STATE]

Your task is to generate the next tactic in the proof.
Put the next tactic inside [TAC]...[/TAC].
-/
[CTX]
{context}
[/CTX]
[STATE]
{state}
[/STATE]
[TAC]
{pre}"
  [p1]

/--
See `makePrompts`.
-/
def makePromptsReasoning (context : String) (state : String) (pre: String) : List String :=
  let p1 := s!"/- You are proving a theorem in Lean 4.
You are given the following information:
- The file contents up to the current tactic, inside [CTX]...[/CTX]
- The current proof state, inside [STATE]...[/STATE]

Your task is to generate the next tactic in the proof.
Put the next tactic inside [TAC]...[/TAC].
If you find it helpful, you can precede the proof with brief thoughts inside [THOUGHTS]...[/THOUGHTS]
In summary, your output should be of the form:
[THOUGHTS]
...
[/THOUGHTS]
[TAC]
...
[/TAC]

[CTX]
{context}
[/CTX]
[STATE]
{state}
[/STATE]
[THOUGHTS]
{pre}"
  [p1]

/--
See `makePrompts`.
-/
def makePromptsMarkdownReasoning (context : String) (state : String) (pre: String) : List String :=
  let p1 := s!"/- You are proving a theorem in Lean 4.
You are given the following information:

The file contents up to the current tactic are as follows:

```lean4
{context}
```

The current proof state is as follows:
{state}

Your task is to generate the next tactic in the proof.
Generate this by writing a markdown file with the completed line, including the context of the file before it
in a markdown code block.

If you find it helpful, you can precede the proof with brief thoughts.
"
  match pre with
  | "" => [p1]
  | pre => [p1 ++ s!"The tactic you generate should start with {pre}"]

/--
See `makeQedPrompts`.
TODO implement
-/
def makeQedPromptsFewShot (context : String) (_state : String) : List String :=
  let p1 := context
  [p1]

/--
See `makeQedPrompts`.
-/
def makeQedPromptsInstruct (context : String) (_state : String) : List String :=
  let p1 := s!"/- You are proving a theorem in Lean 4.
You are given the following information:
- The current file contents up to and including the theorem statement, inside [CTX]...[/CTX]

Your task is to generate the proof.
Put the proof inside [PROOF]...[/PROOF]
-/
[CTX]
{context}
[/CTX]
[PROOF]"
  [p1]

/--
See `makeQedPrompts`.
-/
def makeQedPromptsReasoning (context : String) (state : String) : List String :=
  let p1 := s!"/- You are proving a theorem in Lean 4.
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
{context}
[/CTX]
[STATE]
{state}
[/STATE]
"
  [p1]

/--
See `makeQedPrompts`.
-/
def makeQedPromptsMarkdownReasoning (context : String) (state : String) : List String :=
  let p1 := s!"/- You are proving a theorem in Lean 4.

You are given the following information:
The file contents up to the current tactic are as follows:
```lean4
{context}
```
The current proof state is as follows:
{state}
Your task is to generate the proof.
Generate this by writing a markdown file with the completed line, including the context of the file before it
in a markdown code block.

For example, you can write something along the lines of
```tactics
{context}
<... your proof here...>
```

If you find it helpful, you can precede the proof with brief thoughts, outside the tactic blocks.
"
  [p1]

/--
Makes prompts for single tactic generation,
given a `context` containing the file contents up to the tactic invocation,
and a `state` containing the current proof state,
and a `pre` string containing the prefix of the tactic to be generated.
-/
def makePrompts (promptKind : PromptKind) (context : String) (state : String) (pre: String) : List String :=
  match promptKind with
  | PromptKind.FewShot => makePromptsFewShot context state pre
  | PromptKind.Reasoning => makePromptsReasoning context state pre
  | PromptKind.Instruction => makePromptsInstruct context state pre
  | PromptKind.MarkdownReasoning => makePromptsMarkdownReasoning context state pre


/--
Makes prompts for the complete proof generation,
given a `context` containing the file contents up to the tactic invocation,
and a `state` containing the current proof state.
-/
def makeQedPrompts (promptKind : PromptKind) (context : String) (state : String) : List String :=
  match promptKind with
  | PromptKind.FewShot => makeQedPromptsFewShot context state
  | PromptKind.Reasoning => makeQedPromptsReasoning context state
  | PromptKind.Instruction => makeQedPromptsInstruct context state
  | PromptKind.MarkdownReasoning => makeQedPromptsMarkdownReasoning context state

/--
Returns true if the string `s` contains any of the banned tactics, such as `sorry` and `admit`.
-/
def filterGeneration (s: String) : Bool :=
  let banned := ["sorry", "admit", "▅"]
  !(banned.any fun s' => (s.splitOn s').length > 1)

/--
Parses a tactic out of a response from the LLM.
The tactic is expected to be enclosed in `[TAC]...[/TAC]` tags.
-/
def splitTac (text : String) : String :=
  let text := ((text.splitOn "[TAC]").tailD [text]).headD text
  match (text.splitOn "[/TAC]").head? with
  | some s => s.trim
  | none => text.trim

def parseResponseOllama (res: OllamaResponse) : String :=
  splitTac res.response

/--
Parses a string consisting of Markdown text, and extracts the Lean code blocks.
The code blocks are enclosed in triple backticks.
The opening triple backticks may be followed by a language identifier "lean", "lean4", or "tactics".
The closing triple backticks should be followed by a newline.
-/
def getMarkdownLeanCodeBlocks (markdown : String) : List String := Id.run do
  -- Replace all instances of "lean" with "lean4"
  let markdown := markdown.replace "```lean\n" "```lean4\n"
  -- Replace all instances of "tactics" with "lean4"
  let markdown := markdown.replace "```tactics\n" "```lean4\n"
  -- Split the markdown by opening triple backticks
  let parts := (markdown.splitOn "```lean4\n").tailD []
  let mut blocks : List String := []
  -- From each part, delete the closing triple backticks and after
  for part in parts do
    let part := part.splitOn "```"
    if part.length > 0 then
      blocks := blocks ++ [part.headD ""]
  return blocks

/--
Given a code block and a context, returns the first line of the code block after the context is written out.
-/
def getTacticFromBlockContext (context : String) (block : String) : String := Id.run do
  -- Get the trimmed last nonempty nonwhitespace line of the context
  let last_context := (((context.splitOn "\n").filter (fun x => x.trim.length > 0)).getLast?.getD "").trim

  -- Trim every line of the block
  let block := "\n".intercalate ((block.splitOn "\n").map (fun x => x.trim))

  let post_context := (block.splitOn last_context)[1]?.getD ""
  if post_context.length > 0 then
    -- get the first nonempty nonwhitespace line of the post_context
    let tactic := ((post_context.splitOn "\n").filter (fun x => x.trim.length > 0)).getLast?.getD ""
    return tactic.trim
  else
    return s!"Did not find context: \n\n{context}\n\n in \n\n{block}\n\n"

def parseResponseOllamaKimina (_context : String) (res: OllamaResponse) : List String := Id.run do
  -- Debug: log the raw response
  dbg_trace s!"Kimina raw response: {res.response}"
  let blocks := getMarkdownLeanCodeBlocks res.response
  dbg_trace s!"Found {blocks.length} code blocks"
  let mut results : List String := []
  for block in blocks do
    for line in (block.splitOn "\n") do
      if line.trim.length > 0 then
        results := results ++ [line.trim]
  dbg_trace s!"Parsed tactics: {results}"
  return results

def parseTacticResponseOpenAI (res: OpenAIResponse) (pfx : String) : Array String :=
  (res.choices.map fun x => pfx ++ (splitTac x.message.content)).toArray

def parseTacticResponseAnthropic (res: AnthropicResponse) (pfx : String) : Array String :=
  (res.content.map fun x => pfx ++ (splitTac x.text)).toArray

def tacticGenerationOllamaKimina (_pfx : String) (context : String) (prompts : List String)
(api : API) (options : GenerationOptions) : IO $ Array (String × Float) := do
  let mut results : Std.HashSet String := Std.HashSet.emptyWithCapacity
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
      for tactic in (parseResponseOllamaKimina context res) do
        results := results.insert (tactic)

  let finalResults := (results.toArray.filter filterGeneration).map fun x => (x, 1.0)
  return finalResults

def tacticGenerationOllama (pfx : String) (prompts : List String)
(api : API) (options : GenerationOptions) : IO $ Array (String × Float) := do
  let mut results : Std.HashSet String := Std.HashSet.emptyWithCapacity
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
  let mut results : Std.HashSet String := Std.HashSet.emptyWithCapacity
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

def tacticGenerationAnthropic (pfx : String) (prompts : List String)
(api : API) (options : GenerationOptions) : IO $ Array (String × Float) := do
  let mut results : Std.HashSet String := Std.HashSet.emptyWithCapacity
  for prompt in prompts do
    for i in List.range options.numSamples do
      let temperature := if i == 1 then 0.0 else options.temperature
      let req : AnthropicTacticGenerationRequest := {
        model := api.model,
        messages := [
          {
            role := "user",
            content := prompt
          }
        ],
        temperature := temperature
      }
      let res : AnthropicResponse ← post req api.baseUrl api.key
      for result in (parseTacticResponseAnthropic res pfx) do
        results := results.insert result

  let finalResults := (results.toArray.filter filterGeneration).map fun x => (x, 1.0)
  return finalResults

/--
Parses a proof out of a response from the LLM.
The proof is expected to be enclosed in `[PROOF]...[/PROOF]` tags.
-/
def splitProof (text : String) : String :=
  let text := ((text.splitOn "[PROOF]").tailD [text]).headD text
  match (text.splitOn "[/PROOF]").head? with
  | some s => s.trim
  | none => text.trim

def parseResponseQedOllama (res: OllamaResponse) : String :=
  splitProof res.response

def parseResponseQedOpenAI (res: OpenAIResponse) : Array String :=
  (res.choices.map fun x => (splitProof x.message.content)).toArray

def parseResponseQedAnthropic (res: AnthropicResponse) : Array String :=
  (res.content.map fun x => (splitProof x.text)).toArray

/--
A function that assumes the LLM will repeat the context before the proof.
-/
def parseResponseQed_from_context (context : String) (res : OllamaResponse) : String :=
  "aaa" ++ ((res.response.splitOn (sep := context))[1]?.getD "")

def qedOllama (prompts : List String)
(api : API) (options : GenerationOptionsQed) : IO $ Array (String × Float) := do
  let mut results : Std.HashSet String := Std.HashSet.emptyWithCapacity
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

def qedOllamaKimina (prompts : List String) (context : String)
(api : API) (options : GenerationOptionsQed) : IO $ Array (String × Float) := do
  let mut results : Std.HashSet String := Std.HashSet.emptyWithCapacity
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
      results := results.insert ((parseResponseQed_from_context context res))

  let finalResults := (results.toArray.filter filterGeneration).map fun x => (x, 1.0)
  return finalResults

def qedOpenAI (prompts : List String)
(api : API) (options : GenerationOptionsQed) : IO $ Array (String × Float) := do
  let mut results : Std.HashSet String := Std.HashSet.emptyWithCapacity
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

def qedAnthropic (prompts : List String)
(api : API) (options : GenerationOptionsQed) : IO $ Array (String × Float) := do
  let mut results : Std.HashSet String := Std.HashSet.emptyWithCapacity
  for prompt in prompts do
    for i in List.range options.numSamples do
      let temperature := if i == 1 then 0.0 else options.temperature
      let req : AnthropicQedRequest := {
        model := api.model,
        messages := [
          {
            role := "user",
            content := prompt
          }
        ],
        temperature := temperature
      }
      let res : AnthropicResponse ← post req api.baseUrl api.key
      for result in (parseResponseQedAnthropic res) do
        results := results.insert result

  let finalResults := (results.toArray.filter filterGeneration).map fun x => (x, 1.0)
  return finalResults

def getGenerationOptions (api : API) : CoreM GenerationOptions := do
  let defaultSamples := match api.kind with
  | APIKind.Ollama => 5
  | _ => 32

  let numSamples := match ← Config.getNumSamples with
  | none | some 0 => defaultSamples
  | some n => n

  let options : GenerationOptions := {
    numSamples := numSamples
  }
  return options

def getQedGenerationOptions (api : API): CoreM GenerationOptionsQed := do
  let options ← getGenerationOptions api
  let options : GenerationOptionsQed := {
    numSamples := options.numSamples
  }
  return options

/--
Generates a list of tactics using the LLM API.
-/
def LLMlean.Config.API.tacticGeneration
  (api : API) (tacticState : String) (context : String)
  («prefix» : String) : CoreM $ Array (String × Float) := do
  let prompts := makePrompts api.promptKind context tacticState «prefix»
  let options ← getGenerationOptions api
  match api.responseFormat with
  | ResponseFormat.Markdown =>
    tacticGenerationOllamaKimina «prefix» context prompts api options
  | ResponseFormat.Standard =>
    match api.kind with
    | APIKind.Ollama =>
      tacticGenerationOllama «prefix» prompts api options
    | APIKind.TogetherAI =>
      tacticGenerationOpenAI «prefix» prompts api options
    | APIKind.OpenAI =>
      tacticGenerationOpenAI «prefix» prompts api options
    | APIKind.Anthropic =>
      tacticGenerationAnthropic «prefix» prompts api options

def LLMlean.Config.API.proofCompletion
  (api : API) (tacticState : String) (context : String) : CoreM $ Array (String × Float) := do
  let prompts := makeQedPrompts api.promptKind context tacticState
  let options ← getQedGenerationOptions api
  match api.responseFormat with
  | ResponseFormat.Markdown =>
    qedOllamaKimina prompts context api options
  | ResponseFormat.Standard =>
    match api.kind with
    | APIKind.Ollama =>
      qedOllama prompts api options
    | APIKind.TogetherAI =>
      qedOpenAI prompts api options
    | APIKind.OpenAI =>
      qedOpenAI prompts api options
    | APIKind.Anthropic =>
      qedAnthropic prompts api options

end LLMlean
