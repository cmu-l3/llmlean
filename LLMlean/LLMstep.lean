module
public import LLMlean.Generate
public meta import LLMlean.Generate

public section

open Lean Elab Tactic

/-- Ask for a checked next step, optionally beginning with a given prefix. -/
syntax (name := llmstep) "llmstep" (ppSpace str)? : tactic

elab_rules : tactic
  | `(tactic| llmstep $[$pfx:str]?) => do
    LLMlean.suggest (← getRef) .step (pfx.map TSyntax.getString |>.getD "")
