#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")" && pwd)

verible-verilog-lint \
  --rules=-always-comb \
  "$ROOT_DIR/up8_cpu.v" \
  "$ROOT_DIR/tb_up8_add1_loop.v" \
  "$ROOT_DIR/formal/up8_add1_formal.sv" \
  "$ROOT_DIR/formal/up8_isa_step_formal.sv"
