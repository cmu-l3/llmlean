import Lake
open Lake DSL

package «llmlean» where

@[default_target]
lean_lib «LLMlean» where
  -- add any library configuration options here

-- If -Ktest=on is passed, then add additional requirements
meta if get_config? test = some "on" then do
  require PFR from git "https://github.com/teorth/pfr" @ "master"

  lean_lib LLMleanTest where
    globs := #[.submodules `LLMleanTest]
