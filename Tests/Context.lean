module
public import LLMlean
public meta import LLMlean
import Tests.ContextBridge

open Lean Elab Tactic LLMlean

private meta def requireText (text needle : String) : TacticM Unit :=
  unless (text.splitOn needle).length > 1 do throwError "Missing context text: {needle}\n{text}"

private meta def rejectText (text needle : String) : TacticM Unit :=
  unless (text.splitOn needle).length == 1 do throwError "Unexpected context text: {needle}"

elab "expect_structured_context" : tactic => do
  let before ← prettyGoals
  let settings : Config.Settings := { historyChars := 256, premiseChars := 10000 }
  let b ← Context.build settings (← getRef)
  unless before == (← prettyGoals) do throwError "Context extraction changed the proof state."
  let declarations := String.intercalate "\n" b.declarations.toList
  let glossary := String.intercalate "\n" b.glossary.toList
  requireText declarations "ContextChecks.pushTwice"
  requireText declarations "def ContextChecks.pushTwice"
  requireText declarations "fun {α} xs x =>"
  requireText declarations "theorem ContextChecks.pushTwice_eq"
  requireText declarations "ContextExample.ListTools.length_append_one"
  let candidates ← Context.collectCandidates (← Term.getDeclName?)
  unless candidates.any (fun c => c.name == `ContextExample.ListTools.length_append_one &&
      c.moduleName == `Tests.ContextSupport && !c.localDecl) do
    throwError "Imported declaration provenance was lost."
  rejectText declarations "-- earlier in this file"
  rejectText declarations "-- from "
  rejectText declarations "hiddenImported"
  rejectText declarations "laterDeclaration"
  rejectText declarations "theorem ContextChecks.target"
  rejectText declarations "EARLIER_PROOF_ONLY"
  rejectText declarations "Nat.add_assoc"
  rejectText declarations "LLMlean.Config"
  requireText glossary "push₂"
  requireText glossary "ContextChecks.pushTwice"
  requireText glossary "ℓ["
  requireText glossary "List.length"
  requireText glossary "localZero"
  rejectText glossary "expiredNotation"
  requireText b.currentDeclaration "target"
  requireText b.currentDeclaration "n + 2"
  rejectText b.currentDeclaration "have hlen"
  requireText b.history "have hlen"
  rejectText b.history ("AFTER_" ++ "HOLE_ONLY")
  rejectText b.history "expect_structured_context"
  unless b.history.length ≤ settings.historyChars do throwError "Unbounded proof history"
  unless declarations.length ≤ settings.premiseChars do throwError "Unbounded declarations"
  unless glossary.length ≤ settings.notationChars do throwError "Unbounded notation"
  requireText b.goals "hlen"
  requireText b.goals "⊢"
  let checked ← checkCandidate "simpa only [ContextChecks.pushTwice_eq, ContextExample.ListTools.length_append_one] using hlen"
  unless checked == .complete do throwError "Contextual proof should check: {repr checked}"
  let empty ← Context.build { settings with premiseChars := 0, definitionChars := 0 } (← getRef)
  unless empty.declarations.isEmpty && empty.omittedCount > 0 do throwError "Zero premise budget"
  let noBodies ← Context.build { settings with definitionChars := 0 } (← getRef)
  rejectText (String.intercalate "\n" noBodies.declarations.toList) " := "
  let noNotation ← Context.build { settings with notationChars := 0 } (← getRef)
  unless noNotation.glossary.isEmpty do throwError "Zero notation budget"
  rejectText noNotation.goals "push₂"
  requireText noNotation.goals "ContextChecks.pushTwice"
  for mode in ["window", "full", "all_files"] do
    let alternative ← Context.build { settings with contextMode := mode } (← getRef)
    unless alternative.declarations.isEmpty do throwError "Baseline contains premise summaries"
    rejectText alternative.history ("AFTER_" ++ "HOLE_ONLY")
    if mode == "window" then
      unless alternative.history.length ≤ settings.historyChars do throwError "Unbounded source window"
    else
      requireText alternative.history "expiredNotation"
    if mode == "all_files" then
      let names := alternative.importedFiles.map Prod.fst
      unless names == #[`Tests.ContextSupport, `Tests.ContextBridge] do
        throwError "Expected exactly the transitive project sources, got {names}"
      requireText alternative.render "private theorem hiddenImported"
      requireText alternative.render "public import Tests.ContextSupport"
      rejectText alternative.render ("AFTER_" ++ "HOLE_ONLY")
    else
      unless alternative.importedFiles.isEmpty do throwError "Unexpected imported sources"

namespace ContextChecks

def pushTwice {α : Type} (xs : List α) (x : α) : List α := (xs ++ [x]) ++ [x]

theorem pushTwice_eq {α : Type} (xs : List α) (x : α) :
    pushTwice xs x = (xs ++ [x]) ++ [x] := by
  -- EARLIER_PROOF_ONLY: theorem bodies should never enter the premise summaries.
  rfl

section Expired
local notation "expiredNotation" => pushTwice
end Expired

section Active
open ContextExample.ListTools
open scoped ContextExample.LengthNotation
variable {α : Type} (xs : List α) (x : α)
local notation "push₂" => pushTwice
local notation "localZero" => (0 : Nat)

theorem target (n : Nat) (h : xs.length = n) : ℓ[push₂ xs x] = n + 2 := by
  have z : Nat := localZero
  clear z
  have hlen : xs.length + 2 = n + 2 := congrArg (fun k => k + 2) h
  expect_structured_context
  -- AFTER_HOLE_ONLY
  simpa only [pushTwice_eq, length_append_one] using hlen
end Active

theorem laterDeclaration : True := by trivial

end ContextChecks

elab "expect_original_target" : tactic => do
  let b ← Context.build { historyChars := 90, premiseChars := 0 } (← getRef)
  requireText b.currentDeclaration "∀ n : Nat"
  requireText b.currentDeclaration "originalTarget"
  rejectText b.currentDeclaration "intro"
  requireText b.goals "k : Nat"
  requireText b.goals "k = k"
  rejectText b.history "AFTER_NESTED_HOLE"

-- A nested `by` must retain the enclosing declaration, not mistake `have` for the target.
theorem originalTarget : ∀ n : Nat, n = n := by
  intro k
  have hk : k = k := by
    expect_original_target
    -- AFTER_NESTED_HOLE
    rfl
  exact hk

-- Anonymous examples and multiline declaration headers also need source context.
elab "expect_example_header" : tactic => do
  let b ← Context.build { historyChars := 0, premiseChars := 0 } (← getRef)
  requireText b.currentDeclaration "example"
  requireText b.currentDeclaration "True"
  unless b.history.isEmpty do throwError "Zero history budget"

example
    -- A misleading delimiter := by inside a comment must not split the header.
    : True := by
  expect_example_header
  trivial

elab "expect_equation_header" : tactic => do
  let b ← Context.build { premiseChars := 0 } (← getRef)
  requireText b.currentDeclaration "equationTarget"
  rejectText b.currentDeclaration "| n"
  requireText b.history "| n => by"
  requireText b.goals "n : Nat"

def equationTarget : Nat → Nat
  | n => by
    expect_equation_header
    exact n

namespace ContextShape
structure Token where
  payload : Nat

elab "expect_shape_context" : tactic => do
  let b ← Context.build {} (← getRef)
  let declarations := String.intercalate "\n" b.declarations.toList
  requireText declarations "constructor ContextShape.Token.mk"
  requireText declarations "ContextShape.Token.payload"
  requireText b.goals "Inhabited α"

example {α : Type} [Inhabited α] (x : Token) : x = x := by
  expect_shape_context
  rfl
end ContextShape
