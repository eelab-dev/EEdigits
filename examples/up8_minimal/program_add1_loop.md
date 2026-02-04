# uP8 Minimal — Example Program: Add 1 in a Loop

This example shows a simple **for-loop style** program that adds integer `1` repeatedly.

## Goal

Compute:

- `sum = sum + 1`, repeated `N` times

Register usage:

- `R0` = `sum`
- `R1` = loop counter `i` (counts down)

At the end, `R0` holds the result (`N` mod 256).

## Assembly

```asm
; Program: sum += 1 for i in [0..N-1]
; Inputs:
;   N is encoded as an immediate below.
; Outputs:
;   R0 = N (mod 256)

        MOVI R0, 0x00        ; sum = 0
        MOVI R1, 0x0A        ; N = 10 (change as desired)

LOOP:   ADDI R0, 0x01        ; sum = sum + 1
        SUBI R1, 0x01        ; i = i - 1   (sets Z when i==0)
        JNZ  LOOP            ; if i != 0, repeat

        HALT
```

## Notes

- This relies on `SUBI` setting the `Z` flag when the result is zero.
- If you prefer a count-up loop, you can use an extra register and compare via subtraction.

## Assemble to ROM

From this folder:

```sh
python3 asm_up8.py program_add1_loop.md -o rom_add1_loop.memh
```

This produces `rom_add1_loop.memh` as **one byte per line** (compatible with Verilog `$readmemh`).
