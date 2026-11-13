# Providers

OpenAI with `gpt-6-luna` is the default. Set `OPENAI_API_KEY` in your editor's environment;
no configuration file is needed for this setup. Select `provider = "local"` to use a local server.

All connections use `POST <base_url>/responses` with stateless requests. LLMLean supplies the
original goals, source context, and repair feedback on each call. It does not depend on stored
conversations or `previous_response_id`. The HTTP implementation and proof checker are shared.

| Provider | Default base URL | Key environment variable |
| --- | --- | --- |
| `local` | `http://localhost:11434/v1` | None required; optional `LLMLEAN_API_KEY` |
| `openrouter` | `https://openrouter.ai/api/v1` | `OPENROUTER_API_KEY` |
| `openai` | `https://api.openai.com/v1` | `OPENAI_API_KEY` |

For OpenRouter or OpenAI:

```toml
provider = "openrouter"
model = "<model-id-listed-by-the-provider>"
```

An alternative local server must implement the Responses API; Chat Completions compatibility
alone is insufficient. Point at its API base URL, excluding `/responses`:

```toml
provider = "local"
base_url = "http://localhost:8000/v1"
model = "<server-model-id>"
```

For LM Studio, start its server and use the model identifier shown in its Developer tab:

```toml
provider = "local"
base_url = "http://localhost:1234/v1"
model = "qwen/qwen3.5-9b"
reasoning_effort = "none"
```

With this model, `reasoning_effort = "none"` turns thinking off for LLMLean requests.
Use `"default"` to let the server choose, or a supported effort such as `"high"` to enable it.
Other models and servers may support different efforts.

LLMLean requests text, then reads assistant `output_text` content from the response's `output`
items. Reasoning items are not treated as Lean code. It reports refusals, truncation, HTTP
failures, invalid JSON, and empty answers separately. Provider-specific sampling parameters
and legacy stop tags are not sent. No cloud service is contacted as a local fallback.

Protocol references: [OpenAI Responses](https://developers.openai.com/api/docs/guides/migrate-to-responses),
[Ollama](https://docs.ollama.com/api/openai-compatibility#responses-api),
[OpenRouter](https://openrouter.ai/docs/api_reference/responses/overview).
