import LLMlean

import Mathlib

open BigOperators


example {α : Type _} (r s t : Set α) : r ⊆ s → s ⊆ t → r ⊆ t := by
  intro hrs hst x hx
  exact hst (hrs hx)


example (x y : ℕ) : x + y = y + x := by
  sorry

example (x y z: ℕ) : x + y + z = y + x + z := by
  ac_rfl

variable {Ω : Type*}[Fintype Ω]

structure my_object (Ω : Type*)[Fintype Ω] :=
  (f : Ω → ℝ)
  (cool_property : ∀ x : Ω, 0 ≤ f x)

theorem my_object_sum_nonneg (o1 o2: my_object Ω) : o1.f + o2.f ≥ 0 := by
  sorry
