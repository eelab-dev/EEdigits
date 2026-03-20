# TODO-2 Repro Pack (AW16, depth 15)

This folder is a clean reproduction pack for the reported TODO-2 FIFO metrics.

## Layout

- `active/`: only files required to run the three SBY jobs
- `archive/`: copied logs/manifest from prior exploratory runs

## Important note

The design file in this pack is the **TODO-1 binary-pointer RTL** variant (`generic_fifo_lfsr.v`), which is the one used for the reported TODO-2 metrics.

## Reproduce metrics

From `active/` run:

```bash
sby -f generic_fifo_lfsr_prove_yices_d15_aw16.sby
sby -f generic_fifo_lfsr_prove_bitwuzla_d15_aw16.sby
sby -f generic_fifo_lfsr_prove_z3_d15_aw16.sby
```

## Expected outcomes

All should return `PASS`.
