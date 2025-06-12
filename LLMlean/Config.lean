/- Configuring LLMLean -/
import Lean
import Lake.Toml
import Lake.Toml.Decode
open Lean

namespace LLMlean.Config

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

/-!
## Data Structures for configuration options
-/

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

end LLMlean.Config
