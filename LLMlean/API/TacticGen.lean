/- Tactic generation for LLMlean -/
import LLMlean.API.Common
import LLMlean.API.Prompts

open Lean LLMlean.Config

namespace LLMlean

/--
Parses a tactic out of a response from the LLM.
The tactic is expected to be enclosed in `[TAC]...[/TAC]` tags.
-/
def splitTac (text : String) : String :=
  let text := ((text.splitOn "[TAC]").tailD [text]).headD text
  match (text.splitOn "[/TAC]").head? with
  | some s => s.trim
  | none => text.trim

/-!
## Open AI
-/
def parseTacticResponseOpenAI (res: OpenAIResponse) (pfx : String) : Array String :=
  (res.choices.map fun x => pfx ++ (splitTac x.message.content)).toArray

def tacticGenerationOpenAI (pfx : String) (prompts : List String)
(api : API) (options : ChatGenerationOptions) : IO $ Array (String × Float) := do
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
      n := options.numSamples,
      temperature := options.temperature,
      max_tokens := options.maxTokens,
      stop := options.stopSequences
    }
    let res : OpenAIResponse ← post req api.baseUrl api.key
    for result in (parseTacticResponseOpenAI res pfx) do
      results := results.insert result

  let finalResults := (results.toArray.filter filterGeneration).map fun x => (x, 1.0)
  return finalResults


/-!
## Anthropic
-/
def parseTacticResponseAnthropic (res: AnthropicResponse) (pfx : String) : Array String :=
  (res.content.map fun x => pfx ++ (splitTac x.text)).toArray

def tacticGenerationAnthropic (pfx : String) (prompts : List String)
(api : API) (options : ChatGenerationOptions) : IO $ Array (String × Float) := do
  let mut results : Std.HashSet String := Std.HashSet.emptyWithCapacity
  for prompt in prompts do
    for i in List.range options.numSamples do
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
      for result in (parseTacticResponseAnthropic res pfx) do
        results := results.insert result

  let finalResults := (results.toArray.filter filterGeneration).map fun x => (x, 1.0)
  return finalResults

/-!
## Ollama
-/
def parseResponseOllama (res: OllamaResponse) : String :=
  splitTac res.response

def tacticGenerationOllama (pfx : String) (prompts : List String)
(api : API) (options : ChatGenerationOptions) : IO $ Array (String × Float) := do
  let mut results : Std.HashSet String := Std.HashSet.emptyWithCapacity
  for prompt in prompts do
    for i in List.range options.numSamples do
      let temperature := if i == 1 then 0.0 else options.temperature
      let req : OllamaGenerationRequest := {
        model := api.model,
        prompt := prompt,
        stream := false,
        options := {
          temperature := temperature,
          num_predict := options.maxTokens,
          stop := options.stopSequences
        }
      }
      let res : OllamaResponse ← post req api.baseUrl api.key
      results := results.insert (pfx ++ (parseResponseOllama res))

  let finalResults := (results.toArray.filter filterGeneration).map fun x => (x, 1.0)
  return finalResults


/-!
## Ollama with markdown output (e.g., Kimina Prover)
-/

/--
Given a code block and a context, returns the first line of the code block after the context is written out.
-/
def getTacticFromBlockContext (context : String) (block : String) : String := Id.run do
  -- Get the trimmed last nonempty nonwhitespace line of the context
  let last_context := (((context.splitOn "\n").filter (fun x => x.trim.length > 0)).getLast?.getD "").trim

  -- Trim every line of the block
  let block := "\n".intercalate ((block.splitOn "\n").map (fun x => x.trim))

  let post_context := (block.splitOn last_context)[1]?.getD ""
  if post_context.length > 0 then
    -- get the first nonempty nonwhitespace line of the post_context
    let tactic := ((post_context.splitOn "\n").filter (fun x => x.trim.length > 0)).getLast?.getD ""
    return tactic.trim
  else
    return s!"Did not find context: \n\n{context}\n\n in \n\n{block}\n\n"

def parseTacticResponseOllamaMarkdown (_context : String) (res: OllamaResponse) : List String := Id.run do
  let blocks := getMarkdownLeanCodeBlocks res.response
  let mut results : List String := []
  for block in blocks do
    for line in (block.splitOn "\n") do
      if line.trim.length > 0 then
        results := results ++ [line.trim]
  return results

def tacticGenerationOllamaMarkdown (_pfx : String) (context : String) (prompts : List String)
(api : API) (options : ChatGenerationOptions) : IO $ Array (String × Float) := do
  let mut results : Std.HashSet String := Std.HashSet.emptyWithCapacity
  for prompt in prompts do
    for i in List.range options.numSamples do
      let temperature := if i == 1 then 0.0 else options.temperature
      let req : OllamaGenerationRequest := {
        model := api.model,
        prompt := prompt,
        stream := false,
        options := {
          temperature := temperature,
          num_predict := options.maxTokens,
          stop := options.stopSequences
        }
      }
      let res : OllamaResponse ← post req api.baseUrl api.key
      for tactic in (parseTacticResponseOllamaMarkdown context res) do
        results := results.insert (tactic)

  let finalResults := (results.toArray.filter filterGeneration).map fun x => (x, 1.0)
  return finalResults

/-!
## Main Handler
-/

/--
Generates a list of tactics using the LLM API.
-/
def LLMlean.Config.API.tacticGeneration
  (api : API) (tacticState : String) (context : String)
  («prefix» : String) : CoreM $ Array (String × Float) := do
  let prompts := makePrompts api.promptKind context tacticState «prefix»
  let options ← getChatGenerationOptions api
  match api.kind with
    | APIKind.Ollama =>
      match api.responseFormat with
      | ResponseFormat.Markdown =>
          tacticGenerationOllamaMarkdown «prefix» context prompts api options
      | _ =>
          tacticGenerationOllama «prefix» prompts api options
    | APIKind.TogetherAI =>
      tacticGenerationOpenAI «prefix» prompts api options
    | APIKind.OpenAI =>
      tacticGenerationOpenAI «prefix» prompts api options
    | APIKind.Anthropic =>
      tacticGenerationAnthropic «prefix» prompts api options

end LLMlean
