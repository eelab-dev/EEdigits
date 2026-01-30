# Formal verification (SymbiYosys)

This folder contains a minimal SymbiYosys setup to formally verify `uart_rx`:

- `uart_rx_formal.sv`: formal harness with assertions
- `uart_rx_prove.sby`: prove run

## Running (after you install tools)

From the repo root:

- `sby -f examples/uart/uart_rx/formal/uart_rx_prove.sby`

Typical dependencies:

- SymbiYosys (`sby`)
- Yosys
- an SMT solver such as Z3 or Boolector
