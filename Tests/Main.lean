module
import Tests.Check
import LLMlean

open Lean LLMlean

private def ensure (condition : Bool) (message : String) : IO Unit :=
  unless condition do throw <| IO.userError message

private def expectFailure (action : IO α) : IO Unit := do
  let failed ← try let _ ← action; pure false catch _ => pure true
  ensure failed "Expected an error."

private def configTests : IO Unit := do
  let settings ← IO.ofExcept (Config.resolve)
  ensure (settings.provider == "local" && settings.model == Config.defaultModel) "Local defaults"
  ensure (settings.responsesUrl == "http://localhost:11434/v1/responses") "Responses URL"
  ensure (settings.reasoningEffort == "default") "Preserve server reasoning defaults unless configured."
  let reasoningFile ← Config.parse "reasoning_effort = 'none'\n"
  let reasoning ← IO.ofExcept (Config.resolve reasoningFile)
  ensure (reasoning.reasoningEffort == "none") "Thinking off from TOML"
  let reasoning ← IO.ofExcept (Config.resolve reasoningFile { reasoningEffort := some "high" })
  ensure (reasoning.reasoningEffort == "high") "Environment reasoning override"
  let reasoning ← IO.ofExcept (Config.resolve reasoningFile { reasoningEffort := some "high" }
    (({} : Options).set `llmlean.reasoningEffort "default"))
  ensure (reasoning.reasoningEffort == "default") "Explicit Lean default must override thinking settings."
  let file ← Config.parse "model = 'file-model'\nattempts = 5\nverbose = true\n"
  let opts := (({} : Options).set `llmlean.attempts (3 : Nat)).setBool `llmlean.verbose false
  let resolved ← IO.ofExcept (Config.resolve file { model := some "env-model" } opts)
  ensure (resolved.model == "env-model" && resolved.attempts == 3 && !resolved.verbose)
    "Explicit default values must override config, including false."
  let resolved ← IO.ofExcept (Config.resolve file { model := some "env-model" }
    (opts.set `llmlean.model "option-model"))
  ensure (resolved.model == "option-model") "Lean option precedence"
  let resolved ← IO.ofExcept (Config.resolve { baseUrl := some "http://localhost:8000/v1/" })
  ensure (resolved.responsesUrl == "http://localhost:8000/v1/responses") "Trailing slash"
  for provider in ["openai", "openrouter"] do
    expectFailure (IO.ofExcept (Config.resolve { provider := some provider }))
    let s ← IO.ofExcept (Config.resolve { provider := some provider, model := some "chosen-model" })
    ensure (s.model == "chosen-model" && s.apiKeyEnv != "LLMLEAN_API_KEY") "Cloud model/key"
  for source in ["attempts = '3'", "verbose = 'false'", "attempts = -1", "reasoning_effort = false",
      "mode = 'iterative'", "apiKey = 'must-not-be-accepted'", "unknown = 1", "model = ["] do
    expectFailure (Config.parse source)
  for file in [({ attempts := some 0 } : Config.Overrides), { maxOutputTokens := some 0 },
      { timeoutSeconds := some 0 }, { provider := some "anthropic" }, { model := some "" },
      { reasoningEffort := some "off" },
      { baseUrl := some "http://localhost/v1/responses" }, { baseUrl := some "not-a-url" }] do
    expectFailure (IO.ofExcept (Config.resolve file))

private def responseTests : IO Unit := do
  let response ← IO.ofExcept (Json.parse r#"{"status":"completed","output":[{"type":"reasoning","summary":[]},{"type":"message","role":"assistant","content":[{"type":"output_text","text":"```lean\nrfl\n```"}]}]}"#)
  let text ← IO.ofExcept (Responses.parseResponse response)
  ensure ((extractCandidate text).toOption == some "rfl") "Responses output array"
  for source in [
      r#"{"status":"incomplete","incomplete_details":{"reason":"max_output_tokens"},"output":[]}"#,
      r#"{"status":"completed","output":[{"type":"reasoning","summary":[]}]}"#,
      r#"{"status":"completed","output":[{"type":"message","role":"assistant","status":"incomplete","content":[{"type":"output_text","text":"rfl"}]}]}"#,
      r#"{"status":"completed","output":[{"type":"function_call","name":"anything"}]}"#,
      r#"{"status":"completed","output":[{"type":"message","role":"assistant","content":[{"type":"refusal","refusal":"declined"}]}]}"#,
      r#"{"status":"failed","error":{"message":"provider failure"}}"#,
      r#"{"choices":[{"message":{"content":"rfl"}}]}"#] do
    let json ← IO.ofExcept (Json.parse source)
    expectFailure (IO.ofExcept (Responses.parseResponse json))
  let body := Responses.request {} "instructions" "input"
  ensure ((body.getObjValAs? Bool "store").toOption == some false) "Stateless requests"
  ensure ((body.getObjValAs? String "input").toOption == some "input") "Input"
  ensure ((body.getObjVal? "reasoning").toOption.isNone) "Default requests must omit reasoning."
  let body := Responses.request { reasoningEffort := "none" } "instructions" "input"
  ensure ((body.getObjVal? "reasoning").toOption ==
    some (Json.mkObj [("effort", toJson "none")])) "Thinking off must use Responses reasoning.effort."
  ensure ((body.getObjVal? "temperature").toOption.isNone && (body.getObjVal? "stop").toOption.isNone &&
    (body.getObjVal? "n").toOption.isNone) "Do not send unsupported legacy parameters"
  for text in ["", "```lean\nrfl", "```python\nrfl\n```", "```lean\nrfl\n```\n```lean\ntrivial\n```"] do
    expectFailure (IO.ofExcept (extractCandidate text))
  let quoted := (toJson "```lean\nexample (n : Nat) : n + 0 = n := by\n  rfl\n```").compress
  match extractCandidate quoted with
  | .error error =>
    ensure ((error.splitOn "JSON-quoted string").length > 1)
      "Quoted code should receive actionable format feedback."
  | .ok _ => throw <| IO.userError "JSON-quoted code must not be treated as tactics."
  ensure ((extractCandidate "rfl").toOption == some "rfl") "Bare tactic"
  ensure ((extractCandidate "Explanation\n```lean4\nconstructor\n· trivial\n· trivial\n```").toOption ==
    some "constructor\n· trivial\n· trivial") "Preserve multiline indentation"
  ensure ((Responses.parseHttp (response.compress ++ "\n200")).isOk) "HTTP success"
  for status in [401, 404, 429, 500] do
    expectFailure (IO.ofExcept (Responses.parseHttp (r#"{"error":{"message":"failed"}}"# ++ "\n" ++ toString status)))
  expectFailure (IO.ofExcept (Responses.parseHttp "<html>proxy</html>\n200"))
  ensure (Responses.quoteCurl "a\"b\\c\nd" == "\"a\\\"b\\\\c\\nd\"") "Curl quoting"

public def main : IO Unit := do
  configTests
  responseTests
  IO.println "Offline configuration, Responses, and proof-checking tests passed."
