# Migrating to the Responses version

This is a breaking modernization targeting Lean and Mathlib 4.35.0. Update both the parent
project's toolchain and its Mathlib dependency before updating LLMLean. The public tactics
remain `llmstep`, `llmstep "prefix"`, and `llmqed`.

Replace the old configuration with a minimal configuration, or remove it to use local defaults:

```toml
model = "qwen3.5:9b-q4_K_M"
```

For cloud inference:

```toml
provider = "openrouter" # or "openai"
model = "<provider-model-id>"
```

Set the corresponding `OPENROUTER_API_KEY` or `OPENAI_API_KEY` in the editor's environment.

| Removed setting | Replacement |
| --- | --- |
| `api` / `llmlean.api` / `LLMLEAN_API` | `provider` / `llmlean.provider` / `LLMLEAN_PROVIDER` |
| `endpoint` / `LLMLEAN_ENDPOINT` | `base_url` / `LLMLEAN_BASE_URL`; exclude `/responses` |
| `apiKey` / `llmlean.apiKey` | Provider environment variable |
| `prompt`, `responseFormat` | No configuration needed; shared task instructions and extraction |
| `mode`, `numSamples`, `maxIterations` | `attempts` bounds the shared generation/check/repair loop |
| `maxTokens` / `LLMLEAN_MAX_TOKENS` | `max_output_tokens` / `LLMLEAN_MAX_OUTPUT_TOKENS` |

Remove old environment variables too; the loader reports them rather than silently ignoring
them. Numeric and boolean TOML values must be unquoted. There is no migration of specialized
model prompts: historical prover integrations, raw completions, native Ollama generation, and
direct Anthropic/Together clients have been removed. Use general-purpose models served through
Responses. Models available through OpenRouter use the same connection implementation.

The old `LLMlean.Config.API`, provider-specific generation functions, and custom widget API
have also been removed. Programmatic users can use `Config.Settings`, `Responses.generate`,
and `generateChecked`; these internal interfaces may continue to change during modernization.

`llmqed` only suggests candidates that close all goals. `llmstep` can suggest partial progress
and reports the remaining goals. Suggestions now use Lean's native TryThis/code-action support.

Run `lake exe llmlean doctor --offline` in the LLMLean checkout to validate configuration, then
`lake exe llmlean doctor` to check connectivity and model availability. Live model benchmarking
and the explicit asynchronous Generate/Cancel UI are subsequent milestones.
