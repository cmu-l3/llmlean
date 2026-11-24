module
public meta import LLMlean.Optimize.Editor
public meta import LLMlean.OptimizePanel
public meta import Lean.Server.CodeActions.Basic

public meta section

open Lean Elab Server Lsp

namespace LLMlean.Optimize

/-- A lazy, versioned edit on the original proof; listing actions does no inference. -/
@[code_action_provider] def optimizeProof : CodeActionProvider := fun params snap => do
  let cmd := snap.stx
  let some body := Extraction.theoremBody? cmd | return #[]
  let proof := body[3][1]
  unless body[3].getKind == ``Parser.Command.declValSimple && proof.getKind == ``Parser.Term.byTactic do return #[]
  let some cmdRange := cmd.getRange? | return #[]
  let some proofRange := proof.getRange? | return #[]
  let doc ← RequestM.readDoc
  let text := doc.meta.text
  let pos := text.lspPosToUtf8Pos params.range.start
  unless cmdRange.start ≤ pos && pos < cmdRange.stop do return #[]
  let some file := System.Uri.fileUriToPath? params.textDocument.uri | return #[]
  let action : CodeAction := { title := "LLMLean: Optimize proof", kind? := "refactor.rewrite" }
  let ctx ← read
  let lazyAction := do
    let scope := snap.cmdState.scopes.head!
    let shortName := (Elab.expandDeclIdCore body[1]).1.eraseMacroScopes
    let name := if (`_root_).isPrefixOf shortName then shortName.replacePrefix `_root_ .anonymous
                else scope.currNamespace ++ shortName
    let panel? ← if llmlean.optimizeFeedback.get scope.opts then
        some <$> Panel.start name.toString doc.versionedIdentifier (text.utf8RangeToLspRange cmdRange)
      else pure none
    let token ← panel?.bindM (Panel.beginProgress · ctx)
    let cancelled : BaseIO Bool := do
      if ← ctx.cancelTk.wasCancelled then return true
      if let some panel := panel? then return ← panel.cancel.isSet
      return false
    let ensureCurrent := do
      if ← cancelled then throw <| IO.userError "Optimization cancelled."
    try
      let onPhase := fun message => do
        ensureCurrent
        if let some panel := panel? then Panel.phase panel token message
      let result ← Editor.run doc file snap cmdRange proofRange onPhase cancelled
      ensureCurrent
      let metrics := (result.getObjVal? "metrics").toOption.getD .null
      unless ← IO.ofExcept (result.getObjValAs? Bool "improved") do
        let why ← IO.ofExcept (result.getObjValAs? String "detail")
        if let some panel := panel? then
          Panel.update panel fun _ => { message := why, metrics, finished := true }
          if ctx.initParams.capabilities.lean?.isSome || token.isSome then return action
        throw <| IO.userError s!"No verified improvement found. {why}"
      let original ← IO.ofExcept (result.getObjValAs? String "original")
      unless original.crlfToLf == (proofRange.start.extract text.source proofRange.stop) do
        throw <| IO.userError "The checked proof differs from the editor selection. Run Optimize proof again."
      let replacement ← IO.ofExcept (result.getObjValAs? String "proof")
      let edit := WorkspaceEdit.ofTextEdit doc.versionedIdentifier {
        range := text.utf8RangeToLspRange proofRange, newText := replacement, annotationId? := "optimize" }
      let summary ← IO.ofExcept (result.getObjValAs? String "summary")
      let annotation : ChangeAnnotation := { label := summary, needsConfirmation := true }
      let edit := { edit with changeAnnotations? := some (.ofList [("optimize", annotation)]) }
      if let some panel := panel? then
        let verified : Panel.Feedback := { message := "Verified by Lean", metrics, finished := true }
        if Panel.supportsReview ctx.initParams.capabilities then
          panel.feedback.atomically <| set { verified with edit? := some edit }
          Panel.openPreview panel ctx
          return action
        Panel.update panel fun _ => verified
      return { action with edit? := some edit }
    catch e =>
      if let some panel := panel? then
        Panel.update panel fun s => { s with message := e.toString, waitingSince? := none, finished := true }
        if ← cancelled then return action
      throw e
    finally
      if let some panel := panel? then
        Panel.endProgress token (← panel.feedback.atomically get).message
  return #[{ eager := action, lazy? := some lazyAction }]

end LLMlean.Optimize
