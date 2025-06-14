/- Common types and utilities for LLMlean API -/
import Lean
import LLMlean.Config

open Lean LLMlean.Config

namespace LLMlean

/-!
## Centralized default values
-/

def defaultMaxTokens : Nat := 1024
def defaultTemperature : Float := 0.7
def defaultOllamaSamples : Nat := 4
def defaultSamples : Nat := 32
def defaultStopTactic : List String := ["[/TAC]"]
def defaultStopProof : List String := ["[/PROOF]", "</think>"]
def defaultStopAll : List String := ["[/TAC]", "[/PROOF]", "</think>"]

/-!
## Ollama-specific structures (kept separate due to different API design)
-/
structure GenerationOptionsOllama where
  temperature : Float := defaultTemperature
  «stop» : List String := defaultStopAll
  -- Maximum number of tokens to generate.
  num_predict : Int := defaultMaxTokens
deriving ToJson

structure OllamaGenerationRequest where
  model : String
  prompt : String
  options : GenerationOptionsOllama
  raw : Bool := false
  stream : Bool := false
deriving ToJson

structure OllamaResponse where
  response : String
deriving FromJson

/-!
## Structures for chat-based APIs (OpenAI, Anthropic, Together)
-/
structure ChatGenerationOptions where
  temperature : Float := defaultTemperature
  maxTokens : Nat := defaultMaxTokens
  stopSequences : List String := defaultStopTactic
  numSamples : Nat := defaultSamples
deriving ToJson, FromJson

structure ChatGenerationOptionsQed where
  temperature : Float := defaultTemperature
  maxTokens : Nat := defaultMaxTokens
  stopSequences : List String := defaultStopProof
  numSamples : Nat := defaultSamples
deriving ToJson, FromJson

structure OpenAIMessage where
  role : String
  content : String
deriving FromJson, ToJson

structure OpenAIGenerationRequest where
  model : String
  messages : List OpenAIMessage
  n : Nat := 1
  temperature : Float := defaultTemperature
  max_tokens : Int := defaultMaxTokens
  stream : Bool := false
  «stop» : List String := defaultStopTactic
deriving ToJson

structure AnthropicGenerationRequest where
  model : String
  messages : List OpenAIMessage
  temperature : Float := defaultTemperature
  max_tokens : Nat := defaultMaxTokens
  stream : Bool := false
  stop_sequences : List String := defaultStopTactic
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

/-!
## Utility functions
-/

def getPromptKind (stringArg: String) : PromptKind :=
  match stringArg with
  | "fewshot" => PromptKind.FewShot
  | "reasoning" => PromptKind.Reasoning
  | "markdown" => PromptKind.MarkdownReasoning
  | _ => PromptKind.Instruction

def getResponseFormat (stringArg: String) : ResponseFormat :=
  match stringArg with
  | "markdown" => ResponseFormat.Markdown
  | _ => ResponseFormat.Standard

/-- Gets the configured API, with details coming either from environment variables or the contents of the `config.toml` file. -/
def getConfiguredAPI (tacticKind : TacticKind) : CoreM API := do
  -- Get API kind from config
  let apiKindStr := (← Config.getApiKind).getD "ollama"
  let some apiKind := Config.parseAPIKind apiKindStr
    | throwError s!"Unknown API kind: {apiKindStr}"
  
  -- Get defaults for this API and tactic combination
  let defaults := Config.getDefaultsForAPI apiKind tacticKind
  
  -- Override defaults with any configured values
  let url := (← Config.getEndpoint).getD defaults.endpoint
  let model := (← Config.getModel).getD defaults.model
  let apiKey := (← Config.getApiKey).getD ""
  
  -- Handle prompt kind
  let promptKindStr := (← Config.getPromptKind).getD ""
  let promptKind := if promptKindStr != "" then
    getPromptKind promptKindStr
  else
    defaults.promptKind
  
  -- Handle response format
  let responseFormatStr := (← Config.getResponseFormat).getD ""
  let responseFormat := if responseFormatStr != "" then
    getResponseFormat responseFormatStr
  else
    defaults.responseFormat
  
  let api : API := {
    model := model,
    baseUrl := url,
    kind := apiKind,
    promptKind := promptKind,
    responseFormat := responseFormat,
    key := apiKey
  }
  
  return api

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
Returns true if the string `s` contains any of the banned tactics, such as `sorry` and `admit`.
-/
def filterGeneration (s: String) : Bool :=
  let banned := ["sorry", "admit", "▅"]
  !(banned.any fun s' => (s.splitOn s').length > 1)

def getNumSamples (api : API) (tacticKind : TacticKind) : CoreM Nat := do
  -- Get defaults for this API and tactic
  let defaults := Config.getDefaultsForAPI api.kind tacticKind
  
  -- Check if mode is explicitly set
  let modeStr ← Config.getMode
  let mode := if modeStr == "iterative" then
    Config.GenerationMode.Iterative
  else if modeStr == "parallel" then
    Config.GenerationMode.Parallel
  else
    defaults.mode
  
  match mode with
  | Config.GenerationMode.Iterative =>
    -- In iterative mode, always use 1 sample
    return 1
  | Config.GenerationMode.Parallel =>
    -- In parallel mode, use configured samples or defaults
    match ← Config.getNumSamples with
    | none | some 0 => return defaults.numSamples
    | some n => return n

def getMaxTokens (api : API) (tacticKind : TacticKind) : CoreM Nat := do
  let defaults := Config.getDefaultsForAPI api.kind tacticKind
  match ← Config.getMaxTokens with
  | none | some 0 => return defaults.maxTokens
  | some n => return n

/-- Print configuration details in verbose mode -/
def printConfiguration (api : API) (tacticKind : TacticKind) (numSamples : Nat) (maxTokens : Nat) : CoreM Unit := do
  if ← Config.getVerbose then
    let mode ← Config.getModeEnum
    Config.verbosePrint s!"LLMlean Configuration:"
    Config.verbosePrint s!"  Tactic: {repr tacticKind}"
    Config.verbosePrint s!"  API: {repr api.kind}"
    Config.verbosePrint s!"  Model: {api.model}"
    Config.verbosePrint s!"  Endpoint: {api.baseUrl}"
    Config.verbosePrint s!"  Prompt Kind: {repr api.promptKind}"
    Config.verbosePrint s!"  Response Format: {repr api.responseFormat}"
    Config.verbosePrint s!"  Mode: {repr mode}"
    Config.verbosePrint s!"  Number of Samples: {numSamples}"
    Config.verbosePrint s!"  Max Tokens: {maxTokens}"

def getChatGenerationOptions (api : API) (tacticKind : TacticKind): CoreM ChatGenerationOptions := do
  let numSamples ← getNumSamples api tacticKind
  let maxTokens ← getMaxTokens api tacticKind
  -- Print configuration in verbose mode
  printConfiguration api tacticKind numSamples maxTokens
  return {
    numSamples := numSamples,
    temperature := defaultTemperature,
    maxTokens := maxTokens,
    stopSequences := defaultStopTactic
  }

def getChatGenerationOptionsQed (api : API) (tacticKind : TacticKind) : CoreM ChatGenerationOptionsQed := do
  let numSamples ← getNumSamples api tacticKind
  let maxTokens ← getMaxTokens api tacticKind
  -- Print configuration in verbose mode
  printConfiguration api tacticKind numSamples maxTokens
  return {
    numSamples := numSamples
    temperature := defaultTemperature,
    maxTokens := maxTokens,
    stopSequences := defaultStopProof
  }

/--
Parses a string consisting of Markdown text, and extracts the Lean code blocks.
The code blocks are enclosed in triple backticks.
The opening triple backticks may be followed by a language identifier "lean", "lean4", or "tactics".
The closing triple backticks should be followed by a newline.
-/
def getMarkdownLeanCodeBlocks (markdown : String) : List String := Id.run do
  let markdown := markdown.replace "```lean\n" "```lean4\n"
  let markdown := markdown.replace "```tactics\n" "```lean4\n"
  let parts := (markdown.splitOn "```lean4\n").tailD []
  let mut blocks : List String := []
  -- From each part, delete the closing triple backticks and after
  for part in parts do
    let part := part.splitOn "```"
    if part.length > 0 then
      blocks := blocks ++ [part.headD ""]
  return blocks

end LLMlean
