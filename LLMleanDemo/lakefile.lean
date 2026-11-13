import Lake
open Lake DSL

package LLMleanDemo

-- Use the working copy on the modernization branch.
require llmlean from ".."

@[default_target]
lean_lib Demo where
  roots := #[`Demo, `Solutions, `Context]
