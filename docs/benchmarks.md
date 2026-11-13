# Benchmarks

## Context selection

**LLMLean uses structured context by default** to keep useful declarations, including imports,
while trimming long proof histories. The other policies below serve as comparison baselines.
In this initial experiment, **structured context solved all nine cases with roughly the same
input size as a fixed history window**.

| Policy | Solved | Mean input characters | Median time |
| --- | ---: | ---: | ---: |
| Full prefix | 5/9 | 14,393 | 7.83 s |
| Window | 4/9 | 4,870 | 6.03 s |
| All files (project imports) | 7/9 | 18,096 | 7.44 s |
| **Structured (LLMLean default)** | **9/9** | **4,810** | **7.57 s** |

OpenAI `gpt-6-luna`, one attempt per case. Character counts include instructions.
Times cover context construction, generation, and proof checking.

In the long-file case, structured context reduced the input from **69,474 to 2,674 characters**
and solved the goal. These are nine context variants of one goal, so the results are preliminary;
they do not establish a general success rate or speedup.

<details>
<summary>Reproduce</summary>

Run from the repository root, with your provider configured:

```sh
# Prompt sizes and extraction times, without model requests.
python3 scripts/benchmark_context.py --output context-offline.jsonl

# Four policies × nine cases; one model attempt for each.
python3 scripts/benchmark_context.py --prove --attempts 1 --output context-results.jsonl
```

See the [benchmark code](../scripts/benchmark_context.py) for the exact experimental setup.

</details>
