# LLMLean

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

#### LLM in the cloud:

1. Get a [together.ai](https://www.together.ai/) API key.

2. Set 2 environment variables in VS Code. Example:

<img src="img/env_example1.png" style="width:500px">

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

- <img src="img/llmqed_example2.png" style="width:600px">


Checked suggestions coming soon!

---------------

## Customization

Please see the following:
1. [Customization](docs/customization.md)
