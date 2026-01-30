#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")" && pwd)

verible-verilog-lint \
  "$ROOT_DIR/uart_full.v" \
  "$ROOT_DIR/uart_tx.v" \
  "$ROOT_DIR/uart_rx.v" \
  "$ROOT_DIR/tb_uart_full.v" \
  "$ROOT_DIR/formal/uart_full_formal.sv"
