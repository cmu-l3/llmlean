module
public import Lean

public section
namespace LLMlean.Optimize.Project
open Lean System

abbrev Env := Array (String × Option String)

private def cleanEnv : Env :=
  #["OPENAI_API_KEY", "OPENROUTER_API_KEY", "LLMLEAN_API_KEY", "GEMINI_API_KEY", "GOOGLE_API_KEY"].map (·, none)

/-- Bound Lake and its frontend descendants, including a checker that fails to exit. -/
def output (cmd : String) (args : Array String) (cwd : FilePath) (env : Env := #[])
    (timeoutMs : Nat := 60000) : IO IO.Process.Output := do
  let child ← IO.Process.spawn {
    cmd, args, cwd, env := env ++ cleanEnv, setsid := true,
    stdin := .null, stdout := .piped, stderr := .piped }
  let stdout ← IO.asTask child.stdout.readToEnd .dedicated
  let stderr ← IO.asTask child.stderr.readToEnd .dedicated
  let start ← IO.monoMsNow
  repeat
    if let some exitCode ← child.tryWait then
      return { exitCode, stdout := ← IO.ofExcept stdout.get, stderr := ← IO.ofExcept stderr.get }
    if (← IO.monoMsNow) - start ≥ timeoutMs then
      if System.Platform.isWindows then child.kill
      else
        let killed ← IO.Process.output { cmd := "kill", args := #["-KILL", s!"-{child.pid}"] }
        if killed.exitCode != 0 then child.kill
      discard child.wait
      throw <| IO.userError s!"{cmd} timed out."
    IO.sleep 20
  throw <| IO.userError s!"{cmd} interrupted."

def checked (cmd : String) (args : Array String) (cwd : FilePath) (env : Env := #[]) : IO String := do
  let result ← output cmd args cwd env
  unless result.exitCode == 0 do
    throw <| IO.userError s!"{cmd} failed. {(result.stderr ++ result.stdout).trimAsciiEnd.takeEnd 2000}"
  return result.stdout.trimAsciiEnd.toString

partial def root (path : FilePath) : IO FilePath := do
  let some dir := path.parent | throw <| IO.userError s!"No pinned Lake project contains {path}."
  if (← (dir / "lean-toolchain").pathExists) &&
      ((← (dir / "lakefile.lean").pathExists) || (← (dir / "lakefile.toml").pathExists)) then return dir
  if dir == path then throw <| IO.userError s!"No pinned Lake project contains {path}."
  root dir

def setup (dir file : FilePath) (header? : Option Json := none) (env : Env := #[]) : IO Json := do
  let args := #["--no-build", "setup-file", file.toString] ++ header?.toArray.map Json.compress
  let value ← IO.ofExcept <| Json.parse (← checked "lake" args dir env)
  if (← IO.ofExcept (value.getObjValAs? String "name")) == "_unknown" then
    throw <| IO.userError "Lake does not recognize this file as a project module."
  return value

structure Frontend where
  dir : FilePath
  driver : FilePath
  env : Env

private def driverDir : IO FilePath := do
  if let some source ← (← getSrcSearchPath).findWithExt "lean" `LLMlean then
    if let some pkg := source.parent then
      let dir := pkg / "optimizer"
      if ← (dir / "Frontend435.lean").pathExists then return ← IO.FS.realPath dir
  -- Standalone binaries built by Lake can run outside the package's workspace.
  if let .ok pkg ← (root (← IO.appPath)).toBaseIO then
    let dir := pkg / "optimizer"
    if ← (dir / "Frontend435.lean").pathExists then return dir
  let path ← checked "lake" #["query", "@llmlean/optimizeFrontend"] (← IO.currentDir)
  let some dir := (FilePath.mk path).parent | throw <| IO.userError "Cannot locate the LLMLean frontend."
  IO.FS.realPath dir

def frontend (dir : FilePath) : IO Frontend := do
  let pin := (← IO.FS.readFile (dir / "lean-toolchain")).trimAscii.toString
  let mut env : Env := #[("ELAN_TOOLCHAIN", some pin), ("LEAN_NUM_THREADS", some "1"),
                         ("LAKE_ARTIFACT_CACHE", some "false")]
  let drivers ← driverDir
  match pin with
  | "leanprover/lean4:v4.24.0" => return ⟨dir, drivers / "Frontend424.lean", env⟩
  | "leanprover/lean4:v4.35.0" =>
    let pkg := drivers.parent.get!
    let artifact ← checked "lake" #["--no-build", "query", "+LLMlean.Optimize.Extraction:olean"] pkg env
    let lib ← IO.FS.realPath (pkg / (FilePath.mk artifact).parent.get!.parent.get!.parent.get!)
    let path := [lib] ++ SearchPath.parse ((← IO.getEnv "LEAN_PATH").getD "")
    env := env.push ("LEAN_PATH", some (SearchPath.toString path))
    return ⟨dir, drivers / "Frontend435.lean", env⟩
  | _ => throw <| IO.userError s!"Unsupported Lean toolchain {pin}. Supported versions are 4.24.0 and 4.35.0."

end LLMlean.Optimize.Project
