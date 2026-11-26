module
public import LLMlean.Optimize

public section
open Lean System

namespace LLMlean.Optimize

open Extraction (Span slice)

private structure Location where
  command_range : Span
  statement_range : Span
  proof_range : Span
  deriving FromJson

private def validateSource (record : Json) (loc : Location) (source : String) : Except String Unit := do
  let decl ← record.getObjVal? "declaration"
  let proof ← record.getObjVal? "proof"
  let cmd := loc.command_range
  unless cmd.stop ≤ source.utf8ByteSize && loc.statement_range.stop ≤ loc.proof_range.start do
    throw "Invalid declaration range."
  for (r, expected) in [(loc.statement_range, ← decl.getObjValAs? String "statement_source"),
                         (loc.proof_range, ← proof.getObjValAs? String "source")] do
    unless cmd.contains r && r.start < r.stop &&
        slice source r == expected do throw "The extracted range differs from the source."
  for (owner, field) in [(decl, "identifiers"), (proof, "identifiers"), (proof, "tactics")] do
    for entry in ← owner.getObjValAs? (Array Json) field do
      let r ← entry.getObjValAs? Span "range"
      unless cmd.contains r && r.start ≤ r.stop &&
          slice source r == (← entry.getObjValAs? String "source") do throw "Invalid source observation."

private def configFiles (dir : FilePath) : IO (Array (Option ByteArray)) :=
  #["lakefile.lean", "lakefile.toml", "lean-toolchain", "lake-manifest.json"].mapM fun (name : String) => do
    let path := dir / name
    if ← path.pathExists then return some (← IO.FS.readBinFile path) else return none

private def eventIs (event : Json) (name : String) : Bool :=
  (event.getObjValAs? String "event").toOption == some name

private structure FrontendResult where
  events : Array Json
  valid : Bool
  diagnostics : String

private def collect (frontend : Project.Frontend) (work : FilePath) (source setup : FilePath)
    (verify? : Option Json := none) (retrievalSelector : Array String := #[]) : IO FrontendResult := do
  IO.FS.createDirAll work
  let out := work / "events.jsonl"
  let args := #[source.toString, setup.toString, out.toString]
  let args ← match verify? with
    | none => pure (#["--with-states"] ++ args ++ retrievalSelector)
    | some request => do
      let req := work / "request.json"
      IO.FS.writeFile req request.compress
      pure ((#["--verify"] ++ args).push req.toString)
  let proc ← Project.output "lake"
    (#["--no-build", "env", "lean", "--run", frontend.driver.toString] ++ args)
    frontend.dir frontend.env (if verify?.isSome then 25000 else 120000)
  let mut events := #[]
  if ← out.pathExists then
    for line in (← IO.FS.readFile out).splitOn "\n" do
      if !line.trimAscii.isEmpty then events := events.push (← IO.ofExcept (Json.parse line))
  let complete? := events.back?.filter (eventIs · "complete")
  let errors := events.filterMap fun e => do
    guard ((← (e.getObjValAs? String "severity").toOption) == "error")
    (e.getObjValAs? String "message").toOption
  let diagnostics := if errors.isEmpty then proc.stderr ++ proc.stdout else String.intercalate "\n" errors.toList
  unless (events.any (eventIs · "rejected")) || complete?.isSome do
    throw <| IO.userError s!"Lean frontend did not finish. {diagnostics.trimAsciiEnd.takeEnd 2000}"
  return { events, diagnostics, valid := proc.exitCode == 0 &&
    (complete?.bind fun e => (e.getObjValAs? Bool "has_errors").toOption) == some false }

private def select (events : Array Json) (selector : Array String) : Except String Json := do
  let mut selectedRecords := #[]
  for record in events.filter (eventIs · "record") do
    let selected : Bool ← match selector.toList with
      | ["--decl", name] => do
        pure ((← (← record.getObjVal? "declaration").getObjValAs? String "name") == name)
      | ["--at-byte", offset] => do
        let some pos := offset.toNat? | throw "Invalid byte offset."
        let loc ← record.getObjValAs? Location "location"
        pure (loc.command_range.start ≤ pos && pos < loc.command_range.stop)
      | _ => throw "Expected a declaration name or a byte offset."
    if selected then selectedRecords := selectedRecords.push record
  let #[record] := selectedRecords | throw s!"Expected one named theorem with a complete by-proof at {selector.back?.getD ""}."
  return record

private structure Snapshot where
  file : FilePath
  frontend : Project.Frontend
  disk : ByteArray
  config : Array (Option ByteArray)
  source : String
  sourcePath : FilePath
  setup : Json
  setupPath : FilePath
  record : Json
  location : Location
  messages : Json
  header? : Option Json

private def prepare (file work : FilePath) (selector : Array String) (editorText? : Option String) (retrieve : Bool) : IO Snapshot := do
  let file ← IO.FS.realPath file
  unless file.extension == some "lean" do throw <| IO.userError "Select a Lean source file."
  let dir ← Project.root file
  let frontend ← Project.frontend dir
  let config ← configFiles dir
  let disk ← IO.FS.readBinFile file
  let editor? ← editorText?.mapM fun s => IO.ofExcept (Json.parse s)
  let header? ← editor?.mapM fun e => IO.ofExcept (e.getObjVal? "header")
  let source ← match editor? with
    | some e => IO.ofExcept (e.getObjValAs? String "source")
    | none => do
      let some text := String.fromUTF8? disk | throw <| IO.userError "Invalid UTF-8 Lean source."
      pure text.crlfToLf
  let setup ← Project.setup dir file header? frontend.env
  let setupPath := work / "setup.json"
  IO.FS.writeFile setupPath setup.compress
  let sourcePath := work / "original" / file.fileName.get!
  IO.FS.createDirAll sourcePath.parent.get!
  IO.FS.writeFile sourcePath source
  let retrievalSelector := if retrieve && frontend.driver.fileName == some "Frontend435.lean" then selector else #[]
  let result ← collect frontend (work / "prepare") sourcePath setupPath none retrievalSelector
  unless result.valid do throw <| IO.userError s!"Module extraction failed. {result.diagnostics.trimAsciiEnd.takeEnd 2000}"
  let record ← IO.ofExcept <| select result.events selector
  let location ← IO.ofExcept <| record.getObjValAs? Location "location"
  let some header := result.events.find? (eventIs · "header") | throw <| IO.userError "Missing module header."
  let messages ← IO.ofExcept do
    validateSource record location source
    Prompt.messages record (← setup.getObjValAs? String "name") (← header.getObjValAs? String "lean_version")
      (← header.getObjVal? "imports")
  return { file, frontend, disk, config, source, sourcePath, setup, setupPath, record, location, messages, header? }

private def Snapshot.checkCurrent (s : Snapshot) (editor : Bool) : IO Unit := do
  unless editor || (← IO.FS.readBinFile s.file) == s.disk do
    throw <| IO.userError "The source changed since extraction. Run optimize again."
  unless (← configFiles s.frontend.dir) == s.config do
    throw <| IO.userError "The project configuration changed since extraction."

private def Snapshot.verify (s : Snapshot) (work file : FilePath) (replacement : String) (original : Bool) :
    IO (Except String (Verdict.Record × Nat)) := do
  let proof := s.location.proof_range
  let request := Json.mkObj [("command_start", toJson s.location.command_range.start),
    ("proof_start", toJson proof.start), ("proof_end", toJson (proof.start + replacement.utf8ByteSize)),
    ("enforce_policy", toJson (!original))]
  let result ← collect s.frontend work file s.setupPath (some request)
  return do
    if let some rejection := result.events.find? (eventIs · "rejected") then
      throw (← rejection.getObjValAs? String "reason")
    unless result.valid do throw "Module elaboration failed"
    let #[record] := result.events.filter (eventIs · "record") | throw "Missing target proof."
    let #[timing] := result.events.filter (eventIs · "target_timing") | throw "Missing target timing."
    return (← fromJson? record, ← timing.getObjValAs? Nat "elapsed_ms")

-- Lean's ranges use LF-normalized UTF-8 byte offsets. Copy the surrounding disk bytes verbatim.
private def diskOffset (disk : ByteArray) (normalized : Nat) : Nat := Id.run do
  let mut pos := 0
  for _ in [:normalized] do
    pos := pos + (if disk[pos]? == some 13 && disk[pos + 1]? == some 10 then 2 else 1)
  return pos

private def Snapshot.apply (s : Snapshot) (replacement : String) : IO Unit := do
  let dir := s.file.parent.get!
  IO.FS.withFile dir .read fun lock => do
    lock.lock
    try
      let staged := FilePath.mk (← Project.checked "mktemp" #[(dir / ".llmlean-XXXXXXXX").toString] dir)
      try
        let a := diskOffset s.disk s.location.proof_range.start
        let b := diskOffset s.disk s.location.proof_range.stop
        let body := String.fromUTF8! (s.disk.extract a b)
        let crlf := body.contains "\r\n" || (!body.contains '\n' && s.disk[b]? == some 13 && s.disk[b + 1]? == some 10)
        let text := if crlf then replacement.replace "\n" "\r\n" else replacement
        -- Open the staging file before copying the original mode, which can be read-only.
        IO.FS.withFile staged .write fun handle => do
          discard <| Project.checked "cp" #["-p", s.file.toString, staged.toString] dir
          handle.write (s.disk.extract 0 a ++ text.toUTF8 ++ s.disk.extract b s.disk.size)
          handle.flush
          handle.truncate
        s.checkCurrent false
        IO.FS.rename staged s.file
      finally
        if ← staged.pathExists then IO.FS.removeFile staged
    finally lock.unlock

private def dumpPrompt (s : Snapshot) : IO Json := do
  let file := s.sourcePath.toString
  let digest ← if System.Platform.isOSX then Project.checked "openssl" #["dgst", "-sha256", "-r", file] s.frontend.dir
    else Project.checked "sha256sum" #[file] s.frontend.dir
  return Json.mkObj [("messages", s.messages), ("template", toJson Prompt.version),
    ("source_sha256", toJson ((digest.splitOn " ").head!))]

private def Snapshot.checkCandidate (s : Snapshot) (work : FilePath) (before : Verdict.Record)
    (i : Nat) (replacement : String) : IO Json := do
  unless validReplacement replacement do return Verdict.rejected "Expected a complete non-thinking Lean by-proof."
  let r := s.location.proof_range
  let candidate := work / toString i / "rewrite" / s.file.fileName.get!
  IO.FS.createDirAll candidate.parent.get!
  IO.FS.writeFile candidate ((String.Pos.Raw.extract s.source 0 ⟨r.start⟩) ++ replacement ++
    String.Pos.Raw.extract s.source ⟨r.stop⟩ s.source.rawEndPos)
  let checked ← s.verify (work / toString i / "check") candidate replacement false
  let (after, elapsed) ← match checked with
    | .ok result => pure result
    | .error reason => return Verdict.rejected reason
  let verdict := Verdict.compare before after replacement elapsed
  unless ← IO.ofExcept (verdict.getObjValAs? Bool "improved") do return verdict
  let label := (s.file.toString.dropPrefix (s.frontend.dir.toString ++ String.singleton FilePath.pathSeparator)).toString
  let diff ← Project.output "diff" #["-u", "-L", label, "-L", label, s.sourcePath.toString, candidate.toString] s.frontend.dir
  unless diff.exitCode == 1 do throw <| IO.userError s!"Could not diff the verified rewrite. {diff.stderr}"
  return verdict.setObjVal! "diff" (toJson diff.stdout) |>.setObjVal! "start_byte" (toJson r.start)
    |>.setObjVal! "end_byte" (toJson r.stop)

def run (file : FilePath) (selector : Array String) (dump apply : Bool)
    (editorText? : Option String := none) (onPhase : Phase → IO Unit := fun _ => pure ())
    (cancelled? : Option (BaseIO Bool) := none) : IO Json := IO.FS.withTempDir fun work => do
  onPhase .collecting
  if dump then return ← dumpPrompt (← prepare file work selector editorText? false)
  let cfg ← settings
  let s ← prepare file work selector editorText? cfg.retrieveForOptimize
  let signatures := (s.record.getObjValAs? (Array String) "retrieval_signatures").toOption.getD #[]
  let candidates ← generate s.messages onPhase cancelled? signatures (some cfg)
  s.checkCurrent editorText?.isSome
  unless (← Project.setup s.frontend.dir s.file s.header? s.frontend.env) == s.setup do
    throw <| IO.userError "The Lake module setup changed since extraction."
  let expected : Verdict.Record ← IO.ofExcept (fromJson? s.record)
  let original ← s.verify (work / "baseline") s.sourcePath expected.proof.source true
  let (before, _) ← IO.ofExcept <| original.mapError (s!"Original verification failed: {·}")
  IO.ofExcept <| Verdict.checkIdentity expected.declaration expected.proof.source before
  if Verdict.hasForbiddenAxiom before.proof then throw <| IO.userError "Original verification failed: Unapproved trust axiom"
  let verdict ← candidates.select (s.checkCandidate work before) onPhase cancelled?
  s.checkCurrent editorText?.isSome
  if apply && (← IO.ofExcept (verdict.getObjValAs? Bool "improved")) then
    if editorText?.isSome then throw <| IO.userError "Editor edits must be applied to the versioned document."
    s.apply (← IO.ofExcept (verdict.getObjValAs? String "proof"))
  return verdict


def usage := "Usage: lake exe llmlean optimize FILE --decl FULL.NAME [--dump-prompt | --apply]"

def cli (args : List String) : IO UInt32 := do
  if args == ["--help"] then IO.println usage; return 0
  let file :: "--decl" :: name :: flags := args | throw <| IO.userError usage
  unless flags.isEmpty || flags == ["--dump-prompt"] || flags == ["--apply"] do
    throw <| IO.userError usage
  let dump := flags.contains "--dump-prompt"
  let result ← run file #["--decl", name] dump (flags.contains "--apply")
  if dump then IO.println result.compress
  else if ← IO.ofExcept (result.getObjValAs? Bool "improved") then
    IO.println (← IO.ofExcept (result.getObjValAs? String "summary"))
    IO.print (← IO.ofExcept (result.getObjValAs? String "diff"))
  else
    IO.println s!"No verified improvement found. {← IO.ofExcept (result.getObjValAs? String "detail")}"
  return 0

end LLMlean.Optimize
