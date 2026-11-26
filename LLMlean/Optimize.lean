module
public import LLMlean.API.Responses
public import LLMlean.Optimize.Verdict
public import LLMlean.Optimize.Prompt
public import LLMlean.Optimize.Project

public section

open Lean System

namespace LLMlean.Optimize

def settings : IO Config.Settings := do
  let file : FilePath := "llmlean-optimize.toml"
  let cfg ← if ← file.pathExists then
      IO.ofExcept <| Config.resolve (← Config.parse (← IO.FS.readFile file) file.toString) (← Config.loadEnv)
    else Config.load
  return { cfg with
    maxOutputTokens := min cfg.maxOutputTokens 2048
    reasoningEffort := if cfg.provider == "local" && cfg.reasoningEffort == "default" then "none"
                       else cfg.reasoningEffort }

/-- Send the optimizer messages in Responses' typed input array. -/
def request (cfg : Config.Settings) (messages : Json) : Json :=
  Json.mkObj <| [("model", toJson cfg.model), ("input", messages), ("store", toJson false),
    ("max_output_tokens", toJson cfg.maxOutputTokens), ("stream", toJson false)] ++
    if cfg.reasoningEffort == "default" then [] else
      [("reasoning", Json.mkObj [("effort", toJson cfg.reasoningEffort)])]

inductive Phase where
  | collecting
  | waiting (localModel : Bool) (samples : Nat)
  | checking (index total : Nat)

def Phase.message : Phase → String
  | .collecting => "Collecting goals and referenced lemmas…"
  | .waiting true 1 => "Waiting for local LLM…"
  | .waiting true n => s!"Sampling {n} candidates from the local LLM…"
  | .waiting false _ => "Waiting for cloud LLM…"
  | .checking _ 1 => "Checking proof in Lean…"
  | .checking i n => s!"Checking candidate {i} of {n} in Lean…"

structure Candidates where
  requested : Nat
  received : Nat := 0
  proofs : Array String := #[]
  retrieval : String := ""

private def ensureActive (cancelled? : Option (BaseIO Bool)) : IO Unit := do
  if let some cancelled := cancelled? then
    if ← cancelled then throw <| IO.userError "Optimization cancelled."

private def tokenCount (cfg : Config.Settings) (key : String) (messages : Json)
    (timeout : Nat) (cancelled? : Option (BaseIO Bool)) : IO (Nat × Nat) := do
  let url := (cfg.baseUrl.dropSuffix "/v1").toString ++ "/tokenize"
  let body := Json.mkObj [("model", toJson cfg.model), ("messages", messages),
    ("add_generation_prompt", toJson true), ("chat_template_kwargs",
      Json.mkObj [("enable_thinking", toJson (cfg.reasoningEffort != "none"))])]
  let result ← Responses.send url key (some body) timeout cancelled?
  IO.ofExcept do return (← result.getObjValAs? Nat "count", ← result.getObjValAs? Nat "max_model_len")

private def retrievedPrompt (cfg : Config.Settings) (key : String) (messages : Json)
    (signatures : Array String) (cancelled? : Option (BaseIO Bool)) : IO (Json × String) := do
  if !cfg.retrieveForOptimize then return (messages, "")
  if signatures.isEmpty then return (messages, "no additional project signatures")
  let deadline := (← IO.monoMsNow) + min 15000 (cfg.timeoutSeconds * 250)
  let measure := fun prompt => do
    ensureActive cancelled?
    tokenCount cfg key prompt (deadline - (← IO.monoMsNow)) cancelled?
  let mut selected := #[]
  let mut best := messages
  let mut added := 0
  try
    let (base, window) ← measure messages
    let limit := min (base + cfg.optimizeRetrievalTokens) (min 14336 (window - cfg.maxOutputTokens))
    if limit ≤ base then return (messages, "no retrieval headroom")
    let fits := fun signatures => do
      let some prompt := Prompt.withLemmas messages signatures | return none
      let (size, _) ← measure prompt
      return if size ≤ limit then some (prompt, size - base) else none
    if let some (prompt, extra) ← fits signatures then
      return (prompt, s!"{signatures.size} retrieved signatures (+{extra} prompt tokens)")
    for signature in signatures do
      if (← IO.monoMsNow) ≥ deadline || base + added ≥ limit then break
      let trial := selected.push signature
      if let some (prompt, extra) ← fits trial then
        selected := trial
        best := prompt
        added := extra
  catch _ =>
    ensureActive cancelled?
    if selected.isEmpty then return (messages, "retrieval tokenizer unavailable")
  return (best, s!"{selected.size} retrieved signatures (+{added} prompt tokens)")

def generate (messages : Json) (onPhase : Phase → IO Unit) (cancelled? : Option (BaseIO Bool))
    (signatures : Array String := #[]) (cfg? : Option Config.Settings := none) : IO Candidates := do
  let cfg ← cfg?.elim settings pure
  let key ← cfg.apiKey
  let count := if cfg.provider == "local" then cfg.optimizeCandidates else 1
  onPhase (.waiting (cfg.provider == "local") count)
  let deadline := (← IO.monoMsNow) + cfg.timeoutSeconds * 1000
  let (prompt, retrieval) ← retrievedPrompt cfg key messages signatures cancelled?
  let mut body := request cfg prompt
  if count > 1 then
    body := body.setObjVal! "temperature" (toJson (0.7 : JsonNumber))
              |>.setObjVal! "top_p" (toJson (0.9 : JsonNumber))
  let draw := do
    let remaining := deadline - (← IO.monoMsNow)
    let response ← Responses.send cfg.responsesUrl key (some body) remaining cancelled?
    IO.ofExcept (Responses.parseResponse response)
  let mut batch : Candidates := { requested := count, retrieval }
  let mut failure := IO.userError "Model request timed out."
  for start in [0:count:8] do
    ensureActive cancelled?
    if (← IO.monoMsNow) ≥ deadline then break
    let tasks ← (Array.range (min 8 (count - start))).mapM fun _ => IO.asTask draw .dedicated
    for task in tasks do
      match ← IO.wait task with
      | .ok proof =>
        batch := { batch with received := batch.received + 1 }
        unless batch.proofs.contains proof do
          batch := { batch with proofs := batch.proofs.push proof }
      | .error error => failure := error
  ensureActive cancelled?
  if batch.received == 0 then throw failure
  return batch

private def candidateScore (verdict : Json) : Except String (Nat × Nat) := do
  let metrics ← verdict.getObjVal? "metrics"
  let afterCount := fun field => do
    let counts ← metrics.getObjValAs? (Array Nat) field
    counts[1]?.elim (throw s!"Missing {field} count for the verified candidate.") pure
  return (← afterCount "tokens", ← afterCount "lemmas")

/-- Check every distinct draw against the same original and keep the best verified improvement. -/
def Candidates.select (batch : Candidates) (check : Nat → String → IO Json)
    (onPhase : Phase → IO Unit) (cancelled? : Option (BaseIO Bool)) (showRetrieval := true) : IO Json := do
  let mut bestScore : Option (Nat × Nat) := none
  let mut chosen := Verdict.rejected "No candidate improved the proof."
  let mut improvements := 0
  for i in [:batch.proofs.size] do
    ensureActive cancelled?
    onPhase (.checking (i + 1) batch.proofs.size)
    let result ← try check i batch.proofs[i]! catch e =>
      ensureActive cancelled?
      if batch.requested == 1 then throw e
      pure (Verdict.rejected e.toString)
    if ← IO.ofExcept (result.getObjValAs? Bool "improved") then
      improvements := improvements + 1
      let score ← IO.ofExcept (candidateScore result)
      if bestScore.all (Verdict.betterScore score) then
        bestScore := some score
        chosen := result
    else if i == 0 then
      chosen := result
  ensureActive cancelled?
  let retrieval := if showRetrieval then batch.retrieval else ""
  if batch.requested == 1 then
    if retrieval.isEmpty then return chosen
    let field := if bestScore.isSome then "summary" else "detail"
    let text ← IO.ofExcept (chosen.getObjValAs? String field)
    return chosen.setObjVal! field (toJson s!"{text} · {retrieval}")
  let plural := fun (n : Nat) => if n == 1 then "" else "s"
  let stats := s!"{batch.received}/{batch.requested} responses, " ++
    s!"{batch.proofs.size} distinct candidate{plural batch.proofs.size}, " ++
    s!"{improvements} verified improvement{plural improvements}" ++
    (if retrieval.isEmpty then "" else s!", {retrieval}")
  if bestScore.isNone then
    let detail ← IO.ofExcept (chosen.getObjValAs? String "detail")
    return chosen.setObjVal! "detail" (toJson s!"{stats}. {detail}")
  let summary ← IO.ofExcept (chosen.getObjValAs? String "summary")
  let metrics ← IO.ofExcept (chosen.getObjVal? "metrics")
  return chosen.setObjVal! "summary" (toJson s!"{summary} · {stats}")
    |>.setObjVal! "metrics" (metrics.setObjVal! "samples" (toJson stats))

def editorMessages (record : Json) (file : FilePath) (header : Json) : IO Json := do
  let file ← IO.FS.realPath file
  let setup ← Project.setup (← Project.root file) file (some header)
  let name ← IO.ofExcept (setup.getObjValAs? String "name")
  let imports ← IO.ofExcept (record.getObjVal? "context" >>= (·.getObjVal? "imports"))
  IO.ofExcept <| Prompt.messages record name Lean.versionString imports

def validReplacement (proof : String) : Bool :=
  (proof == "by" || ["by ", "by\n", "by\t"].any (fun s : String => proof.startsWith s)) &&
    !(["<think>", "</think>", "```", "<|im_"].any (fun s : String => proof.contains s))

def editorVerdict (original candidate : Json) (proof : String) (elapsed : Nat) : IO Json := do
  let before ← IO.ofExcept (fromJson? original)
  let after ← IO.ofExcept (fromJson? candidate)
  return Verdict.compare before after proof elapsed

end LLMlean.Optimize
