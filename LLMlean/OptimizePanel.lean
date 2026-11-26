module
public meta import LLMlean.Optimize
public meta import Lean.Widget.Commands
public meta import Lean.Server.Rpc.RequestHandling

public meta section

open Lean Server Lsp

register_option llmlean.optimizeFeedback : Bool := {
  defValue := true, descr := "Show optimizer progress and results in the editor."
}

namespace LLMlean.Optimize.Panel

structure Feedback where
  message : String := ""
  metrics : Json := .null
  finished : Bool := false
  waitingSince? : Option Nat := none
  edit? : Option WorkspaceEdit := none
  previewOpen : Bool := false

structure Run where
  id : Nat
  name : String
  doc : VersionedTextDocumentIdentifier
  range : Lsp.Range
  cancel : IO.CancelToken
  feedback : Std.Mutex Feedback

-- Each Lean file worker has its own registry. Retain suggestions only for the current buffer version.
private initialize runs : Std.Mutex (Nat × Array Run) ← Std.Mutex.new (0, #[])

private def notify [ToJson α] (method : String) (params : α) : IO Unit := do
  -- Code-action and RPC handlers run on the file worker's LSP stream.
  (← IO.getStdout).writeLspNotification ⟨method, params⟩

private def changed (run : Run) : IO Unit :=
  notify "$/llmlean/optimizeChanged" <| Json.mkObj [("uri", toJson run.doc.uri)]

def start (name : String) (doc : VersionedTextDocumentIdentifier) (range : Lsp.Range) : IO Run := do
  let cancel ← IO.CancelToken.new
  let feedback ← Std.Mutex.new {}
  let run ← runs.atomically do
    let (n, entries) ← get
    let run := { id := n + 1, name, doc, range, cancel, feedback : Run }
    let mut keep := #[]
    for old in entries do
      if old.doc.version? == doc.version? && old.range != range then
        keep := keep.push old
      else
        old.cancel.set
    set (n + 1, keep.push run)
    return run
  changed run
  return run

def update (run : Run) (f : Feedback → Feedback) : IO Unit := do
  run.feedback.atomically <| modify f
  changed run

private def findRun (doc : FileWorker.EditableDocument) (pos : Lsp.Position) : BaseIO (Option Run) :=
  runs.atomically do
    return (← get).2.find? fun r =>
      r.doc.version? == some doc.meta.version && r.range.start ≤ pos && pos < r.range.end

@[server_rpc_method]
def status (pos : Lsp.Position) : RequestM (RequestTask Json) := RequestM.pureTask do
  let some run ← findRun (← RequestM.readDoc) pos | return .null
  let s ← run.feedback.atomically get
  let now ← IO.monoMsNow
  return Json.mkObj [("id", toJson run.id), ("name", toJson run.name), ("version", toJson run.doc.version?),
    ("message", toJson s.message), ("metrics", s.metrics), ("finished", toJson s.finished),
    ("waitMs", toJson (s.waitingSince?.map (now - ·))),
    ("canReview", toJson (s.edit?.isSome && !s.previewOpen))]

structure RunAt where
  pos : Lsp.Position
  id : Nat
  deriving FromJson, ToJson

@[server_rpc_method]
def cancelWait (p : RunAt) : RequestM (RequestTask Unit) := RequestM.pureTask do
  if let some run ← findRun (← RequestM.readDoc) p.pos then
    if run.id == p.id && !(← run.feedback.atomically get).finished then
      run.cancel.set

def supportsReview (caps : ClientCapabilities) : Bool := Id.run do
  let some ws := caps.workspace? | return false
  return ws.applyEdit? == some true && (ws.workspaceEdit?.bind (·.changeAnnotationSupport?)).isSome &&
    (caps.textDocument?.bind (·.codeAction?) |>.bind (·.honorsChangeAnnotations?)) == some true

/-- Keep ownership of the annotated edit until the native preview closes. A later review reuses it. -/
def openPreview (run : Run) (ctx : RequestContext) : IO Unit := do
  let edit? ← run.feedback.atomically do
    let s ← get
    if s.previewOpen || s.edit?.isNone then return none
    set { s with previewOpen := true }
    return s.edit?
  let some edit := edit? | return
  changed run
  let params : ApplyWorkspaceEditParams := { label? := some s!"Optimize {run.name}", edit }
  let reply ← ctx.serverRequestEmitter "workspace/applyEdit" (toJson params)
  discard <| ServerTask.IO.mapTaskCheap (t := reply) fun result => do
    let message := match result with
      | .failure _ _ => "Could not open the proof preview."
      | .success _ => "Verified by Lean"
    update run fun s => { s with previewOpen := false, message }

@[server_rpc_method]
def review (p : RunAt) : RequestM (RequestTask Unit) := RequestM.pureTask do
  let some run ← findRun (← RequestM.readDoc) p.pos | return
  if run.id == p.id then openPreview run (← read)

def beginProgress (run : Run) (ctx : RequestContext) : IO (Option String) := do
  unless ctx.initParams.capabilities.window?.isSome do return none
  let token := s!"llmlean/{run.doc.uri}/{run.id}/{← IO.monoMsNow}"
  let reply ← ctx.serverRequestEmitter "window/workDoneProgress/create" (Json.mkObj [("token", toJson token)])
  let .success _ ← reply.wait | return none
  let value : WorkDoneProgressBegin := { title := s!"Optimizing {run.name}" }
  notify "$/progress" ({ token, value } : ProgressParams _)
  return some token

def phase (run : Run) (token : Option String) (stage : Phase) : IO Unit := do
  let message := stage.message
  let since ← match stage with
    | .waiting _ _ => some <$> IO.monoMsNow
    | _ => pure none
  update run fun s => { s with message, waitingSince? := since }
  if let some token := token then
    let value : WorkDoneProgressReport := { message? := some message }
    notify "$/progress" ({ token, value } : ProgressParams _)

def endProgress (token : Option String) (message : String) : IO Unit := do
  if let some token := token then
    notify "$/progress" ({ token, value := ({ message? := some message } : WorkDoneProgressEnd) } : ProgressParams _)

@[widget_module]
def optimizerPanel : Widget.Module where
  javascript := include_str "optimizePanel.js"

def panelInstance : Widget.WidgetInstance where
  id := ``optimizerPanel
  javascriptHash := optimizerPanel.javascriptHash
  props := pure <| Json.mkObj []

run_cmd Widget.addPanelWidgetGlobal optimizerPanel.javascriptHash ``panelInstance

end LLMlean.Optimize.Panel
