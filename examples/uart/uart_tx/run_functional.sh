#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")" && pwd)

iverilog -g2012 -s tb_uart_tx -o "$ROOT_DIR/uart_tx.vvp" \
  "$ROOT_DIR/uart_tx.v" \
  "$ROOT_DIR/tb_uart_tx.v"

vvp "$ROOT_DIR/uart_tx.vvp"
