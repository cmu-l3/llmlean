module
import LLMlean
import Tests.ContextSupport

/-!
A worked example of context selection at a tactic hole.

Check from the repository root:
  lake build Tests.ContextExample

This file makes no LLM calls. At the HOLE marker, replace the `simpa` line
with `llmqed` to try a suggestion with the current implementation.
Insert `llmcontext` at the marker to inspect the actual context without making
a model call. The prompt at the bottom is a simplified illustration; the
builder derives the actual glossary and summaries from Lean's environment.
-/

namespace ContextExample

-- 1. EARLIER DECLARATIONS: these remain available after their definition.
-- Retain the short definition body: its type alone does not explain pushTwice.
def pushTwice {α : Type} (xs : List α) (x : α) : List α :=
  (xs ++ [x]) ++ [x]

-- Retain this theorem's name and statement; its proof can be omitted.
theorem pushTwice_eq {α : Type} (xs : List α) (x : α) :
    pushTwice xs x = (xs ++ [x]) ++ [x] := by
  rfl

-- 2. EXPIRED SCOPE: these commands occur earlier in the source, but their
-- effects end at `end OldScope`. Do not list them as active at the hole.
section OldScope
  open Int
  variable (oldCount : Nat)
  local notation "oldZero" => (0 : Nat)
end OldScope

section ActiveScope

-- 3. ACTIVE SCOPE: these commands still apply at the hole.
-- The enclosing namespace is ContextExample.
open ListTools
open scoped LengthNotation
variable {α : Type} (xs : List α) (x : α)
local notation "push₂" => pushTwice

/- Imagine many unrelated declarations and long proofs here.
   A small recent-source window could lose both the declarations above and
   the commands establishing the active scope. The structured context should
   preserve useful earlier declarations and describe the still-active scope.
-/

theorem pushTwice_length (n : Nat) (h : xs.length = n) :
    ℓ[push₂ xs x] = n + 2 := by
  -- 4. RECENT PROOF HISTORY: this new hypothesis is also in the goal state.
  have hlen : xs.length + 2 = n + 2 := congrArg (fun k => k + 2) h

  -- ======================= HOLE: llmqed =======================
  -- 5. CURRENT PROOF STATE: α, xs, x, n, h, hlen, and the target.
  -- Uncomment `trace_state` to inspect Lean's actual rendering here.
  -- trace_state
  -- llmcontext
  --
  -- This solution uses an earlier theorem (pushTwice_eq), an imported
  -- theorem (length_append_one), and a local hypothesis (hlen).
  simpa only [pushTwice_eq, length_append_one] using hlen

end ActiveScope

-- The notation push₂ and the section variables are no longer active here.
-- The theorem declared inside that section is still available, with the
-- used section variables incorporated into its parameters.
#check pushTwice_length

-- 6. LATER DECLARATION: it must not enter the candidate pool at the hole.
theorem declared_after_the_hole : True := by
  trivial

end ContextExample

/-
ILLUSTRATIVE COMPACT PROMPT AT THE HOLE
====================================
This is explanatory reference information, not a standalone Lean program.
It deliberately uses qualified names to make declaration identities clear.

ACTIVE SCOPE
  namespace ContextExample
  open ContextExample.ListTools
  open scoped ContextExample.LengthNotation
  local notation "push₂" => ContextExample.pushTwice
  scoped notation "ℓ[" xs "]" => List.length xs
    (provided by the active LengthNotation scope)

EARLIER DECLARATIONS IN THIS FILE
  def ContextExample.pushTwice {α : Type} (xs : List α) (x : α) : List α :=
    (xs ++ [x]) ++ [x]
  theorem ContextExample.pushTwice_eq {α : Type} (xs : List α) (x : α) :
    ContextExample.pushTwice xs x = (xs ++ [x]) ++ [x]

IMPORTED PROJECT DECLARATIONS: Tests.ContextSupport
  theorem ContextExample.ListTools.length_append_one
    {α : Type} (xs : List α) (x : α) :
    (xs ++ [x]).length = xs.length + 1

RECENT SOURCE
  have hlen : xs.length + 2 = n + 2 := congrArg (fun k => k + 2) h

CURRENT GOAL AND LOCAL HYPOTHESES
  α : Type
  xs : List α
  x : α
  n : Nat
  h : xs.length = n
  hlen : xs.length + 2 = n + 2
  ⊢ (ContextExample.pushTwice xs x).length = n + 2

The goal above is written without the custom notation for clarity. A real
context builder should keep its notation definitions and goal rendering
consistent. Section variables are already represented in the local context.

Exclude: OldScope's open/variable/notation commands, earlier theorem proofs,
unrelated declarations, declared_after_the_hole, and the solution at the hole.
-/
