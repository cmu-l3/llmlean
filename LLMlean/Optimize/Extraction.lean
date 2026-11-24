module
public import Lean

public section
open Lean Elab

namespace LLMlean.Optimize.Extraction

def obj := Json.mkObj
def str := Json.str
def num (n : Nat) := toJson n
def strings (xs : Array String) := toJson xs

structure Span where
  start : Nat
  stop : Nat
  deriving BEq, Inhabited

def Span.json (r : Span) : Json := obj [("start_byte", num r.start), ("end_byte", num r.stop)]
instance : FromJson Span where
  fromJson? j := return ⟨← j.getObjValAs? Nat "start_byte", ← j.getObjValAs? Nat "end_byte"⟩

def Span.contains (r s : Span) : Bool := r.start ≤ s.start && s.stop ≤ r.stop
def span? (s : Syntax) : Option Span := do
  let a ← s.getPos?
  let b ← s.getTailPos?
  return ⟨a.byteIdx, b.byteIdx⟩
def slice (source : String) (r : Span) : String := String.Pos.Raw.extract source ⟨r.start⟩ ⟨r.stop⟩

partial def nodes (s : Syntax) : Array Syntax :=
  s.getArgs.foldl (fun acc c => acc ++ nodes c) #[s]

def identifiers (s : Syntax) : Array Syntax := (nodes s).filter Syntax.isIdent

def original (s : Syntax) : Bool := match s.getHeadInfo with
  | .original .. => true
  | _ => false

def firstToken (s : Syntax) : String :=
  ((nodes s).find? fun n => n.isAtom || n.isIdent).map (fun n =>
    if n.isIdent then n.getId.toString else n.getAtomVal) |>.getD ""

structure Resolution where
  span : Span
  spelling : Name
  category : String
  name : Name := .anonymous
  binder : Bool := false

structure Observations where
  refs : Array Resolution := #[]
  tactics : Array Syntax := #[]
  contexts : Array ContextInfo := #[]
  tacticInfo : Array (ContextInfo × TacticInfo) := #[]

partial def observe (tree : InfoTree) (ctx? : Option ContextInfo := none)
    (acc : Observations := {}) (withStates := false) : Observations := Id.run do
  match tree with
  | .context c t => return observe t (c.mergeIntoOuter? ctx?) acc withStates
  | .hole _ => return acc
  | .node info children =>
    let mut acc := acc
    if let some ctx := ctx? then
      if acc.contexts.isEmpty then acc := { acc with contexts := #[ctx] }
    match info with
    | .ofTermInfo i =>
      -- Lean attaches the resolution of `.single` to the whole term, including the dot.
      let ref := if i.stx.getKind == ``Parser.Term.dotIdent then i.stx[1] else i.stx
      if original i.stx && original ref then
        if let some r := span? ref then
          let e := i.expr.consumeMData
          let (category, name) := match e with
            | .const n _ => ("global", n)
            | .fvar _ => ("local", .anonymous)
            | _ => ("other_term", .anonymous)
          acc := { acc with refs := acc.refs.push ⟨r, ref.getId, category, name, i.isBinder⟩ }
    | .ofFieldInfo i =>
      if original i.stx then
        if let some r := span? i.stx then
          acc := { acc with refs := acc.refs.push ⟨r, i.fieldName, "global", i.projName, false⟩ }
    | .ofTacticInfo i =>
      acc := { acc with tactics := acc.tactics.push i.stx }
      if withStates then
        if let some ctx := ctx? then
          acc := { acc with tacticInfo := acc.tacticInfo.push (ctx, i) }
    | _ => pure ()
    for c in children do acc := observe c (info.updateContext? ctx?) acc withStates
    return acc

def constKind (env : Environment) (c : ConstantInfo) : String :=
  match (getOriginalConstKind? env c.name).getD (.ofConstantInfo c) with
  | .thm => "theorem"
  | .axiom => "axiom"
  | .defn => "definition"
  | .opaque => "opaque"
  | .ctor => "constructor"
  | .induct => "inductive"
  | .recursor => "recursor"
  | .quot => "quotient"

structure References where
  occurrences : Array Json := #[]
  globals : Array Name := #[]
  lemmas : Array Name := #[]
  total : Nat := 0
  resolved : Nat := 0

def collectRefs (source : String) (stx : Syntax) (obs : Observations)
    (env : Environment) : References := Id.run do
  let mut result : References := {}
  let mut seen : Array Span := #[]
  for ident in identifiers stx do
    let some r := span? ident | continue
    if !original ident || r.start == r.stop then continue
    if seen.contains r then continue
    seen := seen.push r
    -- Dot notation can split one source identifier (h.trans) into a local h and
    -- a global trans with separate source ranges. Only original-source info is used.
    let resolvedInfos := obs.refs.filter fun x => r.contains x.span && x.span.start < x.span.stop
    let gs := resolvedInfos.filter fun x => x.category == "global" && !x.binder
    let locals := resolvedInfos.filter fun x => x.category == "local"
    let mut names : Array Name := #[]
    for g in gs do
      if !names.contains g.name then names := names.push g.name
    let meaningful := resolvedInfos.filter fun x => x.category == "global" || x.category == "local"
    let covered := (List.range (r.stop - r.start)).all fun offset =>
      let p := r.start + offset
      source.toUTF8[p]! == 46 || meaningful.any (fun x => x.span.start ≤ p && p < x.span.stop)
    let category := if !covered then "unresolved"
      else if !names.isEmpty then "global"
      else if !locals.isEmpty then
        if locals.all (·.binder) then "local_binder" else "local"
      else "unresolved"
    result := { result with total := result.total + 1 }
    if category != "unresolved" && category != "ambiguous" then
      result := { result with resolved := result.resolved + 1 }
    if !names.isEmpty then
      for name in names do
        if !result.globals.contains name then result := { result with globals := result.globals.push name }
        if wasOriginallyTheorem env name then
          if !result.lemmas.contains name then result := { result with lemmas := result.lemmas.push name }
    result := { result with occurrences := result.occurrences.push <| obj [
      ("source", str (slice source r)), ("range", r.json), ("category", str category),
      ("contains_local", toJson (!locals.isEmpty)),
      ("names", strings (names.map Name.toString))] }
  return result

def tacticOccurrences (source : String) (proof : Syntax) (obs : Observations) : Array Json := Id.run do
  let mut result := #[]
  let mut seen : Array (Span × Name) := #[]
  for n in nodes proof do
    if n.isAtom || n.isIdent then continue
    let some r := span? n | continue
    let k := n.getKind
    if k == `null || k == `Lean.cdot || k == `Lean.cdotTk || k == ``Parser.Term.byTactic ||
        k == ``Parser.Tactic.tacticSeq || k == ``Parser.Tactic.tacticSeq1Indented ||
        k == ``Parser.Tactic.tacticSeqBracketed then continue
    if seen.contains (r, k) then continue
    if obs.tactics.any (fun t => span? t == some r && t.getKind == k) then
      seen := seen.push (r, k)
      result := result.push <| obj [("name", str (firstToken n)),
        ("syntax_kind", str k.toString), ("range", r.json), ("source", str (slice source r))]
  return result

/-- Only these two well-known declaration shapes are supported. Other wrappers are reported. -/
def theoremBody? (cmd : Syntax) : Option Syntax :=
  if cmd.getKind == ``Parser.Command.declaration && cmd[1].getKind == ``Parser.Command.theorem then
    some cmd[1]
  else if cmd.getKind == `lemma && cmd[1][0].isAtom && cmd[1][0].getAtomVal == "lemma" then
    some cmd[1]
  else none

partial def theoremCommands (cmd : Syntax) : Array Syntax :=
  if (theoremBody? cmd).isSome then #[cmd]
  else cmd.getArgs.foldl (fun xs c => xs ++ theoremCommands c) #[]

def failure (cmd : Syntax) (reason : String) (detail : String := "") : Json := obj [
  ("event", str "failure"), ("category", str reason), ("detail", str detail),
  ("source_name", (theoremBody? cmd).map (fun b => str b[1][0].getId.toString) |>.getD Json.null),
  ("range", (span? cmd).map Span.json |>.getD Json.null),
  ("syntax_kind", str cmd.getKind.toString)]

def ppType (ctx : ContextInfo) (env : Environment) (type : Expr) : IO String :=
  { ctx with env, options := ctx.options.setBool `pp.fullNames true }.runMetaM {} do
    return (← Meta.ppExpr type).pretty

/-- Preserve each source-associated observation, including repeated applications.
    Source order is not a flat execution trace: compound tactics contain children. -/
def tacticStates (obs : Observations) (tactics : Array Json) : IO (Array Json × Bool) := do
  let mut states := #[]
  let mut complete := true
  for index in [:tactics.size] do
    let t := tactics[index]!
    let range ← IO.ofExcept (t.getObjVal? "range")
    let a ← IO.ofExcept (range.getObjValAs? Nat "start_byte")
    let b ← IO.ofExcept (range.getObjValAs? Nat "end_byte")
    let kind ← IO.ofExcept (t.getObjValAs? String "syntax_kind")
    let observations := obs.tacticInfo.filter fun (_, i) =>
      span? i.stx == some ⟨a, b⟩ && i.stx.getKind.toString == kind
    if observations.isEmpty then complete := false
    for ((ctx, i), occurrence) in observations.zipIdx do
      let base := [("tactic_index", num index), ("occurrence_index", num occurrence),
        ("range", range), ("syntax_kind", str kind),
        ("source", (t.getObjVal? "source").toOption.getD Json.null)]
      try
        let pp (mctx : MetavarContext) (goals : List MVarId) : IO (Array Json) := do
          let ctx := { ctx with mctx, options := ctx.options.setBool `pp.fullNames false }
          ctx.runMetaM {} do
            goals.toArray.mapM fun g => do
              return obj [("id", str g.name.toString), ("pretty", str (← Meta.ppGoal g).pretty)]
        let before ← pp i.mctxBefore i.goalsBefore
        let after ← pp i.mctxAfter i.goalsAfter
        states := states.push <| obj (base ++ [("status", str "ok"),
          ("goals_before", toJson before), ("goals_after", toJson after)])
      catch e =>
        complete := false
        states := states.push <| obj (base ++ [("status", str "error"), ("error", str e.toString)])
  return (states, complete)

def referenceDefinitions (ctx : ContextInfo) (env : Environment) (names : Array Name) : IO (Array Json) := do
  let mut result := #[]
  for name in names do
    unless wasOriginallyDefn env name do continue
    let base := [("name", str name.toString), ("representation", str "pretty_printed_elaborated_value")]
    let some (.defnInfo info) := env.find? name | do
      result := result.push <| obj (base ++ [("status", str "omitted_module_visibility")])
      continue
    try
      let body ← ppType ctx env info.value
      if body.utf8ByteSize > 4096 then
        result := result.push <| obj (base ++ [("status", str "omitted_size_limit"), ("body_bytes", num body.utf8ByteSize)])
      else
        result := result.push <| obj (base ++ [("status", str "included"), ("value", str body)])
    catch e =>
      result := result.push <| obj (base ++ [("status", str "error"), ("error", str e.toString)])
  return result

def tokenCount (proof : Syntax) : Nat := Id.run do
  let mut spans : Array Span := #[]
  for stx in nodes proof do
    if !(stx.isAtom || stx.isIdent) || !original stx then continue
    let some r := span? stx | continue
    if r.start < r.stop && !spans.contains r then spans := spans.push r
  return spans.size

def declaredName? (body : Syntax) (obs : Observations) : Option Name := do
  let r ← span? body[1][0]
  let ref ← obs.refs.find? fun ref => ref.span == r && ref.category == "global" && ref.binder
  return ref.name

def extract (source : String) (cmd body : Syntax) (obs : Observations)
    (env : Environment) (auditAxioms := false) (withStates := false) : IO Json := do
  let declId := body[1][0]
  let val := body[3]
  if val.getKind != ``Parser.Command.declValSimple then
    return failure cmd "unsupported_value" "Expected := by ..."
  if (nodes val).any (·.getKind == ``Parser.Term.whereDecls) then
    return failure cmd "unsupported_where"
  let proof := val[1]
  if proof.getKind != ``Parser.Term.byTactic then return failure cmd "unsupported_proof_form"
  -- Termination annotations are outside the supported single-proof replacement boundary.
  if (val.getArgs.toList.drop 2).any (fun s => (span? s).isSome) then
    return failure cmd "unsupported_declaration_suffix"
  let some cr := span? cmd | return failure cmd "source_unavailable"
  let some pr := span? proof | return failure cmd "source_unavailable"
  let some ir := span? declId | return failure cmd "source_unavailable"
  let some assign := val[0].getPos? | return failure cmd "source_unavailable"
  let sr : Span := ⟨cr.start, assign.byteIdx⟩
  let some name := declaredName? body obs | return failure cmd "declaration_name_unresolved"
  let some (.thmInfo ci) := env.find? name | return failure cmd "not_a_theorem"
  if ci.value.hasSorry then return failure cmd "contains_sorry"
  let some ctx := obs.contexts[0]? | return failure cmd "missing_info_tree"
  let statementRefs := collectRefs source body[2] obs env
  let proofRefs := collectRefs source proof obs env
  let names := (statementRefs.globals ++ proofRefs.globals).foldl
    (fun ns n => if ns.contains n then ns else ns.push n) (#[] : Array Name)
  let mut signatures := #[]
  for name in names do
    let some c := env.find? name | continue
    signatures := signatures.push <| obj [("name", str name.toString),
      ("kind", str (constKind env c)), ("type", str (← ppType ctx env c.type))]
  let tactics := tacticOccurrences source proof obs
  let (states, statesComplete) ← if withStates then tacticStates obs tactics else pure (#[], false)
  let definitions ← if withStates then referenceDefinitions ctx env names else pure #[]
  let total := statementRefs.total + proofRefs.total
  let resolved := statementRefs.resolved + proofRefs.resolved
  let warnings := if total == resolved then #[] else #[str "unresolved_identifiers"]
  let axioms ← if auditAxioms then
    ({ ctx with env } : ContextInfo).runMetaM {} (collectAxioms name) else pure #[]
  let available := #["rfl", "assumption", "simp", "simp_all", "aesop", "grind", "omega", "linarith", "cutsat"]
    |>.filter fun name => (Parser.runParserCategory env `tactic name).isOk
  let catalog := #["rfl", "assumption", "simp", "simpa", "simp_all", "dsimp", "aesop", "grind",
    "omega", "linarith", "nlinarith", "norm_num", "ring", "ring_nf", "abel", "positivity",
    "field_simp", "gcongr", "ext", "fun_prop", "continuity", "measurability", "decide", "tauto"]
  let extras := if withStates then [("reference_definitions", toJson definitions),
    ("automation_catalog", obj [("checked", strings catalog),
      ("available", strings (catalog.filter fun name => (Parser.runParserCategory env `tactic name).isOk)),
      ("availability", str "syntax_parses_in_original_environment_not_a_success_guarantee")])] else []
  return obj [
    ("event", str "record"),
    ("location", obj [("command_range", cr.json), ("statement_range", sr.json), ("proof_range", pr.json)]),
    ("declaration", obj [("name", str ci.name.toString), ("source_name", str (slice source ir)),
      ("statement_source", str (slice source sr)), ("type_pp", str (← ppType ctx env ci.type)),
      ("explicit_refs", strings (statementRefs.globals.map Name.toString)),
      ("identifiers", toJson statementRefs.occurrences)]),
    ("proof", obj [("source", str (slice source pr)),
      ("length_tokens", num (tokenCount proof)),
      ("axioms", strings (axioms.map Name.toString)),
      ("explicit_refs", strings (proofRefs.globals.map Name.toString)),
      ("explicit_lemma_refs", strings (proofRefs.lemmas.map Name.toString)),
      ("identifiers", toJson proofRefs.occurrences),
      ("elaborated_constants", strings (ci.value.getUsedConstants.map Name.toString)),
      ("tactics", toJson tactics), ("tactic_count", num tactics.size),
      ("tactic_states", toJson states)]),
    ("context", obj ([("explicit_ref_signatures", toJson signatures),
      ("available_automation", strings available)] ++ extras)),
    ("extraction", obj [("status", str (if total == resolved then "ok" else "partial")),
      ("source_available", toJson true), ("warnings", toJson warnings),
      ("identifier_occurrences", num total), ("resolved_identifier_occurrences", num resolved),
      ("tactic_coverage", str "source_nodes_with_matching_tactic_info"),
      ("tactic_states_status", str (if !withStates then "not_requested" else if statesComplete then "complete" else "partial")),
      ("elaborated_constants_status", str "direct_constants_only")])]

structure VerifyRequest where
  command_start : Nat
  proof_start : Nat
  proof_end : Nat
  enforce_policy : Bool := true
  deriving FromJson

/-- This runs after parsing the target command, before elaborating candidate code. -/
def guardCandidate (cmd : Syntax) (request : VerifyRequest) : Option String := do
  let body ← (theoremBody? cmd).orElse fun _ => none
  if body[3].getKind != ``Parser.Command.declValSimple then return "unsupported_value"
  let proof := body[3][1]
  if proof.getKind != ``Parser.Term.byTactic then return "replacement_is_not_by_proof"
  if span? proof != some ⟨request.proof_start, request.proof_end⟩ then
    return "proof_boundary_changed"
  if (body[3].getArgs.toList.drop 2).any (fun s => (span? s).isSome) then
    return "declaration_suffix_injection"
  if request.enforce_policy then
    let forbidden := ["sorry", "admit", "sorryAx", "axiom", "import", "unsafe",
      "native_decide", "native", "run_tac", "run_elab", "elab", "macro", "initialize",
      "implemented_by", "unsafeCast", "ofReduceBool", "ofReduceNat", "trustCompiler",
      "evalExpr", "evalConst", "set_option", "unhygienic", "save", "restore"]
    for stx in nodes proof do
      if stx.isAtom || stx.isIdent then
        let token := if stx.isIdent then stx.getId.toString else stx.getAtomVal
        if (token.splitOn ".").any forbidden.contains then
          return s!"forbidden_token:{token}"
  none

def lexicalContext (source : String) (scope : Command.Scope) : Json :=
  obj [
    ("namespace", str scope.currNamespace.toString),
    ("open_declarations", toJson (scope.openDecls.map toString)),
    ("universe_parameters", toJson (scope.levelNames.map Name.toString)),
    ("section_variables", toJson (scope.varDecls.filterMap fun b =>
      (span? b).map (slice source)))]

def addedAxioms (before after : Environment) : List String :=
  after.constants.map₂.toList.filterMap fun (name, info) =>
    if before.contains name then none else match info with
      | .axiomInfo _ => if wasOriginallyTheorem after name then none else some name.toString
      | _ => none

end LLMlean.Optimize.Extraction
