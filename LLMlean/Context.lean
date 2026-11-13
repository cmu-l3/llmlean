module
public import LLMlean.Config
public import LLMlean.Check
public import Lean.Parser.Module
public import Lean.PrettyPrinter
public import Lean.OriginalConstKind

public section

open Lean Elab Tactic Meta

namespace LLMlean.Context

/-- Budgets count Unicode characters, not model tokens. -/
def takeChars (s : String) (limit : Nat) : String := (s.take limit).toString

def tailChars (s : String) (limit : Nat) : String :=
  (s.drop (s.length - limit)).toString

/-- Prefer whole trailing lines; a single oversized line still obeys the hard limit. -/
def historyWindow (s : String) (limit : Nat) : String := Id.run do
  if s.length ≤ limit then return s
  let tail := tailChars s limit
  let lines := tail.splitOn "\n"
  if lines.length > 1 then return String.intercalate "\n" lines.tail
  return tail

/-- Keep only the latest failed attempt, reserving half of the budget for feedback. -/
def repairHistory (text diagnostic : String) (limit : Nat) : String := Id.run do
  let before := "\n\nPrevious attempt (possibly truncated):\n"
  let between := "\n\nLean feedback:\n"
  let after := "\nCorrect the tactic sequence for the original goals. Replace only the tactic hole."
  let overhead := before.length + between.length + after.length
  if limit ≤ overhead then return takeChars (between ++ diagnostic) limit
  let budget := limit - overhead
  let attempt := takeChars text (budget / 2)
  return before ++ attempt ++ between ++ takeChars diagnostic (budget - attempt.length) ++ after

structure Candidate where
  name : Name
  type : Expr
  kind : ConstantKind
  moduleName : Name
  localDecl : Bool
  order : Nat

structure Bundle where
  currentDeclaration : String := ""
  history : String := ""
  goals : String := ""
  glossary : Array String := #[]
  declarations : Array String := #[]
  importedFiles : Array (Name × String) := #[]
  candidateCount : Nat := 0
  omittedCount : Nat := 0
  historyTruncated : Bool := false
  glossaryOmitted : Bool := false
  deriving Inhabited

private def block (title text : String) : String :=
  s!"{title}:\n```lean\n{text}\n```"

def Bundle.render (b : Bundle) : String :=
  String.intercalate "\n\n" <| [
    "Reference context only. Declaration summaries omit theorem proofs. Use the qualified names.",
    block ("Active custom notation (examples of equivalent expressions)" ++
      if b.glossaryOmitted then " (some source explanations omitted by budget)" else "")
      (if b.glossary.isEmpty then "-- None needed for the rendered expressions."
       else String.intercalate "\n" b.glossary.toList),
    block s!"Available declarations ({b.declarations.size} included; {b.omittedCount} omitted)"
      (String.intercalate "\n\n" b.declarations.toList)] ++
    (b.importedFiles.toList.map fun (name, source) =>
      block s!"Imported project file: {name}" source) ++ [
    block "Current declaration (unfinished target, NOT an available premise)" b.currentDeclaration,
    block ("Recent source/proof history before the hole" ++
      if b.historyTruncated then " (earlier text omitted)" else "") b.history]

/-- Qualified names with familiar notation; no user `pp.all` setting can explode a prompt. -/
def printOptions (o : Options) : Options :=
  o.setBool `pp.all false |>.setBool `pp.fullNames true |>.setBool `pp.privateNames false
    |>.setBool `pp.notation true |>.setBool `pp.explicit false |>.setBool `pp.universes false
    |>.setBool `pp.proofs false |>.setBool `pp.raw false

private def customSyntax (env : Environment) (stx : Syntax) : Bool :=
  let kind := stx.getKind
  if !env.containsOnBranch kind then false else
  match env.getModuleIdxFor? kind with
  | none => true
  | some idx =>
    let root := env.header.modules[idx.toNat]!.module.getRoot
    root != `Init && root != `Lean && root != `Std

/-- Explain actual active notation using Lean's expression annotations, not a scan of old commands.
This also works for imported/scoped notation and avoids retaining expired notation. -/
private def notationFor (e : Expr) : MetaM (Array String) := do
  let rendered ← PrettyPrinter.ppExprWithInfos e
  let mut entries := #[]
  for (_, info) in rendered.infos do
    let ti ← match info with
      | .ofTermInfo ti => pure ti
      | .ofDelabTermInfo ti => pure ti.toTermInfo
      | _ => continue
    unless customSyntax (← getEnv) ti.stx do continue
    let lhs := toString (← PrettyPrinter.ppTerm ⟨ti.stx⟩)
    let rhs ← withLCtx' ti.lctx <| withOptions (fun o =>
      o.setBool `pp.notation false |>.setBool `pp.fieldNotation false) do
        return toString (← ppExpr ti.expr)
    let entry := s!"{lhs}  means  {rhs}"
    unless entries.contains entry do entries := entries.push entry
  return entries

private def addNotation (entries more : Array String) (limit : Nat) : Array String := Id.run do
  let mut entries := entries
  let mut used := (String.intercalate "\n" entries.toList).length
  for entry in more do
    unless entries.contains entry do
      if used + entry.length + 1 ≤ limit then
        entries := entries.push entry
        used := used + entry.length + 1
  return entries

private partial def qualifySyntax : Syntax → Syntax
  | .ident info raw _ [.decl resolved []] =>
    .ident info raw (privateToUserName resolved) []
  | .node info kind args => .node info kind (args.map qualifySyntax)
  | stx => stx

/-- Explain notation used in the retained source even if it disappeared from the current goals. -/
private def sourceNotation (stx : Syntax) (headerEnd historyStart hole : String.Pos.Raw) :
    TacticM (Array String) := do
  let mut entries := #[]
  for node in stx.topDown do
    let some r := node.getRange? | continue
    unless r.stop ≤ hole && (r.stop ≤ headerEnd || historyStart ≤ r.start) do continue
    unless customSyntax (← getEnv) node do continue
    try
      if let some expanded ← liftMacroM (Macro.expandMacro? node) then
        let lhs := toString (← PrettyPrinter.ppTerm ⟨node⟩)
        let rhs := toString (← PrettyPrinter.ppTerm ⟨qualifySyntax expanded⟩)
        let entry := s!"{lhs}  expands to  {rhs}"
        unless entries.contains entry do entries := entries.push entry
    catch _ => Core.checkInterrupted
  return entries

/-- Locate the enclosing declaration using Lean syntax, including nested `by` blocks.
Only source strictly before the invocation is ever returned. Parsing does not elaborate code. -/
private def declarationBody? (stx : Syntax) : Option (Syntax × String.Pos.Raw) := do
  let body ← stx.find? fun n => n.isOfKind ``Parser.Command.declValSimple ||
    n.isOfKind ``Parser.Command.declValEqns || n.isOfKind ``Parser.Command.whereStructInst
  let start ← if body.isOfKind ``Parser.Command.declValSimple then body[1].getPos? else body.getPos?
  return (body, start)

private partial def declarationParts (stx : Syntax) (source : String) (hole : String.Pos.Raw) :
    Option (String × String) := do
  let range ← stx.getRange?
  guard (range.start ≤ hole && hole < range.stop)
  if stx.isOfKind ``Parser.Command.declaration then
    let (_, bodyStart) ← declarationBody? stx
    guard (bodyStart ≤ hole)
    return (String.Pos.Raw.extract source range.start bodyStart,
      String.Pos.Raw.extract source bodyStart hole)
  for child in stx.getArgs do
    if let some parts := declarationParts child source hole then return parts
  none

private def sourceParts (ref : Syntax) (historyChars : Nat) :
    TacticM (String × String × Bool × Syntax) := do
  let fileMap ← getFileMap
  let some hole := ref.getPos? | return ("-- Source position unavailable.", "", false, .missing)
  let input := Parser.mkInputContext fileMap.source (← readThe Core.Context).fileName
  let (_, initial, _) ← Parser.parseHeader input
  let pmctx : Parser.ParserModuleContext := { env := ← getEnv, options := ← getOptions }
  let mut state := initial
  while state.pos ≤ hole do
    Core.checkInterrupted
    let (stx, next, _) := Parser.parseCommand input pmctx state {}
    if let some (header, history) := declarationParts stx fileMap.source hole then
      return (header.trimAscii.toString, historyWindow history historyChars, history.length > historyChars, stx)
    if next.pos ≤ state.pos then break
    state := next
  -- Macro-generated declarations may lack a recoverable source header.
  let sourcePrefix := String.Pos.Raw.extract fileMap.source 0 hole
  return ("-- Source header unavailable; use the current goals.",
    historyWindow sourcePrefix historyChars, sourcePrefix.length > historyChars, .missing)

private partial def findProjectRoot (dir : System.FilePath) : IO (Option System.FilePath) := do
  if (← (dir / "lakefile.lean").pathExists) || (← (dir / "lakefile.toml").pathExists) then
    return some dir
  let some parent := dir.parent | return none
  if parent == dir then return none
  findProjectRoot parent

private def isWithin (root path : System.FilePath) : Bool :=
  root.components.isPrefixOf path.components

private def projectRoot : CoreM System.FilePath := do
  let cwd ← IO.currentDir
  let file := System.FilePath.mk (← read).fileName
  let file := if file.isAbsolute then file else cwd / file
  let root ← findProjectRoot (file.parent.getD cwd)
  let root ← match root with
    | some root => pure root
    | none => pure ((← findProjectRoot cwd).getD cwd)
  IO.FS.realPath root

/-- Membership is determined by the resolved build path, not a declaration's namespace.
The environment's module data is already an imported-module declaration index. -/
private def projectModules : CoreM (Array (Name × ModuleData)) := do
  let root ← projectRoot
  let env ← getEnv
  let mut roots : Std.HashMap Name Bool := {}
  let mut modules := #[]
  for i in [:env.header.modules.size] do
    let name := env.header.modules[i]!.module
    -- The integration's own implementation is not project mathematical context.
    if name.getRoot == `LLMlean then continue
    let key := name.getRoot
    let belongs ← match roots[key]? with
      | some b => pure b
      | none =>
        let b ← try
          let path ← IO.FS.realPath (← findOLean name)
          pure (isWithin root path && !isWithin (root / ".lake" / "packages") path)
        catch _ => pure false
        roots := roots.insert key b
        pure b
    if belongs then modules := modules.push (name, env.header.moduleData[i]!)
  return modules

/-- The raw-source baseline reads each transitive project import once, in Lean's module order.
Missing source is an error: silently skipping it would invalidate the all-files comparison. -/
private def importedProjectFiles : CoreM (Array (Name × String)) := do
  let paths := (← projectRoot) :: (← getSrcSearchPath)
  let mut files := #[]
  for (name, _) in ← projectModules do
    Core.checkInterrupted
    let source ← try
      IO.FS.readFile (← findLean paths name)
    catch ex => throwError "all_files: cannot read source for imported module {name}: {ex.toMessageData}"
    files := files.push (name, source)
  return files

private def usableName (env : Environment) (name : Name) (localDecl : Bool)
    (target : Option Name) : Bool := Id.run do
  if target.any (fun t => t.isPrefixOf name) then return false
  if isPrivateName name && !localDecl then return false
  let userName := privateToUserName name
  if userName.isInternalDetail || userName.hasMacroScopes then return false
  if isAuxRecursor env name || isNoConfusion env name then return false
  if userName.anyS (fun s => ["sizeOf_spec", "ctorIdx", "noConfusionType", "rec", "below", "ibelow"].contains s) then
    return false
  if !env.containsOnBranch name then return false
  -- Elaborator/parser implementations are not mathematical premises.
  let some val := env.findConstVal? name | return false
  let result := val.type.getForallBody.getAppFn
  if let .const n _ := result then
    if (`Lean).isPrefixOf n then return false
  return true

/-- Candidate extraction is independent of ranking so a future premise selector can replace it. -/
def collectCandidates (target : Option Name) : CoreM (Array Candidate) := do
  let env ← getEnv
  let mut candidates := #[]
  for info in ← env.getLocalConstantInfos (skipTheoremSubDecls := true) do
    if usableName env info.name true target then
      candidates := candidates.push {
        name := info.name, type := info.toConstantVal.type, kind := info.kind,
        moduleName := env.mainModule, localDecl := true, order := candidates.size }
  for (moduleName, data) in ← projectModules do
    for info in data.constants do
      if usableName env info.name false target then
        candidates := candidates.push {
          name := info.name, type := info.type, kind := (AsyncConstantInfo.ofConstantInfo info).kind,
          moduleName, localDecl := false, order := candidates.size }
  return candidates

private def score (c : Candidate) (symbols : NameSet) : Nat := Id.run do
  let mut score := if symbols.contains c.name then 10000 else 0
  for name in c.type.getUsedConstants do
    -- Ubiquitous logical/type constructors carry little relevance information.
    if symbols.contains name &&
        ![`Eq, `HEq, `Nat, `List, `And, `Or, `True, `False, `OfNat, `HAdd, `HMul, `HAppend].contains name.getRoot then
      score := score + 100
    else if symbols.contains name && name != name.getRoot &&
        [`Nat, `List].contains name.getRoot then
      score := score + 20
  return score + if c.localDecl then 10 else 0

/-- Stable baseline: goal symbols, type overlap, then current-file recency. -/
def rankCandidates (candidates : Array Candidate) (symbols : NameSet) : Array Candidate :=
  ((candidates.map fun c => (score c symbols, c)).qsort fun (sa, a) (sb, b) =>
      if sa != sb then sa > sb
      else if a.localDecl && b.localDecl then a.order > b.order
      else Name.quickLt a.name b.name).map (·.2)

private def summarize (c : Candidate) (bodyLimit : Nat) : MetaM (String × Array String) := do
  let env ← getEnv
  let kind := if wasOriginallyTheorem env c.name then "theorem" else
    match (getOriginalConstKind? env c.name).getD c.kind with
    | .defn => "def"
    | .induct => "inductive"
    | .ctor => "constructor"
    | .axiom => "axiom"
    | _ => "constant"
  let mut text := s!"{kind} {privateToUserName c.name} : {← ppExpr c.type}"
  let mut glossary ← notationFor c.type
  if c.kind == .induct then
    if let some (.inductInfo val) := env.find? c.name then
      for name in val.ctors do
        if let some ctor := env.findConstVal? name then
          text := text ++ s!"\n  constructor {privateToUserName name} : {← ppExpr ctor.type}"
          glossary := glossary ++ (← notationFor ctor.type)
  if c.kind == .defn && bodyLimit > 0 then
    if let some (.defnInfo val) := env.find? c.name then
      if val.value.sizeWithoutSharing ≤ bodyLimit && !(← isProof val.value) then
        let body := toString (← ppExpr val.value)
        if body.length ≤ bodyLimit then
          text := text ++ " := " ++ body
          glossary := glossary ++ (← notationFor val.value)
  return (text, glossary)

def build (settings : Config.Settings) (ref : Syntax) : TacticM Bundle := withoutModifyingState do
  withOptions printOptions do
    let mut b : Bundle := {}
    let (header, history, truncated, sourceSyntax) ← sourceParts ref settings.historyChars
    let target ← Term.getDeclName?
    let targetHeader := (target.map (fun n => s!"-- Target: {privateToUserName n}\n") |>.getD "") ++ header
    b := { b with
      currentDeclaration := targetHeader
      history := history
      historyTruncated := truncated }
    let mut symbols : NameSet := {}
    for g in ← getUnsolvedGoals do
      let (goal, glossary, used) ← g.withContext do
        let mut expressions := #[(← g.getType)]
        for decl in ← getLCtx do
          unless decl.isImplementationDetail do
            expressions := expressions.push decl.type
            if let some value := decl.value? then expressions := expressions.push value
        let mut glossary := #[]
        let mut used : NameSet := {}
        for e in expressions do
          for name in e.getUsedConstants do used := used.insert name
          if settings.contextMode == "structured" then
            glossary := glossary ++ (← notationFor e)
        let merged := addNotation b.glossary glossary settings.notationChars
        if glossary.all merged.contains then
          return (toString (← ppGoal g), merged, used)
        else
          -- A notation budget must not leave the rendered goal unexplained.
          let goal ← withOptions (·.setBool `pp.notation false) do
            return toString (← ppGoal g)
          return (goal, b.glossary, used)
      b := { b with
        goals := b.goals ++ (if b.goals.isEmpty then "" else "\n\n") ++ goal
        glossary := glossary }
      for n in used do symbols := symbols.insert n
    if settings.contextMode != "structured" then
      let source := (← getFileMap).source
      let sourcePrefix := ref.getPos?.map (String.Pos.Raw.extract source 0) |>.getD ""
      let window := settings.contextMode == "window"
      let importedFiles ← if settings.contextMode == "all_files" then importedProjectFiles else pure #[]
      return { b with
        importedFiles
        history := if window then historyWindow sourcePrefix settings.historyChars else sourcePrefix
        historyTruncated := window && sourcePrefix.length > settings.historyChars }
    if let some hole := ref.getPos? then
      if let some (_, bodyStart) := declarationBody? sourceSyntax then
        let sourceGlossary ← sourceNotation sourceSyntax bodyStart
          ⟨hole.byteIdx - history.utf8ByteSize⟩ hole
        let merged := addNotation b.glossary sourceGlossary settings.notationChars
        b := { b with glossary := merged, glossaryOmitted := !sourceGlossary.all merged.contains }
    let candidates ← collectCandidates target
    let mut used := 0
    for c in rankCandidates candidates symbols do
      Core.checkInterrupted
      if used ≥ settings.premiseChars then break
      let (text, glossary) ← summarize c settings.definitionChars
      let (text, glossary) ← if used + text.length + 2 > settings.premiseChars then
        summarize c 0
      else pure (text, glossary)
      let merged := addNotation b.glossary glossary settings.notationChars
      let (text, merged) ← if glossary.all merged.contains then pure (text, merged) else do
        let (plain, _) ← withOptions (·.setBool `pp.notation false) <| summarize c settings.definitionChars
        pure (plain, b.glossary)
      if used + text.length + 2 ≤ settings.premiseChars then
        b := { b with
          declarations := b.declarations.push text
          glossary := merged }
        used := used + text.length + 2
    return { b with
      candidateCount := candidates.size
      omittedCount := candidates.size - b.declarations.size }

end LLMlean.Context
