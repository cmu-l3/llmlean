# LLMLean
You can use an LLM running on your laptop, or an LLM from the OpenAI API or Together.ai API.
#### LLM on your laptop:
1. Install [ollama](https://ollama.com/).

2. Pull a language model:
```bash
ollama pull solobsd/llemma-7b
```

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

#### LLM in the cloud (OpenAI):

1. Get an [OpenAI API](https://openai.com/index/openai-api/) key.

2. Set 2 environment variables:

```bash
export LLMLEAN_API=openai
export LLMLEAN_API_KEY=your-openai-api-key
```

Then do steps (3) and (4) above. Now use a tactic described below.

#### LLM in the cloud (together.ai):

1. Get a [together.ai](https://www.together.ai/) API key.

2. Set 2 environment variables:

```bash
export LLMLEAN_API=together
export LLMLEAN_API_KEY=your-together-api-key
```

Then do steps (3) and (4) above. Now use a tactic described below.

----
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

---------------

## Customization

Please see the following:
1. [Customization](docs/customization.md)
