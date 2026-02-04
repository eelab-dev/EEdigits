#!/usr/bin/env bash
set -euo pipefail

# Sensible defaults for interactive terminals (VS Code, etc.)
export TERM="${TERM:-xterm-256color}"
export COLORTERM="${COLORTERM:-truecolor}"

# If no command is provided, start an interactive login bash.
if [[ "$#" -eq 0 ]]; then
  exec /bin/bash -l
fi

exec "$@"
