#!/usr/bin/env python3
"""Compare context policies on controlled Lean fixtures.

Default: offline prompt size, premise visibility, and construction latency.
--prove: also send model requests using the ordinary LLMLean configuration.
Each run checks suggestions in the original environment; reference solutions
are after the invocation and are never included in the prompt.
"""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MARKER = "LLMLEAN_CONTEXT_BENCH "

HELPER = """
namespace ContextExample.ListTools
theorem length_append_one {α : Type} (xs : List α) (x : α) :
    (xs ++ [x]).length = xs.length + 1 := by simp
end ContextExample.ListTools
"""
EARLIER = """
namespace ContextBench
def pushTwice {α : Type} (xs : List α) (x : α) : List α :=
  (xs ++ [x]) ++ [x]
theorem pushTwice_eq {α : Type} (xs : List α) (x : α) :
    pushTwice xs x = (xs ++ [x]) ++ [x] := by rfl
"""
TARGET = """
open ContextExample.ListTools
local notation "push₂" => pushTwice
example {α : Type} (xs : List α) (x : α) (n : Nat) (h : xs.length = n) :
    (push₂ xs x).length = n + 2 := by
  have hlen : xs.length + 2 = n + 2 := congrArg (fun k => k + 2) h
  context_benchmark {case_id} {repeat} {prove}
  simpa only [pushTwice_eq, length_append_one] using hlen
end ContextBench
"""


def source(case, repeat, prove, attempts):
    name, imports, declarations, proof_lines = case
    chunks = ["import Tests.ContextBench\n"]
    if imports:
        chunks.append(f"import {imports}\n")
    chunks.append(f"set_option maxHeartbeats 0\nset_option llmlean.attempts {attempts}\n")
    if not imports:
        chunks.append(HELPER)
    chunks.append(EARLIER)
    for i in range(declarations):
        chunks.append(f"theorem distractor_{i} (n : Nat) : n = n := by\n")
        for j in range(proof_lines):
            chunks.append(f"  have h{j} : True := True.intro\n")
        chunks.append("  rfl\n")
    # format_map would interpret Lean implicit binders as substitutions.
    target = TARGET.replace("{case_id}", json.dumps(name))
    target = target.replace("{repeat}", str(repeat)).replace("{prove}", str(prove).lower())
    chunks.append(target)
    return "".join(chunks)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prove", action="store_true", help="Opt into model requests; may incur charges")
    parser.add_argument("--repeats", type=int, default=1)
    parser.add_argument("--attempts", type=int, default=1, help="Attempts per model run (default: solve@1)")
    parser.add_argument("--case", action="append", help="Run only these case names; may be repeated")
    parser.add_argument("--output", type=Path, help="Also save JSONL results to this file")
    args = parser.parse_args()
    if args.repeats < 1 or args.attempts < 1:
        parser.error("--repeats and --attempts must be positive")
    cases = [
        ("imports_same_file", None, 0, 0),
        ("imports_direct", "Tests.ContextSupport", 0, 0),
        ("imports_transitive", "Tests.ContextBridge", 0, 0),
        ("proofs_short", "Tests.ContextSupport", 8, 0),
        ("proofs_medium", "Tests.ContextSupport", 8, 32),
        ("proofs_long", "Tests.ContextSupport", 8, 256),
        ("declarations_small", "Tests.ContextSupport", 10, 0),
        ("declarations_medium", "Tests.ContextSupport", 100, 0),
        ("declarations_large", "Tests.ContextSupport", 500, 0),
    ]
    if args.case:
        unknown = set(args.case) - {case[0] for case in cases}
        if unknown:
            parser.error(f"Unknown cases: {', '.join(sorted(unknown))}")
        cases = [case for case in cases if case[0] in args.case]
    subprocess.run(["lake", "build", "Tests.ContextBench", "Tests.ContextBridge"], cwd=ROOT, check=True)
    rows = []
    # Stay inside this Lake project so imported-module ownership is measured accurately.
    with tempfile.TemporaryDirectory(prefix=".context-bench-", dir=ROOT) as tmp:
        for repeat in range(args.repeats):
            for case in cases:
                file = Path(tmp) / f"{case[0]}.lean"
                text = source(case, repeat, args.prove, args.attempts)
                file.write_text(text)
                result = subprocess.run(["lake", "env", "lean", str(file)], cwd=ROOT,
                                        capture_output=True, text=True)
                if result.returncode:
                    raise SystemExit(result.stdout + result.stderr)
                found = []
                for line in result.stdout.splitlines():
                    if line.startswith(MARKER):
                        row = json.loads(line[len(MARKER):])
                        row["source_chars"] = len(text)
                        found.append(row)
                        print(json.dumps(row), flush=True)
                if len(found) != 4:
                    raise SystemExit(f"Expected four policies for {case[0]}: {result.stdout}")
                rows.extend(found)
                if args.output:
                    # Preserve completed cases if a later invocation is interrupted.
                    args.output.write_text("".join(json.dumps(row) + "\n" for row in rows))


if __name__ == "__main__":
    main()
