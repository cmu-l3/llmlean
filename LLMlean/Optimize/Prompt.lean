module
public import LLMlean.Optimize.Extraction

public section
namespace LLMlean.Optimize.Prompt
open Lean
open LLMlean.Optimize.Extraction (Span)

def version := "rewrite-context-c-length-first-v1"
private def systemPrompt := (include_str "SystemPrompt.txt").trimAsciiEnd.toString
private def omittedDefinitions : List String :=
  ["Set", "Set.Mem", "Set.instMembership", "Membership.mem", "Membership", "Nat", "Int", "Bool",
   "List", "Option", "Prod", "Sum", "Subtype", "Eq", "HEq", "Iff",
   "And", "Or", "Not", "Exists", "True", "False", "id", "Function.comp",
   "Function.const", "OfNat.ofNat", "OfNat", "HAdd.hAdd", "HSub.hSub", "HMul.hMul", "HDiv.hDiv", "HPow.hPow",
   "LT.lt", "LE.le", "BEq.beq", "Decidable", "DecidableEq"]
private def guidance : String → Option String
  | "rfl" => some "Definitional equality; try before search."
  | "assumption" => some "Close a goal already present as a local hypothesis."
  | "simp" => some "Simplification and rewriting with simp lemmas; selectively unfold useful definitions."
  | "simpa" => some "Simplify the goal and a supplied proof to match."
  | "simp_all" => some "Simplify the goal and mutually dependent local hypotheses."
  | "dsimp" => some "Definitional simplification before other automation."
  | "grind" => some "First-order/equality reasoning with local facts and selected lemmas; prepare useful facts first."
  | "aesop" => some "Structured proof search for logical goals, constructors, and applicable rules."
  | "omega" => some "Linear arithmetic over Nat and Int, including natural-number subtraction."
  | "linarith" => some "Linear equalities and inequalities over ordered arithmetic types."
  | "nlinarith" => some "Polynomial inequalities when its preprocessing can expose a linear contradiction; incomplete."
  | "norm_num" => some "Concrete numeric calculations and numeric side conditions."
  | "ring" => some "Commutative polynomial identities."
  | "ring_nf" => some "Normalize polynomial expressions before another tactic."
  | "abel" => some "Identities in commutative additive groups/monoids."
  | "positivity" => some "Positivity, nonnegativity, and nonzero side conditions."
  | "field_simp" => some "Clear denominators; discharge nonzero side conditions, then use ring or arithmetic."
  | "gcongr" => some "Reduce inequalities using monotonicity/congruence."
  | "ext" => some "Reduce equality of functions/structures to component or pointwise goals."
  | "fun_prop" => some "Recognized function properties, for example continuity, via registered rules."
  | "continuity" => some "Continuity goals built from known continuous functions."
  | "measurability" => some "Measurability goals built from registered measurable functions."
  | "decide" => some "Small decidable propositions; do not use native_decide."
  | "tauto" => some "Propositional reasoning."
  | _ => none

-- The training messages use compact UTF-8 JSON with insertion-ordered object fields.
private def quote (s : String) : String := Id.run do
  if !s.any (fun c => c == '\t' || c == '\x08' || c == '\x0c') then return Json.renderString s
  let mut out := "\""
  for c in s.toList do
    out := out ++ (match c with
      | '\t' => "\\t" | '\x08' => "\\b" | '\x0c' => "\\f"
      | _ => Json.escape (String.singleton c))
  return out ++ "\""

private def object (fields : List (String × String)) : String :=
  "{" ++ String.intercalate "," (fields.map fun (k, v) => quote k ++ ":" ++ v) ++ "}"

private def array (items : Array String) : String := "[" ++ String.intercalate "," items.toList ++ "]"

private partial def render : Json → String
  | .str s => quote s
  | .arr vs => array (vs.map render)
  | .obj fs => object (fs.toList.map fun (k, v) => (k, render v))
  | v => v.compress

private def fields (v : Json) : Except String (List (String × String)) := do
  return (← v.getObj?).toList.map fun (k, x) => (k, render x)

private def tacticTrace (proof : Json) (start : Nat) : Except String String := do
  let tactics ← proof.getObjValAs? (Array Json) "tactics"
  let ranges ← tactics.mapM (·.getObjValAs? Span "range")
  let source := (← proof.getObjValAs? String "source").toUTF8
  let mut entries := #[]
  let mut seen : Std.HashSet (Nat × Nat) := {}
  let mut covered : Std.HashSet Nat := {}
  for state in ← proof.getObjValAs? (Array Json) "tactic_states" do
    let i ← state.getObjValAs? Nat "tactic_index"
    let occurrence ← state.getObjValAs? Nat "occurrence_index"
    let some tactic := tactics[i]? | throw "Unknown tactic in proof trace."
    let r := ranges[i]!
    let snippet ← tactic.getObjValAs? String "source"
    unless !seen.contains (i, occurrence) && (← state.getObjValAs? String "status") == "ok" &&
        (← state.getObjValAs? Span "range") == r && (← state.getObjValAs? String "source") == snippet &&
        (← state.getObjVal? "syntax_kind") == (← tactic.getObjVal? "syntax_kind") &&
        start ≤ r.start && r.start < r.stop && r.stop ≤ start + source.size &&
        source.extract (r.start - start) (r.stop - start) == snippet.toUTF8 do
      throw "Tactic state does not match the source proof."
    for side in ["goals_before", "goals_after"] do
      for goal in ← state.getObjValAs? (Array Json) side do
        discard <| goal.getObjValAs? String "id"
        discard <| goal.getObjValAs? String "pretty"
    covered := covered.insert i
    seen := seen.insert (i, occurrence)
    let mut parent : Option Nat := none
    let mut width := source.size + 1
    for (other, j) in ranges.zipIdx do
      let size := other.stop - other.start
      if other != r && other.contains r && size < width then
        parent := some j
        width := size
    entries := entries.push (object ((← fields state) ++ [("parent_tactic_index", render (toJson parent))]))
  unless !tactics.isEmpty && covered.size == tactics.size do throw "Incomplete tactic-state coverage."
  return object [
    ("ordering", quote "source syntax preorder, with all matching observations per tactic; nested ranges are not sequential steps"),
    ("coverage", quote "all source tactics recognized by the extractor; pretty-printed goals with local context"),
    ("entries", array entries)]

def messages (record : Json) (moduleName leanVersion : String) (imports : Json) : Except String Json := do
  let extraction ← record.getObjVal? "extraction"
  unless (← extraction.getObjValAs? String "status") == "ok" do throw "Incomplete explicit-reference metadata."
  unless (← extraction.getObjValAs? String "tactic_states_status") == "complete" do throw "Incomplete tactic states."
  let decl ← record.getObjVal? "declaration"
  let proof ← record.getObjVal? "proof"
  let ctx ← record.getObjVal? "context"
  let statementRefs ← decl.getObjValAs? (Array String) "explicit_refs"
  let proofRefs ← proof.getObjValAs? (Array String) "explicit_refs"
  let names := (statementRefs ++ proofRefs).toList.eraseDups.mergeSort
  let mut signatures : Std.HashMap String Json := {}
  for s in ← ctx.getObjValAs? (Array Json) "explicit_ref_signatures" do
    signatures := signatures.insert (← s.getObjValAs? String "name") s
  let mut refs := #[]
  let mut expectedDefs : Std.HashSet String := {}
  for name in names do
    let some s := signatures[name]? | throw s!"Missing signature for {name}."
    let used := (if statementRefs.contains name then #["statement"] else #[]) ++
      (if proofRefs.contains name then #["proof"] else #[])
    refs := refs.push (object ((← fields s) ++ [("used_in", render (toJson used))]))
    if (← s.getObjValAs? String "kind") == "definition" then expectedDefs := expectedDefs.insert name
  let mut defs := #[]
  let mut omitted := #[]
  let mut seenDefs : Std.HashSet String := {}
  for d in ← ctx.getObjValAs? (Array Json) "reference_definitions" do
    let name ← d.getObjValAs? String "name"
    unless names.contains name do continue
    seenDefs := seenDefs.insert name
    if omittedDefinitions.contains name then
      omitted := omitted.push (object [("name", quote name), ("reason", quote "foundational_definition_body")])
      let fs := (← d.getObj?).erase "value" |>.insert "status" (toJson "omitted_foundational_definition")
      defs := defs.push (render (.obj fs))
    else
      defs := defs.push (render d)
  unless expectedDefs == seenDefs do throw "Incomplete reference definitions."
  let location ← record.getObjVal? "location"
  let proofRange ← location.getObjValAs? Span "proof_range"
  let trace ← tacticTrace proof proofRange.start
  let catalog ← ctx.getObjVal? "automation_catalog"
  let available ← catalog.getObjValAs? (Array String) "available"
  let advice := available.toList.filterMap fun t => (guidance t).map fun s => (t, quote s)
  let automation := object [("availability", render (← catalog.getObjVal? "availability")),
    ("available_tactics", render (toJson available)), ("guidance", object advice)]
  let filter := object [("version", quote "sft-context-v1"), ("omissions", array omitted),
    ("rule", quote "Omit only bodies of exactly listed foundational definitions; keep their signatures and all explicit theorem premises. Record every omission. Never drop an entire namespace or silently truncate states.")]
  let environment := object ((← fields (← record.getObjVal? "lexical_context")) ++ [
    ("lean_version", quote leanVersion), ("module", quote moduleName), ("imports", render imports)])
  let user := object [
    ("theorem_statement", render (← decl.getObjVal? "statement_source")),
    ("elaborated_signature_including_section_variables", render (← decl.getObjVal? "type_pp")),
    ("original_proof", render (← proof.getObjVal? "source")), ("explicit_reference_signatures", array refs),
    ("tactic_state_trace", trace), ("automation", automation), ("reference_definitions", array defs),
    ("context_filter", filter), ("original_environment", environment)]
  if systemPrompt.utf8ByteSize + user.utf8ByteSize > 65536 then throw "Proof context exceeds 64 KiB."
  return .arr #[Json.mkObj [("role", "system"), ("content", toJson systemPrompt)],
                Json.mkObj [("role", "user"), ("content", toJson user)]]

/-- Append whole signatures while preserving the original training prompt's field order. -/
def withLemmas (messages : Json) (signatures : Array String) : Option Json := do
  let #[system, user] ← messages.getArr?.toOption | none
  let content ← (user.getObjValAs? String "content").toOption
  let text := (content.dropEnd 1).toString ++ ",\"additional_available_lemmas\":" ++
    array (signatures.map quote) ++ "}"
  guard (systemPrompt.utf8ByteSize + text.utf8ByteSize ≤ 65536)
  return .arr #[system, user.setObjVal! "content" (toJson text)]

end LLMlean.Optimize.Prompt
