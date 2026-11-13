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
  have h0 : True := True.intro
  have h1 : True := True.intro
  have h2 : True := True.intro
  have h3 : True := True.intro
  have h4 : True := True.intro
  have h5 : True := True.intro
  have h6 : True := True.intro
  have h7 : True := True.intro
  have h8 : True := True.intro
  have h9 : True := True.intro
  have h10 : True := True.intro
  have h11 : True := True.intro
  have h12 : True := True.intro
  have h13 : True := True.intro
  have h14 : True := True.intro
  have h15 : True := True.intro
  have h16 : True := True.intro
  have h17 : True := True.intro
  have h18 : True := True.intro
  have h19 : True := True.intro
  have h20 : True := True.intro
  have h21 : True := True.intro
  have h22 : True := True.intro
  have h23 : True := True.intro
  have h24 : True := True.intro
  have h25 : True := True.intro
  have h26 : True := True.intro
  have h27 : True := True.intro
  have h28 : True := True.intro
  have h29 : True := True.intro
  have h30 : True := True.intro
  have h31 : True := True.intro
  rfl
theorem distractor_1 (n : Nat) : n = n := by
  have h0 : True := True.intro
  have h1 : True := True.intro
  have h2 : True := True.intro
  have h3 : True := True.intro
  have h4 : True := True.intro
  have h5 : True := True.intro
  have h6 : True := True.intro
  have h7 : True := True.intro
  have h8 : True := True.intro
  have h9 : True := True.intro
  have h10 : True := True.intro
  have h11 : True := True.intro
  have h12 : True := True.intro
  have h13 : True := True.intro
  have h14 : True := True.intro
  have h15 : True := True.intro
  have h16 : True := True.intro
  have h17 : True := True.intro
  have h18 : True := True.intro
  have h19 : True := True.intro
  have h20 : True := True.intro
  have h21 : True := True.intro
  have h22 : True := True.intro
  have h23 : True := True.intro
  have h24 : True := True.intro
  have h25 : True := True.intro
  have h26 : True := True.intro
  have h27 : True := True.intro
  have h28 : True := True.intro
  have h29 : True := True.intro
  have h30 : True := True.intro
  have h31 : True := True.intro
  rfl
theorem distractor_2 (n : Nat) : n = n := by
  have h0 : True := True.intro
  have h1 : True := True.intro
  have h2 : True := True.intro
  have h3 : True := True.intro
  have h4 : True := True.intro
  have h5 : True := True.intro
  have h6 : True := True.intro
  have h7 : True := True.intro
  have h8 : True := True.intro
  have h9 : True := True.intro
  have h10 : True := True.intro
  have h11 : True := True.intro
  have h12 : True := True.intro
  have h13 : True := True.intro
  have h14 : True := True.intro
  have h15 : True := True.intro
  have h16 : True := True.intro
  have h17 : True := True.intro
  have h18 : True := True.intro
  have h19 : True := True.intro
  have h20 : True := True.intro
  have h21 : True := True.intro
  have h22 : True := True.intro
  have h23 : True := True.intro
  have h24 : True := True.intro
  have h25 : True := True.intro
  have h26 : True := True.intro
  have h27 : True := True.intro
  have h28 : True := True.intro
  have h29 : True := True.intro
  have h30 : True := True.intro
  have h31 : True := True.intro
  rfl
theorem distractor_3 (n : Nat) : n = n := by
  have h0 : True := True.intro
  have h1 : True := True.intro
  have h2 : True := True.intro
  have h3 : True := True.intro
  have h4 : True := True.intro
  have h5 : True := True.intro
  have h6 : True := True.intro
  have h7 : True := True.intro
  have h8 : True := True.intro
  have h9 : True := True.intro
  have h10 : True := True.intro
  have h11 : True := True.intro
  have h12 : True := True.intro
  have h13 : True := True.intro
  have h14 : True := True.intro
  have h15 : True := True.intro
  have h16 : True := True.intro
  have h17 : True := True.intro
  have h18 : True := True.intro
  have h19 : True := True.intro
  have h20 : True := True.intro
  have h21 : True := True.intro
  have h22 : True := True.intro
  have h23 : True := True.intro
  have h24 : True := True.intro
  have h25 : True := True.intro
  have h26 : True := True.intro
  have h27 : True := True.intro
  have h28 : True := True.intro
  have h29 : True := True.intro
  have h30 : True := True.intro
  have h31 : True := True.intro
  rfl
theorem distractor_4 (n : Nat) : n = n := by
  have h0 : True := True.intro
  have h1 : True := True.intro
  have h2 : True := True.intro
  have h3 : True := True.intro
  have h4 : True := True.intro
  have h5 : True := True.intro
  have h6 : True := True.intro
  have h7 : True := True.intro
  have h8 : True := True.intro
  have h9 : True := True.intro
  have h10 : True := True.intro
  have h11 : True := True.intro
  have h12 : True := True.intro
  have h13 : True := True.intro
  have h14 : True := True.intro
  have h15 : True := True.intro
  have h16 : True := True.intro
  have h17 : True := True.intro
  have h18 : True := True.intro
  have h19 : True := True.intro
  have h20 : True := True.intro
  have h21 : True := True.intro
  have h22 : True := True.intro
  have h23 : True := True.intro
  have h24 : True := True.intro
  have h25 : True := True.intro
  have h26 : True := True.intro
  have h27 : True := True.intro
  have h28 : True := True.intro
  have h29 : True := True.intro
  have h30 : True := True.intro
  have h31 : True := True.intro
  rfl
theorem distractor_5 (n : Nat) : n = n := by
  have h0 : True := True.intro
  have h1 : True := True.intro
  have h2 : True := True.intro
  have h3 : True := True.intro
  have h4 : True := True.intro
  have h5 : True := True.intro
  have h6 : True := True.intro
  have h7 : True := True.intro
  have h8 : True := True.intro
  have h9 : True := True.intro
  have h10 : True := True.intro
  have h11 : True := True.intro
  have h12 : True := True.intro
  have h13 : True := True.intro
  have h14 : True := True.intro
  have h15 : True := True.intro
  have h16 : True := True.intro
  have h17 : True := True.intro
  have h18 : True := True.intro
  have h19 : True := True.intro
  have h20 : True := True.intro
  have h21 : True := True.intro
  have h22 : True := True.intro
  have h23 : True := True.intro
  have h24 : True := True.intro
  have h25 : True := True.intro
  have h26 : True := True.intro
  have h27 : True := True.intro
  have h28 : True := True.intro
  have h29 : True := True.intro
  have h30 : True := True.intro
  have h31 : True := True.intro
  rfl
theorem distractor_6 (n : Nat) : n = n := by
  have h0 : True := True.intro
  have h1 : True := True.intro
  have h2 : True := True.intro
  have h3 : True := True.intro
  have h4 : True := True.intro
  have h5 : True := True.intro
  have h6 : True := True.intro
  have h7 : True := True.intro
  have h8 : True := True.intro
  have h9 : True := True.intro
  have h10 : True := True.intro
  have h11 : True := True.intro
  have h12 : True := True.intro
  have h13 : True := True.intro
  have h14 : True := True.intro
  have h15 : True := True.intro
  have h16 : True := True.intro
  have h17 : True := True.intro
  have h18 : True := True.intro
  have h19 : True := True.intro
  have h20 : True := True.intro
  have h21 : True := True.intro
  have h22 : True := True.intro
  have h23 : True := True.intro
  have h24 : True := True.intro
  have h25 : True := True.intro
  have h26 : True := True.intro
  have h27 : True := True.intro
  have h28 : True := True.intro
  have h29 : True := True.intro
  have h30 : True := True.intro
  have h31 : True := True.intro
  rfl
theorem distractor_7 (n : Nat) : n = n := by
  have h0 : True := True.intro
  have h1 : True := True.intro
  have h2 : True := True.intro
  have h3 : True := True.intro
  have h4 : True := True.intro
  have h5 : True := True.intro
  have h6 : True := True.intro
  have h7 : True := True.intro
  have h8 : True := True.intro
  have h9 : True := True.intro
  have h10 : True := True.intro
  have h11 : True := True.intro
  have h12 : True := True.intro
  have h13 : True := True.intro
  have h14 : True := True.intro
  have h15 : True := True.intro
  have h16 : True := True.intro
  have h17 : True := True.intro
  have h18 : True := True.intro
  have h19 : True := True.intro
  have h20 : True := True.intro
  have h21 : True := True.intro
  have h22 : True := True.intro
  have h23 : True := True.intro
  have h24 : True := True.intro
  have h25 : True := True.intro
  have h26 : True := True.intro
  have h27 : True := True.intro
  have h28 : True := True.intro
  have h29 : True := True.intro
  have h30 : True := True.intro
  have h31 : True := True.intro
  rfl

open ContextExample.ListTools
local notation "push₂" => pushTwice
example {α : Type} (xs : List α) (x : α) (n : Nat) (h : xs.length = n) :
    (push₂ xs x).length = n + 2 := by
  have hlen : xs.length + 2 = n + 2 := congrArg (fun k => k + 2) h
  context_benchmark "proofs_medium" 0 false
  simpa only [pushTwice_eq, length_append_one] using hlen
end ContextBench
