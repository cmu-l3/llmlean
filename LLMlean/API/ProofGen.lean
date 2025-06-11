/- Proof completion for LLMlean -/
import LLMlean.API.Common
import LLMlean.API.Prompts

open Lean LLMlean.Config

namespace LLMlean

/--
Parses a proof out of a response from the LLM.
The proof is expected to be enclosed in `[PROOF]...[/PROOF]` tags.
-/
def splitProof (text : String) : String :=
  let text := ((text.splitOn "[PROOF]").tailD [text]).headD text
  match (text.splitOn "[/PROOF]").head? with
  | some s => s.trim
  | none => text.trim

/-!
## OpenAI
-/
def parseResponseQedOpenAI (res: OpenAIResponse) : Array String :=
  (res.choices.map fun x => (splitProof x.message.content)).toArray

def qedOpenAI (prompts : List String)
(api : API) (numSamples : Nat) (options : ChatGenerationOptionsQed) : IO $ Array (String × Float) := do
  let mut results : Std.HashSet String := Std.HashSet.emptyWithCapacity
  for prompt in prompts do
    let req : OpenAIGenerationRequest := {
      model := api.model,
      messages := [
        {
          role := "user",
          content := prompt
        }
      ],
      n := numSamples,
      temperature := options.temperature,
      max_tokens := options.maxTokens,
      stop := options.stopSequences
    }
    let res : OpenAIResponse ← post req api.baseUrl api.key
    for result in (parseResponseQedOpenAI res) do
      results := results.insert result

  let finalResults := (results.toArray.filter filterGeneration).map fun x => (x, 1.0)
  return finalResults

/-!
## Anthropic
-/
def parseResponseQedAnthropic (res: AnthropicResponse) : Array String :=
  (res.content.map fun x => (splitProof x.text)).toArray

def qedAnthropic (prompts : List String)
(api : API) (numSamples : Nat) (options : ChatGenerationOptionsQed) : IO $ Array (String × Float) := do
  let mut results : Std.HashSet String := Std.HashSet.emptyWithCapacity
  for prompt in prompts do
    for i in List.range numSamples do
      let temperature := if i == 1 then 0.0 else options.temperature
      let req : AnthropicGenerationRequest := {
        model := api.model,
        messages := [
          {
            role := "user",
            content := prompt
          }
        ],
        temperature := temperature,
        max_tokens := options.maxTokens,
        stop_sequences := options.stopSequences
      }
      let res : AnthropicResponse ← post req api.baseUrl api.key
      for result in (parseResponseQedAnthropic res) do
        results := results.insert result

  let finalResults := (results.toArray.filter filterGeneration).map fun x => (x, 1.0)
  return finalResults

/-!
## Ollama
-/
def parseResponseQedOllama (res: OllamaResponse) : String :=
  splitProof res.response

def qedOllama (prompts : List String)
(api : API) (numSamples : Nat) (options : ChatGenerationOptionsQed) : IO $ Array (String × Float) := do
  let mut results : Std.HashSet String := Std.HashSet.emptyWithCapacity
  for prompt in prompts do
    for i in List.range numSamples do
      let temperature := if i == 1 then 0.0 else options.temperature
      let req : OllamaGenerationRequest := {
        model := api.model,
        prompt := prompt,
        stream := false,
        options := {
          temperature := temperature,
          stop := options.stopSequences,
          num_predict := options.maxTokens
        }
      }
      let res : OllamaResponse ← post req api.baseUrl api.key
      results := results.insert (parseResponseQedOllama res)

  let finalResults := (results.toArray.filter filterGeneration).map fun x => (x, 1.0)
  return finalResults

/-!
## Ollama with markdown output (e.g., Kimina Prover)
-/

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

def qedOllamaMarkdown (prompts : List String) (context : String)
(api : API) (numSamples : Nat) (options : ChatGenerationOptionsQed) : IO $ Array (String × Float) := do
  let mut results : Std.HashSet String := Std.HashSet.emptyWithCapacity
  for prompt in prompts do
    for i in List.range numSamples do
      let temperature := if i == 1 then 0.0 else options.temperature
      let req : OllamaGenerationRequest := {
        model := api.model,
        prompt := prompt,
        stream := false,
        options := {
          temperature := temperature,
          stop := options.stopSequences,
          num_predict := options.maxTokens
        }
      }
      let res : OllamaResponse ← post req api.baseUrl api.key
      match extractProofFromMarkdownResponse context res.response with
      | some proof => results := results.insert proof
      | none => results := results

  let finalResults := (results.toArray.filter filterGeneration).map fun x => (x, 1.0)
  return finalResults

/-!
## Main Handler
-/

/--
Generates proof completions using the LLM API.
-/
def LLMlean.Config.API.proofCompletion
  (api : API) (tacticState : String) (context : String) : CoreM $ Array (String × Float) := do
  let prompts := makeQedPrompts api.promptKind context tacticState
  let numSamples ← getNumSamples api
  let options := getChatGenerationOptionsQed
  match api.kind with
    | APIKind.Ollama =>
      match api.responseFormat with
      | ResponseFormat.Markdown =>
        qedOllamaMarkdown prompts context api numSamples options
      | _ =>
        qedOllama prompts api numSamples options
    | APIKind.TogetherAI =>
      qedOpenAI prompts api numSamples options
    | APIKind.OpenAI =>
      qedOpenAI prompts api numSamples options
    | APIKind.Anthropic =>
      qedAnthropic prompts api numSamples options

end LLMlean
