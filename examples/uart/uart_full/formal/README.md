MGR workspace layout
- tools/: scripts for mutation generation and audit execution
- configs/: campaign configs
- campaigns/<design>/baseline/: frozen inputs
- campaigns/<design>/mutants/: generated mutants + manifest
- campaigns/<design>/runs/: audit run outputs
- campaigns/<design>/reports/: summaries and analysis# Formal verification (SymbiYosys)

This folder contains a minimal SymbiYosys setup to formally verify `uart_full`:

- `uart_full_formal.sv`: formal harness with assertions
- `uart_full_prove.sby`: prove run

## Running (after you install tools)

From the repo root:

- `sby -f examples/uart/uart_full/formal/uart_full_prove.sby`

Typical dependencies:

- SymbiYosys (`sby`)
- Yosys
- an SMT solver such as Z3 or Boolector
