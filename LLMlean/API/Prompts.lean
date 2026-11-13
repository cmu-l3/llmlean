module
public import Lean

public section

namespace LLMlean

inductive TaskKind where
  | step
  | proof
  deriving BEq, Repr, Inhabited

def instructions (task : TaskKind) : String :=
  "You are filling a tactic hole INSIDE an existing Lean 4 proof. " ++
  "Your response replaces only the current llmstep/llmqed invocation. " ++
  "The surrounding declaration and its 'by' already exist. " ++
  "Use the supplied local context and current goals. " ++
  "Prefer the supplied qualified declaration names. The current declaration is an unfinished target, not a proved premise. " ++
  (match task with
    | .step => "Suggest one useful next tactic or short tactic sequence. "
    | .proof => "Complete all current goals with a tactic sequence. ") ++
  "\n\nOutput rules:\n" ++
  "- Return exactly one fenced lean code block containing only the replacement tactics.\n" ++
  "- Do not include an example, theorem, lemma, definition, imports, or an outer 'by'.\n" ++
  "- Do not quote or JSON-encode the response. Use actual line breaks.\n" ++
  "- Do not include explanations or alternative answers.\n" ++
  "- Do not use sorry, admit, or invoke llmstep/llmqed.\n\n" ++
  "Example: for the goal 'n : Nat ⊢ n + 0 = n', the entire response is:\n" ++
  "```lean\nrfl\n```\n\n" ++
  "Example: for the goal '⊢ True ∧ True', a complete response is:\n" ++
  "```lean\nconstructor\n· trivial\n· trivial\n```"

def prompt (context goals pfx : String) : String :=
  s!"Context (reference only; do not repeat):\n{context}\n\nCurrent goals and local hypotheses:\n{goals}" ++
  "\n\nFill only the tactic hole with a tactic sequence, not a declaration or a whole proof file." ++
  (if pfx.isEmpty then "" else s!"\n\nThe replacement must begin with: {pfx}")

/-- Accept one code block or bare tactics; never silently splice multiple alternatives together. -/
def extractCandidate (text : String) : Except String String := do
  let text := text.trimAscii.toString
  if let .ok (.str _) := Lean.Json.parse text then
    throw "Return Lean tactics directly in one code block, not a JSON-quoted string. Use actual line breaks."
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
