module
public import LLMlean
public meta import LLMlean

open Lean Elab Tactic LLMlean

elab "expect_check " code:str " => " expected:ident : tactic => do
  let before ← prettyGoals
  let result ← checkCandidate code.getString
  let tag := match result with
    | .complete => "complete"
    | .progress _ => "progress"
    | .invalid _ => "invalid"
  unless tag == expected.getId.toString do
    throwError "Expected {expected.getId}, got {repr result}"
  unless (← prettyGoals) == before do throwError "Checking changed the tactic state."

macro "hidden_admission" : tactic => `(tactic| exact sorry)

example (n : Nat) : n = n := by
  expect_check "rfl" => complete
  expect_check "example (n : Nat) : n = n := by\n  rfl" => invalid
  expect_check "by\n  rfl" => invalid
  expect_check "exact does_not_exist" => invalid
  expect_check "sorry" => invalid
  expect_check "hidden_admission" => invalid
  expect_check "skip" => invalid
  expect_check "llmqed" => invalid
  expect_check "run_tac Lean.Elab.Tactic.setGoals []" => invalid
  rfl

example : True ∧ True := by
  expect_check "constructor" => progress
  expect_check "constructor\n· trivial\n· trivial" => complete
  expect_check "constructor\n· trivial\n· exact missing" => invalid
  exact ⟨True.intro, True.intro⟩

/-- warning: declaration uses `sorry` -/
#guard_msgs in
theorem tainted : True := by sorry

example : True := by
  expect_check "exact tainted" => invalid
  trivial

elab "test_refinement" : tactic => do
  let count ← IO.mkRef (0 : Nat)
  let generator : Generator := fun _ _ input _ => do
    let n ← count.get
    count.set (n + 1)
    if n == 0 then return "```lean\nconstructor\n```"
    unless (input.splitOn "Remaining goals:").length > 1 do
      throw <| IO.userError "Repair request is missing remaining goals."
    return "```lean\nconstructor\n· trivial\n· trivial\n```"
  let before ← prettyGoals
  let result ← generateChecked {} .proof "example : True ∧ True := by" "" generator
  unless result.result == .complete && (← count.get) == 2 do
    throwError "Expected completion after one repair."
  unless (← prettyGoals) == before do throwError "Refinement changed the original state."

example : True ∧ True := by
  test_refinement
  exact ⟨True.intro, True.intro⟩

elab "test_declaration_repair" : tactic => do
  let count ← IO.mkRef (0 : Nat)
  let generator : Generator := fun _ _ input _ => do
    let n ← count.get
    count.set (n + 1)
    if n == 0 then
      return "```lean\nexample (n : Nat) : n + 0 = n := by\n  rfl\n```"
    unless (input.splitOn "inside the existing 'by' proof").length > 1 do
      throw <| IO.userError "Repair must explain that only tactics belong in the existing proof."
    return "```lean\nrfl\n```"
  let before ← prettyGoals
  let result ← generateChecked {} .proof "example (n : Nat) : n + 0 = n := by" "" generator
  unless result.code == "rfl" && result.result == .complete && (← count.get) == 2 do
    throwError "Expected a whole declaration to be rejected and repaired to tactics."
  unless (← prettyGoals) == before do throwError "Repair changed the original state."

example (n : Nat) : n + 0 = n := by
  test_declaration_repair
  rfl

elab "test_step" : tactic => do
  let count ← IO.mkRef (0 : Nat)
  let generator : Generator := fun _ _ _ _ => do
    count.modify (· + 1)
    return "```lean\nconstructor\n```"
  let result ← generateChecked {} .step "" "constr" generator
  unless (← count.get) == 1 do throwError "Step should stop at the first useful candidate."
  match result.result with
  | .progress _ => pure ()
  | _ => throwError "Expected partial progress."

example : True ∧ True := by
  test_step
  exact ⟨True.intro, True.intro⟩

elab "test_budget" : tactic => do
  let count ← IO.mkRef (0 : Nat)
  let generator : Generator := fun _ _ _ _ => do
    count.modify (· + 1)
    return "not valid Lean"
  let failed ← try
    let _ ← generateChecked { attempts := 2 } .proof "" "" generator
    pure false
  catch _ => pure true
  unless failed && (← count.get) == 2 do throwError "Attempt budget was not enforced."

example : True := by
  test_budget
  trivial

elab "test_bounded_repairs" : tactic => do
  let count ← IO.mkRef (0 : Nat)
  let generator : Generator := fun _ _ input _ => do
    let n ← count.get
    count.set (n + 1)
    if n == 0 then return "exact staleAttemptOne"
    if n == 1 then return "exact staleAttemptTwo"
    if (input.splitOn "staleAttemptOne").length > 1 then
      throw <| IO.userError "Old failures accumulated in repair history."
    unless (input.splitOn "staleAttemptTwo").length > 1 do
      throw <| IO.userError "Latest failure missing from repair history."
    return "trivial"
  let result ← generateChecked { attempts := 3, repairChars := 500 } .proof "" "" generator
  unless result.result == .complete && (← count.get) == 3 do
    throwError "Expected completion with bounded repair history."

example : True := by
  test_bounded_repairs
  trivial

elab "test_no_goals" : tactic => do
  let count ← IO.mkRef (0 : Nat)
  let generator : Generator := fun _ _ _ _ => do
    count.modify (· + 1)
    return "trivial"
  let failed ← try
    let _ ← generateChecked {} .step "" "" generator
    pure false
  catch _ => pure true
  unless failed && (← count.get) == 0 do throwError "A solved proof must not call the model."

example : True := by
  trivial
  test_no_goals
