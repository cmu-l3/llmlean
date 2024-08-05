/-
`llmqed` tactic for LLM-based proof completion.
-/
import Lean.Widget.UserWidget
import Lean.Meta.Tactic.TryThis
import Std.Lean.Position

import LLMlean.API
import LLMlean.LLMstep

open Lean LLMlean

/- Calls an LLM API with the given context, prefix and pretty-printed goal. -/
def runTactic (goal ctx: String) : IO (Array (String × Float)) := do
  let api ← getAPI
  let s ← api.proofCompletion goal ctx
  return s

def formatSuggestion (suggestion: String)
(body : String.Pos)
(start : String.Pos)
(column : Nat):=
  let lines := (suggestion.splitOn "\n")
  let lines := [(lines.headD "").trim] ++ lines.tailD []
  let lines := lines.map fun (line : String) =>
    Std.Format.pretty line (indent := (body - start).1) (column := column)
  "\n  ".intercalate lines

/- Check whether the suggestion `s` completes the proof, is valid (does
not result in an error message), or is invalid. -/
def checkSuggestion' (s: String) : Lean.Elab.Tactic.TacticM CheckResult := do
  withoutModifyingState do
  try
    /- FIXME: this only checks a subset of good proofs -/
    let s' := "(" ++ (s.replace "\n" "\n ") ++ " )"
    match Parser.runParserCategory (← getEnv) `tactic s' with
      | Except.ok stx =>
        try
          _ ← Lean.Elab.Tactic.evalTactic stx
          let goals ← Lean.Elab.Tactic.getUnsolvedGoals
          if (← getThe Core.State).messages.hasErrors then
            pure CheckResult.Invalid
          else if goals.isEmpty then
            pure CheckResult.ProofDone
          else
            pure CheckResult.Valid
        catch _ =>
          pure CheckResult.Invalid
      | Except.error e =>
        pure CheckResult.Invalid
    catch e =>
      pure CheckResult.Invalid


def addSuggestions' (tacRef : Syntax) (suggestions: Array (String × Float))
    (origSpan? : Option Syntax := none)
    (extraMsg : String := "") : Lean.Elab.Tactic.TacticM Unit := do
  let suggestions := suggestions.map fun ⟨x, _⟩ => x
  if let some tacticRange := (origSpan?.getD tacRef).getRange? then
    let map ← getFileMap
    let start := findLineStart map.source tacticRange.start
    let body := map.source.findAux (· ≠ ' ') tacticRange.start start

    let checks ← suggestions.mapM checkSuggestion'
    let texts : Array String := suggestions.map fun text =>
      formatSuggestion text body start (tacticRange.start - start).1

    let textsAndChecks := (texts.zip checks |>.qsort
      fun a b => compare a.2 b.2 = Ordering.lt).filter fun x =>
        match x.2 with
        | CheckResult.ProofDone => true
        | CheckResult.Valid => true
        | CheckResult.Invalid => false

    let start := (tacRef.getRange?.getD tacticRange).start
    let stop := (tacRef.getRange?.getD tacticRange).stop
    let stxRange :=

    { start := map.lineStart (map.toPosition start).line
      stop := map.lineStart ((map.toPosition stop).line + 1) }
    let full_range : String.Range :=
    { start := tacticRange.start, stop := tacticRange.stop }
    let full_range := map.utf8RangeToLspRange full_range
    let tactic := Std.Format.pretty f!"{tacRef.prettyPrint}"
    let json := Json.mkObj [
      ("tactic", tactic),
      ("suggestions", toJson textsAndChecks),
      ("range", toJson full_range),
      ("info", extraMsg)
    ]
    Widget.saveWidgetInfo ``llmstepTryThisWidget json (.ofRange stxRange)

/--
Call the LLM on a goal, asking for suggestions.
-/
def llmQed (ctx : String) (g : MVarId) : MetaM (Array (String × Float)) := do
  let pp := toString (← Meta.ppGoal g)
  runTactic pp ctx

open Lean Elab Tactic

/- `llmqed` tactic. -/
syntax "llmqed": tactic
elab_rules : tactic
  | `(tactic | llmqed%$tac) => do
    match tac.getRange? with
    | some range =>
      let src := (← getFileMap).source
      let ctx := src.extract src.toSubstring.startPos range.start
      addSuggestions' tac (← liftMetaMAtMain (llmQed ctx))
    | none =>
      addSuggestions' tac (← liftMetaMAtMain (llmQed ""))
