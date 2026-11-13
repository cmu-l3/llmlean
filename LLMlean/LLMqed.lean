module
public import LLMlean.Generate
public meta import LLMlean.Generate

public section

open Lean Elab Tactic

/-- Ask for a checked completion of all goals, refining failed attempts with Lean feedback. -/
syntax (name := llmqed) "llmqed" : tactic

elab_rules : tactic
  | `(tactic| llmqed) => do
    LLMlean.suggest (← getRef) .proof
