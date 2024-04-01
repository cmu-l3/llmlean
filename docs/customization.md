### Environment variables

The following environment variables let you customize LLMLean.

- `LLMLEAN_ENDPOINT`: API endpoint
- `LLMLEAN_PROMPT`:
  - "fewshot" :  for base models
  - "instruction" : for instruction-tuned models
- `LLMLEAN_API`:
  - "ollama" : to use ollama
  - "together" : to use a Together API endpoint (or your own server)

#### Setting environment variables
To set environment variables in VS Code, go to:

- Settings (`Command` + `,` on Mac)
- Extensions -> Lean 4
- Add the environment variables to Server Env. 

Then restart the Lean Server (`Command` + `t`, then type `> Lean 4: Restart Server`).
