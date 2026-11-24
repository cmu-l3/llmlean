module
public import LLMlean.API.Responses
public import LLMlean.Optimize.Verdict
public import LLMlean.Optimize.Prompt
public import LLMlean.Optimize.Project

public section

open Lean System

namespace LLMlean.Optimize

private def settings : IO Config.Settings := do
  let file : FilePath := "llmlean-optimize.toml"
  let cfg ← if ← file.pathExists then
      IO.ofExcept <| Config.resolve (← Config.parse (← IO.FS.readFile file) file.toString) (← Config.loadEnv)
    else Config.load
  return { cfg with
    maxOutputTokens := min cfg.maxOutputTokens 2048
    reasoningEffort := if cfg.provider == "local" && cfg.reasoningEffort == "default" then "none"
                       else cfg.reasoningEffort }

/-- The optimizer sends the SFT messages as-is in Responses' typed input array. -/
def request (cfg : Config.Settings) (messages : Json) : Json :=
  Json.mkObj <| [("model", toJson cfg.model), ("input", messages), ("store", toJson false),
    ("max_output_tokens", toJson cfg.maxOutputTokens), ("stream", toJson false)] ++
    if cfg.reasoningEffort == "default" then [] else
      [("reasoning", Json.mkObj [("effort", toJson cfg.reasoningEffort)])]

inductive Phase where
  | collecting
  | waiting (localModel : Bool)
  | checking

def Phase.message : Phase → String
  | .collecting => "Collecting goals and referenced lemmas…"
  | .waiting true => "Waiting for local LLM…"
  | .waiting false => "Waiting for cloud LLM…"
  | .checking => "Checking proof in Lean…"

def generate (messages : Json) (onPhase : Phase → IO Unit)
    (cancelled? : Option (BaseIO Bool)) : IO String := do
  let cfg ← settings
  let key ← cfg.apiKey
  onPhase (.waiting (cfg.provider == "local"))
  let response ← Responses.send cfg.responsesUrl key (some (request cfg messages))
    (cfg.timeoutSeconds * 1000) cancelled?
  let proof ← IO.ofExcept (Responses.parseResponse response)
  onPhase .checking
  return proof

def editorMessages (record : Json) (file : FilePath) (header : Json) : IO Json := do
  let file ← IO.FS.realPath file
  let setup ← Project.setup (← Project.root file) file (some header)
  let name ← IO.ofExcept (setup.getObjValAs? String "name")
  let imports ← IO.ofExcept (record.getObjVal? "context" >>= (·.getObjVal? "imports"))
  IO.ofExcept <| Prompt.messages record name Lean.versionString imports

def validReplacement (proof : String) : Bool :=
  (proof == "by" || ["by ", "by\n", "by\t"].any (fun s : String => proof.startsWith s)) &&
    !(["<think>", "</think>", "```", "<|im_"].any (fun s : String => proof.contains s))

def editorVerdict (original candidate : Json) (proof : String) (elapsed : Nat) : IO Json := do
  let before ← IO.ofExcept (fromJson? original)
  let after ← IO.ofExcept (fromJson? candidate)
  return Verdict.compare before after proof elapsed

end LLMlean.Optimize
