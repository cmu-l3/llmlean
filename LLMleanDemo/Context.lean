module
import LLMlean
import Context.Reachability

namespace Warehouse

structure Stock where
  available : Nat
  dispatched : Nat

inductive Dispatch : Stock → Stock → Prop where
  | send (n d : Nat) : Dispatch ⟨n + 1, d⟩ ⟨n, d + 1⟩

def total (s : Stock) : Nat := s.available + s.dispatched

open TransitionSystem
local infix:50 " ⟶* " => Reachable Dispatch

theorem dispatch_preserves_total {s t : Stock} (h : Dispatch s t) :
    total t = total s := by
  sorry

theorem dispatch_increases_count {s t : Stock} (h : Dispatch s t) :
    s.dispatched ≤ t.dispatched := by
  sorry

theorem empty_stock_cannot_dispatch (d : Nat) :
    ¬ ∃ t, Dispatch ⟨0, d⟩ t := by
  intro ⟨t, h⟩
  cases h

example {s t : Stock} (h : s ⟶* t) : total t = total s := by
  sorry

example {s t : Stock} (h : s ⟶* t) : s.dispatched ≤ t.dispatched := by
  sorry

example {s t : Stock} (h : s ⟶* t) (hempty : t.available = 0) :
    t.dispatched = total s := by
  sorry

example (n d : Nat) : (⟨n, d⟩ : Stock) ⟶* ⟨0, d + n⟩ := by
  sorry

end Warehouse
