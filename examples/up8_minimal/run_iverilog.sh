#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")"

# Assemble ROM from the markdown program (keeps ROM in sync with docs)
python3 asm_up8.py program_add1_loop.md -o rom_add1_loop.memh

iverilog -g2012 -o tb_up8_add1_loop.vvp \
  up8_cpu.v tb_up8_add1_loop.v

vvp tb_up8_add1_loop.vvp

echo "Waveform: $(pwd)/up8_add1_loop.vcd"
