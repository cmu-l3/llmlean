import Lake
open Lake DSL

package «llmlean» {
  -- add any package configuration options here
}

require mathlib from git "https://github.com/leanprover-community/mathlib4" @ "600a5fa3828fef53b2fa20d30dc8e1fb51ce0f98"

@[default_target]
lean_lib «LLMlean» {
  -- add any library configuration options here
}
