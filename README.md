# LLMLean

LLMlean integrates LLMs and Lean for tactic suggestions, proof completion, and more.

Here's an example of using LLMLean on problems from [Mathematics in Lean](https://github.com/leanprover-community/mathematics_in_lean):

https://github.com/user-attachments/assets/284a8b32-b7a5-4606-8240-effe086f2b82

You can use an LLM running on your laptop, or an LLM from the Open AI API or Together.ai API:

<img src="img/llmlean.png" style="width:600px">

#### LLM in the cloud (default):

1. Get an [OpenAI API](https://openai.com/index/openai-api/) key.

2. Set 1 environment variable:

```bash
export LLMLEAN_API_KEY=your-openai-api-key
```

To do so, add the export statement to the `~/.zshrc` file (on Mac) or `~/.bashrc` (Linux), and restart VS Code.

3. Add `llmlean` to lakefile:
```lean
require llmlean from git
  "https://github.com/cmu-l3/llmlean.git"
```

4. Import:
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

3. Set 2 environment variables:
```bash
export LLMLEAN_API=openai
export LLMLEAN_MODEL=wellecks/ntpctx-llama3-8b # model name from above
```

Then do steps (3) and (4) above. Now use a tactic described below.



#### Option 3: LLM in the cloud (together.ai):

1. Get a [together.ai](https://www.together.ai/) API key.

2. Set 2 environment variables:

```bash
export LLMLEAN_API=together
export LLMLEAN_API_KEY=your-together-api-key
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
