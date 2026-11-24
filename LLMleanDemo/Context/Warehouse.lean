module

public section

namespace Warehouse

structure Stock where
  available : Nat
  dispatched : Nat

inductive Dispatch : Stock → Stock → Prop where
  | send (n d : Nat) : Dispatch ⟨n + 1, d⟩ ⟨n, d + 1⟩

@[expose] def total (s : Stock) : Nat := s.available + s.dispatched

theorem Dispatch.count_le {s t : Stock} (h : Dispatch s t) : s.dispatched ≤ t.dispatched := by
  cases h
  exact Nat.le_succ _

theorem Dispatch.total_eq {s t : Stock} (h : Dispatch s t) : total t = total s := by
  cases h
  simp only [total]
  omega

end Warehouse
