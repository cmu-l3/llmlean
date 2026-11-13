# LLMLean demo

Try `llmstep` and `llmqed` interactively in [VS Code](https://code.visualstudio.com/).
This demo uses LLMLean from the parent directory.

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

The default is OpenAI with `gpt-6-luna`, set in [llmlean.openai.toml](llmlean.openai.toml).
Running `bash open-vscode.sh` without an argument also selects OpenAI.
If you change your key, close the demo's VS Code instance and relaunch it.

## Local model

Install and start [Ollama](https://ollama.com/), then run:

```sh
ollama pull qwen3.5:9b-q4_K_M
bash open-vscode.sh local
```

Local settings are in [llmlean.local.toml](llmlean.local.toml).

## Using the demo

For examples with project context, open [Context.lean](Context.lean). It develops a
warehouse dispatch system using the path and invariant lemmas in
[Context/Reachability.lean](Context/Reachability.lean). Replace a `sorry` with
`llmqed`, or insert `llmcontext` to inspect the supplied context.

Try one example at a time. The proof stays unfinished until you accept a suggestion;
`llmstep` may leave more goals to solve. Editing an active LLM tactic can send another request.

[Solutions.lean](Solutions.lean) has worked proofs. To check your setup, run this
in the demo window's terminal:

```sh
lake exe llmlean doctor
```
