/-
`llmstep` tactic for LLM-based next-tactic suggestions.
Examples:
 llmstep ""
 llmstep "have"
 llmstep "apply Continuous"
-/
import Lean.Widget.UserWidget
import Lean.Meta.Tactic.TryThis

import LLMlean.API

open Lean LLMlean

/- Calls an LLM API with the given context, prefix and pretty-printed goal.
  Optionally allows to provide a specific API for a model to call. -/
def runSuggest (goal pre ctx: String) (api : Option Config.API := none) :
    CoreM (Array (String × Float)) := do
  let api : Config.API ← match api with
    | some api => pure api
    -- if the API is provided, use the one found in the configuration.
    | none => getConfiguredAPI Config.TacticKind.LLMStep
  
  let s ← api.tacticGeneration goal ctx pre
  return s


/- Display clickable suggestions in the VSCode Lean Infoview.
    When a suggestion is clicked, this widget replaces the `llmstep` call
    with the suggestion, and saves the call in an adjacent comment.
    Code based on `Std.Tactic.TryThis.tryThisWidget`. -/
@[widget_module] def llmstepTryThisWidget : Widget.UserWidgetDefinition where
  name := "LLMLean suggestions"
  javascript := "
import * as React from 'react';
import { EditorContext } from '@leanprover/infoview';
const e = React.createElement;
export default function(props) {
  const editorConnection = React.useContext(EditorContext)
  function onClick(suggestion) {
    editorConnection.api.applyEdit({
      changes: { [props.pos.uri]: [{ range:
        props.range,
        newText: suggestion[0]
        }] }
    })
  }
  const suggestionElement = props.suggestions.length > 0
    ? [
      'Try this: ',
      ...(props.suggestions.map((suggestion, i) =>
          e('li', {onClick: () => onClick(suggestion),
            className:
              suggestion[1] === 'ProofDone' ? 'link pointer dim green' :
              suggestion[1] === 'Valid' ? 'link pointer dim blue' :
              'link pointer dim',
            title: 'Apply suggestion'},
            suggestion[1] === 'ProofDone' ? '🎉 ' + suggestion[0] : suggestion[0]
        )
      )),
      props.info
    ]
    : 'No valid suggestions.';
  return e('div',
  {className: 'ml1'},
  e('ul', {className: 'font-code pre-wrap'},
  suggestionElement))
}"

inductive CheckResult : Type
  | ProofDone
  | Valid
  | Invalid
  deriving ToJson, Ord, BEq

/- Check whether the suggestion `s` completes the proof, is valid (does
not result in an error message), or is invalid. -/
def checkSuggestion (s: String) : Lean.Elab.Tactic.TacticM CheckResult := do
  withoutModifyingState do
  try
    match Parser.runParserCategory (← getEnv) `tactic s with
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
      | Except.error _ =>
        pure CheckResult.Invalid
    catch _ => pure CheckResult.Invalid


/- Adds multiple suggestions to the Lean InfoView.
   Code based on `Std.Tactic.addSuggestion`. -/
def addSuggestions (tacRef : Syntax) (pfxRef: Syntax) (suggestions: Array (String × Float))
    (origSpan? : Option Syntax := none)
    (extraMsg : String := "") : Lean.Elab.Tactic.TacticM Unit := do
  let suggestions := suggestions.map fun ⟨x, _⟩ => x
  if let some tacticRange := (origSpan?.getD tacRef).getRange? then
    if let some argRange := (origSpan?.getD pfxRef).getRange? then
      let map ← getFileMap
      let start := String.findLineStart map.source tacticRange.start
      let body := map.source.findAux (· ≠ ' ') tacticRange.start start

      let checks ← suggestions.mapM checkSuggestion
      let texts := suggestions.map fun text => (
        (Std.Format.pretty text.trim
         (indent := (body - start).1)
         (column := (tacticRange.start - start).1)
      ))

      let textsAndChecks := (texts.zip checks |>.qsort
        fun a b => compare a.2 b.2 = Ordering.lt).filter fun x =>
          match x.2 with
          | CheckResult.ProofDone => true
          | CheckResult.Valid => true
          | CheckResult.Invalid => false

      let start := (tacRef.getRange?.getD tacticRange).start
      let stop := (pfxRef.getRange?.getD argRange).stop
      let stxRange :=

      { start := map.lineStart (map.toPosition start).line
        stop := map.lineStart ((map.toPosition stop).line + 1) }
      let full_range : String.Range :=
      { start := tacticRange.start, stop := argRange.stop }
      let full_range := map.utf8RangeToLspRange full_range
      let tactic := Std.Format.pretty f!"{tacRef.prettyPrint}{pfxRef.prettyPrint}"
      let json := Json.mkObj [
        ("tactic", tactic),
        ("suggestions", toJson textsAndChecks),
        ("range", toJson full_range),
        ("info", extraMsg)
      ]
      Widget.savePanelWidgetInfo (hash llmstepTryThisWidget.javascript) (StateT.lift json) (.ofRange stxRange)

/--
Call the LLM on a goal, asking for suggestions beginning with a prefix.
-/
def llmStep (pre : String) (ctx : String) (g : MVarId) : MetaM (Array (String × Float)) := do
  let pp := toString (← Meta.ppGoal g)
  runSuggest pp pre ctx


open Lean Elab Tactic

/- `llmstep` tactic.
   Examples:
    llmstep ""
    llmstep "have"
    llmstep "apply Continuous" -/
syntax "llmstep" str: tactic
elab_rules : tactic
  | `(tactic | llmstep%$tac $pfx:str ) => do
    match tac.getRange? with
    | some range =>
      -- Get the source context from the file from which the tactic was called.
      let src := (← getFileMap).source
      -- Extract the context, from the start of the file to the start of tactic call.
      let ctx := src.extract src.toSubstring.startPos range.start
      addSuggestions tac pfx (← liftMetaMAtMain (llmStep pfx.getString ctx))
    | none =>
      addSuggestions tac pfx (← liftMetaMAtMain (llmStep pfx.getString ""))

/-- Parse `llmstep` as `llmstep ""` -/
macro "llmstep" : tactic => `(tactic| llmstep "")
