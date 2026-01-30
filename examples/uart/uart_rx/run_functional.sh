#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")" && pwd)

iverilog -g2012 -s tb_uart_rx -o "$ROOT_DIR/uart_rx_sim" \
  "$ROOT_DIR/uart_rx.v" \
  "$ROOT_DIR/tb_uart_rx.v"

vvp "$ROOT_DIR/uart_rx_sim"
