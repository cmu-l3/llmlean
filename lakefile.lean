import Lake
open Lake DSL

package «llmlean» where

@[default_target]
lean_lib «LLMlean» where

lean_exe llmlean where
  root := `LLMlean.Doctor

lean_lib Tests where

@[test_driver]
lean_exe llmlean_tests where
  root := `Tests.Main
