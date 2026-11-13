#!/usr/bin/env bash
set -euo pipefail

demo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
provider="${1:-openai}"

case "$provider" in
  local)
    export LLMLEAN_CONFIG="$demo_dir/llmlean.local.toml"
    ;;
  openai)
    export LLMLEAN_CONFIG="$demo_dir/llmlean.openai.toml"
    if [[ -z "${OPENAI_API_KEY:-}" ]]; then
      if [[ ! -t 0 ]]; then
        echo "Set OPENAI_API_KEY in your terminal, then run this launcher again." >&2
        exit 1
      fi
      read -r -s -p "OpenAI API key (hidden): " OPENAI_API_KEY
      printf '\n'
      if [[ -z "$OPENAI_API_KEY" ]]; then
        echo "An OpenAI API key is required." >&2
        exit 1
      fi
    fi
    export OPENAI_API_KEY
    ;;
  *)
    echo "Usage: bash open-vscode.sh [local|openai]" >&2
    exit 1
    ;;
esac

if command -v code >/dev/null 2>&1; then
  code_bin="$(command -v code)"
elif [[ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]]; then
  code_bin="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
else
  echo "Install VS Code and its 'code' shell command, then run this launcher again." >&2
  exit 1
fi

# A separate instance inherits this environment even when another VS Code is open.
# The key is passed through the environment, not written to files or command arguments.
exec "$code_bin" --user-data-dir "$demo_dir/.vscode-data/$provider" \
  --extensions-dir "$HOME/.vscode/extensions" \
  --new-window "$demo_dir" "$demo_dir/Demo.lean"
