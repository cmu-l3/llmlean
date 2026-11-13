import Tests.ContextBench
set_option maxHeartbeats 0
set_option llmlean.attempts 1

namespace ContextExample.ListTools
theorem length_append_one {α : Type} (xs : List α) (x : α) :
    (xs ++ [x]).length = xs.length + 1 := by simp
end ContextExample.ListTools

namespace ContextBench
def pushTwice {α : Type} (xs : List α) (x : α) : List α :=
  (xs ++ [x]) ++ [x]
theorem pushTwice_eq {α : Type} (xs : List α) (x : α) :
    pushTwice xs x = (xs ++ [x]) ++ [x] := by rfl

open ContextExample.ListTools
local notation "push₂" => pushTwice
example {α : Type} (xs : List α) (x : α) (n : Nat) (h : xs.length = n) :
    (push₂ xs x).length = n + 2 := by
  have hlen : xs.length + 2 = n + 2 := congrArg (fun k => k + 2) h
  context_benchmark "imports_same_file" 0 false
  simpa only [pushTwice_eq, length_append_one] using hlen
end ContextBench
