import Lake
open Lake DSL

package «llmlean» where

@[default_target]
lean_lib «LLMlean» where
  -- add any library configuration options here

-- If -Ktest=on is passed, then add additional requirements
meta if get_config? test = some "on" then do
  require mathlib from git "https://github.com/leanprover-community/mathlib4" @ "v4.20.0-rc5"

  lean_lib LLMleanTest where
    globs := #[.submodules `LLMleanTest]