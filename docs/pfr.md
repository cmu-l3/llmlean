## Demo in [PFR](https://github.com/teorth/pfr)

To use LLMLean in the Polynomial Freiman Ruzsa conjecture formalization, we provide a version with a matching `lean-toolchain` and `mathlib` version.

First clone [PFR](https://github.com/teorth/pfr) and checkout commit `6a5082ee465f9e44cea479c7b741b3163162bb7e` of PFR.

Then add the following to the PFR `lakefile.lean`:
```
require llmlean from git
  "https://github.com/cmu-l3/llmlean.git" @ "v4.8.0-rc1"
```
Run `lake update llmlean`, then `lake exe cache get` and `lake build`. You can then `import LLMlean` in a PFR file. 

Here is an example of proving a lemma with `llmqed` (OpenAI GPT-4o):

<img src="img/llmqed_pfr.png" style="width:500px">

And using `llmqed` to make part of an existing proof simpler:

<img src="img/llmqed_pfr2.png" style="width:500px">
