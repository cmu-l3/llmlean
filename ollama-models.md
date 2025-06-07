
# Ollama Models

This document provides a list of models for proving that are available on [Ollama](https://ollama.com/).

## [miniCTX](https://www.arxiv.org/abs/2408.03350)

This is the prover referenced in the main [README](README.md). Again, to use it, you can pull it with the following command:

```bash
ollama pull wellecks/ntpctx-llama3-8b
```

and set 2 configuration variables in `~/.config/llmlean/config.toml`:

```toml
api = "ollama"
model = "wellecks/ntpctx-llama3-8b"
```

## Kimina Models

There are [a few models available from Kimina](https://huggingface.co/collections/AI-MO/kimina-prover-preview-67fb536b883d60e7ca25d7f9), the collaboration between the Project Numina and Kimi teams.

**Note**: Since these models were trained to output Lean snippets in Markdown format, you will need to set the `prompt` configuration variable to `markdown` in your `~/.config/llmlean/config.toml` file.

### `BoltonBailey/Kimina-Prover-Preview-Distill-1.5B`

To download the model

```bash
ollama pull BoltonBailey/Kimina-Prover-Preview-Distill-1.5B
```

To use it, set 3 configuration variables in `~/.config/llmlean/config.toml`:

```toml
api = "ollama"
model = "BoltonBailey/Kimina-Prover-Preview-Distill-1.5B"
prompt = "markdown"
```

### `BoltonBailey/Kimina-Prover-Preview-Distill-7B`

To download the model

```bash
ollama pull BoltonBailey/Kimina-Prover-Preview-Distill-7B
```
To use it, set 3 configuration variables in `~/.config/llmlean/config.toml`:

```toml
api = "ollama"
model = "BoltonBailey/Kimina-Prover-Preview-Distill-7B"
prompt = "markdown"
```
