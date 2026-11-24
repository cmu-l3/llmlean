module
meta import LLMlean.Optimize.Verdict

meta section

open Lean LLMlean.Optimize.Verdict

private def original : Record := {
  declaration := ⟨"Example.swap", "theorem swap", "P ∧ Q → Q ∧ P"⟩
  proof := ⟨"by exact h", 3, #["a", "b"], #["Existing.ax"]⟩
  extraction := ⟨"ok"⟩ }

private def candidate : Record := { original with
  proof := ⟨"by grind", 2, #["a", "a"], #["Existing.ax", "Classical.choice"]⟩ }

private def improves (before after : Record) (ms : Nat := 1) : Bool :=
  ((compare before after after.proof.source ms).getObjValAs? Bool "improved").toOption == some true

#guard improves original candidate 2000
#guard !improves original candidate 2001
#guard !improves original original
private def partialVerdict (before after : Record) : String × Array (Option Nat) := Id.run do
  let result := compare before after after.proof.source 1
  let .ok false := result.getObjValAs? Bool "improved" | return default
  let .ok reason := result.getObjValAs? String "detail" | return default
  let .ok counts := result.getObjVal? "metrics" >>= (·.getObjValAs? (Array (Option Nat)) "lemmas") | return default
  return (reason, counts)

#guard partialVerdict original { candidate with extraction := ⟨"partial"⟩ } ==
  ("Could not count all explicitly named lemmas in the rewrite.", #[some 2, none])
#guard partialVerdict { original with extraction := ⟨"partial"⟩ } candidate ==
  ("Could not count all explicitly named lemmas in the original proof.", #[none, some 1])
#guard !improves original { candidate with proof.length_tokens := 4 }
#guard !improves original { candidate with proof.explicit_lemma_refs := #["a", "b", "c"] }
#guard !improves original { candidate with proof.axioms := #["New.ax"] }
#guard !improves { original with proof.axioms := #["sorryAx"] } candidate
#guard !improves original { candidate with proof.axioms := #["Lean.ofReduceBool"] }
#guard !improves original { candidate with declaration.type_pp := "True" }
#guard ((compare original candidate "by rfl" 0).getObjValAs? Bool "improved").toOption == some false
#guard ((compare original candidate "by grind" 0).getObjVal? "metrics" >>= (·.getObjValAs? (Array Nat) "lemmas")).toOption == some #[2, 1]
