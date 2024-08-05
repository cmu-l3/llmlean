import Lake
open Lake DSL

package «llmlean» {
  -- add any package configuration options here
}

require mathlib from git "https://github.com/leanprover-community/mathlib4" @ "db651742f2c631e5b8525e9aabcf3d61ed094a4a"

@[default_target]
lean_lib «LLMlean» {
  -- add any library configuration options here
}
