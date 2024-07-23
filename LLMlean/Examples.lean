import Mathlib
import Mathlib.Data.Nat.Factorization.Basic
import Mathlib.Data.Nat.Prime
import LLMlean


example {α : Type _} (r s t : Set α) : r ⊆ s → s ⊆ t → r ⊆ t := by
  sorry

example (x y : ℕ) : x + y = y + x := by
  sorry

variable {Ω : Type*}[Fintype Ω]

structure my_object (Ω : Type*)[Fintype Ω] :=
  (f : Ω → ℝ)
  (cool_property : ∀ x : Ω, 0 ≤ f x)

theorem my_object_sum_nonneg (o1 o2: my_object Ω) : o1.f + o2.f ≥ 0 := by
  sorry

theorem test_thm (m n : Nat) (h : m.Coprime n) : m.gcd n = 1 := by
  sorry
