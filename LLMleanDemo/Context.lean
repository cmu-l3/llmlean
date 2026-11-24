module
import LLMlean
public import Context.Reachability
public import Context.Warehouse

namespace Warehouse

open TransitionSystem
local infix:50 " ⟶* " => Reachable Dispatch

-- Try “LLMLean: Optimize proof” anywhere in this proof.
/-- If the warehouse closes empty, the two shifts together shipped all its opening stock. -/
public theorem two_shift_shipments {opening handoff closing : Stock}
    (morning : opening ⟶* handoff) (evening : handoff ⟶* closing)
    (empty : closing.available = 0) :
    (handoff.dispatched - opening.dispatched) +
      (closing.dispatched - handoff.dispatched) = opening.available := by
  have countStep {s t : Stock} (h : Dispatch s t) : s.dispatched ≤ t.dispatched := by
    cases h
    exact Nat.le_succ _
  have morningCount : opening.dispatched ≤ handoff.dispatched :=
    Reachable.monotone Stock.dispatched (fun h => countStep h) morning
  have eveningCount : handoff.dispatched ≤ closing.dispatched :=
    Reachable.monotone Stock.dispatched (fun h => countStep h) evening

  have totalStep {s t : Stock} (h : Dispatch s t) : total t = total s := by
    cases h
    simp only [total]
    omega
  have day : opening ⟶* closing := Reachable.trans morning evening
  have closingTotal : total closing = total opening := by
    apply Reachable.preserves (fun s => total s = total opening) _ day rfl
    intro s t hs h
    exact (totalStep h).trans hs
  have closingCount : closing.dispatched = opening.available + opening.dispatched := by
    simpa [total, empty] using closingTotal

  calc
    (handoff.dispatched - opening.dispatched) + (closing.dispatched - handoff.dispatched)
        = closing.dispatched - opening.dispatched := by omega
    _ = opening.available := by omega

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
