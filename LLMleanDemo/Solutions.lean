module
import LLMlean

/-!
Worked proofs for Demo.lean. These are hand-written examples of the ordinary
Lean code you keep after accepting a suggestion, not recorded model outputs.
This file makes no model calls.
-/

example (n : Nat) : n + 0 = n := by
  rfl

example (P Q : Prop) (hp : P) (hpq : P → Q) : Q := by
  exact hpq hp

example (P Q : Prop) (h : P ∧ Q) : Q ∧ P := by
  exact ⟨h.2, h.1⟩

example (P Q R : Prop) (hp : P) (hq : Q) (hr : R) : P ∧ Q ∧ R := by
  constructor
  · exact hp
  · constructor
    · exact hq
    · exact hr

example (α : Type) (xs ys : List α) :
    (xs ++ ys).length = xs.length + ys.length := by
  exact List.length_append
