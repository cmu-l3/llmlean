### Environment variables

The following environment variables let you customize LLMLean.

#### LLM in the cloud
Example:

- `LLMLEAN_API`:
  - `together` : to use Together.ai API
  - `openai` : to use OpenAI API
- `LLMLEAN_API_KEY`:
  - E.g. [API key](https://api.together.xyz/settings/api-keys) for Together API, or OpenAI API key
- `LLMLEAN_ENDPOINT`: API endpoint
  - E.g. `https://api.together.xyz/v1/completions` for Together API
- `LLMLEAN_PROMPT`:
  - `fewshot` :  for base models
  - `instruction` : for instruction-tuned models
- `LLMLEAN_MODEL`:
  - Example for Together API: `mistralai/Mixtral-8x7B-Instruct-v0.1`
  - Example for Open AI: `gpt-4o`
- `LLMLEAN_NUMSAMPLES`:
  - Example: `10`


#### LLM on your laptop
- `LLMLEAN_API`:
  - `ollama` : to use ollama (default)
- `LLMLEAN_ENDPOINT`:
  - With ollama it is `http://localhost:11434/api/generate`
- `LLMLEAN_PROMPT`:
  - `fewshot` :  for base models
  - `instruction` : for instruction-tuned models
- `LLMLEAN_MODEL`:
  - Example: `solobsd/llemma-7b`
- `LLMLEAN_NUMSAMPLES`:
  - Example: `10`



