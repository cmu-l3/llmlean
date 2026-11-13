# LLMLean

LLMLean integrates LLMs and Lean for tactic suggestions and proof completion.
You can use an LLM running on your laptop, or an LLM from OpenAI or OpenRouter.

## Installation

Requires Lean **4.35.0**.

1. Add LLMLean to your project's `lakefile.lean`:

   ```lean
   require llmlean from git
     "https://github.com/cmu-l3/llmlean.git"
   ```

2. Run `lake update llmlean` from your project directory.

3. Import LLMLean in your Lean file:

   ```lean
   import LLMlean
   ```

## Setup

### Option 1: OpenAI

1. Get an [OpenAI API key](https://platform.openai.com/api-keys) and set it in your terminal:

   ```sh
   export OPENAI_API_KEY="<your-api-key>"
   ```

2. Create `llmlean.toml` in your project directory:

   ```toml
   provider = "openai"
   model = "gpt-5.4-mini"
   ```

3. Quit VS Code, then open your project from the same terminal so it picks up the key:

   ```sh
   code .
   ```

Now use a tactic described below.

### Option 2: LLM on your laptop

1. Install and start [Ollama](https://ollama.com/).

2. Pull a model:

   ```sh
   ollama pull qwen3.5:9b-q4_K_M
   ```

3. Set `llmlean.toml` to:

   ```toml
   provider = "local"
   model = "qwen3.5:9b-q4_K_M"
   ```

No API key is needed. Local Ollama is also the default when no configuration is set.

## Tactics

### `llmstep`

Suggest the next tactic:

```lean
example (n : Nat) : n + 0 = n := by
  llmstep
```

You can give a prefix, e.g. `llmstep "apply "`.

### `llmqed`

Suggest a completion of the current proof:

```lean
example (P Q : Prop) (h : P ∧ Q) : Q ∧ P := by
  llmqed
```

The suggestions are checked in Lean. Click **Try this** in the Infoview to insert one.

## Demo

The [demo project](LLMleanDemo/README.md) has examples to try in VS Code, with worked solutions.

## Customization

See [customization](docs/customization.md), [other providers](docs/other_providers.md),
and [migration from older versions](docs/migration.md).

## Testing

From the LLMLean repository directory:

```sh
lake build llmlean
lake test
python3 scripts/test_transport.py
```

Mathlib examples are in [LLMleanTest](LLMleanTest).
