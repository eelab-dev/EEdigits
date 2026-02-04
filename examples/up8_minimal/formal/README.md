# uP8 Minimal — Formal Verification

This folder contains SymbiYosys proofs for the uP8 CPU:

- An end-to-end proof for the bundled ROM program (`program_add1_loop.md`)
- An ISA step-semantics proof that does **not** rely on any program/ROM

## What is proven

For the fixed ROM image (N=10 loop):

- Within a bounded number of cycles after reset deasserts, the CPU reaches `HALT`
- At that point (and thereafter):
  - `R0 == 10`
  - `R1 == 0`

For the ISA step proof (no program):

- Instruction bytes are **symbolic** each cycle (no ROM required)
- Assuming the CPU was not halted in the prior cycle and excluding LOAD/STORE,
  the next-state of all observable signals is exactly what the ISA specifies:
  `pc`, `halted`, `z`, `c`, `r0..r3`.

## Run

From `examples/up8_minimal/`:

```sh
./run_formal.sh
```

This runs both proofs with **Z3** (fast).
