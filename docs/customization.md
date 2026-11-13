# Configuration

LLMLean reads and validates its optional TOML file once per invocation. Unknown keys and wrong
types are errors. Numbers and booleans are ordinary TOML values, not quoted strings.

| TOML key | Default | Environment variable | Lean option |
| --- | --- | --- | --- |
| `provider` | `"local"` | `LLMLEAN_PROVIDER` | `llmlean.provider` |
| `model` | `"qwen3.5:9b-q4_K_M"` for local; required for cloud | `LLMLEAN_MODEL` | `llmlean.model` |
| `base_url` | Provider preset | `LLMLEAN_BASE_URL` | `llmlean.baseUrl` |
| `attempts` | `3` | `LLMLEAN_ATTEMPTS` | `llmlean.attempts` |
| `timeout_seconds` | `90` | `LLMLEAN_TIMEOUT_SECONDS` | `llmlean.timeoutSeconds` |
| `max_output_tokens` | `4096` | `LLMLEAN_MAX_OUTPUT_TOKENS` | `llmlean.maxOutputTokens` |
| `reasoning_effort` | `"default"` | `LLMLEAN_REASONING_EFFORT` | `llmlean.reasoningEffort` |
| `verbose` | `false` | `LLMLEAN_VERBOSE` | `llmlean.verbose` |

Precedence: explicitly set Lean options > environment > file > defaults. An explicit `false`
or a value equal to the default still overrides a lower-priority setting.

```lean
set_option llmlean.attempts 2 in
example : True ∧ True := by
  llmqed
```

`attempts` bounds the total number of model calls, including repairs. `timeout_seconds` bounds
the generation loop; individual requests receive the remaining budget. Candidate evaluation
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

An absent default config file is valid and uses local defaults. Keys are read only from the
provider's environment variable; putting credentials in TOML or Lean source is unsupported.
The editor must inherit the environment variables (restart it after changing them).

For old configurations, see [migration](migration.md).
