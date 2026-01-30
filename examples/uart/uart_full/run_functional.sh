#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")" && pwd)

iverilog -g2012 -s tb_uart_full -o "$ROOT_DIR/uart_full_sim" \
  "$ROOT_DIR/uart_full.v" \
  "$ROOT_DIR/uart_tx.v" \
  "$ROOT_DIR/uart_rx.v" \
  "$ROOT_DIR/tb_uart_full.v"

vvp "$ROOT_DIR/uart_full_sim"
