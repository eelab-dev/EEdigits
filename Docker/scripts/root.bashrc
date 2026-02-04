# ~/.bashrc (root)

# Only run in interactive shells.
case $- in
  *i*) ;;
  *) return ;;
esac

# --- VS Code shell integration (manual install fallback) ---
# VS Code usually injects this automatically for supported shells.
# This is a safe fallback for cases where injection doesn't apply.
if [[ "${TERM_PROGRAM:-}" == "vscode" ]]; then
  if [[ -z "${VSCODE_SHELL_INTEGRATION:-}" ]] && command -v code >/dev/null 2>&1; then
    # 'code' is the VS Code remote CLI in dev containers.
    # It returns a path to a shell script that enables rich integration.
    _vscode_si_path="$(code --locate-shell-integration-path bash 2>/dev/null || true)"
    if [[ -n "${_vscode_si_path}" && -r "${_vscode_si_path}" ]]; then
      # shellcheck disable=SC1090
      . "${_vscode_si_path}"
    fi
    unset _vscode_si_path
  fi
fi

# --- Colors + prompt ---
export TERM="${TERM:-xterm-256color}"
export COLORTERM="${COLORTERM:-truecolor}"

# Enable colored 'ls' output when available.
if command -v dircolors >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  eval "$(dircolors -b 2>/dev/null || true)"
fi

if command -v ls >/dev/null 2>&1; then
  alias ls='ls --color=auto'
  alias ll='ls -alF'
  alias la='ls -A'
fi

# Colored prompt (user@host:cwd)
if command -v tput >/dev/null 2>&1 && tput setaf 1 >/dev/null 2>&1; then
  PS1='\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '
else
  PS1='\u@\h:\w\$ '
fi

# Quality-of-life
shopt -s checkwinsize 2>/dev/null || true
