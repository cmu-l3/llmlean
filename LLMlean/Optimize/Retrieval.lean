module
public import LLMlean.Context

public section
open Lean Elab

namespace LLMlean.Optimize

/-- Rank visible project theorems against the target type in the pre-command environment. -/
def projectTheorems (ctx? : Option ContextInfo) (env : Environment) (decl : ConstantVal)
    (record : Json) (root : System.FilePath) : IO (Array String) := do
  let some ctx := ctx? | return #[]
  let refs ← IO.ofExcept do
    let context ← record.getObjVal? "context"
    (← context.getObjValAs? (Array Json) "explicit_ref_signatures").mapM (·.getObjValAs? String "name")
  ({ ctx with env } : ContextInfo).runMetaM {} <| withOptions Context.printOptions do
    let symbols := decl.type.getUsedConstants.foldl NameSet.insert {}
    let pool ← Context.collectCandidates (some decl.name) (some root)
    let mut result := #[]
    let mut used := 0
    for c in Context.rankCandidates pool symbols do
      Core.checkInterrupted
      let name := (privateToUserName c.name).toString
      if refs.contains name || refs.contains c.name.toString || !wasOriginallyTheorem env c.name then continue
      let signature := s!"theorem {name} : {← Meta.ppExpr c.type}"
      -- Bound the staging buffer before counting model tokens.
      if used + signature.utf8ByteSize > 16384 then continue
      result := result.push signature
      used := used + signature.utf8ByteSize
    return result

end LLMlean.Optimize
