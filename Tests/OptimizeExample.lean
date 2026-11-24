import LLMlean

namespace OptimizeExample

section
variable {α : Type} (x : α)

theorem keep (h : x = x) : x = x := by
  have hx : x = x := h
  exact hx

end

theorem swap (P Q : Prop) (h : P ∧ Q) : Q ∧ P := by
  have hp : P := h.left
  have hq : Q := h.right
  exact ⟨hq, hp⟩


end OptimizeExample
