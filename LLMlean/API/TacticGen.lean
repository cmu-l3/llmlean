/- Tactic generation for LLMlean -/
import LLMlean.API.Common
import LLMlean.API.Prompts

open Lean LLMlean.Config

namespace LLMlean

/--
Parses a tactic out of a response from the LLM.
The tactic is expected to be enclosed in `[TAC]...[/TAC]` tags.
-/
def splitTac (text : String) : String :=
  let text := ((text.splitOn "[TAC]").tailD [text]).headD text
  match (text.splitOn "[/TAC]").head? with
  | some s => s.trim
  | none => text.trim

open Config API

/--
Generates a list of tactics using the LLM API.
-/
def LLMlean.Config.API.tacticGeneration
  (api : API) (tacticState : String) (context : String)
  («prefix» : String) : CoreM $ Array (String × Float) := do
  let prompts := makePrompts api.promptKind context tacticState «prefix»
  let options ← getChatGenerationOptions api TacticKind.LLMStep
  let mut results : Std.HashMap String Float := {}
  for (tactic, prob) in  ← generate api prompts options do
    if tactic.startsWith prefix.trim then
      results := results.insert («prefix» ++ splitTac tactic) prob
  return results.toArray

end LLMlean
