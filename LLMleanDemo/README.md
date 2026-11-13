# LLMLean demo

Try `llmstep` and `llmqed` in VS Code. This demo uses LLMLean from the parent directory.

## OpenAI

1. Get an [OpenAI API key](https://platform.openai.com/api-keys).
2. Download the repository and open the demo:

   ```sh
   git clone https://github.com/cmu-l3/llmlean.git
   cd llmlean/LLMleanDemo
   lake build
   bash open-vscode.sh openai
   ```

   If you already have the repository, run the last two commands from its `LLMleanDemo` directory.

3. Enter your key when prompted, or set `OPENAI_API_KEY` in your shell first.
4. In [Demo.lean](Demo.lean), replace a `sorry` with `llmstep` or `llmqed`.
   Click **Try this** in the Infoview to accept the suggestion.

The model is set in [llmlean.openai.toml](llmlean.openai.toml).
If you change your key, close the demo's VS Code instance and relaunch it.

## Local model

Install and start [Ollama](https://ollama.com/), then run:

```sh
ollama pull qwen3.5:9b-q4_K_M
bash open-vscode.sh local
```

Local settings are in [llmlean.toml](llmlean.toml).

## Using the demo

Try one example at a time. The proof stays unfinished until you accept a suggestion;
`llmstep` may leave more goals to solve. Editing an active LLM tactic can send another request.

[Solutions.lean](Solutions.lean) has worked proofs. To check your setup, run this
in the demo window's terminal:

```sh
lake exe llmlean doctor
```
