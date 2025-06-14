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
  let promptKind := (← Config.getPromptKind).getD "reasoning"
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
  let promptKind := (← Config.getPromptKind).getD "reasoning"
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
  let promptKind := (← Config.getPromptKind).getD "reasoning"
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
Returns true if the string `s` contains any of the banned tactics, such as `sorry` and `admit`.
-/
def filterGeneration (s: String) : Bool :=
  let banned := ["sorry", "admit", "▅"]
  !(banned.any fun s' => (s.splitOn s').length > 1)

def getNumSamples (api : API) : CoreM Nat := do
  -- Check if we're in iterative mode
  let mode ← Config.getModeEnum
  match mode with
  | Config.GenerationMode.Iterative =>
    -- In iterative mode, always use 1 sample
    return 1
  | Config.GenerationMode.Parallel =>
    -- In parallel mode, use configured samples
    let apiDefaultSamples := match api.kind with
    | APIKind.Ollama => defaultOllamaSamples
    | _ => defaultSamples

    match ← Config.getNumSamples with
    | none | some 0 => return apiDefaultSamples
    | some n => return n

def getMaxTokens : CoreM Nat := do
  match ← Config.getMaxTokens with
  | none | some 0 => return defaultMaxTokens
  | some n => return n

def getChatGenerationOptions (api : API): CoreM ChatGenerationOptions := do
  let numSamples ← getNumSamples api
  let maxTokens ← getMaxTokens
  return {
    numSamples := numSamples,
    temperature := defaultTemperature,
    maxTokens := maxTokens,
    stopSequences := defaultStopTactic
  }

def getChatGenerationOptionsQed (api : API) : CoreM ChatGenerationOptionsQed := do
  let numSamples ← getNumSamples api
  let maxTokens ← getMaxTokens
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
