module
public import Lean
public import Lean.Util.CollectAxioms

public section

open Lean Elab Tactic Meta

namespace LLMlean

register_option llmlean.checking : Bool := {
  defValue := false, descr := "Internal: prevent recursive generation while checking candidates."
}

inductive CheckResult where
  | complete
  | progress (goals : String)
  | invalid (diagnostic : String)
  deriving BEq, Repr, Inhabited

def prettyGoals : TacticM String := do
  let goals ← (← getUnsolvedGoals).mapM fun g => return toString (← ppGoal g)
  return String.intercalate "\n\n" goals

/-- Parse a normal `by` block so bullets, indentation, and multiline tactics keep their meaning. -/
def parseTactics (code : String) : CoreM (TSyntax ``Parser.Tactic.tacticSeq) := do
  let source := "by\n" ++ String.intercalate "\n" ((code.splitOn "\n").map ("  " ++ ·))
  let term ← match Parser.runParserCategory (← getEnv) `term source with
    | .ok term => pure term
    | .error error =>
      throwError "Expected only a tactic sequence inside the existing 'by' proof. Do not return an example, theorem, lemma, imports, or an outer 'by'.\nLean parser: {error}"
  match term with
  | `(term| by $tactics:tacticSeq) => return tactics
  | _ => throwError "Expected a tactic sequence."

private def containsSorry (e : Expr) : MetaM Bool := do
  if e.hasSorry then return true
  for name in e.getUsedConstants do
    if (← collectAxioms name).contains ``sorryAx then return true
  return false

/-- Check in an isolated state, including messages. A successful result never applies the tactic. -/
def checkCandidate (code : String) : TacticM CheckResult := withoutModifyingState do
  withOptions (fun opts => (opts.setBool `llmlean.checking true).set `maxHeartbeats (200000 : Nat)) do
  withCurrHeartbeats do
    let original ← getUnsolvedGoals
    let before ← prettyGoals
    modifyThe Core.State fun s => { s with messages := {} }
    try
      let tactics ← parseTactics code
      evalTactic tactics
      let errors := (← getThe Core.State).messages.toList.filter (·.severity == .error)
      unless errors.isEmpty do
        return .invalid (String.intercalate "\n" (← errors.mapM (·.data.toString)))
      let remaining ← getUnsolvedGoals
      for goal in original do
        goal.withContext do
          let proof ← instantiateMVars (mkMVar goal)
          if ← containsSorry proof then throwError "Candidate contains a sorry/admit dependency."
          if remaining.isEmpty then
            if proof.hasMVar then throwError "Candidate left unresolved proof metavariables."
            -- `have`/`let` declarations can retain assigned metavariables in their
            -- types or values. The kernel does not consult the elaborator's assignments.
            withLCtx' (← instantiateLCtxMVars (← getLCtx)) do
              checkWithKernel proof
            unless ← isDefEq (← inferType proof) (← goal.getType) do
              throwError "Candidate proves a different goal."
      if remaining.isEmpty then return .complete
      let after ← prettyGoals
      if before == after then return .invalid "The tactic did not change the goals."
      return .progress after
    catch ex =>
      Core.checkInterrupted
      return .invalid (← ex.toMessageData.toString)

end LLMlean
