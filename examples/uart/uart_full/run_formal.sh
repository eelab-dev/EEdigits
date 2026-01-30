#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")" && pwd)

cd "$ROOT_DIR/formal"

sby -f uart_full_prove.sby
sby -f uart_full_cover.sby
