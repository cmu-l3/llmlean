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
theorem distractor_10 (n : Nat) : n = n := by
  rfl
theorem distractor_11 (n : Nat) : n = n := by
  rfl
theorem distractor_12 (n : Nat) : n = n := by
  rfl
theorem distractor_13 (n : Nat) : n = n := by
  rfl
theorem distractor_14 (n : Nat) : n = n := by
  rfl
theorem distractor_15 (n : Nat) : n = n := by
  rfl
theorem distractor_16 (n : Nat) : n = n := by
  rfl
theorem distractor_17 (n : Nat) : n = n := by
  rfl
theorem distractor_18 (n : Nat) : n = n := by
  rfl
theorem distractor_19 (n : Nat) : n = n := by
  rfl
theorem distractor_20 (n : Nat) : n = n := by
  rfl
theorem distractor_21 (n : Nat) : n = n := by
  rfl
theorem distractor_22 (n : Nat) : n = n := by
  rfl
theorem distractor_23 (n : Nat) : n = n := by
  rfl
theorem distractor_24 (n : Nat) : n = n := by
  rfl
theorem distractor_25 (n : Nat) : n = n := by
  rfl
theorem distractor_26 (n : Nat) : n = n := by
  rfl
theorem distractor_27 (n : Nat) : n = n := by
  rfl
theorem distractor_28 (n : Nat) : n = n := by
  rfl
theorem distractor_29 (n : Nat) : n = n := by
  rfl
theorem distractor_30 (n : Nat) : n = n := by
  rfl
theorem distractor_31 (n : Nat) : n = n := by
  rfl
theorem distractor_32 (n : Nat) : n = n := by
  rfl
theorem distractor_33 (n : Nat) : n = n := by
  rfl
theorem distractor_34 (n : Nat) : n = n := by
  rfl
theorem distractor_35 (n : Nat) : n = n := by
  rfl
theorem distractor_36 (n : Nat) : n = n := by
  rfl
theorem distractor_37 (n : Nat) : n = n := by
  rfl
theorem distractor_38 (n : Nat) : n = n := by
  rfl
theorem distractor_39 (n : Nat) : n = n := by
  rfl
theorem distractor_40 (n : Nat) : n = n := by
  rfl
theorem distractor_41 (n : Nat) : n = n := by
  rfl
theorem distractor_42 (n : Nat) : n = n := by
  rfl
theorem distractor_43 (n : Nat) : n = n := by
  rfl
theorem distractor_44 (n : Nat) : n = n := by
  rfl
theorem distractor_45 (n : Nat) : n = n := by
  rfl
theorem distractor_46 (n : Nat) : n = n := by
  rfl
theorem distractor_47 (n : Nat) : n = n := by
  rfl
theorem distractor_48 (n : Nat) : n = n := by
  rfl
theorem distractor_49 (n : Nat) : n = n := by
  rfl
theorem distractor_50 (n : Nat) : n = n := by
  rfl
theorem distractor_51 (n : Nat) : n = n := by
  rfl
theorem distractor_52 (n : Nat) : n = n := by
  rfl
theorem distractor_53 (n : Nat) : n = n := by
  rfl
theorem distractor_54 (n : Nat) : n = n := by
  rfl
theorem distractor_55 (n : Nat) : n = n := by
  rfl
theorem distractor_56 (n : Nat) : n = n := by
  rfl
theorem distractor_57 (n : Nat) : n = n := by
  rfl
theorem distractor_58 (n : Nat) : n = n := by
  rfl
theorem distractor_59 (n : Nat) : n = n := by
  rfl
theorem distractor_60 (n : Nat) : n = n := by
  rfl
theorem distractor_61 (n : Nat) : n = n := by
  rfl
theorem distractor_62 (n : Nat) : n = n := by
  rfl
theorem distractor_63 (n : Nat) : n = n := by
  rfl
theorem distractor_64 (n : Nat) : n = n := by
  rfl
theorem distractor_65 (n : Nat) : n = n := by
  rfl
theorem distractor_66 (n : Nat) : n = n := by
  rfl
theorem distractor_67 (n : Nat) : n = n := by
  rfl
theorem distractor_68 (n : Nat) : n = n := by
  rfl
theorem distractor_69 (n : Nat) : n = n := by
  rfl
theorem distractor_70 (n : Nat) : n = n := by
  rfl
theorem distractor_71 (n : Nat) : n = n := by
  rfl
theorem distractor_72 (n : Nat) : n = n := by
  rfl
theorem distractor_73 (n : Nat) : n = n := by
  rfl
theorem distractor_74 (n : Nat) : n = n := by
  rfl
theorem distractor_75 (n : Nat) : n = n := by
  rfl
theorem distractor_76 (n : Nat) : n = n := by
  rfl
theorem distractor_77 (n : Nat) : n = n := by
  rfl
theorem distractor_78 (n : Nat) : n = n := by
  rfl
theorem distractor_79 (n : Nat) : n = n := by
  rfl
theorem distractor_80 (n : Nat) : n = n := by
  rfl
theorem distractor_81 (n : Nat) : n = n := by
  rfl
theorem distractor_82 (n : Nat) : n = n := by
  rfl
theorem distractor_83 (n : Nat) : n = n := by
  rfl
theorem distractor_84 (n : Nat) : n = n := by
  rfl
theorem distractor_85 (n : Nat) : n = n := by
  rfl
theorem distractor_86 (n : Nat) : n = n := by
  rfl
theorem distractor_87 (n : Nat) : n = n := by
  rfl
theorem distractor_88 (n : Nat) : n = n := by
  rfl
theorem distractor_89 (n : Nat) : n = n := by
  rfl
theorem distractor_90 (n : Nat) : n = n := by
  rfl
theorem distractor_91 (n : Nat) : n = n := by
  rfl
theorem distractor_92 (n : Nat) : n = n := by
  rfl
theorem distractor_93 (n : Nat) : n = n := by
  rfl
theorem distractor_94 (n : Nat) : n = n := by
  rfl
theorem distractor_95 (n : Nat) : n = n := by
  rfl
theorem distractor_96 (n : Nat) : n = n := by
  rfl
theorem distractor_97 (n : Nat) : n = n := by
  rfl
theorem distractor_98 (n : Nat) : n = n := by
  rfl
theorem distractor_99 (n : Nat) : n = n := by
  rfl

open ContextExample.ListTools
local notation "push₂" => pushTwice
example {α : Type} (xs : List α) (x : α) (n : Nat) (h : xs.length = n) :
    (push₂ xs x).length = n + 2 := by
  have hlen : xs.length + 2 = n + 2 := congrArg (fun k => k + 2) h
  context_benchmark "declarations_medium" 0 false
  simpa only [pushTwice_eq, length_append_one] using hlen
end ContextBench
