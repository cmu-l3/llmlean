/- Prompt generation for LLMlean -/
import LLMlean.Config

open LLMlean.Config

namespace LLMlean

/--
See `makePrompts`.
-/
def makePromptsFewShot (context : String) (state : String) (pre: String) : List String :=
  let p1 := s!"Given the Lean 4 tactic state, suggest a next tactic.
Here are some examples:

Tactic state:
---
α : Type u_1
r : α → α → Prop
inst✝¹ : DecidableEq α
inst✝ : IsIrrefl α r
⊢ CutExpand r ≤ InvImage (Finsupp.Lex (rᶜ ⊓ fun x x_1 => x ≠ x_1) fun x x_1 => x < x_1) ↑toFinsupp
---
Next tactic:
---
rintro s t ⟨u, a, hr, he⟩
---

Tactic state:
---
ι : Type u_1
I✝ J✝ : Box ι
x y : ι → ℝ
I J : WithBot (Box ι)
⊢ ↑I = ↑J ↔ I = J
---
Next tactic:
---
simp only [Subset.antisymm_iff, ← le_antisymm_iff, withBotCoe_subset_iff]
---

Tactic state:
---
m n : ℕ
h : Nat.coprime m n
⊢ Nat.gcd m n = 1
---
Next tactic:
---
rw [← h.gcd_eq_one]
---

Tactic state:
---
{state}
---
Next tactic:
---
{pre}"
  let p2 := match pre with
  | "" => context
  | _  => p1

  [p1, p2]

/--
See `makePrompts`.
-/
def makePromptsInstruct (context : String) (state : String) (pre: String) : List String :=
  let p1 := s!"/- You are proving a theorem in Lean 4.
You are given the following information:
- The file contents up to the current tactic, inside [CTX]...[/CTX]
- The current proof state, inside [STATE]...[/STATE]

Your task is to generate the next tactic in the proof.
Put the next tactic inside [TAC]...[/TAC].
-/
[CTX]
{context}
[/CTX]
[STATE]
{state}
[/STATE]
[TAC]
{pre}"
  [p1]

/--
See `makePrompts`.
-/
def makePromptsReasoning (context : String) (state : String) (pre: String) : List String :=
  let p1 := s!"/- You are proving a theorem in Lean 4.
You are given the following information:
- The file contents up to the current tactic, inside [CTX]...[/CTX]
- The current proof state, inside [STATE]...[/STATE]

Your task is to generate the next tactic in the proof.
Put the next tactic inside [TAC]...[/TAC].
If you find it helpful, you can precede the proof with brief thoughts inside [THOUGHTS]...[/THOUGHTS]
In summary, your output should be of the form:
[THOUGHTS]
...
[/THOUGHTS]
[TAC]
...
[/TAC]

[CTX]
{context}
[/CTX]
[STATE]
{state}
[/STATE]
[THOUGHTS]
{pre}"
  [p1]

/--
See `makePrompts`.
-/
def makePromptsMarkdownReasoning (context : String) (state : String) (pre: String) : List String :=
  let p1 := s!"You are proving a theorem in Lean 4.
You are given the following information:

The file contents up to the current tactic are as follows:

```lean4
{context}
```

The current proof state is as follows:
{state}

Your task is to generate the next tactic in the proof.
Generate this by writing a markdown file with the completed line, including the context of the file before it
in a markdown code block.

If you find it helpful, you can precede the proof with brief thoughts. When you are done, end with </think>.

"
  match pre with
  | "" => [p1]
  | pre => [p1 ++ s!"The tactic you generate should start with {pre}"]

/--
See `makeQedPrompts`.
TODO implement
-/
def makeQedPromptsFewShot (context : String) (_state : String) : List String :=
  let p1 := context
  [p1]

/--
See `makeQedPrompts`.
-/
def makeQedPromptsInstruct (context : String) (_state : String) : List String :=
  let p1 := s!"/- You are proving a theorem in Lean 4.
You are given the following information:
- The current file contents up to and including the theorem statement, inside [CTX]...[/CTX]

Your task is to generate the proof.
Put the proof inside [PROOF]...[/PROOF]
-/
[CTX]
{context}
[/CTX]
[PROOF]"
  [p1]

/--
See `makeQedPrompts`.
-/
def makeQedPromptsReasoning (context : String) (state : String) : List String :=
  let p1 := s!"/- You are proving a theorem in Lean 4.
You are given the following information:
- The file contents up to the current tactic, inside [CTX]...[/CTX]
- The current proof state, inside [STATE]...[/STATE]

Your task is to generate the rest of the proof.
Put the generation inside [PROOF]...[/PROOF].
If you find it helpful, you can precede the proof with brief thoughts inside [THOUGHTS]...[/THOUGHTS]
In summary, your output should be of the form:
[THOUGHTS]
...
[/THOUGHTS]
[PROOF]
...
[/PROOF]
Your proof will be checked by combining each line with a ; combinator and checking
the resulting combined tactic.
Therefore, make sure the proof is formatted as one tactic per line,
with no additional comments or text.
-/
[CTX]
{context}
[/CTX]
[STATE]
{state}
[/STATE]
"
  [p1]

/--
See `makeQedPrompts`.
-/
def makeQedPromptsMarkdownReasoning (context : String) (state : String) : List String :=
  let p1 := s!"You are proving a theorem in Lean 4.

You are given the following information:
The file contents up to the current tactic are as follows:
```lean4
{context}
```
The current proof state is as follows:
{state}
Your task is to generate the proof.
Generate this by writing a markdown file with the completed proof, including the context of the file before it
in a markdown code block.

IMPORTANT: you must end by writing your full proof in the format:
```lean4
<... your proof here...>
```

If you find it helpful, you can precede the proof with brief thoughts, outside the tactic blocks.
IMPORTANT: Once you have written a complete proof, end with </think>.
"
  [p1]

/--
Makes prompts for single tactic generation,
given a `context` containing the file contents up to the tactic invocation,
and a `state` containing the current proof state,
and a `pre` string containing the prefix of the tactic to be generated.
-/
def makePrompts (promptKind : PromptKind) (context : String) (state : String) (pre: String) : List String :=
  match promptKind with
  | PromptKind.FewShot => makePromptsFewShot context state pre
  | PromptKind.Reasoning => makePromptsReasoning context state pre
  | PromptKind.Instruction => makePromptsInstruct context state pre
  | PromptKind.MarkdownReasoning => makePromptsMarkdownReasoning context state pre


/--
Makes prompts for the complete proof generation,
given a `context` containing the file contents up to the tactic invocation,
and a `state` containing the current proof state.
-/
def makeQedPrompts (promptKind : PromptKind) (context : String) (state : String) : List String :=
  match promptKind with
  | PromptKind.FewShot => makeQedPromptsFewShot context state
  | PromptKind.Reasoning => makeQedPromptsReasoning context state
  | PromptKind.Instruction => makeQedPromptsInstruct context state
  | PromptKind.MarkdownReasoning => makeQedPromptsMarkdownReasoning context state

end LLMlean
