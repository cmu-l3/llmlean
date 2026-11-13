module

/-!
Small project module imported by ContextExample.lean.
Its declarations are available to Lean, but the current source-prefix prompt
only shows the import line, not these statements.
-/

public section

namespace ContextExample.ListTools

private theorem hiddenImported : True := by trivial

theorem length_append_one {α : Type} (xs : List α) (x : α) :
    (xs ++ [x]).length = xs.length + 1 := by
  simp

end ContextExample.ListTools

namespace ContextExample.LengthNotation

scoped notation "ℓ[" xs "]" => List.length xs

end ContextExample.LengthNotation
