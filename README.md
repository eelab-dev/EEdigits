# PRAMANA — Proof-centric RTL Agentic Model for Assurance, Narrative, and Automation

**PRAMANA** takes its name from Sanskrit, where it means *measure*, *proof*, or *means of knowledge*. The tool aims to execute the hardware verification lifecycle autonomously — from harness quality assessment through solver selection to failure explanation — as a fully closed-loop agentic system. This repository implements the foundational tier of that vision: autonomous formal verification via four cooperating agents.

| Agent | Name | Purpose |
|---|---|---|
| **Agent II** | Mutation-Guided Refinement (MGR) | Measure and improve formal harness quality via mutation analysis |
| **Agent III** | Predictive Solver Portfolio (PSP) | Select the best SMT solver for the design; generate a ready-to-run `.sby` file |
| **Agent IV** | Causal Narrative Synthesis (CNS) | Explain formal verification failures with causal, step-by-step narratives |

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
5. [Agent IV — Causal Narrative Synthesis (CNS)](#agent-iv--causal-narrative-synthesis-cns)

---

## Prerequisites

The following tools must be installed and available on `PATH`:

| Tool | Purpose | Install reference |
|---|---|---|
| `yosys` | RTL synthesis and statistics extraction | [yosys-install.md](yosys-install.md) |
| `sby` (SymbiYosys) | Formal verification runner | [yosys-install.md](yosys-install.md) |
| `smtbmc` with Yices / Z3 / Bitwuzla backends | SMT solvers | [z3-install.md](z3-install.md) |
| Python 3.9+ | Script execution | system package manager |
| `anthropic` Python package | Agent IV (CNS) LLM calls | `pip install anthropic` |
| LLM API key | Agent IV (CNS) narrative generation | set `LLM_API_KEY` env var |

Verify tool availability:

```bash
yosys --version
sby --version
python3 --version
```

For CNS, set your API key:

```bash
export LLM_API_KEY=<your-key>
```

> **Note:** Agents II and III require only the open-source tools
> listed above — no LLM or API key is needed. Agent IV (CNS) requires an
> API key to generate narratives. All pre-computed CNS responses for the
> 8 benchmark cases are already committed to the repository (in `cns/responses_r2/`),
> so scoring and inspection can be done without re-running the LLM.

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
├── cns/
│   ├── cns_agent.py              # Agent IV: CNS — prompt builder, API caller, scorer
│   ├── ground_truth.json         # Ground truth for 8 benchmark cases
│   ├── cases/                    # Input case JSON files (C1–C8)
│   ├── responses/                # Raw CNS responses (Round 2, default)
│   ├── responses_r1/             # Round 1 (zero-shot baseline) responses
│   ├── responses_r2/             # Round 2 (refined prompt) responses
│   ├── scored/                   # Per-case binary scores (Round 2)
│   ├── scored_r1/                # Per-case binary scores (Round 1)
│   └── scored_r2/                # Per-case binary scores (Round 2)
│
└── mgr/
    ├── tools/
    │   ├── mutant_generator.py   # Step 1: generate mutants from a single RTL file
    │   └── audit_runner.py       # Step 2: run sby per mutant, classify, summarise
    └── campaigns/                # One subdirectory per design under verification
        ├── and2bit/              # 2-bit AND gate (trivial sanity check)
        ├── uart_rx/              # UART receiver FSM
        ├── uart_full/            # UART top-level wrapper
        ├── up8/                  # 8-bit pipelined CPU
        ├── sha3/                 # Keccak-f permutation core
        ├── sdram/                # SDRAM controller (iterative, 4 rounds)
        ├── vga_lcd/              # VGA vertical timing FSM
        └── pipelined_fft_256/    # FFT-256 CNORM normalisation unit
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

#### Design 1 — `and2bit`

RTL target for mutation: `and2bit.v` (trivial 2-bit AND gate).

**Step 1 — Generate mutants:**

```bash
python3 mgr/tools/mutant_generator.py \
    --rtl    examples/and2bit/and2bit.v \
    --out    mgr/campaigns/and2bit/mutants/r1 \
    --design and2bit \
    --max-mutants 20
```

**Step 2 — Audit mutants:**

```bash
python3 mgr/tools/audit_runner.py \
    --manifest      mgr/campaigns/and2bit/mutants/r1/manifest.json \
    --rtl-files     mgr/campaigns/and2bit/baseline/and2bit.v \
    --harness-files mgr/campaigns/and2bit/baseline/and2bit_formal.sv \
    --sby           mgr/campaigns/and2bit/baseline/and2bit_prove.sby \
    --workdir       mgr/campaigns/and2bit/runs/r1 \
    --timeout       60
```

**Results (R1):** 20/20 KILLED → effective kill rate **100 %** ✓

---

#### Design 2 — UART RX (`uart_rx`)

RTL target for mutation: `uart_rx.v` (serial receiver FSM).

**Step 1 — Generate mutants:**

```bash
python3 mgr/tools/mutant_generator.py \
    --rtl    mgr/campaigns/uart_rx/baseline/uart_rx.v \
    --out    mgr/campaigns/uart_rx/mutants/r1 \
    --design uart_rx \
    --max-mutants 20
```

**Step 2 — Audit mutants:**

```bash
python3 mgr/tools/audit_runner.py \
    --manifest      mgr/campaigns/uart_rx/mutants/r1/manifest.json \
    --rtl-files     mgr/campaigns/uart_rx/baseline/uart_rx.v \
    --harness-files mgr/campaigns/uart_rx/refinement_v1/uart_rx_formal.sv \
    --sby           mgr/campaigns/uart_rx/refinement_v1/uart_rx_prove.sby \
    --workdir       mgr/campaigns/uart_rx/runs/r1 \
    --timeout       60
```

**Results (R1):** 18/20 KILLED → effective kill rate **90 %** ✓
(2 survivors are `#1→#0` delay true equivalents, unkillable at RTL-formal level.)

---

#### Design 3 — UART Full (`uart_full`)

RTL target for mutation: `uart_tx.v` (TX state machine, the primary logic file of the full-UART design).
Full RTL set: `uart_full.v`, `uart_tx.v`, `uart_rx.v`.

**Step 1 — Generate mutants:**

```bash
python3 mgr/tools/mutant_generator.py \
    --rtl    mgr/campaigns/uart_full/baseline/uart_tx.v \
    --out    mgr/campaigns/uart_full/mutants/r1 \
    --design uart_full \
    --max-mutants 20
```

**Step 2 — Audit mutants:**

```bash
python3 mgr/tools/audit_runner.py \
    --manifest      mgr/campaigns/uart_full/mutants/r1/manifest.json \
    --rtl-files     mgr/campaigns/uart_full/baseline/uart_full.v \
                    mgr/campaigns/uart_full/baseline/uart_tx.v \
                    mgr/campaigns/uart_full/baseline/uart_rx.v \
    --harness-files mgr/campaigns/uart_full/baseline/uart_full_formal.sv \
    --sby           mgr/campaigns/uart_full/baseline/uart_full_prove.sby \
    --workdir       mgr/campaigns/uart_full/runs/r1 \
    --timeout       120
```

**Results (R1):** 18/20 KILLED → effective kill rate **90 %** ✓

---

#### Design 4 — UP8 Minimal CPU (`up8`)

RTL target for mutation: `up8_cpu.v` (8-bit pipelined CPU).

The UP8 core requires preprocessor flags (`FORMAL`, `UP8_INLINE_ROM`, `UP8_FORMAL_ROMONLY`)
that are already baked into the baseline `.sby` file in the campaign directory.

**Step 1 — Generate mutants:**

```bash
python3 mgr/tools/mutant_generator.py \
    --rtl    mgr/campaigns/up8/baseline/up8_cpu.v \
    --out    mgr/campaigns/up8/mutants/r1 \
    --design up8 \
    --max-mutants 20
```

**Step 2 — Audit mutants:**

```bash
python3 mgr/tools/audit_runner.py \
    --manifest      mgr/campaigns/up8/mutants/r1/manifest.json \
    --rtl-files     mgr/campaigns/up8/baseline/up8_cpu.v \
                    mgr/campaigns/up8/baseline/up8_inline_rom.vh \
    --harness-files mgr/campaigns/up8/baseline/up8_add1_formal.sv \
    --sby           mgr/campaigns/up8/baseline/up8_add1_prove.sby \
    --workdir       mgr/campaigns/up8/runs/r1 \
    --timeout       120
```

**Results (R1):** 20/20 KILLED → effective kill rate **100 %** ✓

---

#### Design 5 — SHA3 / Keccak (`sha3`)

RTL target for mutation: `keccak.v` (Keccak-f permutation core).
Full RTL set: all `.v` files in `mgr/campaigns/sha3/baseline/`.

**Step 1 — Generate mutants:**

```bash
python3 mgr/tools/mutant_generator.py \
    --rtl    mgr/campaigns/sha3/baseline/keccak.v \
    --out    mgr/campaigns/sha3/mutants/r1 \
    --design sha3 \
    --max-mutants 20
```

**Step 2 — Audit mutants:**

```bash
python3 mgr/tools/audit_runner.py \
    --manifest      mgr/campaigns/sha3/mutants/r1/manifest.json \
    --rtl-files     mgr/campaigns/sha3/baseline/keccak.v \
                    mgr/campaigns/sha3/baseline/padder.v \
                    mgr/campaigns/sha3/baseline/padder1.v \
                    mgr/campaigns/sha3/baseline/f_permutation.v \
                    mgr/campaigns/sha3/baseline/round2in1.v \
                    mgr/campaigns/sha3/baseline/rconst2in1.v \
    --harness-files mgr/campaigns/sha3/baseline/sha3_keccak_prove_formal.sv \
    --sby           mgr/campaigns/sha3/baseline/sha3_prove.sby \
    --workdir       mgr/campaigns/sha3/runs/r1 \
    --timeout       120
```

**Results (R1):** 20/20 KILLED → effective kill rate **100 %** ✓

---

#### Design 6 — SDRAM Controller (`sdram`)

RTL target for mutation: `sdram.v` (SDRAM controller with Xilinx IO stubs).
Full RTL set: `sdram.v`, `iobuf_stub.v`, `oddr2_stub.v`. Iterative campaign over 4 rounds.

**Step 1 — Generate mutants:**

```bash
python3 mgr/tools/mutant_generator.py \
    --rtl    mgr/campaigns/sdram/baseline/sdram.v \
    --out    mgr/campaigns/sdram/mutants/r1 \
    --design sdram \
    --max-mutants 20
```

**Step 2 — Audit mutants (R4 shown):**

```bash
python3 mgr/tools/audit_runner.py \
    --manifest      mgr/campaigns/sdram/mutants/r1/manifest.json \
    --rtl-files     mgr/campaigns/sdram/refinement_v4/sdram.v \
                    mgr/campaigns/sdram/baseline/iobuf_stub.v \
                    mgr/campaigns/sdram/baseline/oddr2_stub.v \
    --harness-files mgr/campaigns/sdram/refinement_v4/sdram_prove_formal.sv \
    --sby           mgr/campaigns/sdram/refinement_v4/sdram_prove.sby \
    --workdir       mgr/campaigns/sdram/runs/r4 \
    --timeout       120
```

**Results (R4, plateau):** 7/19 effective → **36.8 %** ✓
(8 INVALID; 4 surviving mutants are timing-parameter true equivalents beyond practical BMC depth.)

---

#### Design 7 — VGA Vertical Timing (`vga_lcd`)

RTL target for mutation: `vga_vtim.v` (5-state VGA timing FSM, 174 lines).

**Step 1 — Generate mutants:**

```bash
python3 mgr/tools/mutant_generator.py \
    --rtl    mgr/campaigns/vga_lcd/baseline/vga_vtim.v \
    --out    mgr/campaigns/vga_lcd/mutants/r1 \
    --design vga_vtim \
    --max-mutants 20
```

**Step 2 — Audit mutants (R2 shown):**

```bash
python3 mgr/tools/audit_runner.py \
    --manifest      mgr/campaigns/vga_lcd/mutants/r1/manifest.json \
    --rtl-files     mgr/campaigns/vga_lcd/baseline/timescale.v \
                    mgr/campaigns/vga_lcd/refinement_v2/vga_vtim.v \
    --harness-files mgr/campaigns/vga_lcd/refinement_v2/vga_vtim_prove_formal.sv \
    --sby           mgr/campaigns/vga_lcd/refinement_v2/vga_vtim_prove.sby \
    --workdir       mgr/campaigns/vga_lcd/runs/r2 \
    --timeout       120
```

**Results (R2):** 18/20 KILLED → effective kill rate **90 %** ✓
R1 was 14/20 (70 %); cycle-count gate assertions added in R2 killed 4 more mutants.

> **Yosys SMTBMC note:** Use `$past(dut_output)` rather than `$past(harness_tracking_reg)` — the solver treats local tracking registers as unconstrained in the initial state, making such assertions vacuously true at step 0.

---

#### Design 8 — Pipelined FFT 256 / CNORM (`pipelined_fft_256`)

RTL target for mutation: `cnorm.v` (CNORM normalisation + OVF detection unit, 133 lines).
The `FFT256_CONFIG.inc` macro file (defines `nb=10`) lives in the campaign directory along with the RTL copy.

**Step 1 — Generate mutants:**

```bash
python3 mgr/tools/mutant_generator.py \
    --rtl    mgr/campaigns/pipelined_fft_256/baseline/cnorm.v \
    --out    mgr/campaigns/pipelined_fft_256/mutants/r1 \
    --design cnorm \
    --max-mutants 20
```

**Step 2 — Audit mutants (R2 shown):**

```bash
python3 mgr/tools/audit_runner.py \
    --manifest      mgr/campaigns/pipelined_fft_256/mutants/r1/manifest.json \
    --rtl-files     mgr/campaigns/pipelined_fft_256/refinement_v2/cnorm.v \
                    mgr/campaigns/pipelined_fft_256/refinement_v2/FFT256_CONFIG.inc \
    --harness-files mgr/campaigns/pipelined_fft_256/refinement_v2/cnorm_prove_formal.sv \
    --sby           mgr/campaigns/pipelined_fft_256/refinement_v2/cnorm_prove.sby \
    --workdir       mgr/campaigns/pipelined_fft_256/runs/r2 \
    --timeout       60
```

**Results (R2):** 15/16 effective → **93.8 %** ✓
R1 was 14/16 (87.5 %); adding `A_ovf_shift3_nb1_fire` (OVF must fire when `DR[nb+3] ≠ DR[nb+1]` in SHIFT=11) killed M016 in R2.
The single survivor (M001) mutates code inside an untaken `` `ifdef FFT256round `` block — a true equivalent.

---

#### Starting a New Refinement Round

If the effective kill rate is below the threshold, create a new round directory, copy
in the RTL files and the updated harness, then repeat Steps 1–2:

```bash
# Example: starting refinement_v3 for uart_rx
ROUND=mgr/campaigns/uart_rx/refinement_v3
mkdir -p "$ROUND"
cp mgr/campaigns/uart_rx/refinement_v2/uart_rx.v "$ROUND/"

# Place the new harness and .sby in $ROUND, then run:
python3 mgr/tools/mutant_generator.py \
    --rtl    "$ROUND/uart_rx.v" \
    --out    mgr/campaigns/uart_rx/mutants/r3 \
    --design uart_rx \
    --max-mutants 20

python3 mgr/tools/audit_runner.py \
    --manifest      mgr/campaigns/uart_rx/mutants/r3/manifest.json \
    --rtl-files     "$ROUND/uart_rx.v" \
    --harness-files "$ROUND/<new_harness>.sv" \
    --sby           "$ROUND/<new_prove>.sby" \
    --workdir       mgr/campaigns/uart_rx/runs/r3 \
    --timeout       60
```

> **Convention:** each `refinement_vN/` directory is immutable once created — never
> overwrite a completed round. Always start a new `refinement_v(N+1)/`.

---

#### MGR Kill Rate Summary

| Design | Round | Total | KILLED | SURVIVED | INVALID | Effective Kill Rate |
|---|---|---|---|---|---|---|
| `and2bit` | R1 (`baseline`) | 20 | 20 | — | — | **100 %** ✓ |
| `uart_rx` | R1 (`refinement_v1`) | 20 | 18 | 2 | — | **90 %** ✓ ‡ |
| `uart_full` | R1 (`refinement_v1`) | 20 | 18 | 2 | — | **90 %** ✓ ‡ |
| `up8` | R1 (`refinement_v1`) | 20 | 20 | — | — | **100 %** ✓ |
| `sha3` | R1 (`refinement_v1`) | 20 | 20 | — | — | **100 %** ✓ |
| `sdram` | R1 (`refinement_v1`) | 27 | 6 | 13 | 8 | 31.6 % |
| `sdram` | R4 (`refinement_v4`) | 19 | 7 | 4 | 8 | **36.8 %** ✓ § |
| `vga_lcd` | R1 (`refinement_v1`) | 20 | 14 | 6 | — | 70 % |
| `vga_lcd` | R2 (`refinement_v2`) | 20 | 18 | 2 | — | **90 %** ✓ ‡ |
| `pipelined_fft_256` (CNORM) | R1 (`refinement_v1`) | 20 | 14 | 2 | 4 | 87.5 % |
| `pipelined_fft_256` (CNORM) | R2 (`refinement_v2`) | 20 | 15 | 1 | 4 | **93.8 %** ✓ ‡ |

‡ Remaining survivors are **true equivalents** (non-blocking delay `#1→#0` or dead `` `ifdef `` branches compiled out by the preprocessor); no assertion can kill them.
§ Plateau is structural: 4 surviving mutants alter timing-parameter logic whose observable effect lies beyond any practical BMC depth. 8 INVALID mutants excluded from effective count.
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

The SDRAM design references Xilinx primitives (`IOBUF`, `ODDR2`) that are not part
of the design. Stub files in `examples/sdram/` provide empty module definitions so
Yosys can elaborate the hierarchy.

```bash
python3 manage_formal.py sdram 30 \
    examples/sdram/iobuf_stub.v \
    examples/sdram/oddr2_stub.v \
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

#### Design 5 — SHA3 / Keccak (`sha3`)

```bash
python3 manage_formal.py keccak 80 \
    examples/sha3/f_permutation.v \
    examples/sha3/keccak.v \
    examples/sha3/padder.v \
    examples/sha3/padder1.v \
    examples/sha3/rconst2in1.v \
    examples/sha3/round2in1.v \
    --formal_sv  examples/sha3/formal/sha3_keccak_prove_formal.sv \
    --formal_top sha3_keccak_prove_formal
```

Output: `examples/sha3/formal/keccak_auto.sby`

> **Note:** The RTL module is named `keccak` (lowercase); pass `keccak` as the
> `top_module` argument, not `sha3_keccak_prove_formal`.

---

#### Design 6 — VGA Vertical Timing (`vga_vtim`)

The `vga_vtim` module is self-contained and can be run without pulling in the full
`vga_enh_top` design hierarchy.

```bash
python3 manage_formal.py vga_vtim 20 \
    examples/vga_lcd_latest/timescale.v \
    examples/vga_lcd_latest/vga_vtim.v \
    --formal_sv  mgr/campaigns/vga_lcd/refinement_v2/vga_vtim_prove_formal.sv \
    --formal_top vga_vtim_prove_formal
```

Output: `mgr/campaigns/vga_lcd/refinement_v2/vga_vtim_auto.sby`

---

#### Design 7 — Pipelined FFT 256 / CNORM (`CNORM`)

The `CNORM` module (note: uppercase) includes `FFT256_CONFIG.inc` via a `` `include ``
directive. Run `manage_formal.py` from the campaign directory where both `cnorm.v`
and `FFT256_CONFIG.inc` are co-located.

```bash
python3 manage_formal.py CNORM 30 \
    mgr/campaigns/pipelined_fft_256/refinement_v2/cnorm.v \
    --formal_sv  mgr/campaigns/pipelined_fft_256/refinement_v2/cnorm_prove_formal.sv \
    --formal_top cnorm_prove_formal
```

Output: `mgr/campaigns/pipelined_fft_256/refinement_v2/CNORM_auto.sby`

---

#### Design 8 — UP8 Minimal CPU (`up8_cpu`) ⚠ Exception

The UP8 core requires preprocessor flags (`FORMAL`, `UP8_INLINE_ROM`,
`UP8_FORMAL_ROMONLY`) that are passed via a special `read` command already present
in the campaign `.sby` file. `manage_formal.py` cannot elaborate `up8_cpu.v` without
those flags, so solver selection is done via the campaign artifacts instead.

Use the pre-built proof directly:

```bash
sby -f mgr/campaigns/up8/baseline/up8_add1_prove.sby
```

The `.sby` file already contains the correct solver choice (yices, via the
`D_M > 0.35` rule) and preprocessor flags.

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

---

## Agent IV — Causal Narrative Synthesis (CNS)

> **Note:** This agent calls an LLM to generate explanations.
> To reproduce results, set the `LLM_API_KEY` environment variable.
> Without it, `cns_agent.py` writes prompts to disk so they can be submitted manually
> or via another API client.

CNS takes a failed BMC counterexample — the failing assertion, the mutation applied,
and the signal trace — and produces a concise, structured root-cause narrative:

1. **Cycle identification** — the step at which the assertion fires.
2. **Signal attribution** — the signals directly responsible for the failure.
3. **Failure mechanism class** — one of six categories:
   `missing_state_transition`, `stuck_signal`, `overflow_flag_error`,
   `handshake_failure`, `pointer_index_bug`, `timing_progression_error`.
4. **Root-cause sentence** — a one-sentence causal explanation.

### Prerequisites

```bash
pip install anthropic
export LLM_API_KEY=<your-key>
```

### Input Format

Each case is a JSON file in `cns/cases/`. Required fields:

```json
{
  "case_id": "C1",
  "failing_assertion_text": "assert (OVF == 0);",
  "failing_assertion_name": "A_no_spurious_ovf",
  "failing_assertion_file": "cnorm_prove_formal.sv",
  "failing_assertion_line": 42,
  "original_snippet": "if (A > B)",
  "mutated_snippet": "if (!(A > B))",
  "target_module": "CNORM",
  "source_line": 78,
  "mutation_class": "predicate_inversion",
  "trace_path": "<path/to/trace_tb.v>",
  "key_signals": ["OVF", "START", "ED"],
  "first_bad_cycle": 1
}
```

`trace_path` points to the `trace_tb.v` file produced by `sby` when a BMC
counterexample is found. `key_signals` are the signal names to emphasise in the trace table.

### Running CNS

**Run a single case:**

```bash
python3 cns/cns_agent.py --case cns/cases/C1.json
```

**Run all 8 benchmark cases:**

```bash
python3 cns/cns_agent.py --all
```

Responses are saved to `cns/responses_r2/` (the default round directory).

**Score responses against ground truth:**

```bash
python3 cns/cns_agent.py --score
```

Output: per-case JSON files in `cns/scored_r2/` with binary flags
(`correct_cycle`, `correct_signal`, `correct_mechanism`, `unsupported_claims`,
`overall_faithful`), and a summary table.

### Refinement Rounds

The `--round` flag controls which response/scored subdirectory is used:

```bash
# Round 1: zero-shot baseline
python3 cns/cns_agent.py --all --round 1

# Round 2: refined prompt (default)
python3 cns/cns_agent.py --all --round 2
```

Round 1 responses are already cached in `cns/responses_r1/`.
Round 2 responses are in `cns/responses_r2/`.

### Benchmark Cases

Eight BMC failures across four designs are included as benchmarks:

| ID | Design | Mutation class | First bad cycle | Root cause class |
|----|--------|---------------|-----------------|-----------------|
| C1 | FFT CNORM | predicate_inversion | 1 | overflow_flag_error |
| C2 | FFT CNORM | equality_flip | 1 | overflow_flag_error |
| C3 | FFT CNORM | predicate_inversion | 1 | stuck_signal |
| C4 | VGA LCD | predicate_inversion | 1 | missing_state_transition |
| C5 | VGA LCD | predicate_inversion | 7 | missing_state_transition |
| C6 | UART RX | equality_flip | 13 | timing_progression_error |
| C7 | UART RX | predicate_inversion | 31 | handshake_failure |
| C8 | SHA3 | constant_perturbation | 27 | pointer_index_bug |

### CNS Evaluation Results

Scoring uses four binary metrics per case. A response is `overall_faithful` only if
all four pass. Ground truth was written before any LLM response was generated
(blind evaluation).

| Round | Correct Cycle | Correct Signals | Correct Mechanism | Unsupported Claims | Overall Faithful |
|-------|--------------|-----------------|-------------------|--------------------|-----------------|
| R1 (zero-shot) | 4/8 | 8/8 | 5/8 | 0 | 3/8 |
| R2 (refined prompt) | 8/8 | 8/8 | 8/8 | 0 | **8/8** |

The prompt refinements that drove R1 → R2 improvement:

- **Step anchor (R1 fix):** Explicitly telling the model that the assertion fires at
  step `first_bad_cycle` — not at the first cycle of signal divergence — fixed all
  four cycle mis-attributions.
- **Mechanism guide (R2 fix):** Providing tight definitions for each of the six
  failure classes, with distinguishing symptoms and explicit warnings (e.g., "use
  `stuck_signal` when a data register is frozen; use `missing_state_transition` only
  for the FSM state register itself"), fixed all three mechanism mis-classifications
  (C3: stuck_signal; C7: handshake_failure; C8: pointer_index_bug).
