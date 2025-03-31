# LLMLean

LLMlean integrates LLMs and Lean for tactic suggestions, proof completion, and more.

Here's an example of using LLMLean on problems from [Mathematics in Lean](https://github.com/leanprover-community/mathematics_in_lean):

https://github.com/user-attachments/assets/284a8b32-b7a5-4606-8240-effe086f2b82

You can use an LLM running on your laptop, or an LLM from the Open AI API or Together.ai API:

<img src="img/llmlean.png" style="width:600px">

#### LLM in the cloud (default):

1. Get an [OpenAI API](https://openai.com/index/openai-api/) key.

2. Modify `~/.config/llmlean/config.toml` (or `C:\Users\<Username>\AppData\Roaming\llmlean\config.toml` on Windows), and enter the following:

```toml
api = "openai"
model = "gpt-4o"
apiKey = "<your-api-key>"
```

(Alternatively, you may set the API key using the environment variable `LLMLEAN_API_KEY` or using `set_option llmlean.apiKey "<your-api-key>"`.)
Similarly, to set up an Anthropic LLM, use

```toml
api = "anthropic"
model = "claude-3-7-sonnet-20250219"
apiKey = "<your-anthropic-api-key>"
```

1. Add `llmlean` to lakefile:
```lean
require llmlean from git
  "https://github.com/cmu-l3/llmlean.git"
```

1. Import:
```lean
import LLMlean
```

Now use a tactic described below.
#### Option 2: LLM on your laptop:
1. Install [ollama](https://ollama.com/).

2. Pull a language model:
```bash
ollama pull wellecks/ntpctx-llama3-8b
```

3. Set 2 configuration variables in `~/.config/llmlean/config.toml`:

```toml
api = "ollama"
model = "wellecks/ntpctx-llama3-8b" # model name from above
```

Then do steps (3) and (4) above. Now use a tactic described below.



#### Option 3: LLM in the cloud (together.ai):

1. Get a [together.ai](https://www.together.ai/) API key.

2. Set 2 configuration variables in `~/.config/llmlean/config.toml`:

```toml
api = "together"
apiKey = "<your-together-api-key>"
```

Then do steps (3) and (4) above. Now use a tactic described below.


## Tactics
### `llmstep` tactic
Next-tactic suggestions via `llmstep "{prefix}"`. Examples:

- `llmstep ""`

  <img src="img/llmstep_empty.png" style="width:500px">

- `llmstep "apply "`

  <img src="img/llmstep_apply.png" style="width:500px">

The suggestions are checked in Lean.

### `llmqed` tactic
Complete the current proof via `llmqed`. Examples:

- <img src="img/llmqed_example.png" style="width:500px">


The suggestions are checked in Lean.

*For the best performance, especially for the `llmqed` tactic, we recommend using the Open AI API.*



## Demo in [PFR](https://github.com/teorth/pfr)

Here is an example of proving a lemma with `llmqed` (OpenAI GPT-4o):

<img src="./img/llmqed_pfr.png" style="width:800px">

And using `llmqed` to make part of an existing proof simpler:

<img src="./img/llmqed_pfr2.png" style="width:800px">



## Customization

Please see the following:
- [Customization](docs/customization.md)


## Testing
Rebuild LLMLean with the config `test=on`:
```sh
lake -R -Ktest=on update
lake build
```
Then manually check `llmlean` on the files under `LLMleanTest`.
