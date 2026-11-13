# Configuration

LLMLean reads and validates its optional TOML file once per invocation. Unknown keys and wrong
types are errors. Numbers and booleans are ordinary TOML values, not quoted strings.

| TOML key | Default | Environment variable | Lean option |
| --- | --- | --- | --- |
| `provider` | `"openai"` | `LLMLEAN_PROVIDER` | `llmlean.provider` |
| `model` | `"gpt-6-luna"` for OpenAI; `"qwen3.5:9b-q4_K_M"` for local; required for OpenRouter | `LLMLEAN_MODEL` | `llmlean.model` |
| `base_url` | Provider preset | `LLMLEAN_BASE_URL` | `llmlean.baseUrl` |
| `attempts` | `3` | `LLMLEAN_ATTEMPTS` | `llmlean.attempts` |
| `timeout_seconds` | `90` | `LLMLEAN_TIMEOUT_SECONDS` | `llmlean.timeoutSeconds` |
| `max_output_tokens` | `4096` | `LLMLEAN_MAX_OUTPUT_TOKENS` | `llmlean.maxOutputTokens` |
| `reasoning_effort` | `"default"` | `LLMLEAN_REASONING_EFFORT` | `llmlean.reasoningEffort` |
| `verbose` | `false` | `LLMLEAN_VERBOSE` | `llmlean.verbose` |
| `context_mode` | `"structured"` | `LLMLEAN_CONTEXT_MODE` | `llmlean.contextMode` |
| `history_chars` | `6000` | `LLMLEAN_HISTORY_CHARS` | `llmlean.historyChars` |
| `premise_chars` | `16000` | `LLMLEAN_PREMISE_CHARS` | `llmlean.premiseChars` |
| `notation_chars` | `4000` | `LLMLEAN_NOTATION_CHARS` | `llmlean.notationChars` |
| `repair_chars` | `6000` | `LLMLEAN_REPAIR_CHARS` | `llmlean.repairChars` |
| `definition_chars` | `1200` | `LLMLEAN_DEFINITION_CHARS` | `llmlean.definitionChars` |

Precedence: explicitly set Lean options > environment > file > defaults. An explicit `false`
or a value equal to the default still overrides a lower-priority setting.

```lean
set_option llmlean.attempts 2 in
example : True ∧ True := by
  llmqed
```

`attempts` bounds the total number of model calls, including repairs. `timeout_seconds` bounds
context construction and the generation loop; individual requests receive the remaining budget. Candidate evaluation
also has a 200,000-heartbeat limit. Heartbeats are cooperative, so they are not a hard wall-clock
timeout for arbitrary metaprograms. `max_output_tokens` includes reasoning tokens. Truncated
responses produce an error instead of presenting an incomplete fragment as a suggestion.

`reasoning_effort = "none"` requests thinking off, for example with Qwen3.5 in LM Studio.
`"default"` omits the API setting and lets the server choose. Explicit values are sent as
`reasoning.effort`; accepted values are `none`, `minimal`, `low`, `medium`, `high`, and `xhigh`,
but support depends on the server and model. A server may reject an unsupported value.
This controls individual LLMLean requests without changing the model's settings in its UI.

Configuration paths:

1. `LLMLEAN_CONFIG`, if set (an absent explicit file is an error).
2. `llmlean.toml` in the current working directory, if present. Open the project
   folder in VS Code or run Lake from that directory to use it.
3. `%APPDATA%/llmlean/config.toml` on Windows.
4. `$XDG_CONFIG_HOME/llmlean/config.toml`, when set.
5. `~/.config/llmlean/config.toml`.

The first matching file is used; project and global files are not merged.

An absent default config file is valid and selects OpenAI with `gpt-6-luna`.
Set `OPENAI_API_KEY` to make model requests, or choose `provider = "local"` to use Ollama.
Keys are read only from the provider's environment variable; putting credentials in TOML or Lean source is unsupported.
The editor must inherit the environment variables (restart it after changing them).

For old configurations, see [migration](migration.md).

## Context selection

The default `structured` mode supplies:

- Qualified declaration names and elaborated types from earlier in the current file and
  accessible imports in the current Lake project, including transitive imports.
- Short definition bodies when Lean exposes them, and constructor signatures for inductive types
  and structures. Theorem proofs are omitted.
- A glossary of active custom notation used in the rendered expressions and retained source.
  Ordinary mathematical notation is preserved. Expired notation is not collected.
- The current declaration's source header, labeled as an unfinished target, and a bounded
  suffix of the proof before the invocation. The target's qualified name is supplied separately.
- Current goals and local hypotheses, with qualified constant names and their actual local names.

The declaration budget is filled deterministically: constants occurring in the proof state,
statements sharing symbols with it, and then current-file recency. This is a simple baseline,
not a learned premise selector. Imports are identified through Lean's module index and resolved
build paths under the nearest Lake project; dependency packages under `.lake/packages` and
LLMLean's implementation modules are excluded. External/custom build directories may require
future explicit project configuration. Nothing after the hole in the current file is sent, and the target is not
included among available premises.

Budgets count **Unicode characters, not tokens**. `premise_chars` and `notation_chars` bound
those entire sections; `definition_chars` bounds each optional definition body. Oversized bodies
are omitted, and oversized declaration summaries are skipped rather than cut mid-statement.
The source history prefers complete trailing lines. Zero disables the corresponding optional
component. The full target header and current proof state are protected, so these settings are
not a hard limit on the entire request. `repair_chars` bounds the most recent unsuccessful
attempt and its feedback; previous failures are not accumulated.

If a notation explanation does not fit, rendered goals/declarations fall back to expanded
notation. Source excerpts retain their original spelling; omitted source explanations are
reported in the glossary heading. Unusual macro-generated declarations may lack a recoverable
source header; the prompt marks this and falls back to a bounded preceding-source window.
Current section parameters remain visible through the proof state. Local simp attributes,
instances, and custom tactic implementations are not exhaustively summarized; checking still
uses the actual Lean environment.

Three comparison modes are available: `window` sends a bounded source prefix; `full` sends
the full prefix; and `all_files` adds the complete source of every transitively imported project
module to the full prefix, including theorem proofs. `all_files` uses the same project membership
rules as `structured`, excludes dependency packages and LLMLean implementation modules, and
fails if an imported source cannot be found. All three retain the target header and current goals,
but omit premise summaries and the notation glossary. Only `window` bounds the raw source.
See [Benchmarks](benchmarks.md#context-selection) for a comparison.

```lean
set_option llmlean.historyChars 2000
set_option llmlean.premiseChars 8000

example (n : Nat) : n + 0 = n := by
  llmcontext -- Preview the actual prompt and construction time; no model request.
  rfl
```

`llmcontext` leaves the proof state unchanged. `llmlean.verbose` reports context size,
declaration coverage, and construction time during normal suggestions. See
[the worked example](../Tests/ContextExample.lean) and run `python3 scripts/benchmark_context.py`
for offline context measurements. Add `--prove` explicitly to run model-backed comparisons
using your configured provider; that can incur API charges.
