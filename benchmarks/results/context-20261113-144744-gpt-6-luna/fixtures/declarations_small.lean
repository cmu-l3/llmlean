import Tests.ContextBench
import Tests.ContextSupport
set_option maxHeartbeats 0
set_option llmlean.attempts 1

namespace ContextBench
def pushTwice {α : Type} (xs : List α) (x : α) : List α :=
  (xs ++ [x]) ++ [x]
theorem pushTwice_eq {α : Type} (xs : List α) (x : α) :
    pushTwice xs x = (xs ++ [x]) ++ [x] := by rfl
theorem distractor_0 (n : Nat) : n = n := by
  rfl
theorem distractor_1 (n : Nat) : n = n := by
  rfl
theorem distractor_2 (n : Nat) : n = n := by
  rfl
theorem distractor_3 (n : Nat) : n = n := by
  rfl
theorem distractor_4 (n : Nat) : n = n := by
  rfl
theorem distractor_5 (n : Nat) : n = n := by
  rfl
theorem distractor_6 (n : Nat) : n = n := by
  rfl
theorem distractor_7 (n : Nat) : n = n := by
  rfl
theorem distractor_8 (n : Nat) : n = n := by
  rfl
theorem distractor_9 (n : Nat) : n = n := by
  rfl

open ContextExample.ListTools
local notation "push₂" => pushTwice
example {α : Type} (xs : List α) (x : α) (n : Nat) (h : xs.length = n) :
    (push₂ xs x).length = n + 2 := by
  have hlen : xs.length + 2 = n + 2 := congrArg (fun k => k + 2) h
  context_benchmark "declarations_small" 0 false
  simpa only [pushTwice_eq, length_append_one] using hlen
end ContextBench
