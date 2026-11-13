module
import LLMlean

/-!
# Try LLMLean

Launch with `bash open-vscode.sh openai` to use an OpenAI key,
or `bash open-vscode.sh local` after starting Ollama (see README.md).
Then open Lean's Infoview.

For each exercise:
  1. Replace `sorry` with the indicated LLM tactic, one exercise at a time.
  2. Leave the cursor on that line and wait for a checked "Try this" suggestion.
  3. Click the suggestion to replace the LLM tactic with ordinary Lean code.

An "unsolved goals" error is expected until you accept the suggestion.
`llmstep` may leave goals: repeat it on the remaining goals or finish by hand.
`llmqed` only suggests a completion of all current goals.

Requests currently run during elaboration, so editing can trigger another request.
Accept a suggestion or change the tactic back to `sorry` before moving on.
The starting file makes no model calls. Solutions.lean has ordinary worked proofs.
-/

-- Show attempt counts in the Infoview while experimenting.
set_option llmlean.verbose true

-- Sanity check: this proof should already show "No goals" in the Infoview.
example (n : Nat) : n = n := by
  rfl

-- 1. A first suggestion. Replace `sorry` with: llmstep
example (n : Nat) : n + 0 = n := by
  rfl

-- 2. Guide the response. Replace `sorry` with: llmstep "exact "
example (P Q : Prop) (hp : P) (hpq : P → Q) : Q := by
  sorry

-- 3. Complete a proof. Replace `sorry` with: llmqed
example (P Q : Prop) (h : P ∧ Q) : Q ∧ P := by
  sorry

-- 4. Work in steps. Replace `sorry` with: llmstep "constructor"
-- After accepting, use another llmstep on any remaining goals.
example (P Q R : Prop) (hp : P) (hq : Q) (hr : R) : P ∧ Q ∧ R := by
  sorry

-- 5. A list theorem. Replace `sorry` with: llmqed
example (α : Type) (xs ys : List α) :
    (xs ++ ys).length = xs.length + ys.length := by
  simp
