# Other LLM Providers

LLMLean supports various cloud LLM providers beyond OpenAI. This document covers how to configure them.

## Anthropic

To use Anthropic's Claude models:

1. Get an [Anthropic API](https://www.anthropic.com/api) key.

2. Set configuration variables in `~/.config/llmlean/config.toml`:

```toml
api = "anthropic"
model = "claude-3-5-sonnet-20241022"
apiKey = "<your-anthropic-api-key>"
```

## Together.AI

To use Together.AI:

1. Get a [Together.AI](https://www.together.ai/) API key.

2. Set configuration variables in `~/.config/llmlean/config.toml`:

```toml
api = "together"
model = "Qwen/Qwen2.5-72B-Instruct-Turbo"
apiKey = "<your-together-api-key>"
```

## OpenAI-Compatible Providers

Many providers offer OpenAI-compatible APIs. For these providers:

1. Get an API key from your provider.

2. Set configuration variables in `~/.config/llmlean/config.toml`:

```toml
api = "openai"
endpoint = "<provider-endpoint-url>"
model = "<model-name>"
apiKey = "<your-api-key>"
```

## Environment Variables

For any provider, you can also set configuration using environment variables:

```bash
export LLMLEAN_API=<api-type>
export LLMLEAN_ENDPOINT=<endpoint-url>
export LLMLEAN_MODEL=<model-name>
export LLMLEAN_API_KEY=<your-api-key>
```

## Lean Options

You can also set configuration directly in your Lean files:

```lean
set_option llmlean.api "openai"
set_option llmlean.model "gpt-4o"
set_option llmlean.apiKey "<your-api-key>"
```

Note: Be careful not to commit API keys to version control when using this method.