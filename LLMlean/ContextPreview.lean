module
public import LLMlean.Context
public import LLMlean.API.Prompts
public meta import LLMlean.Context
public meta import LLMlean.API.Prompts

public section

open Lean Elab Tactic

/-- Show the context and goals that would be sent to the model, without making a request. -/
syntax (name := llmcontext) "llmcontext" : tactic

elab_rules : tactic
  | `(tactic| llmcontext) => do
    let _ ← getMainGoal
    let settings ← LLMlean.Config.load (← getOptions)
    let started ← IO.monoMsNow
    let context ← LLMlean.Context.build settings (← getRef)
    logInfo m!"Context construction: {(← IO.monoMsNow) - started} ms; {context.declarations.size}/{context.candidateCount} declarations; {context.render.length + context.goals.length} Unicode characters."
    logInfo m!"{LLMlean.prompt context.render context.goals ""}"
