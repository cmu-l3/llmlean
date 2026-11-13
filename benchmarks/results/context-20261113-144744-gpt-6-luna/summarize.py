"""Combine the two benchmark batches and write reviewable result tables."""
import csv
import json
from pathlib import Path
from statistics import mean, median

root = Path(__file__).resolve().parent
rows = [json.loads(line) for name in ('pilot.jsonl', 'remaining.jsonl')
        for line in (root / name).read_text().splitlines() if line.strip()]
manifest = json.loads((root / 'manifest.json').read_text())
expected = {(case, mode) for case in manifest['cases'] for mode in manifest['mode_order']}
assert len(rows) == len(expected) == 27
assert {(r['case'], r['mode']) for r in rows} == expected
assert all(r['requests'] == 1 and r['attempt_limit'] == 1 for r in rows)
assert all(r['model'] == manifest['model'] for r in rows)
(root / 'results.jsonl').write_text(''.join(json.dumps(row) + '\n' for row in rows))
with (root / 'results.csv').open('w', newline='') as file:
    writer = csv.DictWriter(file, fieldnames=list(rows[0]))
    writer.writeheader()
    writer.writerows(rows)
summary = {}
for mode in manifest['mode_order']:
    group = [r for r in rows if r['mode'] == mode]
    summary[mode] = {
        'solved': sum(r['solved'] is True for r in group),
        'cases': len(group),
        'median_total_seconds': median(r['total_ms'] for r in group) / 1000,
        'mean_total_seconds': mean(r['total_ms'] for r in group) / 1000,
        'median_request_seconds': median(r['request_ms'] for r in group) / 1000,
        'mean_input_chars': mean(r['input_chars'] for r in group),
        'median_context_ms': median(r['context_ms'] for r in group),
        'helper_visible': sum(r['helper_visible'] for r in group),
    }
(root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary, indent=2))
for case in ('proofs_long', 'declarations_large'):
    print(case)
    for row in rows:
        if row['case'] == case:
            print(row['mode'], 'solved=' + str(row['solved']),
                  'seconds=' + str(row['total_ms'] / 1000),
                  'chars=' + str(row['input_chars']),
                  'context_ms=' + str(row['context_ms']))
for row in rows:
    if not row['solved']:
        print('FAILURE', row['case'], row['mode'], row['error'])
