/- Configuring LLMLean -/
import Lean
import Lake.Toml
import Lake.Toml.Decode
open Lean

namespace LLMlean.Config

/-- Default maximum iterations for iterative refinement mode -/
def defaultMaxIterations : Nat := 3

-- Register trace class for LLMlean
initialize registerTraceClass `llmlean


register_option llmlean.api : String := {
  defValue := "",
  descr := "If set, LLM API kind (e.g. openai, ollama, together)"
}

register_option llmlean.endpoint : String := {
  defValue := "",
  descr := "If set, URL endpoint of the LLM service."
}

register_option llmlean.model : String := {
  defValue := "",
  descr := "If set, model name of the LLM"
}

register_option llmlean.prompt : String := {
  defValue := "",
  descr := "If set, prompt kind for the LLM (e.g. fewshot, reasoning, instruction)"
}

register_option llmlean.apiKey : String := {
  defValue := "",
  descr := "If set, API key for the LLM service"
}

register_option llmlean.numSamples : Nat := {
  defValue := 0,
  descr := "If nonzero, number of samples to send to LLM API"
}

register_option llmlean.maxTokens : Nat := {
  defValue := 0,
  descr := "If nonzero, maximum number of tokens parameter for the LLM API"
}

register_option llmlean.responseFormat : String := {
  defValue := "",
  descr := "If set, response format for the LLM (e.g. standard, markdown)"
}

register_option llmlean.mode : String := {
  defValue := "iterative",
  descr := "Generation mode: 'parallel' (generate multiple samples) or 'iterative' (refine on errors)"
}

register_option llmlean.maxIterations : Nat := {
  defValue := defaultMaxIterations,
  descr := s!"Maximum refinement iterations in iterative mode (default: {defaultMaxIterations})"
}


def getConfigPath : IO (Option System.FilePath) := do
  let home ← IO.getEnv "HOME"
  let appData ← IO.getEnv "APPDATA"
  if System.Platform.isWindows then
    if let some appData := appData then
      return (appData : System.FilePath)/"llmlean"/"config.toml"
  if let some home := home then
    return (home : System.FilePath)/".config"/"llmlean"/"config.toml"
  return none

open Lake.Toml in
def getConfigTable : IO (Option Lake.Toml.Table) := do
  let some configPath ← getConfigPath | return none
  if ← configPath.pathExists then
    let configSrc ← IO.FS.readFile configPath
    match ← loadToml (Parser.mkInputContext configSrc configPath.toString) |>.toIO' with
    | .ok table => return some table
    | .error log => do
        log.forM fun msg => do
          IO.throwServerError (← msg.toString)
        return none
  else
    return none

open Lake Toml

/-- Access a value from the `config.toml` file, or print errors. -/
def getFromConfigFile (key : Name) : IO (Option String) := do
  let table ← getConfigTable
  let table := table.get!
  let result := EStateM.run (s := #[]) do
    let value : Option String ← table.decode? key
    return value
  match result with
  | .ok value errors => do
    for e in errors do IO.eprintln e.msg
    return value
  | .error () errors => do
    for e in errors do IO.eprintln e.msg
    return none

def getApiKind : CoreM (Option String) := do
  match llmlean.api.get (← getOptions) with
  | "" =>
    match ← IO.getEnv "LLMLEAN_API" with
    | none => getFromConfigFile `api
    | some api => return some api
  | api => return some api

def getEndpoint : CoreM (Option String) := do
  match llmlean.endpoint.get (← getOptions) with
  | "" =>
    match ← IO.getEnv "LLMLEAN_ENDPOINT" with
    | none => getFromConfigFile `endpoint
    | some endpoint => return some endpoint
  | endpoint => return some endpoint

def getModel : CoreM (Option String) := do
  match llmlean.model.get (← getOptions) with
  | "" =>
    match ← IO.getEnv "LLMLEAN_MODEL" with
    | none => getFromConfigFile `model
    | some model => return some model
  | model => return some model

def getPromptKind : CoreM (Option String) := do
  match llmlean.prompt.get (← getOptions) with
  | "" =>
    match ← IO.getEnv "LLMLEAN_PROMPT" with
    | none => getFromConfigFile `prompt
    | some prompt => return some prompt
  | prompt => return some prompt

def getApiKey : CoreM (Option String) := do
  match llmlean.apiKey.get (← getOptions) with
  | "" =>
    match ← IO.getEnv "LLMLEAN_API_KEY" with
    | none => getFromConfigFile `apiKey
    | some apiKey => return some apiKey
  | apiKey => return some apiKey

def getNumSamples : CoreM (Option Nat) := do
  match llmlean.numSamples.get (← getOptions) with
  | 0 =>
    match ← IO.getEnv "LLMLEAN_NUM_SAMPLES" with
    | none => Option.map String.toNat! <$> getFromConfigFile `numSamples
    | some numSamples => return numSamples.toNat?
  | numSamples => return some numSamples

def getMaxTokens : CoreM (Option Nat) := do
  match llmlean.maxTokens.get (← getOptions) with
  | 0 =>
    match ← IO.getEnv "LLMLEAN_MAX_TOKENS" with
    | none => Option.map String.toNat! <$> getFromConfigFile `maxTokens
    | some maxTokens => return maxTokens.toNat?
  | maxTokens => return some maxTokens

def getResponseFormat : CoreM (Option String) := do
  match llmlean.responseFormat.get (← getOptions) with
  | "" =>
    match ← IO.getEnv "LLMLEAN_RESPONSE_FORMAT" with
    | none => getFromConfigFile `responseFormat
    | some responseFormat => return some responseFormat
  | responseFormat => return some responseFormat

def getMode : CoreM String := do
  let modeStr ← match llmlean.mode.get (← getOptions) with
  | "" =>
    match ← IO.getEnv "LLMLEAN_MODE" with
    | none =>
      match ← getFromConfigFile `mode with
      | none => pure "parallel"
      | some mode => pure mode
    | some mode => pure mode
  | mode => pure mode

  match modeStr with
  | "parallel" => return "parallel"
  | "iterative" => return "iterative"
  | mode =>
    logWarning s!"Invalid mode '{mode}', using 'parallel'"
    return "parallel"

def getMaxIterations : CoreM Nat := do
  let optValue := llmlean.maxIterations.get (← getOptions)
  -- Check if it's the default value (which means not explicitly set)
  if optValue == defaultMaxIterations then
    -- Try environment variable first
    match ← IO.getEnv "LLMLEAN_MAX_ITERATIONS" with
    | some maxIterations => return maxIterations.toNat!
    | none =>
      -- Then try config file
      match ← getFromConfigFile `maxIterations with
      | some n => return n.toNat!
      | none => return defaultMaxIterations
  else
    -- Use the explicitly set value
    return optValue


/-!
## Data Structures for configuration options
-/

inductive GenerationMode : Type
  | Parallel     -- Generate multiple samples in parallel
  | Iterative    -- Generate one sample, refine on errors
  deriving Inhabited, Repr, BEq

inductive APIKind : Type
  | Ollama
  | TogetherAI
  | OpenAI
  | Anthropic
  deriving Inhabited, Repr

inductive PromptKind : Type
  | FewShot
  | Instruction
  | Reasoning
  | MarkdownReasoning
  deriving Inhabited, Repr

inductive ResponseFormat : Type
  | Standard     -- [TAC]...[/TAC] and [PROOF]...[/PROOF] format
  | Markdown     -- ```lean4...``` format
  deriving Inhabited, Repr

structure API where
  model : String
  baseUrl : String
  kind : APIKind := .Ollama
  promptKind : PromptKind := .FewShot
  responseFormat : ResponseFormat := .Standard
  key : String := ""
deriving Inhabited, Repr

def getModeEnum : CoreM GenerationMode := do
  let modeStr ← getMode
  match modeStr with
  | "parallel" => return GenerationMode.Parallel
  | "iterative" => return GenerationMode.Iterative
  | _ => return GenerationMode.Parallel

register_option llmlean.verbose : Bool := {
  defValue := false,
  descr := "Enable verbose output for LLM interactions and iterative refinement"
}

def getVerbose : CoreM Bool := do
  if llmlean.verbose.get (← getOptions) then
    return true
  else
    match ← IO.getEnv "LLMLEAN_VERBOSE" with
    | some "true" | some "1" => return true
    | _ =>
      match ← getFromConfigFile `verbose with
      | some "true" | some "1" => return true
      | _ => return false

/-- Print a verbose message using trace if verbose mode is enabled -/
def verbosePrint (msg : String) : CoreM Unit := do
  if ← getVerbose then
    -- Temporarily enable the trace option and use trace
    withOptions (fun opts => opts.setBool `trace.llmlean true) do
      trace[llmlean] msg

/-!
## Tactic Kind
-/

inductive TacticKind : Type
  | LLMStep   -- For llmstep tactic (single-step suggestions)
  | LLMQed    -- For llmqed tactic (full proof generation)
  deriving Inhabited, Repr, BEq

/-!
## Default Values for APIs based on Tactic
-/

/-- Default configuration for each API -/
structure APIDefaults where
  model : String
  mode : GenerationMode
  promptKind : PromptKind
  responseFormat : ResponseFormat
  numSamples : Nat
  maxTokens : Nat
  endpoint : String
  deriving Inhabited, Repr

/-- Get default configuration based on API kind and tactic kind -/
def getDefaultsForAPI (apiKind : APIKind) (tactic : TacticKind) : APIDefaults :=
  match apiKind, tactic with
  -- Ollama defaults
  | APIKind.Ollama, TacticKind.LLMStep => {
      model := "wellecks/ntpctx-llama3-8b"
      mode := GenerationMode.Parallel
      promptKind := PromptKind.Instruction
      responseFormat := ResponseFormat.Standard
      numSamples := 4
      maxTokens := 128
      endpoint := "http://localhost:11434/api/generate"
    }
  | APIKind.Ollama, TacticKind.LLMQed => {
      model := "wellecks/ntpctx-llama3-8b"
      mode := GenerationMode.Iterative
      promptKind := PromptKind.Instruction
      responseFormat := ResponseFormat.Standard
      numSamples := 1
      maxTokens := 256
      endpoint := "http://localhost:11434/api/generate"
    }
  -- OpenAI defaults
  | APIKind.OpenAI, TacticKind.LLMStep => {
      model := "gpt-4o"
      mode := GenerationMode.Parallel
      promptKind := PromptKind.Reasoning
      responseFormat := ResponseFormat.Standard
      numSamples := 16
      maxTokens := 512
      endpoint := "https://api.openai.com/v1/chat/completions"
    }
  | APIKind.OpenAI, TacticKind.LLMQed => {
      model := "gpt-4o"
      mode := GenerationMode.Parallel
      promptKind := PromptKind.Reasoning
      responseFormat := ResponseFormat.Standard
      numSamples := 16
      maxTokens := 2048
      endpoint := "https://api.openai.com/v1/chat/completions"
    }
  -- Anthropic defaults
  | APIKind.Anthropic, TacticKind.LLMStep => {
      model := "claude-sonnet-4-20250514"
      mode := GenerationMode.Parallel
      promptKind := PromptKind.Reasoning
      responseFormat := ResponseFormat.Standard
      numSamples := 1
      maxTokens := 512
      endpoint := "https://api.anthropic.com/v1/messages"
    }
  | APIKind.Anthropic, TacticKind.LLMQed => {
      model := "claude-opus-4-20250514"
      mode := GenerationMode.Iterative
      promptKind := PromptKind.Reasoning
      responseFormat := ResponseFormat.Standard
      numSamples := 1
      maxTokens := 2048
      endpoint := "https://api.anthropic.com/v1/messages"
    }
  -- Together defaults
  | APIKind.TogetherAI, TacticKind.LLMStep => {
      model := "Qwen/Qwen2.5-72B-Instruct-Turbo"
      mode := GenerationMode.Parallel
      promptKind := PromptKind.Reasoning
      responseFormat := ResponseFormat.Standard
      numSamples := 32
      maxTokens := 512
      endpoint := "https://api.together.xyz/v1/chat/completions"
    }
  | APIKind.TogetherAI, TacticKind.LLMQed => {
      model := "Qwen/Qwen2.5-72B-Instruct-Turbo"
      mode := GenerationMode.Parallel
      promptKind := PromptKind.Reasoning
      responseFormat := ResponseFormat.Standard
      numSamples := 1
      maxTokens := 1024
      endpoint := "https://api.together.xyz/v1/chat/completions"
    }

/-- Parse API kind from string -/
def parseAPIKind (apiStr : String) : Option APIKind :=
  match apiStr.toLower with
  | "ollama" => some APIKind.Ollama
  | "openai" => some APIKind.OpenAI
  | "anthropic" => some APIKind.Anthropic
  | "together" => some APIKind.TogetherAI
  | _ => none

end LLMlean.Config
