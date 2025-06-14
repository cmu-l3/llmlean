### Configurations

The following configurations let you customize LLMLean. Each variable can be set in the configuration file `~/.config/llmlean/config.toml` (or `C:\Users\<Username>\AppData\Roaming\llmlean\config.toml` on Windows).

#### LLM in the cloud
Example:

- `api`:
  - `together` : to use Together.ai API
  - `openai` : to use OpenAI API
  - `anthropic` : to use Anthropic API
- `apiKey`:
  - E.g. [API key](https://api.together.xyz/settings/api-keys) for Together API, or OpenAI / Anthropic API key
- `endpoint`: API endpoint
  - E.g. `https://api.together.xyz/v1/completions` for Together API
- `prompt`:
  - `fewshot`: for base models
  - `instruction`: for instruction-tuned models
- `model`:
  - Example for Together API: `mistralai/Mixtral-8x7B-Instruct-v0.1`
  - Example for Open AI: `gpt-4o`
  - Example for Anthropic: `claude-3-7-sonnet-20250219`
- `numSamples`:
  - Example: `10`
- `mode`:
  - `parallel`: Generate multiple proof attempts in parallel
  - `iterative`: Generate and refine proofs based on error feedback
- `maxIterations`:
  - Number of refinement iterations in iterative mode (e.g., `3`)
- `verbose`:
  - `true`: Show detailed LLM interaction and refinement steps

Set each variable in the configuration file, as indicated in [README](../README.md). Alternatively, set environment variables `LLMLEAN_API`, `LLMLEAN_API_KEY`, `LLMLEAN_ENDPOINT`, `LLMLEAN_PROMPT`, `LLMLEAN_MODEL`, `LLMLEAN_NUM_SAMPLES`, `LLMLEAN_MODE`, `LLMLEAN_MAX_ITERATIONS`, and `LLMLEAN_VERBOSE` respectively, or enter `set_option llmlean.<relevant-config> <value>` before `llmstep`/`llmqed` is called.

**Note on Iterative Refinement**: This mode works particularly well with models that can understand and learn from error messages. We recommend using instruction-tuned models with the `reasoning` prompt type for best results.

#### LLM on your laptop
- `api`:
  - `ollama` : to use ollama (default)
- `endpoint`:
  - With ollama it is `http://localhost:11434/api/generate`
- `prompt`:
  - `fewshot`: for base models
  - `instruction`: for instruction-tuned models
- `model`:
  - Example: `solobsd/llemma-7b`
- `numSamples`:
  - Example: `10`
