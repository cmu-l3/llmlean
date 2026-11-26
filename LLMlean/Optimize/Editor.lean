module
public meta import Lean.Server.FileWorker.Utils
public meta import LLMlean.Optimize
public meta import LLMlean.Optimize.Retrieval
public meta import LLMlean.Optimize.Extraction

public meta section

open Lean Elab Server Snapshots
open LLMlean.Optimize.Extraction

namespace LLMlean.Optimize.Editor

private structure TheoremData where
  declaration : ConstantVal
  record : Json
  context? : Option ContextInfo

private def theoremData (source : String) (cmd : Syntax) (tree : InfoTree) (env : Environment)
    (withStates : Bool) : IO TheoremData := do
  let some body := theoremBody? cmd | throw <| IO.userError "Expected a named theorem or lemma."
  let observations := observe tree none {} withStates
  let result ← extract source cmd body observations env true withStates
  unless (result.getObjValAs? String "event").toOption == some "record" do
    let why := (result.getObjValAs? String "category").toOption.getD "Missing proof information"
    throw <| IO.userError s!"Could not extract the proof: {why}"
  let some decl := (declaredName? body observations).bind env.find? |
    throw <| IO.userError "Missing elaborated declaration."
  return ⟨decl.toConstantVal, result, observations.contexts[0]?⟩

/-- Stop at the selected command, even when the rest of the buffer is still elaborating. -/
private def previous (doc : FileWorker.EditableDocument) (snap : Snapshot) : IO Snapshot := do
  let (snaps, err?) ← (doc.cmdSnaps.waitUntil (·.endPos >= snap.endPos)).wait
  if let some err := err? then throw err
  let current :: before :: _ := snaps.reverse | throw <| IO.userError "Missing theorem snapshot."
  unless current.endPos == snap.endPos && current.stx.getRange? == snap.stx.getRange? do
    throw <| IO.userError "The theorem snapshot changed. Run Optimize proof again."
  return before

private def diagnostics (state : Command.State) : MessageLog :=
  let tasks := Language.SnapshotTree.mk { diagnostics := .empty } state.snapshotTasks
  tasks.getAll.foldl (fun log snap => log ++ snap.diagnostics.msgLog) state.messages

private def check (doc : FileWorker.EditableDocument) (before : Snapshot) (cmdRange proofRange : Syntax.Range)
    (original : TheoremData) (proof : String) (tk : IO.CancelToken) : IO Json := do
  let proof := proof.trimAscii.toString
  unless validReplacement proof do
    return Verdict.rejected "Expected a complete non-thinking Lean by-proof."
  let text := doc.meta.text.source
  let source := (String.Pos.Raw.extract text 0 proofRange.start) ++ proof ++
    proofRange.stop.extract text text.rawEndPos
  let input := Parser.mkInputContext source doc.meta.mkInputContext.fileName
  let scope := before.cmdState.scopes.head!
  let (cmd, _, errors) := Parser.parseCommand input {
    env := before.env, options := scope.opts, currNamespace := scope.currNamespace,
    openDecls := scope.openDecls } before.mpState {}
  if errors.hasErrors || (theoremBody? cmd).isNone || cmd.getPos? != some cmdRange.start then
    return Verdict.rejected "The replacement does not parse as the selected theorem."
  let request : VerifyRequest := {
    command_start := cmdRange.start.byteIdx, proof_start := proofRange.start.byteIdx,
    proof_end := proofRange.start.byteIdx + proof.utf8ByteSize }
  if let some reason := guardCandidate cmd request then return Verdict.rejected reason
  let state := { before.cmdState with
    messages := {}, snapshotTasks := #[],
    scopes := before.cmdState.scopes.map fun s =>
      { s with opts := s.opts.setBool `Elab.async false
          |>.setBool `debug.skipKernelTC false |>.setBool `llmlean.checking true } }
  let ctx : Command.Context := {
    cmdPos := before.endPos, fileName := input.fileName,
    fileMap := input.fileMap, snap? := none, cancelTk? := some tk }
  let started ← IO.monoMsNow
  let elaborated ← EIO.toIO' <| ((Command.elabCommandTopLevel cmd #[]) ctx).run state
  let .ok (_, after) := elaborated | return Verdict.rejected "The replacement did not elaborate."
  let messages := diagnostics after
  if messages.hasErrors then
    let some err := messages.toList.find? (·.severity == .error) | return Verdict.rejected "Lean rejected the proof."
    return Verdict.rejected (← err.data.toString)
  let elapsed := (← IO.monoMsNow) - started
  unless (addedAxioms before.env after.env).isEmpty do return Verdict.rejected "New axiom declarations."
  let trees := after.infoState.substituteLazy.get.trees
  let some tree := trees.toArray[0]? | return Verdict.rejected "Missing replacement proof information."
  let target ← theoremData source cmd tree after.env false
  let old := original.declaration
  let new := target.declaration
  if old.name != new.name || old.levelParams.length != new.levelParams.length then
    return Verdict.rejected "The declaration changed."
  let type := new.type.instantiateLevelParams new.levelParams (old.levelParams.map mkLevelParam)
  unless (Kernel.isDefEq after.env {} old.type type).toOption == some true do
    return Verdict.rejected "The elaborated theorem type changed."
  editorVerdict original.record target.record proof elapsed

def run (doc : FileWorker.EditableDocument) (file : System.FilePath) (snap : Snapshot) (cmdRange proofRange : Syntax.Range)
    (onPhase : Phase → IO Unit) (cancelled : BaseIO Bool) : IO Json := do
  onPhase .collecting
  let before ← previous doc snap
  let source := doc.meta.text.source
  if (diagnostics snap.cmdState).hasErrors then throw <| IO.userError "The original theorem has errors."
  let original ← theoremData source snap.stx snap.infoTree snap.env true
  let record := original.record.setObjVal! "lexical_context" (lexicalContext source before.cmdState.scopes.head!)
    |>.setObjVal! "context" ((← IO.ofExcept (original.record.getObjVal? "context")).setObjVal!
      "imports" (toJson (snap.env.imports.map fun i => i.module.toString)))
  let messages ← editorMessages record file (toJson (Elab.HeaderSyntax.toModuleHeader ⟨doc.initSnap.stx⟩))
  let cfg ← settings
  let signatures ← if cfg.retrieveForOptimize then
      projectTheorems original.context? before.env original.declaration record (← Project.root (← IO.FS.realPath file))
    else pure #[]
  let candidates ← generate messages onPhase (some cancelled) signatures (some cfg)
  let verify := fun (_ : Nat) (proof : String) => do
    let token ← IO.CancelToken.new
    let task ← IO.asTask (check doc before cmdRange proofRange original proof token) .dedicated
    let start ← IO.monoMsNow
    repeat
      if ← IO.hasFinished task then return ← IO.ofExcept task.get
      if ← cancelled then
        token.set
        throw <| IO.userError "Optimization cancelled."
      if (← IO.monoMsNow) - start >= 25000 then
        token.set
        throw <| IO.userError "Lean verification timed out."
      IO.sleep 10
    throw <| IO.userError "Lean verification interrupted."
  candidates.select verify onPhase (some cancelled) (showRetrieval := false)

end LLMlean.Optimize.Editor
