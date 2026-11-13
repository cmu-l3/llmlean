module
import Mathlib.Tactic
public import LLMlean
public meta import LLMlean

open Lean Elab Tactic LLMlean

-- These assertions deliberately leave the proof state unchanged.
set_option linter.unusedTactic false

elab "check_mathlib_candidate " code:str : tactic => do
  let result ← checkCandidate code.getString
  unless result == .complete do throwError "Expected a complete Mathlib proof, got {repr result}"

example (x y : ℤ) : (x + y) ^ 2 = x ^ 2 + 2 * x * y + y ^ 2 := by
  check_mathlib_candidate "ring"
  ring

example (x : ℝ) (h : 0 < x) : 0 < x + 1 := by
  check_mathlib_candidate "linarith"
  linarith
