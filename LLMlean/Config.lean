module
public import Lean
public import Lake.Toml
public import Lake.Toml.Decode

public section

open Lean

namespace LLMlean.Config

register_option llmlean.provider : String := {
  defValue := "local", descr := "Connection preset: local, openrouter, or openai."
}
register_option llmlean.model : String := {
  defValue := "", descr := "Model identifier. Defaults to a quantized local model."
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
register_option llmlean.timeoutSeconds : Nat := {
  defValue := 90, descr := "Wall-clock budget for an invocation."
}
register_option llmlean.verbose : Bool := {
  defValue := false, descr := "Show generation/check progress."
}

def defaultModel : String := "qwen3.5:9b-q4_K_M"

/-- Preserve absence, including for booleans and default-valued overrides. -/
structure Overrides where
  provider : Option String := none
  model : Option String := none
  baseUrl : Option String := none
  attempts : Option Nat := none
  maxOutputTokens : Option Nat := none
  timeoutSeconds : Option Nat := none
  verbose : Option Bool := none
  deriving Inhabited, Repr

/-- Secrets are excluded from printable settings. Every preset uses Responses. -/
structure Settings where
  provider : String := "local"
  model : String := defaultModel
  baseUrl : String := "http://localhost:11434/v1"
  apiKeyEnv : String := "LLMLEAN_API_KEY"
  attempts : Nat := 3
  maxOutputTokens : Nat := 4096
  timeoutSeconds : Nat := 90
  verbose : Bool := false
  deriving Inhabited, Repr

def Settings.responsesUrl (s : Settings) : String := s.baseUrl ++ "/responses"

private def pick (high low : Overrides) : Overrides := {
  provider := high.provider.or low.provider
  model := high.model.or low.model
  baseUrl := high.baseUrl.or low.baseUrl
  attempts := high.attempts.or low.attempts
  maxOutputTokens := high.maxOutputTokens.or low.maxOutputTokens
  timeoutSeconds := high.timeoutSeconds.or low.timeoutSeconds
  verbose := high.verbose.or low.verbose
}

def fromOptions (opts : Options) : Overrides := {
  provider := opts.get? `llmlean.provider
  model := opts.get? `llmlean.model
  baseUrl := opts.get? `llmlean.baseUrl
  attempts := opts.get? `llmlean.attempts
  maxOutputTokens := opts.get? `llmlean.maxOutputTokens
  timeoutSeconds := opts.get? `llmlean.timeoutSeconds
  verbose := opts.get? `llmlean.verbose
}

/-- Explicit Lean options > environment > config file > defaults. -/
def resolve (file env : Overrides := {}) (opts : Options := {}) : Except String Settings := do
  let o := pick (fromOptions opts) (pick env file)
  let provider := o.provider.getD "local"
  let (baseUrl, keyEnv) ← match provider with
    | "local" => pure ("http://localhost:11434/v1", "LLMLEAN_API_KEY")
    | "openai" => pure ("https://api.openai.com/v1", "OPENAI_API_KEY")
    | "openrouter" => pure ("https://openrouter.ai/api/v1", "OPENROUTER_API_KEY")
    | _ => throw "provider must be local, openrouter, or openai"
  let model ← match o.model with
    | some model => pure model.trimAscii.toString
    | none =>
      if provider == "local" then pure defaultModel
      else throw s!"Set model for provider '{provider}'."
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
    timeoutSeconds := o.timeoutSeconds.getD 90
    verbose := o.verbose.getD false
  }
  if settings.attempts == 0 then throw "attempts must be a positive integer"
  if settings.maxOutputTokens == 0 then throw "max_output_tokens must be a positive integer"
  if settings.timeoutSeconds == 0 then throw "timeout_seconds must be a positive integer"
  return settings

open Lake Toml in
def decodeTable (table : Table) : Except String Overrides := do
  let known := #[`provider, `model, `base_url, `attempts, `max_output_tokens, `timeout_seconds, `verbose]
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
      timeoutSeconds := ← table.decode? `timeout_seconds
      verbose := ← table.decode? `verbose
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
    timeoutSeconds := ← envNat "LLMLEAN_TIMEOUT_SECONDS"
    verbose
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
