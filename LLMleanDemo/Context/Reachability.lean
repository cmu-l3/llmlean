module

public section

namespace TransitionSystem

universe u v

inductive Reachable {α : Type u} (step : α → α → Prop) : α → α → Prop where
  | refl (a : α) : Reachable step a a
  | tail {a b c : α} : Reachable step a b → step b c → Reachable step a c

namespace Reachable

variable {α : Type u} {β : Type v}
variable {step : α → α → Prop} {a b c : α}

theorem single (h : step a b) : Reachable step a b :=
  .tail (.refl a) h

theorem trans (hab : Reachable step a b) (hbc : Reachable step b c) :
    Reachable step a c := by
  induction hbc with
  | refl => exact hab
  | tail _ hstep ih => exact .tail ih hstep

theorem preserves (P : α → Prop)
    (hstep : ∀ {s t}, P s → step s t → P t)
    (hab : Reachable step a b) (ha : P a) : P b := by
  induction hab with
  | refl => exact ha
  | tail _ h ih => exact hstep ih h

theorem monotone (measure : α → Nat)
    (hstep : ∀ {s t}, step s t → measure s ≤ measure t)
    (hab : Reachable step a b) : measure a ≤ measure b := by
  induction hab with
  | refl => exact Nat.le_refl _
  | tail _ h ih => exact Nat.le_trans ih (hstep h)

theorem map {next : β → β → Prop} (f : α → β)
    (hstep : ∀ {s t}, step s t → next (f s) (f t))
    (hab : Reachable step a b) : Reachable next (f a) (f b) := by
  induction hab with
  | refl => exact .refl _
  | tail _ h ih => exact .tail ih (hstep h)

end Reachable
end TransitionSystem
