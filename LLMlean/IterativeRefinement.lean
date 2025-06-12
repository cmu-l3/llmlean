import Lean
import LLMlean.Config
import LLMlean.API
import LLMlean.LLMstep

namespace LLMlean

open Lean
open Elab
open Config

/-!
## Iterative Refinement for Proof Generation

This module implements iterative refinement for LLM-based proof generation.
Instead of generating multiple samples in parallel, it generates one attempt,
analyzes any errors, and refines the proof based on the feedback.
-/

/-- Result of a proof attempt -/
inductive ProofAttemptResult
  | Success (proof : String)
  | Error (attempt : String) (errorMsg : String) (goalState : String)
  deriving Inhabited, Repr

/-- Context for iterative refinement -/
structure RefinementContext where
  originalGoal : String
  previousAttempts : List (String × String)  -- (attempt, error)
  iteration : Nat
  deriving Inhabited, Repr

/-- Extract detailed error information from failed tactic evaluation -/
structure ErrorInfo where
  message : String
  hasUnsolvedGoals : Bool := false
  deriving Inhabited, Repr

def extractErrorInfo (messages : MessageLog) (hasUnsolvedGoals : Bool := false) : IO ErrorInfo := do
  let mut errorMsgs : List String := []
  for msg in messages.toList do
    if msg.severity == MessageSeverity.error then
      let msgStr ← msg.data.toString
      errorMsgs := errorMsgs.append [msgStr]

  let errorMessage := if errorMsgs.isEmpty then
    if hasUnsolvedGoals then
      "Tactic succeeded but did not complete the proof"
    else
      "Unknown error"
  else
    String.intercalate "\n\n-----" errorMsgs

  IO.println s!"errorMsgs: {errorMsgs}"
  return {
    message := errorMessage
    hasUnsolvedGoals := hasUnsolvedGoals
  }

/-- Generate a single proof completion attempt -/
def generateSingleProofAttempt (api : Config.API) (tacticState : String) (context : String) : CoreM String := do
  -- Generate with API
  let results ← LLMlean.Config.API.proofCompletion api tacticState context
  if h : results.size > 0 then
    return results[0].1
  else
    throwError "No response from LLM"

/-- Generate a refinement proof attempt with error context -/
def generateRefinementProofAttempt (api : Config.API) (tacticState : String) (context : String)
    (previousAttempt : String) (errorMsg : String) : CoreM String := do
  -- Generate with refinement API
  let results ← LLMlean.Config.API.proofCompletionRefinement api tacticState context previousAttempt errorMsg
  if h : results.size > 0 then
    return results[0].1
  else
    throwError "No response from LLM"


/-- Result of checking a proof with error message -/
structure CheckResultWithError where
  result : CheckResult
  errorMsg : String := ""

/-- Check if a proof completion is valid and get error messages -/
def checkProofCompletion (proof : String) : Elab.Tactic.TacticM CheckResultWithError := do
  let (result, messages) ← withoutModifyingState do
    try
      -- Same validation as in LLMqed
      let s' := "(" ++ (proof.replace "\n" "\n ") ++ " )"
      match Parser.runParserCategory (← getEnv) `tactic s' with
        | Except.ok stx =>
          try
            _ ← Elab.Tactic.evalTactic stx
            let goals ← Elab.Tactic.getUnsolvedGoals
            let messages := (← getThe Core.State).messages
            if messages.hasErrors then
              pure (CheckResult.Invalid, messages)
            else if goals.isEmpty then
              pure (CheckResult.ProofDone, messages)
            else
              pure (CheckResult.Valid, messages)
          catch e =>
            let messages := (← getThe Core.State).messages
            pure (CheckResult.Invalid, messages)
        | Except.error parseError =>
          pure (CheckResult.Invalid, MessageLog.empty.add {
            fileName := ""
            pos := ⟨0, 0⟩
            severity := MessageSeverity.error
            data := parseError
          })
      catch e =>
        pure (CheckResult.Invalid, MessageLog.empty.add {
          fileName := ""
          pos := ⟨0, 0⟩
          severity := MessageSeverity.error
          data := e.toMessageData
        })

  -- Extract error message if invalid
  let errorMsg ← if result == CheckResult.Invalid then
    let errorInfo ← extractErrorInfo messages false
    pure errorInfo.message
  else if result == CheckResult.Valid then
    pure "Tactic valid but proof incomplete"
  else
    pure ""

  return { result := result, errorMsg := errorMsg }

/-- Main iterative refinement loop for proof completion -/
def iterativeRefinementProofInTactic (tacticState : String) (context : String)
    (api : Config.API) (maxIterations : Nat) : Elab.Tactic.TacticM (List String) := do
  IO.println s!"[Iterative Refinement] Starting with max iterations: {maxIterations}"
  IO.println s!"[Iterative Refinement] Original goal: {tacticState}"

  let mut ctx : RefinementContext := {
    originalGoal := tacticState
    previousAttempts := []
    iteration := 0
  }

  let mut validProofs : List String := []

  for i in [0:maxIterations] do
    ctx := { ctx with iteration := i }
    IO.println s!"\n[Iterative Refinement] === Iteration {i + 1}/{maxIterations} ==="

    -- Generate attempt based on iteration
    let proof ← if i == 0 then
      -- First attempt: use normal API
      IO.println s!"[Iterative Refinement] Calling LLM (first attempt)..."
      generateSingleProofAttempt api tacticState context
    else
      -- Refinement: use dedicated refinement API
      let (lastAttempt, lastError) := ctx.previousAttempts.head!
      IO.println s!"[Iterative Refinement] Previous attempt:\n{lastAttempt}"
      IO.println s!"[Iterative Refinement] Error: {lastError}"
      IO.println s!"[Iterative Refinement] Calling LLM with refinement context..."
      generateRefinementProofAttempt api tacticState context lastAttempt lastError

    IO.println s!"[Iterative Refinement] LLM response:\n{proof}"

    -- Check if the proof is valid
    let checkResult ← checkProofCompletion proof
    match checkResult.result with
    | CheckResult.ProofDone =>
      IO.println s!"[Iterative Refinement] ✓ Proof complete!"
      validProofs := validProofs ++ [proof]
      break
    | CheckResult.Valid =>
      IO.println s!"[Iterative Refinement] ⚠ Valid tactic but proof not complete, continuing..."
      IO.println s!"[Iterative Refinement] Reason: {checkResult.errorMsg}"
      ctx := { ctx with previousAttempts := (proof, checkResult.errorMsg) :: ctx.previousAttempts }
    | CheckResult.Invalid =>
      IO.println s!"[Iterative Refinement] ✗ Invalid proof, continuing..."
      IO.println s!"[Iterative Refinement] Error: {checkResult.errorMsg}"
      ctx := { ctx with previousAttempts := (proof, checkResult.errorMsg) :: ctx.previousAttempts }

  IO.println s!"[Iterative Refinement] Completed. Generated {validProofs.length} valid proof(s)."
  return validProofs


end LLMlean
