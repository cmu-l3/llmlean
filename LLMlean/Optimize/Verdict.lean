module
public import Lean.Data.Json

public section

namespace LLMlean.Optimize.Verdict

open Lean

/-- The fields used from a Lean frontend extraction record. -/
structure Declaration where
  name : String
  statement_source : String
  type_pp : String
  deriving FromJson

structure Proof where
  source : String
  length_tokens : Nat
  explicit_lemma_refs : Array String
  axioms : Array String
  deriving FromJson

structure Extraction where
  status : String
  deriving FromJson

structure Record where
  declaration : Declaration
  proof : Proof
  extraction : Extraction
  deriving FromJson

def checkIdentity (expected : Declaration) (source : String) (record : Record) : Except String Unit := do
  unless record.declaration.name == expected.name &&
      record.declaration.statement_source == expected.statement_source do
    throw "Declaration statement or name changed"
  unless record.declaration.type_pp == expected.type_pp do
    throw "Elaborated theorem signature changed"
  unless record.proof.source == source do
    throw "Candidate did not occupy exactly the original proof boundary"

def hasForbiddenAxiom (proof : Proof) : Bool :=
  proof.axioms.any fun name => #["sorryAx", "Lean.ofReduceBool", "Lean.ofReduceNat"].contains name

def rejected (detail : String) : Json :=
  Json.mkObj [("improved", toJson false), ("detail", toJson detail)]

/-- Order verified proofs by source tokens, breaking ties by distinct explicitly named lemmas. -/
def betterScore : Nat × Nat → Nat × Nat → Bool
  | (tokens, lemmas), (otherTokens, otherLemmas) =>
    tokens < otherTokens || (tokens == otherTokens && lemmas < otherLemmas)

def compare (original candidate : Record) (replacement : String) (elapsedMs : Nat) : Json := Id.run do
  if let .error reason := checkIdentity original.declaration replacement candidate then
    return rejected reason
  let before := original.proof
  let after := candidate.proof
  if hasForbiddenAxiom before || hasForbiddenAxiom after then
    return rejected "Unapproved trust axiom"
  let permitted := #["propext", "Classical.choice", "Quot.sound"]
  if after.axioms.any fun ax => !before.axioms.contains ax && !permitted.contains ax then
    return rejected "New unapproved axiom dependencies"
  if elapsedMs > 2000 then return rejected "Target elaboration runtime bound exceeded"
  let tokens := before.length_tokens
  let newTokens := after.length_tokens
  let lemmas := before.explicit_lemma_refs.toList.eraseDups.length
  let newLemmas := after.explicit_lemma_refs.toList.eraseDups.length
  let beforeComplete := original.extraction.status == "ok"
  let afterComplete := candidate.extraction.status == "ok"
  let lemmaCounts := #[if beforeComplete then some lemmas else none,
                       if afterComplete then some newLemmas else none]
  let metrics := Json.mkObj [("tokens", toJson #[tokens, newTokens]), ("lemmas", toJson lemmaCounts)]
  unless beforeComplete && afterComplete do
    let which := if beforeComplete then "the rewrite" else if afterComplete then "the original proof" else "either proof"
    return (rejected s!"Could not count all explicitly named lemmas in {which}.").setObjVal! "metrics" metrics
  unless betterScore (newTokens, newLemmas) (tokens, lemmas) do
    return (rejected "The verified proof did not improve the source metrics.").setObjVal! "metrics" metrics
  let summary := s!"Proof tokens {tokens} → {newTokens}, explicit lemmas {lemmas} → {newLemmas}"
  return Json.mkObj [("improved", toJson true), ("metrics", metrics), ("summary", toJson summary),
    ("original", toJson before.source), ("proof", toJson replacement)]

end LLMlean.Optimize.Verdict
