module
public import Lean
public import Lake.Toml
public import Lake.Toml.Decode

public section

open Lean

namespace LLMlean.Config

register_option llmlean.provider : String := {
  defValue := "openai", descr := "Connection preset: openai (default), openrouter, or local."
}
register_option llmlean.model : String := {
  defValue := "", descr := "Model identifier. Defaults to gpt-6-luna for OpenAI or a quantized model for local."
}
register_option llmlean.baseUrl : String := {
  defValue := "", descr := "API base URL, including /v1 but excluding /responses."
}
register_option llmlean.attempts : Nat := {
  defValue := 3, descr := "Maximum generation/check attempts per invocation."
}
register_option llmlean.maxOutputTokens : Nat := {
  defValue := 4096, descr := "Maximum output tokens per request, including reasoning."
}
register_option llmlean.reasoningEffort : String := {
  defValue := "default", descr := "Reasoning effort: default, none, minimal, low, medium, high, or xhigh. Support depends on the model/server."
}
register_option llmlean.timeoutSeconds : Nat := {
  defValue := 90, descr := "Wall-clock budget for an invocation."
}
register_option llmlean.verbose : Bool := {
  defValue := false, descr := "Show generation/check progress."
}

register_option llmlean.contextMode : String := {
  defValue := "structured", descr := "Context: structured, window, full, or all_files (prefix and imported project sources)."
}
register_option llmlean.historyChars : Nat := {
  defValue := 6000, descr := "Maximum Unicode characters of source/proof history; zero disables it."
}
register_option llmlean.premiseChars : Nat := {
  defValue := 16000, descr := "Maximum characters of earlier and imported declaration summaries."
}
register_option llmlean.notationChars : Nat := {
  defValue := 4000, descr := "Maximum characters of notation explanations."
}
register_option llmlean.repairChars : Nat := {
  defValue := 6000, descr := "Maximum characters of the latest failed attempt and feedback."
}
register_option llmlean.definitionChars : Nat := {
  defValue := 1200, descr := "Maximum characters of a definition body; larger bodies are omitted."
}

def defaultModel : String := "gpt-6-luna"
def defaultLocalModel : String := "qwen3.5:9b-q4_K_M"

/-- Preserve absence, including for booleans and default-valued overrides. -/
structure Overrides where
  provider : Option String := none
  model : Option String := none
  baseUrl : Option String := none
  attempts : Option Nat := none
  maxOutputTokens : Option Nat := none
  reasoningEffort : Option String := none
  timeoutSeconds : Option Nat := none
  verbose : Option Bool := none
  contextMode : Option String := none
  historyChars : Option Nat := none
  premiseChars : Option Nat := none
  notationChars : Option Nat := none
  repairChars : Option Nat := none
  definitionChars : Option Nat := none
  deriving Inhabited, Repr

/-- Secrets are excluded from printable settings. Every preset uses Responses. -/
structure Settings where
  provider : String := "openai"
  model : String := defaultModel
  baseUrl : String := "https://api.openai.com/v1"
  apiKeyEnv : String := "OPENAI_API_KEY"
  attempts : Nat := 3
  maxOutputTokens : Nat := 4096
  reasoningEffort : String := "default"
  timeoutSeconds : Nat := 90
  verbose : Bool := false
  contextMode : String := "structured"
  historyChars : Nat := 6000
  premiseChars : Nat := 16000
  notationChars : Nat := 4000
  repairChars : Nat := 6000
  definitionChars : Nat := 1200
  deriving Inhabited, Repr

def Settings.responsesUrl (s : Settings) : String := s.baseUrl ++ "/responses"

private def pick (high low : Overrides) : Overrides := {
  provider := high.provider.or low.provider
  model := high.model.or low.model
  baseUrl := high.baseUrl.or low.baseUrl
  attempts := high.attempts.or low.attempts
  maxOutputTokens := high.maxOutputTokens.or low.maxOutputTokens
  reasoningEffort := high.reasoningEffort.or low.reasoningEffort
  timeoutSeconds := high.timeoutSeconds.or low.timeoutSeconds
  verbose := high.verbose.or low.verbose
  contextMode := high.contextMode.or low.contextMode
  historyChars := high.historyChars.or low.historyChars
  premiseChars := high.premiseChars.or low.premiseChars
  notationChars := high.notationChars.or low.notationChars
  repairChars := high.repairChars.or low.repairChars
  definitionChars := high.definitionChars.or low.definitionChars
}

def fromOptions (opts : Options) : Overrides := {
  provider := opts.get? `llmlean.provider
  model := opts.get? `llmlean.model
  baseUrl := opts.get? `llmlean.baseUrl
  attempts := opts.get? `llmlean.attempts
  maxOutputTokens := opts.get? `llmlean.maxOutputTokens
  reasoningEffort := opts.get? `llmlean.reasoningEffort
  timeoutSeconds := opts.get? `llmlean.timeoutSeconds
  verbose := opts.get? `llmlean.verbose
  contextMode := opts.get? `llmlean.contextMode
  historyChars := opts.get? `llmlean.historyChars
  premiseChars := opts.get? `llmlean.premiseChars
  notationChars := opts.get? `llmlean.notationChars
  repairChars := opts.get? `llmlean.repairChars
  definitionChars := opts.get? `llmlean.definitionChars
}

/-- Explicit Lean options > environment > config file > defaults. -/
def resolve (file env : Overrides := {}) (opts : Options := {}) : Except String Settings := do
  let o := pick (fromOptions opts) (pick env file)
  let provider := o.provider.getD "openai"
  let (baseUrl, keyEnv) ← match provider with
    | "local" => pure ("http://localhost:11434/v1", "LLMLEAN_API_KEY")
    | "openai" => pure ("https://api.openai.com/v1", "OPENAI_API_KEY")
    | "openrouter" => pure ("https://openrouter.ai/api/v1", "OPENROUTER_API_KEY")
    | _ => throw "provider must be local, openrouter, or openai"
  let model ← match o.model with
    | some model => pure model.trimAscii.toString
    | none =>
      match provider with
      | "openai" => pure defaultModel
      | "local" => pure defaultLocalModel
      | _ => throw s!"Set model for provider '{provider}'."
  if model.isEmpty then throw "model must not be empty"
  let baseUrl := (o.baseUrl.getD baseUrl).trimAscii.toString
  let baseUrl := (baseUrl.dropEndWhile (· == '/')).toString
  if !(baseUrl.startsWith "http://" || baseUrl.startsWith "https://") ||
      baseUrl.toList.any Char.isWhitespace then
    throw "base_url must be an http:// or https:// API base URL"
  if baseUrl.endsWith "/responses" || baseUrl.endsWith "/chat/completions" ||
      baseUrl.endsWith "/api/generate" then
    throw "base_url must exclude the endpoint path; for Ollama use http://localhost:11434/v1"
  let settings : Settings := {
    provider, model, baseUrl, apiKeyEnv := keyEnv
    attempts := o.attempts.getD 3
    maxOutputTokens := o.maxOutputTokens.getD 4096
    reasoningEffort := o.reasoningEffort.getD "default"
    timeoutSeconds := o.timeoutSeconds.getD 90
    verbose := o.verbose.getD false
    contextMode := o.contextMode.getD "structured"
    historyChars := o.historyChars.getD 6000
    premiseChars := o.premiseChars.getD 16000
    notationChars := o.notationChars.getD 4000
    repairChars := o.repairChars.getD 6000
    definitionChars := o.definitionChars.getD 1200
  }
  if settings.attempts == 0 then throw "attempts must be a positive integer"
  if settings.maxOutputTokens == 0 then throw "max_output_tokens must be a positive integer"
  if settings.timeoutSeconds == 0 then throw "timeout_seconds must be a positive integer"
  unless #["default", "none", "minimal", "low", "medium", "high", "xhigh"].contains settings.reasoningEffort do
    throw "reasoning_effort must be default, none, minimal, low, medium, high, or xhigh"
  unless #["structured", "window", "full", "all_files"].contains settings.contextMode do
    throw "context_mode must be structured, window, full, or all_files"
  return settings

open Lake Toml in
def decodeTable (table : Table) : Except String Overrides := do
  let known := #[`provider, `model, `base_url, `attempts, `max_output_tokens, `reasoning_effort,
    `timeout_seconds, `verbose, `context_mode, `history_chars, `premise_chars, `notation_chars,
    `repair_chars, `definition_chars]
  for (key, _) in table.items do
    unless known.contains key do
      throw s!"Unsupported configuration key '{key}'. LLMLean now uses provider/model/base_url and Responses. See docs/migration.md."
  let decode : EDecodeM Overrides := do
    return {
      provider := ← table.decode? `provider
      model := ← table.decode? `model
      baseUrl := ← table.decode? `base_url
      attempts := ← table.decode? `attempts
      maxOutputTokens := ← table.decode? `max_output_tokens
      reasoningEffort := ← table.decode? `reasoning_effort
      timeoutSeconds := ← table.decode? `timeout_seconds
      verbose := ← table.decode? `verbose
      contextMode := ← table.decode? `context_mode
      historyChars := ← table.decode? `history_chars
      premiseChars := ← table.decode? `premise_chars
      notationChars := ← table.decode? `notation_chars
      repairChars := ← table.decode? `repair_chars
      definitionChars := ← table.decode? `definition_chars
    }
  match decode.run #[] with
  | .ok value errors =>
    if errors.isEmpty then return value
    else throw (String.intercalate "\n" (errors.toList.map (·.msg)))
  | .error _ errors => throw (String.intercalate "\n" (errors.toList.map (·.msg)))

def parse (source : String) (fileName := "llmlean/config.toml") : IO Overrides := do
  match ← Lake.Toml.loadToml (Parser.mkInputContext source fileName) |>.toIO' with
  | .ok table => IO.ofExcept (decodeTable table)
  | .error messages =>
    let errors ← messages.toList.mapM (·.toString)
    throw <| IO.userError (String.intercalate "\n" errors)

def configPath : IO (Option System.FilePath) := do
  if let some path ← IO.getEnv "LLMLEAN_CONFIG" then return some path
  let projectFile := System.FilePath.mk "llmlean.toml"
  if ← projectFile.pathExists then return some projectFile
  if System.Platform.isWindows then
    if let some path ← IO.getEnv "APPDATA" then return some (System.FilePath.mk path / "llmlean/config.toml")
  if let some path ← IO.getEnv "XDG_CONFIG_HOME" then
    return some (System.FilePath.mk path / "llmlean/config.toml")
  if let some path ← IO.getEnv "HOME" then
    return some (System.FilePath.mk path / ".config/llmlean/config.toml")
  return none

def loadFile : IO Overrides := do
  let some path ← configPath | return {}
  if ← path.pathExists then return ← parse (← IO.FS.readFile path) path.toString
  if (← IO.getEnv "LLMLEAN_CONFIG").isSome then
    throw <| IO.userError s!"LLMLEAN_CONFIG file does not exist: {path}"
  return {}

private def envNat (name : String) : IO (Option Nat) := do
  let some value ← IO.getEnv name | return none
  let some value := value.toNat? | throw <| IO.userError s!"{name} must be an integer"
  return some value

def loadEnv : IO Overrides := do
  for name in #["LLMLEAN_API", "LLMLEAN_ENDPOINT", "LLMLEAN_PROMPT", "LLMLEAN_RESPONSE_FORMAT",
      "LLMLEAN_MODE", "LLMLEAN_NUM_SAMPLES", "LLMLEAN_MAX_TOKENS", "LLMLEAN_MAX_ITERATIONS"] do
    if (← IO.getEnv name).isSome then
      throw <| IO.userError s!"{name} is no longer supported. See docs/migration.md."
  let verbose ← match ← IO.getEnv "LLMLEAN_VERBOSE" with
    | none => pure none
    | some "true" | some "1" => pure (some true)
    | some "false" | some "0" => pure (some false)
    | _ => throw <| IO.userError "LLMLEAN_VERBOSE must be true or false"
  return {
    provider := ← IO.getEnv "LLMLEAN_PROVIDER"
    model := ← IO.getEnv "LLMLEAN_MODEL"
    baseUrl := ← IO.getEnv "LLMLEAN_BASE_URL"
    attempts := ← envNat "LLMLEAN_ATTEMPTS"
    maxOutputTokens := ← envNat "LLMLEAN_MAX_OUTPUT_TOKENS"
    reasoningEffort := ← IO.getEnv "LLMLEAN_REASONING_EFFORT"
    timeoutSeconds := ← envNat "LLMLEAN_TIMEOUT_SECONDS"
    verbose
    contextMode := ← IO.getEnv "LLMLEAN_CONTEXT_MODE"
    historyChars := ← envNat "LLMLEAN_HISTORY_CHARS"
    premiseChars := ← envNat "LLMLEAN_PREMISE_CHARS"
    notationChars := ← envNat "LLMLEAN_NOTATION_CHARS"
    repairChars := ← envNat "LLMLEAN_REPAIR_CHARS"
    definitionChars := ← envNat "LLMLEAN_DEFINITION_CHARS"
  }

def load (opts : Options := {}) : IO Settings := do
  let file ← loadFile
  let env ← loadEnv
  IO.ofExcept (resolve file env opts)

def Settings.apiKey (s : Settings) : IO String := do
  let key := (← IO.getEnv s.apiKeyEnv).getD ""
  if s.provider != "local" && key.isEmpty then
    throw <| IO.userError s!"Set {s.apiKeyEnv} to use {s.provider}."
  if key.contains '\n' || key.contains '\r' then
    throw <| IO.userError s!"{s.apiKeyEnv} contains a newline."
  return key

end LLMlean.Config
