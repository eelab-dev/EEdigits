#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")" && pwd)

FORMAL_TIMEOUT_SECONDS="${FORMAL_TIMEOUT_SECONDS:-300}"


cd "$ROOT_DIR/formal"

timeout "$FORMAL_TIMEOUT_SECONDS" sby -f up8_add1_prove_z3.sby
timeout "$FORMAL_TIMEOUT_SECONDS" sby -f up8_isa_step_z3.sby
