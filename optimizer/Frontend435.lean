import LLMlean.Optimize.Extraction

open Lean Elab LLMlean.Optimize.Extraction

namespace ProofRewrite

def emit (out : IO.FS.Handle) (j : Json) : IO Unit := out.putStrLn j.compress

partial def loop (source : String) (out : IO.FS.Handle)
    (request? : Option VerifyRequest := none) (withStates := false)
    (hadErrors := false) : Frontend.FrontendM (Bool × Bool) := do
  let before ← Frontend.getCommandState
  -- Avoid retaining whole-module info trees, and force synchronous elaboration.
  Frontend.setCommandState { before with
    infoState := { before.infoState with trees := {} }
    scopes := before.scopes.map (fun s => { s with opts := s.opts.setBool `Elab.async false }) }
  -- Same parser/frontend path as Lean, with a pre-elaboration boundary guard.
  Frontend.updateCmdPos
  let cmdState ← Frontend.getCommandState
  let ictx ← Frontend.getInputContext
  let pstate ← Frontend.getParserState
  let scope := cmdState.scopes.head!
  let pmctx := {
    env := cmdState.env, options := scope.opts,
    currNamespace := scope.currNamespace, openDecls := scope.openDecls }
  let (cmd, ps, messages) := Parser.parseCommand ictx pmctx pstate cmdState.messages
  Frontend.setParserState ps
  Frontend.setMessages messages
  let isTarget := request?.any fun r => (span? cmd).any (·.start == r.command_start)
  if isTarget then
    if let some request := request? then
      if (theoremBody? cmd).isNone then
        emit out (obj [("event", str "rejected"), ("reason", str "declaration_shape_changed")])
        return (false, hadErrors)
      if let some reason := guardCandidate cmd request then
        emit out (obj [("event", str "rejected"), ("reason", str reason)])
        return (false, hadErrors)
  let started ← IO.monoMsNow
  Frontend.elabCommandAtFrontend cmd
  if isTarget then
    emit out (obj [("event", str "target_timing"), ("elapsed_ms", num ((← IO.monoMsNow) - started))])
  let st ← get
  let after := st.commandState
  -- Modern Lean keeps diagnostics per command and in snapshot tasks. Accumulate
  -- errors across the entire file, including a failing command followed by EOF.
  let snapshots := Language.SnapshotTree.mk { diagnostics := .empty } after.snapshotTasks
  let commandMessages := snapshots.getAll.map (·.diagnostics.msgLog)
    |>.foldl (· ++ ·) after.messages
  let hadErrors := hadErrors || commandMessages.hasErrors
  for msg in commandMessages.reportedPlusUnreported.toList do
    emit out <| obj [("event", str "diagnostic"),
      ("severity", str (match msg.severity with | .error => "error" | .warning => "warning" | .information => "information")),
      ("message", str (← msg.toString))]
  if isTarget && request?.any (·.enforce_policy) then
    let newAxioms := addedAxioms before.env after.env
    unless newAxioms.isEmpty do
      emit out (obj [("event", str "rejected"), ("reason", str "new_axiom_declarations"),
        ("names", toJson newAxioms)])
      return (false, hadErrors)
  let obs := after.infoState.trees.foldl (fun acc t => observe t none acc withStates) {}
  let found := if request?.isSome && !isTarget then #[] else theoremCommands cmd
  for candidate in found do
    if candidate != cmd then
      emit out (failure candidate "unsupported_command_wrapper" cmd.getKind.toString)
    else if commandMessages.hasErrors then
      emit out (failure candidate "elaboration_error")
    else if let some body := theoremBody? cmd then
      try
        let record ← extract source cmd body obs after.env request?.isSome withStates
        let lexical := lexicalContext source scope
        emit out (record.setObjVal! "lexical_context" lexical)
      catch e => emit out (failure cmd "metadata_error" e.toString)
  -- The driver only needs the latest command.
  modify fun s => { s with commands := #[], commandState.snapshotTasks := #[] }
  if Parser.isTerminalCommand cmd then return (true, hadErrors)
  loop source out request? withStates hadErrors

unsafe def run (path setupPath output : String) (requestPath? : Option String := none) (withStates := false) : IO UInt32 := do
  initSearchPath (← findSysroot)
  enableInitializersExecution
  let source ← IO.FS.readFile path
  let request? ← requestPath?.mapM fun p => do
    let text ← IO.FS.readFile p
    IO.ofExcept (Json.parse text >>= fromJson? (α := VerifyRequest))
  let setupJson ← IO.FS.readFile setupPath
  let setup : ModuleSetup ← IO.ofExcept <| Json.parse setupJson >>= fromJson?
  setup.dynlibs.forM Lean.loadDynlib
  let ictx := Parser.mkInputContext source path
  let (header, ps, msgs) ← Parser.parseHeader ictx
  let opts := setup.options.toOptions.setBool `Elab.async false
  let imports := setup.imports?.getD (headerToImports header)
  let (env, msgs) ← processHeaderCore (HeaderSyntax.startPos header) imports
    (strictOr setup.isModule (HeaderSyntax.isModule header))
    opts msgs ictx (plugins := setup.plugins) (mainModule := setup.name) (arts := setup.importArts)
  let out ← IO.FS.Handle.mk output .write
  emit out <| obj [("event", str "header"), ("schema_version", str "0.1"),
    ("lean_version", str Lean.versionString),
    ("imports", strings (imports.map fun i => i.module.toString))]
  let ((completed, hasErrors), _) ← StateRefT'.run
    ((loop source out request? withStates msgs.hasErrors) { inputCtx := ictx })
    { commandState := Command.mkState env msgs opts, parserState := ps, cmdPos := ps.pos }
  emit out <| obj [("event", str "complete"), ("has_errors", toJson hasErrors),
    ("candidate_rejected", toJson (!completed))]
  return if hasErrors || !completed then 1 else 0

end ProofRewrite

unsafe def main (args : List String) : IO UInt32 := do
  match args with
  | [path, setupPath, output] => ProofRewrite.run path setupPath output
  | ["--with-states", path, setupPath, output] => ProofRewrite.run path setupPath output none true
  | ["--verify", path, setupPath, output, request] => ProofRewrite.run path setupPath output (some request)
  | _ =>
    IO.eprintln "Usage: lean --run lean/Extract.lean SOURCE SETUP.json OUTPUT.jsonl"
    return 2
