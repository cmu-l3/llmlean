import LLMlean.API

open LLMlean LLMlean.Config


def markdownExample1 : String :=
  "# Example Markdown File\n" ++
  "This is an example of a markdown file.\n" ++
  "Here is a code block:\n" ++
  "```lean\n" ++
  "import Mathlib\n" ++
  "theorem foo (a b : ℕ) : a + a + b = a + b + a := by\n" ++
  "  ring\n" ++
  "```\n" ++
  "And here is some inline code: `x + y = y + x`.\n" ++
  "## Another Section\n" ++
  "This is another section of the markdown file.\n" ++
  "Here is another code block:\n" ++
  "```lean\n" ++
  "example {α : Type _} (r s t : Set α) : r ⊆ s → s ⊆ t → r ⊆ t := by\n" ++
  "  sorry\n" ++
  "```\n"

def contextExample1 : String :=
  "import Mathlib\n" ++
  "theorem foo (a b : ℕ) : a + a + b = a + b + a := by\n"

def codeBlockExample1 : String :=
  "import Mathlib\n" ++
  "theorem foo (a b : ℕ) : a + a + b = a + b + a := by\n" ++
  "  ring\n"

def codeBlockExample2 : String :=
  "example {α : Type _} (r s t : Set α) : r ⊆ s → s ⊆ t → r ⊆ t := by\n" ++
  "  sorry\n"

-- Test `getMarkdownLeanCodeBlocks
/--
info: true
-/
#guard_msgs in
#eval getMarkdownLeanCodeBlocks markdownExample1 == [codeBlockExample1, codeBlockExample2]

-- Test `getTacticFromBlockContext`
/--
info: true
-/
#guard_msgs in
#eval getTacticFromBlockContext "import Mathlib\ntheorem foo (a b : ℕ) : a + a + b = a + b + a := by" codeBlockExample1 == "ring"

-- Test `parseResponseQedOllamaMarkdown`
/--
info: "ring"
-/
#guard_msgs in
#eval parseResponseQedOllamaMarkdown contextExample1 markdownExample1

-- #eval do
--   let api : API ← getConfiguredAPI
--   IO.println (reprStr api)
--   let context := "import Mathlib\ntheorem foo (a b : ℕ) : a + a + b = a + b + a := by "
--   let tacticState := "a b : ℕ\n⊢  a + a + b = a + b + a"
--   let prefix_ := ""
--   let res ← API.proofCompletion api tacticState context
--   for r in res do
--     IO.println r
