module
public import LLMlean
public meta import LLMlean

open Lean Elab Tactic LLMlean

/-- Benchmark all policies at exactly the same source position and proof state.
The final flag opts into actual model calls; otherwise only context extraction runs. -/
syntax "context_benchmark " str ppSpace num ppSpace ident : tactic

elab_rules : tactic
  | `(tactic| context_benchmark $caseId:str $repeatIndex:num $prove:ident) => do
    let runModel := prove.getId == `true
    let settings ← if runModel then Config.load (← getOptions) else
      IO.ofExcept (Config.resolve {} {} (← getOptions))
    let modes := #["full", "window", "all_files", "structured"]
    -- Rotate order across repetitions to reduce systematic warm-cache/order effects.
    for j in [:modes.size] do
      let mode := modes[(j + repeatIndex.getNat) % modes.size]!
      let settings := { settings with contextMode := mode }
      let start ← IO.monoMsNow
      let b ← Context.build settings (← getRef)
      let contextMs := (← IO.monoMsNow) - start
      let input := prompt b.render b.goals ""
      let requests ← IO.mkRef (0 : Nat)
      let requestMs ← IO.mkRef (0 : Nat)
      let generator : Generator := fun cfg instructions input remaining => do
        requests.modify (· + 1)
        let t ← IO.monoMsNow
        try Responses.generate cfg instructions input remaining
        finally requestMs.modify (· + ((← IO.monoMsNow) - t))
      let mut solved : Option Bool := none
      let mut diagnostic := ""
      if runModel then
        try
          let result ← generateChecked settings .proof b.render "" generator
            (goals? := some b.goals) (startedMs? := some start)
          solved := some (result.result == .complete)
        catch ex =>
          Core.checkInterrupted
          solved := some false
          diagnostic := ← ex.toMessageData.toString
      let row := Json.mkObj [
        ("case", toJson caseId.getString), ("repeat", toJson repeatIndex.getNat),
        ("mode", toJson mode), ("context_ms", toJson contextMs),
        ("total_ms", toJson ((← IO.monoMsNow) - start)),
        ("request_ms", toJson (← requestMs.get)), ("requests", toJson (← requests.get)),
        ("input_chars", toJson input.length),
        ("instruction_chars", toJson (instructions .proof).length),
        ("total_input_chars", toJson (input.length + (instructions .proof).length)),
        ("history_chars", toJson b.history.length),
        ("imported_files", toJson (b.importedFiles.map (fun (name, _) => name.toString))),
        ("imported_source_chars", toJson (b.importedFiles.foldl (fun n (_, source) => n + source.length) 0)),
        ("declarations", toJson b.declarations.size), ("candidates", toJson b.candidateCount),
        ("helper_visible", toJson (decide ((input.splitOn "length_append_one").length > 1))),
        ("solved", toJson solved), ("error", toJson diagnostic),
        ("model", toJson (if runModel then settings.model else "offline")),
        ("attempt_limit", toJson settings.attempts)]
      IO.println s!"LLMLEAN_CONTEXT_BENCH {row.compress}"
