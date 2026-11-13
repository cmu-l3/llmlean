module
import LLMlean.API.Responses

open Lean LLMlean

public def main (args : List String) : IO UInt32 := do
  unless args == ["doctor"] || args == ["doctor", "--offline"] do
    IO.println "Usage: lake exe llmlean doctor [--offline]"
    return if args == ["--help"] then 0 else 1
  try
    let settings ← Config.load
    IO.println s!"Provider: {settings.provider}\nModel: {settings.model}\nResponses: {settings.responsesUrl}"
    IO.println s!"Reasoning effort: {settings.reasoningEffort}"
    IO.println s!"Budget: {settings.attempts} attempts, {settings.timeoutSeconds}s, {settings.maxOutputTokens} output tokens/request"
    if args.contains "--offline" then return 0
    let key ← settings.apiKey
    let json ← Responses.send (settings.baseUrl ++ "/models") key none 10000
    let models ← IO.ofExcept (json.getObjValAs? (Array Json) "data")
    unless models.any (fun m => (m.getObjValAs? String "id").toOption == some settings.model) do
      let hint := if settings.provider == "local" then s!" Run: ollama pull {settings.model}" else " Check the provider's model identifier."
      throw <| IO.userError s!"Server is reachable but the configured model is not listed.{hint}"
    IO.println "Server reachable; model available. Responses generation has not been probed."
    return 0
  catch error =>
    (← IO.getStderr).putStrLn s!"LLMLean: {error}"
    return 1
