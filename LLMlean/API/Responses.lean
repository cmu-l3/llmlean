module
public import LLMlean.Config

public section

open Lean

namespace LLMlean.Responses

/-- Deliberately stateless: the same request works with Ollama, OpenRouter, and OpenAI. -/
def request (settings : Config.Settings) (instructions input : String) : Json :=
  Json.mkObj [
    ("model", toJson settings.model),
    ("instructions", toJson instructions),
    ("input", toJson input),
    ("max_output_tokens", toJson settings.maxOutputTokens),
    ("store", toJson false),
    ("stream", toJson false)
  ]

private def errorMessage (json : Json) : Option String :=
  ((json.getObjVal? "error").toOption.bind fun e => (e.getObjValAs? String "message").toOption)

/-- Read the wire-format output items, not the SDK-only `output_text` convenience property. -/
def parseResponse (json : Json) : Except String String := do
  if let some error := errorMessage json then throw s!"Model API error: {error}"
  let status ← json.getObjValAs? String "status"
  if status == "incomplete" then
    let reason := ((json.getObjVal? "incomplete_details").bind
      (·.getObjValAs? String "reason")).toOption.getD "unknown"
    throw s!"Model output was incomplete ({reason}). Increase max_output_tokens or reduce the context."
  unless status == "completed" do throw s!"Model response did not complete (status: {status})."
  let output ← json.getObjValAs? (Array Json) "output"
  let mut texts : Array String := #[]
  for item in output do
    match ← item.getObjValAs? String "type" with
    | "reasoning" => pure ()
    | "message" =>
      unless (← item.getObjValAs? String "role") == "assistant" do
        throw "Unexpected non-assistant output message."
      if let some status := (item.getObjValAs? String "status").toOption then
        unless status == "completed" do throw "Assistant output message is incomplete."
      for part in (← item.getObjValAs? (Array Json) "content") do
        match ← part.getObjValAs? String "type" with
        | "output_text" => texts := texts.push (← part.getObjValAs? String "text")
        | "refusal" => throw s!"Model declined the request: {← part.getObjValAs? String "refusal"}"
        | kind => throw s!"Unexpected response content: {kind}"
    | kind => throw s!"Unexpected response output: {kind}. LLMLean requested text only."
  let text := (String.join texts.toList).trimAscii.toString
  if text.isEmpty then throw "Model returned no answer text (possibly only reasoning)."
  return text

/-- Curl config quoting; credentials and proof context go through stdin, never shell arguments. -/
def quoteCurl (value : String) : String :=
  "\"" ++ (value.replace "\\" "\\\\" |>.replace "\"" "\\\"" |>.replace "\n" "\\n"
    |>.replace "\r" "\\r" |>.replace "\t" "\\t") ++ "\""

def curlConfig (url key : String) (body : Option Json) : String :=
  "url = " ++ quoteCurl url ++ "\nheader = \"Content-Type: application/json\"\n" ++
  (if key.isEmpty then "" else "header = " ++ quoteCurl ("Authorization: Bearer " ++ key) ++ "\n") ++
  (match body with
    | none => ""
    | some body => "data = " ++ quoteCurl body.compress ++ "\n")

def parseHttp (stdout : String) : Except String Json := do
  let lines := stdout.splitOn "\n"
  let some status := lines.getLast?.bind String.toNat? | throw "Missing HTTP status from curl."
  let body := String.intercalate "\n" lines.dropLast
  let parsed := Json.parse body
  unless status >= 200 && status < 300 do
    let detail := (parsed.toOption.bind errorMessage).getD "Server returned an error."
    let help := match status with
      | 401 | 403 => " Check the provider API key and access permissions."
      | 404 => " Check the model and base_url; the server must support /v1/responses."
      | 429 => " Rate limit or quota exceeded; try again later."
      | _ => ""
    throw s!"HTTP {status}: {detail}{help}"
  match parsed with
  | .ok json => return json
  | .error _ => throw "Server returned invalid JSON. Check that base_url points to a Responses API."

/-- Shared transport. HTTP failures are not retried automatically, avoiding duplicate paid requests. -/
def send (url key : String) (body : Option Json) (timeoutMs : Nat) : IO Json := do
  if timeoutMs == 0 then throw <| IO.userError "LLMLean time budget exhausted."
  let seconds := toString (Float.ofNat timeoutMs / 1000.0)
  let connectSeconds := toString (Float.ofNat (min 10000 timeoutMs) / 1000.0)
  let result ← IO.Process.output {
    cmd := "curl"
    args := #["--disable", "--silent", "--show-error", "--connect-timeout", connectSeconds,
      "--max-time", seconds, "--max-filesize", "16777216",
      "--request", if body.isSome then "POST" else "GET",
      "--write-out", "\n%{http_code}", "--config", "-"]
  } (some (curlConfig url key body))
  if result.exitCode == 28 then
    throw <| IO.userError "Model request timed out. Increase timeout_seconds or choose a smaller model."
  if result.exitCode != 0 then
    throw <| IO.userError s!"Cannot reach {url} (curl exit {result.exitCode}). Check that the model server is running."
  IO.ofExcept (parseHttp result.stdout)

def generate (settings : Config.Settings) (instructions input : String)
    (timeoutMs : Nat) : IO String := do
  let key ← settings.apiKey
  let json ← send settings.responsesUrl key (some (request settings instructions input)) timeoutMs
  IO.ofExcept (parseResponse json)

end LLMlean.Responses
