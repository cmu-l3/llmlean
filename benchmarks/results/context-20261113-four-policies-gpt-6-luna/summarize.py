"""Validate the saved run and regenerate its CSV and aggregate results."""
import csv
from datetime import datetime
import json
from pathlib import Path
from statistics import mean, median

root = Path(__file__).resolve().parent
rows = [json.loads(line) for line in (root / "results.jsonl").read_text().splitlines()]
manifest = json.loads((root / "manifest.json").read_text())
expected = {(case, mode, repeat) for case in manifest["cases"]
            for mode in manifest["mode_order"] for repeat in range(manifest["repeats"])}
assert len(rows) == len(expected)
assert {(r["case"], r["mode"], r["repeat"]) for r in rows} == expected
assert all(r["requests"] == 1 and r["attempt_limit"] == 1 for r in rows)
assert all(r["model"] == manifest["model"] for r in rows)
assert all(r["total_input_chars"] == r["input_chars"] + r["instruction_chars"] for r in rows)

with (root / "results.csv").open("w", newline="") as file:
    writer = csv.DictWriter(file, fieldnames=list(rows[0]))
    writer.writeheader()
    writer.writerows(rows)

summary = {}
for mode in manifest["mode_order"]:
    group = [r for r in rows if r["mode"] == mode]
    summary[mode] = {
        "solved": sum(r["solved"] is True for r in group),
        "cases": len(group),
        "mean_total_input_chars": mean(r["total_input_chars"] for r in group),
        "sum_total_input_chars": sum(r["total_input_chars"] for r in group),
        "mean_input_chars": mean(r["input_chars"] for r in group),
        "median_total_seconds": median(r["total_ms"] for r in group) / 1000,
        "median_request_seconds": median(r["request_ms"] for r in group) / 1000,
        "median_context_ms": median(r["context_ms"] for r in group),
        "helper_visible": sum(r["helper_visible"] for r in group),
    }
(root / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
manifest.update(status="completed", requests=sum(r["requests"] for r in rows))
manifest.setdefault("completed_local", datetime.now().astimezone().isoformat())
(root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(summary, indent=2))
for row in rows:
    print(row["case"], row["mode"], "solved=" + str(row["solved"]),
          "chars=" + str(row["total_input_chars"]), "seconds=" + str(row["total_ms"] / 1000))
    if not row["solved"]:
        print(row["error"])
