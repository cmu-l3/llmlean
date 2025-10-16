/- Proof completion for LLMlean -/
import LLMlean.API.Common
import LLMlean.API.Prompts

open Lean LLMlean.Config

namespace LLMlean

open API

/--
Generates proof completions using the LLM API.
-/
def LLMlean.Config.API.proofCompletion
  (api : API) (tacticState : String) (context : String) : CoreM $ Array (String × Float) := do
  let prompts := makeQedPrompts api.promptKind context tacticState
  let options ← getChatGenerationOptions api TacticKind.LLMQed
  let responses := (← generate api prompts options).map (fun (x, p) => (splitProof x, p))
  return responses.filter (fun (x, _) => filterGeneration x)

/--
Extracts proof from markdown response by finding the last code block
and extracting content after the context.
-/
def extractProofFromMarkdownResponse (context : String) (response : String) : Option String := do
  let blocks := getMarkdownLeanCodeBlocks response
  let lastBlock ← blocks.getLast?

  -- Try to find where the context ends in the block
  -- First try: split by the entire context
  let splitByFullContext := lastBlock.splitOn context
  if splitByFullContext.length > 1 then
    -- Found the full context, return everything after it
    let proof := splitByFullContext[1]!.trim
    return proof

  -- Second try: find the last non-empty line of context and split by that
  let contextLines := context.splitOn "\n"
  let lastContextLine := (contextLines.filter (fun x => x.trim.length > 0)).getLast?.getD ""
  if lastContextLine.length > 0 then
    let splitByLastLine := lastBlock.splitOn lastContextLine
    if splitByLastLine.length > 1 then
      -- Found the last context line, return everything after it
      let proof := splitByLastLine[1]!.trim
      return proof

  -- If we can't find the context, return the whole block
  some lastBlock.trim


/--
Generates proof completions with refinement context using the LLM API.
-/
def LLMlean.Config.API.proofCompletionRefinement
  (api : API) (tacticState : String) (context : String)
  (previousAttempt : String) (errorMsg : String) : CoreM $ Array (String × Float) := do
  let prompts := makeQedRefinementPrompts api.promptKind context tacticState previousAttempt errorMsg
  let options ← getChatGenerationOptions api TacticKind.LLMQed
  let responses ← generate api prompts options
  return Std.HashMap.toArray (responses.foldl (fun results (response, prob) =>
    match extractProofFromMarkdownResponse context response with
      | some proof => results.insert proof prob
      | none => results
  ) {})

end LLMlean
