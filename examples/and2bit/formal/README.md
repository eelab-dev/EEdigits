# Formal verification (SymbiYosys)

This folder contains a minimal SymbiYosys setup to formally verify the combinational identity of `and2bit`:

- `and2bit_formal.sv`: formal harness with assertions/covers
- `and2bit_prove.sby`: prove run
- `and2bit_cover.sby`: cover run

## Running (after you install tools)

From the repo root:

- `sby -f formal/and2bit_prove.sby`
- `sby -f formal/and2bit_cover.sby`

Typical dependencies:

- SymbiYosys (`sby`)
- Yosys
- an SMT solver such as Z3 or Boolector
