# `LLMLean` 
1. Install [ollama](https://ollama.com/).

2. Pull the language model:
```bash
ollama pull solobsd/llemma-7b
```

4. Add `llmlean` to lakefile:
```lean
require llmlean from git
  "git@github.com:wellecks/llm-lean.git"
```

3. Import:
```lean
import LLMlean
```


---
### `llmstep` tactic
Next-tactic suggestions via `llmstep "{prefix}"`, where `{prefix}` is arbitrary. Examples:

- `llmstep ""`

  <img src="img/llmstep_empty.png" style="width:500px">

- `llmstep "apply "`

  <img src="img/llmstep_apply.png" style="width:500px">

