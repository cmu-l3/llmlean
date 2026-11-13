module
public import LLMlean.API
public import LLMlean.Check
public import LLMlean.Context
public import Lean.Meta.Tactic.TryThis

public section

open Lean Elab Tactic

namespace LLMlean

/-- Injectable generation; the final argument is the remaining budget in milliseconds. -/
abbrev Generator := Config.Settings → String → String → Nat → IO String

structure Suggestion where
  code : String
  result : CheckResult

/-- Both tactics share one bounded generate/check/repair loop. -/
def generateChecked (settings : Config.Settings) (task : TaskKind) (context : String)
    (pfx : String := "") (generate : Generator := Responses.generate)
    (goals? : Option String := none) (startedMs? : Option Nat := none) : TacticM Suggestion := do
  if llmlean.checking.get (← getOptions) then
    throwError "LLM generation cannot be called from a generated tactic."
  let _ ← getMainGoal
  let started ← match startedMs? with | some t => pure t | none => IO.monoMsNow
  let goals ← match goals? with | some goals => pure goals | none => prettyGoals
  let initial := prompt context goals pfx
  let mut history := ""
  let mut diagnostic := "No checked suggestion found."
  for i in [:settings.attempts] do
    Core.checkInterrupted
    let elapsed := (← IO.monoMsNow) - started
    let remainingMs := settings.timeoutSeconds * 1000 - elapsed
    if remainingMs == 0 then throwError "LLMLean time budget exhausted."
    if settings.verbose then logInfo m!"LLMLean: attempt {i + 1}/{settings.attempts} ({settings.model})"
    let text ← generate settings (instructions task) (initial ++ history) remainingMs
    Core.checkInterrupted
    if (← IO.monoMsNow) - started >= settings.timeoutSeconds * 1000 then
      throwError "LLMLean time budget exhausted."
    let candidate := extractCandidate text
    let result ← match candidate with
      | .error error => pure (CheckResult.invalid error)
      | .ok code =>
        if !pfx.isEmpty && !code.startsWith pfx then
          pure (.invalid s!"The tactic must begin with '{pfx}'.")
        else checkCandidate code
    if (← IO.monoMsNow) - started >= settings.timeoutSeconds * 1000 then
      throwError "LLMLean time budget exhausted."
    match result with
    | .complete => return { code := candidate.toOption.getD "", result }
    | .progress goals =>
      if task == .step then return { code := candidate.toOption.getD "", result }
      diagnostic := s!"The proof is incomplete. Remaining goals:\n{goals}"
    | .invalid error => diagnostic := error
    history := Context.repairHistory text diagnostic settings.repairChars
  throwError "No checked suggestion after {settings.attempts} attempts.\n{diagnostic}"

def suggest (ref : Syntax) (task : TaskKind) (pfx : String := "") : TacticM Unit := do
  if llmlean.checking.get (← getOptions) then
    throwError "LLM generation cannot be called from a generated tactic."
  let settings ← Config.load (← getOptions)
  let _ ← getMainGoal
  let started ← IO.monoMsNow
  let context ← Context.build settings ref
  if settings.verbose then
    logInfo m!"LLMLean context: {context.declarations.size}/{context.candidateCount} declarations, {context.history.length} history characters, {context.render.length + context.goals.length} context characters, {(← IO.monoMsNow) - started} ms ({settings.contextMode})"
  let suggestion ← generateChecked settings task context.render pfx
    (goals? := some context.goals) (startedMs? := some started)
  let code ← parseTactics suggestion.code
  let detail := match suggestion.result with
    | .complete => " (closes all goals)"
    | .progress goals => s!"\nRemaining goals:\n{goals}"
    | .invalid _ => ""
  Meta.Tactic.TryThis.addSuggestion ref {
    suggestion := code
    postInfo? := some detail
  } (origSpan? := some ref)

end LLMlean
