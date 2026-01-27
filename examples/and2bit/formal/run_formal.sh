#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Prefer local Z3 if available.
if [[ -x "${SCRIPT_DIR}/.tools/z3/install/bin/z3" ]]; then
  export PATH="${SCRIPT_DIR}/.tools/z3/install/bin:${PATH}"
fi

cd "${SCRIPT_DIR}"

sby -f and2bit_prove.sby
sby -f and2bit_cover.sby
