module
public import Lean

public section

namespace LLMlean

inductive TaskKind where
  | step
  | proof
  deriving BEq, Repr, Inhabited

def instructions (task : TaskKind) : String :=
  "You are assisting with Lean 4. Use the supplied local context and current goals. " ++
  (match task with
    | .step => "Suggest one useful next tactic or short tactic sequence. "
    | .proof => "Complete all current goals with a tactic sequence. ") ++
  "Return only the replacement tactic sequence in one fenced lean code block. " ++
  "Do not repeat the theorem statement, imports, or the outer 'by'. " ++
  "Do not use sorry, admit, or invoke llmstep/llmqed."

def prompt (context goals pfx : String) : String :=
  s!"Source before this tactic:\n```lean\n{context}\n```\n\nCurrent goals:\n{goals}" ++
  (if pfx.isEmpty then "" else s!"\n\nThe replacement must begin with: {pfx}")

/-- Accept one code block or bare tactics; never silently splice multiple alternatives together. -/
def extractCandidate (text : String) : Except String String := do
  let text := text.trimAscii.toString
  let parts := text.splitOn "```"
  let code ← match parts with
    | [_] => pure text
    | [_, block, _] =>
      let lines := block.splitOn "\n"
      let language := (lines.headD "").trimAscii.toString
      unless language == "lean" || language == "lean4" || language.isEmpty do
        throw "Expected a lean code block."
      pure (String.intercalate "\n" lines.tail)
    | _ => throw "Expected exactly one complete Lean code block."
  let code := code.trimAscii.toString
  if code.isEmpty then throw "Model returned an empty tactic sequence."
  return code

end LLMlean
