# PRAMANA — Proof-centric RTL Agentic Model for Assurance, Narrative, and Automation

**PRAMANA** takes its name from Sanskrit, where it means *measure*, *proof*, or *means of knowledge*. The tool aims to execute the hardware verification lifecycle autonomously — from harness quality assessment through solver selection to failure explanation — as a fully closed-loop agentic system. This repository implements the foundational tier of that vision: autonomous formal verification via three cooperating agents.

| Agent | Name | Purpose |
|---|---|---|
| **Agent II** | Mutation-Guided Refinement (MGR) | Measure and improve formal harness quality via mutation analysis |
| **Agent III** | Predictive Solver Portfolio (PSP) | Select the best SMT solver for the design; generate a ready-to-run `.sby` file |
| **Agent IV** | Causal Narrative Synthesis (CNS) | Explain formal failures in human-readable language (future work) |

> **Starting point:** Agent I (harness generation) is a prerequisite but is assumed
> complete — the user provides a working formal harness `.sv` file.
> This README begins at **Agent II (MGR)**.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Repository Structure](#repository-structure)
3. [Agent II — Mutation-Guided Refinement (MGR)](#agent-ii--mutation-guided-refinement-mgr)
   - [Concept](#concept)
   - [Step 1: Generate Mutants](#step-1-generate-mutants)
   - [Step 2: Audit Mutants](#step-2-audit-mutants)
   - [Step 3: Interpret Results and Decide](#step-3-interpret-results-and-decide)
   - [Worked Examples](#worked-examples)
4. [Agent III — Predictive Solver Portfolio (PSP)](#agent-iii--predictive-solver-portfolio-psp)

---

## Prerequisites

The following tools must be installed and available on `PATH`:

| Tool | Purpose | Install reference |
|---|---|---|
| `yosys` | RTL synthesis and statistics extraction | [yosys-install.md](yosys-install.md) |
| `sby` (SymbiYosys) | Formal verification runner | [yosys-install.md](yosys-install.md) |
| `smtbmc` with Yices / Z3 / Bitwuzla backends | SMT solvers | [z3-install.md](z3-install.md) |
| Python 3.9+ | Script execution | system package manager |

Verify availability:

```bash
yosys --version
sby --version
python3 --version
```

---

## Repository Structure

```
digital-tools/
│
├── manage_formal.py          # Agent III: PSP orchestrator (Yosys → metrics → solver → .sby)
├── extract_stat_json.py      # Helper: extract JSON stats block from a Yosys log
├── extract_complexity_metrics.py  # Helper: compute D_A, D_M, W, D_R, I_C, CHI_NORM
├── generate_metrics_table.py # Batch metrics printer/CSV exporter for all designs
│
├── examples/                 # Reference RTL designs and their formal setups
│   ├── uart/                 # UART (tx + rx + top)
│   ├── i2c/                  # I2C master
│   ├── generic_fifo_lfsr/    # Synchronous FIFO with LFSR
│   │   └── repro_todo2_aw16_d15/active/   # ← canonical FIFO formal files (use these)
│   ├── sdram/
│   ├── sha3/
│   ├── pipelined_fft_256_latest/
│   ├── vga_lcd_latest/
│   └── up8_minimal/          # 8-bit microprocessor (special handling required)
│
└── mgr/
    ├── tools/
    │   ├── mutant_generator.py   # Step 1: generate mutants from a single RTL file
    │   └── audit_runner.py       # Step 2: run sby per mutant, classify, summarise
    └── campaigns/                # One subdirectory per design under verification
        ├── uart_tx/
        │   ├── baseline/         # Unmodified RTL + baseline harness
        │   ├── refinement_v1/    # Round 1: harness, .sby, mutants/, runs/
        │   └── refinement_v2/    # Round 2 (current best)
        ├── i2c/
        │   ├── refinement_v1/
        │   └── refinement_v2/
        └── generic_fifo_lfsr/
            ├── refinement_v1/
            ├── refinement_v2/
            └── refinement_v3/    # Round 3 (current best, 100 % kill rate)
```

**Campaign round convention:** each `refinement_vN/` directory is immutable once
created — never overwrite a completed round. Start a new `refinement_v(N+1)/` for
each new harness iteration.

---

## Agent II — Mutation-Guided Refinement (MGR)

### Concept

MGR measures how well a formal harness can detect bugs by injecting small artificial
bugs (mutants) into the RTL and checking whether the harness catches them:

- **KILLED** — the harness found a counterexample for this mutant (good).
- **SURVIVED** — the harness passed despite the bug (the harness needs strengthening).
- **INVALID** — the mutant could not be elaborated (e.g., a reset-sensitivity change
  broke compilation); excluded from the kill-rate denominator.
- **TIMEOUT / INCONCLUSIVE** — the solver did not finish within the time budget.

Two kill rates are reported:

```
Raw Kill Rate      = KILLED / TOTAL
Effective Kill Rate = KILLED / (TOTAL − INVALID)
```

The **effective kill rate** is the primary metric. The target threshold is **T = 50 %**.
If the effective kill rate is below T, strengthen the harness and run a new round.

---

### Step 1: Generate Mutants

`mgr/tools/mutant_generator.py` targets **one RTL file** (the primary state/logic
file of the design) and applies conservative, one-change-at-a-time transformations.

**CLI:**

```bash
python3 mgr/tools/mutant_generator.py \
    --rtl   <path/to/target_rtl_file.v> \
    --out   <output_directory>           \
    --design <design_name>               \
    [--max-mutants <N>]                  # default: 30
```

Outputs written to `<output_directory>/`:
- `manifest.json` — metadata for every generated mutant (used by audit_runner)
- `mutants/` — one `.v` file per mutant

**Important:** `--rtl` is the single file to mutate (e.g., `uart_tx.v`), not the full
RTL set. The tool reads this file, applies mutations, and records the absolute path in
`manifest.json` so `audit_runner.py` knows which file to swap per mutant.

---

### Step 2: Audit Mutants

`mgr/tools/audit_runner.py` creates an isolated workspace for each mutant, runs
`sby`, and classifies the result.

**CLI:**

```bash
python3 mgr/tools/audit_runner.py \
    --manifest   <path/to/manifest.json>          \
    --rtl-files  <file1.v> <file2.v> ...          \
    --harness-files <harness.sv>                  \
    --sby        <path/to/prove.sby>              \
    --workdir    <path/to/runs_directory>         \
    --timeout    <seconds_per_mutant>
```

- `--rtl-files` — **all** RTL files needed to compile the design (timescale, sub-modules,
  top-level wrappers, etc.). The tool copies them all into each mutant's workspace.
- `--harness-files` — formal harness `.sv` file(s).
- `--sby` — the `.sby` configuration file for this campaign round.

Outputs written to `<workdir>/`:
- `summary.json` — total, per-class counts, raw/effective kill rates, list of survived mutants
- `summary.csv` — same data in tabular form
- `<mutant_id>/logs/stdout.log`, `stderr.log` — per-mutant sby output

---

### Step 3: Interpret Results and Decide

Read `<workdir>/summary.json`:

```json
{
  "total_mutants": 20,
  "counts": { "KILLED": 18, "SURVIVED": 2, "INVALID": 0 },
  "raw_kill_rate": 0.9,
  "effective_mutants": 20,
  "effective_kill_rate": 0.9,
  "survived_mutants": ["M003", "M011"]
}
```

**Decision logic:**

- `effective_kill_rate >= 0.50` → harness quality is sufficient. Proceed to Agent III (PSP).
- `effective_kill_rate < 0.50` → inspect `survived_mutants`, identify what property
  is missing, update the harness, create a new `refinement_v(N+1)/` directory, and
  repeat from Step 1.

---

### Worked Examples

All commands below are run from the repository root (`/workspaces/digital-tools/`).

---

#### Design 1 — UART TX (`uart_tx`)

RTL target for mutation: `uart_tx.v` (state machine and data path).
Full RTL set: `uart_full.v`, `uart_tx.v`, `uart_rx.v`.

**Step 1 — Generate mutants (Round 2 shown):**

```bash
python3 mgr/tools/mutant_generator.py \
    --rtl    mgr/campaigns/uart_tx/baseline/uart_tx.v \
    --out    mgr/campaigns/uart_tx/refinement_v2/mutants \
    --design uart_tx \
    --max-mutants 20
```

**Step 2 — Audit mutants:**

```bash
python3 mgr/tools/audit_runner.py \
    --manifest      mgr/campaigns/uart_tx/refinement_v2/mutants/manifest.json \
    --rtl-files     mgr/campaigns/uart_tx/baseline/uart_full.v \
                    mgr/campaigns/uart_tx/baseline/uart_tx.v \
                    mgr/campaigns/uart_tx/baseline/uart_rx.v \
    --harness-files mgr/campaigns/uart_tx/refinement_v2/uart_full_formal_v3.sv \
    --sby           mgr/campaigns/uart_tx/refinement_v2/uart_full_prove_v3.sby \
    --workdir       mgr/campaigns/uart_tx/refinement_v2/runs \
    --timeout       120
```

**Results (Round 2):** 18/20 KILLED → effective kill rate **90 %** ✓

---

#### Design 2 — I2C Master (`i2c`)

RTL target for mutation: `i2c_master_top_formal.v`.
Full RTL set: the four `.v` files in the refinement directory.

**Step 1 — Generate mutants (Round 2 shown):**

```bash
python3 mgr/tools/mutant_generator.py \
    --rtl    mgr/campaigns/i2c/refinement_v2/i2c_master_top_formal.v \
    --out    mgr/campaigns/i2c/refinement_v2/mutants \
    --design i2c \
    --max-mutants 10
```

**Step 2 — Audit mutants:**

```bash
python3 mgr/tools/audit_runner.py \
    --manifest      mgr/campaigns/i2c/refinement_v2/mutants/manifest.json \
    --rtl-files     mgr/campaigns/i2c/refinement_v2/i2c_master_defines.v \
                    mgr/campaigns/i2c/refinement_v2/i2c_master_bit_ctrl_formal.v \
                    mgr/campaigns/i2c/refinement_v2/i2c_master_byte_ctrl_formal.v \
                    mgr/campaigns/i2c/refinement_v2/i2c_master_top_formal.v \
    --harness-files mgr/campaigns/i2c/refinement_v2/i2c_master_top_prove_formal_v2.sv \
    --sby           mgr/campaigns/i2c/refinement_v2/i2c_master_top_prove_v2.sby \
    --workdir       mgr/campaigns/i2c/refinement_v2/runs \
    --timeout       180
```

**Results (Round 2):** 10/10 KILLED → effective kill rate **100 %** ✓

---

#### Design 3 — Synchronous FIFO (`generic_fifo_lfsr`)

> **Exception:** The canonical formal files for this design are located under
> `examples/generic_fifo_lfsr/repro_todo2_aw16_d15/active/`, not the top-level
> `examples/generic_fifo_lfsr/formal/`. Always use the `active/` path.

RTL target for mutation: `generic_fifo_lfsr.v`.
Full RTL set: `timescale.v`, `generic_dpram_formal.v`, `generic_fifo_lfsr.v`.

**Step 1 — Generate mutants (Round 3 shown):**

```bash
python3 mgr/tools/mutant_generator.py \
    --rtl    mgr/campaigns/generic_fifo_lfsr/refinement_v3/generic_fifo_lfsr.v \
    --out    mgr/campaigns/generic_fifo_lfsr/refinement_v3/mutants \
    --design generic_fifo_lfsr \
    --max-mutants 10
```

**Step 2 — Audit mutants:**

```bash
python3 mgr/tools/audit_runner.py \
    --manifest      mgr/campaigns/generic_fifo_lfsr/refinement_v3/mutants/manifest.json \
    --rtl-files     mgr/campaigns/generic_fifo_lfsr/refinement_v3/timescale.v \
                    mgr/campaigns/generic_fifo_lfsr/refinement_v3/generic_dpram_formal.v \
                    mgr/campaigns/generic_fifo_lfsr/refinement_v3/generic_fifo_lfsr.v \
    --harness-files mgr/campaigns/generic_fifo_lfsr/refinement_v3/generic_fifo_lfsr_prove_formal_v2.sv \
    --sby           mgr/campaigns/generic_fifo_lfsr/refinement_v3/generic_fifo_lfsr_prove_v3.sby \
    --workdir       mgr/campaigns/generic_fifo_lfsr/refinement_v3/runs \
    --timeout       120
```

**Results (Round 3):** 10/10 KILLED → effective kill rate **100 %** ✓

---

#### Starting a New Refinement Round

If the kill rate is below the threshold, create a new round directory, copy the RTL
files and the updated harness into it, then repeat the two steps above:

```bash
# Example: starting refinement_v4 for FIFO
ROUND=mgr/campaigns/generic_fifo_lfsr/refinement_v4
mkdir -p "$ROUND"

# Copy RTL files from the previous round (or directly from examples/)
cp mgr/campaigns/generic_fifo_lfsr/refinement_v3/timescale.v         "$ROUND/"
cp mgr/campaigns/generic_fifo_lfsr/refinement_v3/generic_dpram_formal.v "$ROUND/"
cp mgr/campaigns/generic_fifo_lfsr/refinement_v3/generic_fifo_lfsr.v  "$ROUND/"

# Place the updated harness and .sby into the new round directory, then run:
python3 mgr/tools/mutant_generator.py \
    --rtl    "$ROUND/generic_fifo_lfsr.v" \
    --out    "$ROUND/mutants" \
    --design generic_fifo_lfsr \
    --max-mutants 10

python3 mgr/tools/audit_runner.py \
    --manifest      "$ROUND/mutants/manifest.json" \
    --rtl-files     "$ROUND/timescale.v" \
                    "$ROUND/generic_dpram_formal.v" \
                    "$ROUND/generic_fifo_lfsr.v" \
    --harness-files "$ROUND/<new_harness>.sv" \
    --sby           "$ROUND/<new_prove>.sby" \
    --workdir       "$ROUND/runs" \
    --timeout       120
```

---

#### MGR Kill Rate Summary

| Design | Round | Total | KILLED | SURVIVED | INVALID | Effective Kill Rate |
|---|---|---|---|---|---|---|
| `uart_tx` | baseline | 20 | 5 | 15 | — | 25 % |
| `uart_tx` | R1 (`refinement_v1`) | 20 | 7 | 13 | — | 35 % |
| `uart_tx` | R2 (`refinement_v2`) | 20 | 18 | 2 | — | **90 %** ✓ |
| `i2c` | R1 (`refinement_v1`) | 10 | 1 | 9 | — | 10 % |
| `i2c` | R2 (`refinement_v2`) | 10 | 10 | — | — | **100 %** ✓ |
| `generic_fifo_lfsr` | R1 (`refinement_v1`) | 5 | 2 | — | 2 | 67 % † |
| `generic_fifo_lfsr` | R2 (`refinement_v2`) | 14 | 5 | 3 | 6 | 62.5 % † |
| `generic_fifo_lfsr` | R3 (`refinement_v3`) | 10 | 10 | — | — | **100 %** ✓ |

† Exceeds the 50 % threshold but refinement continued to reach higher confidence.
— indicates the count was zero (not recorded as a key in the summary JSON).

---

## Agent III — Predictive Solver Portfolio (PSP)

PSP measures the structural complexity of an RTL design, maps it to a complexity
score (`CHI_NORM`), selects the best SMT solver from a portfolio, chooses a BMC
depth, and writes a ready-to-run `.sby` file — all automatically.

### Concept

Six complexity metrics are extracted from a Yosys `stat -json` report:

| Metric | Meaning |
|---|---|
| `D_A` | AND-tree depth (combinational complexity) |
| `D_M` | Multi-driver depth (fan-out complexity) |
| `W` | Register width (state-space width) |
| `D_R` | RAM size in bits (logarithm of state-space depth) |
| `I_C` | Internal connectivity ratio |
| `CHI_NORM` | Weighted composite score in [0, 1] |

Solver selection rules (evaluated in priority order, first match wins):

| Priority | Condition | Solver | Rationale |
|---|---|---|---|
| 1 | `W_norm > 0.50` | bitwuzla | Very wide datapath — bit-vector native reasoning |
| 2 | `D_M > 0.35` | yices | High mux/control density — fast SAT-style search |
| 3 | `I_C > 0.35 AND W_norm < 0.10` | bitwuzla | Symbolic-pointer / high-index narrow designs |
| 4 | `D_A > 0.30 AND W_norm < 0.25` | yices | Arithmetic-heavy moderate-width pipelines |
| 5 | `D_R_norm > 0.30` | yices | Memory-heavy design |
| default | — | yices | General control-oriented or mixed RTL |

---

### Step 1: Run `manage_formal.py`

```bash
python3 manage_formal.py \
    <top_module> \
    <k_depth> \
    <v_file1> [<v_file2> ...] \
    [--formal_sv  <harness.sv>] \
    [--formal_top <harness_top_module>] \
    [--prep_flags <extra_prep_flags>]
```

Artifacts written to the directory of `--formal_sv` (or the first `.v` file):

| File | Description |
|---|---|
| `design_dump.log` | Full Yosys output |
| `design_stats.json` | Parsed JSON statistics |
| `<top>_auto.sby` | Ready-to-run SymbiYosys configuration |

After the file is created, run the proof:

```bash
sby -f <top>_auto.sby
```

---

### Step 2: Batch Metrics (Optional)

To profile all designs in `examples/` and update `metrics_table.csv`:

```bash
python3 generate_metrics_table.py
```

Output is printed to stdout and saved to `metrics_table.csv` in the repository root.

---

### Worked Examples

All commands below are run from `/workspaces/digital-tools/`.

---

#### Design 1 — UART Full (`uart_full`)

```bash
python3 manage_formal.py uart_full 25 \
    examples/uart/uart_full/uart_full.v \
    examples/uart/uart_full/uart_rx.v \
    examples/uart/uart_full/uart_tx.v \
    --formal_sv  examples/uart/uart_full/formal/uart_full_formal.sv \
    --formal_top uart_full_formal
```

Output: `examples/uart/uart_full/formal/uart_full_auto.sby`

Run the proof:

```bash
sby -f examples/uart/uart_full/formal/uart_full_auto.sby
```

---

#### Design 2 — I2C Master (`i2c_master_top_formal`)

```bash
python3 manage_formal.py i2c_master_top_formal 80 \
    examples/i2c/i2c_master_defines.v \
    examples/i2c/i2c_master_bit_ctrl_formal.v \
    examples/i2c/i2c_master_byte_ctrl_formal.v \
    examples/i2c/i2c_master_top_formal.v \
    --formal_sv  examples/i2c/formal/i2c_master_top_prove_formal.sv \
    --formal_top i2c_master_top_prove_formal
```

Output: `examples/i2c/formal/i2c_master_top_formal_auto.sby`

---

#### Design 3 — SDRAM Controller (`sdram`)

```bash
python3 manage_formal.py sdram 30 \
    examples/sdram/sdram.v \
    --formal_sv  examples/sdram/formal/sdram_prove_formal.sv \
    --formal_top sdram_prove_formal
```

Output: `examples/sdram/formal/sdram_auto.sby`

---

#### Design 4 — FIFO + LFSR (`generic_fifo_lfsr`)

> **Exception:** Use the canonical RTL from `repro_todo2_aw16_d15/active/`,
> not the top-level `examples/generic_fifo_lfsr/formal/` directory.

```bash
FIFO=examples/generic_fifo_lfsr/repro_todo2_aw16_d15/active

python3 manage_formal.py generic_fifo_lfsr 40 \
    "$FIFO/timescale.v" \
    "$FIFO/generic_dpram_formal.v" \
    "$FIFO/generic_fifo_lfsr.v" \
    --formal_sv  "$FIFO/generic_fifo_lfsr_prove_formal.sv" \
    --formal_top generic_fifo_lfsr_prove_formal
```

Output: `<FIFO>/generic_fifo_lfsr_auto.sby`

---

#### Design 5 — UP8 Minimal CPU (`up8_cpu`) ⚠ Exception

The UP8 core requires macro definitions and an include path that `manage_formal.py`
does not pass to the `read` command. The tool **can** produce a solver selection
and a draft `.sby`, but the draft's `[script]` section must be patched manually.

**Step 1 — Run manage_formal.py to get the solver selection:**

```bash
python3 manage_formal.py up8_cpu 45 \
    examples/up8_minimal/up8_cpu.v
```

**Step 2 — Patch the generated `up8_cpu_auto.sby`:**
Replace the auto-generated `read -formal up8_cpu.v` line with:

```
read -formal -D FORMAL -D UP8_INLINE_ROM -D UP8_FORMAL_ROMONLY -I . up8_cpu.v
```

Also add the harness and ROM include file to `[script]` and `[files]`, e.g.:

```ini
[script]
read -formal -D FORMAL -D UP8_INLINE_ROM -D UP8_FORMAL_ROMONLY -I . up8_cpu.v
read -formal up8_add1_formal.sv
prep -top up8_add1_formal

[files]
../up8_cpu.v
up8_add1_formal.sv
up8_inline_rom.vh
```

The manually crafted proofs already exist in `examples/up8_minimal/formal/` and
can be used directly:

```bash
# BMC proof (add1 infinite loop) using Z3
sby -f examples/up8_minimal/formal/up8_add1_prove_z3.sby

# Same proof using Bitwuzla (faster on this design)
sby -f examples/up8_minimal/formal/up8_add1_prove_bitwuzla.sby

# ISA step-correctness proof (one instruction per step)
sby -f examples/up8_minimal/formal/up8_isa_step_z3.sby
```

---

### PSP Solver Selection Results

All 8 benchmarks verified against Table 4 (observed ASL in s/step, lower = faster).

| Design | W_norm | D_A | D_M | I_C | DR_norm | Rule fired | PSP pick | Table 4 winner |
|---|---|---|---|---|---|---|---|---|
| I2C Master | 0.047 | 0.143 | 0.390 | 0.122 | 0.000 | D_M > 0.35 | yices | yices (0.038) |
| UART (Full) | 0.047 | 0.239 | 0.349 | 0.143 | 0.000 | default | yices | yices (0.008) |
| Sync. FIFO | 0.031 | 0.132 | 0.289 | 0.423 | 0.000 | I_C > 0.35 ∧ W_norm < 0.10 | bitwuzla | bitwuzla (2.733) |
| SDRAM Controller | 0.062 | 0.180 | 0.384 | 0.161 | 0.000 | D_M > 0.35 | yices | yices (0.024) |
| Pipelined FFT 256 | 0.156 | 0.374 | 0.096 | 0.054 | 0.035 | D_A > 0.30 ∧ W_norm < 0.25 | yices | yices (0.613) |
| SHA3 (Keccak) | 1.000 | 0.017 | 0.019 | 0.158 | 0.000 | W_norm > 0.50 | bitwuzla | bitwuzla (0.250) |
| VGA LCD | 0.078 | 0.146 | 0.257 | 0.326 | 0.016 | default | yices | yices (0.150) |
| uP8 (Add/ISA) | 0.094 | 0.224 | 0.598 | 0.033 | 0.500 | D_M > 0.35 | yices | yices (0.044/0.556) |
