#!/usr/bin/env sh
set -eu

ROOT_DIR=$(cd "$(dirname "$0")" && pwd)
BUILD_DIR="$ROOT_DIR/build"
WAVES_DIR="$ROOT_DIR/waves"

mkdir -p "$BUILD_DIR" "$WAVES_DIR"

# Assemble ROM from the markdown program (keeps ROM in sync with docs)
python3 "$ROOT_DIR/asm_up8.py" "$ROOT_DIR/program_add1_loop.md" -o "$BUILD_DIR/rom_add1_loop.memh"

iverilog -g2012 -o "$BUILD_DIR/tb_up8_add1_loop.vvp" \
  "$ROOT_DIR/up8_cpu.v" "$ROOT_DIR/tb_up8_add1_loop.v"

VCD_OUT="$WAVES_DIR/up8_add1_loop.vcd"

vvp "$BUILD_DIR/tb_up8_add1_loop.vvp" \
  +ROM="$BUILD_DIR/rom_add1_loop.memh" \
  +VCD="$VCD_OUT"

echo "Waveform generated: $VCD_OUT"

if command -v gtkwave >/dev/null 2>&1; then
  echo "Opening in gtkwave..."
  gtkwave "$VCD_OUT"
else
  echo "Tip: open with GTKWave: gtkwave $VCD_OUT"
fi
