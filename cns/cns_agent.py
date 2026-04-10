#!/usr/bin/env python3
"""
cns_agent.py — Causal Narrative Synthesis for formal-verification failures.

Usage:
    python3 cns_agent.py --case cns/cases/C1.json [--model <model-id>]
    python3 cns_agent.py --all                      # run all cases in cns/cases/
    python3 cns_agent.py --score                    # score existing responses vs GT

Outputs:
    cns/responses/<case_id>.txt    — raw CNS narrative
    cns/scored/<case_id>.json      — per-case binary scores

Environment:
    LLM_API_KEY — if set, calls the LLM API.
                  If absent, writes cns/responses/<case_id>.prompt
                  so the prompt can be pasted manually.
"""

from __future__ import annotations
import argparse
import json
import os
import re
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
BASE = Path(__file__).parent
CASES_DIR  = BASE / "cases"
RESP_DIR   = BASE / "responses"
SCORED_DIR = BASE / "scored"
GT_FILE    = BASE / "ground_truth.json"

RESP_DIR.mkdir(parents=True, exist_ok=True)
SCORED_DIR.mkdir(parents=True, exist_ok=True)

DEFAULT_MODEL = "claude-opus-4-5"

# ---------------------------------------------------------------------------
# Fixed CNS prompt template  (Round 2 — R1 step anchor + R2 mechanism guide)
# ---------------------------------------------------------------------------
PROMPT_TEMPLATE = """\
[FAILING ASSERTION]
{failing_assertion_text}
(property name: {failing_assertion_name}, file: {failing_assertion_file}:{failing_assertion_line})

[MUTATION APPLIED]
Original : {original_snippet}
Mutated  : {mutated_snippet}
(module: {target_module}, source line: {source_line}, class: {mutation_class})

[RTL CONTEXT]
{rtl_context}

[COUNTEREXAMPLE TRACE]
{trace_table}

[ASSERTION FIRED AT STEP]  ← R1  (step-anchor refinement)
The BMC counterexample ends at step {first_bad_cycle}: the failing assertion above
fires at cycle {first_bad_cycle}.  The trace covers cycles 0 through {first_bad_cycle}.
The mutation may cause a signal to deviate from its expected value as early as
cycle 1, but the PROPERTY FAILURE occurs at cycle {first_bad_cycle}.
For liveness-style assertions ("eventually X must be true within N steps"),
report {first_bad_cycle} as the first-bad cycle, NOT the first cycle of wire divergence.

Task:
Identify and state concisely:
1. The cycle at which the assertion fires (this is cycle {first_bad_cycle}).  Also
   note the first cycle in 0..{first_bad_cycle} where a signal first deviates from
   its expected value.  If the assertion is a liveness time-out, report {first_bad_cycle}.
2. The signal(s) directly responsible for the assertion failure (name them exactly
   as they appear in the trace).
3. The failure mechanism class — choose the MOST SPECIFIC applicable class:  ← R2

   missing_state_transition : An FSM state register fails to advance to the next
     encoded state because the transition guard is false/inverted.
     Symptom: the state register holds the same encoded value for extra cycles.

   stuck_signal : A DATA register (not the FSM state) retains a stale value
     because its write-enable or update condition is false/inverted.  The FSM may
     be advancing normally; only this one data register is frozen.
     Symptom: one output or pipeline register stays constant while others change.

   overflow_flag_error : A flag (OVF, carry, overflow, shift indicator) is set
     or cleared under the wrong arithmetic or comparison condition.

   handshake_failure : A dedicated one-per-period completion/acknowledge/tick
     signal is inverted so the receiver acts on every NON-completion cycle instead
     of the single completion cycle.  The signal is a periodic strobe, not a
     free-running counter terminal-count.

   pointer_index_bug : A shift-register slice width or array index expression is
     wrong (e.g. i[8:0] instead of i[9:0]), so a one-hot or binary counter can
     never reach the required bit position regardless of elapsed time.

   timing_progression_error : A free-running counter's terminal-count comparison
     is wrong (e.g. != instead of ==), causing a timer to fire at the wrong period
     or never.  Use ONLY when the counter is free-running AND the error is NOT
     caused by an inverted handshake strobe or a pointer/index width mismatch.

4. A one-sentence root-cause explanation.

STRICT RULE: Do not mention any signal, event, or internal state that is not
visible in the trace or RTL context above.
"""

# ---------------------------------------------------------------------------
# RTL context extraction
# ---------------------------------------------------------------------------

def extract_rtl_context(source_file: str, line_no: int, radius: int = 12) -> str:
    """Return ±radius lines around the mutated line from source_file."""
    if not source_file:
        return "[No source file specified]"
    p = Path(source_file)
    if not p.exists():
        # Try relative to workspace root
        for candidate in [
            Path("/workspaces/digital-tools") / source_file,
            Path("/workspaces/digital-tools/examples") / p.name,
        ]:
            if candidate.exists():
                p = candidate
                break
        else:
            return f"[Source file not found: {source_file}]"
    lines = p.read_text(errors="replace").splitlines()
    start = max(0, line_no - radius - 1)
    end   = min(len(lines), line_no + radius)
    result = []
    for i, ln in enumerate(lines[start:end], start=start + 1):
        marker = ">>>" if i == line_no else "   "
        result.append(f"{marker} {i:4d} | {ln}")
    return "\n".join(result)


# ---------------------------------------------------------------------------
# Trace table extraction from trace_tb.v
# ---------------------------------------------------------------------------

def extract_trace_table(case: dict) -> str:
    """
    Build a compact cycle | signal | value table from the trace_tb.v that was
    produced by the sby run for this case.
    """
    trace_path = case.get("trace_path")
    if not trace_path or not Path(trace_path).exists():
        return "[Trace file not available — see case JSON for trace_path]"

    text = Path(trace_path).read_text(errors="replace")

    # Signals we care about (from key_signals + extras)
    key_sigs = set(case.get("key_signals", []))

    # Parse: initial state block (before always @)
    # and per-cycle state blocks (// state N ... if (cycle == N-1))
    rows: dict[int, dict[str, str]] = {}  # cycle -> {signal: value}

    # Initial state is at cycle 0 (before clock edge 0)
    init_block_match = re.search(
        r'initial begin.*?always @\(posedge clock\)',
        text, re.DOTALL
    )
    init_text = init_block_match.group(0) if init_block_match else ""

    # Per-cycle blocks
    cycle_blocks = re.findall(
        r'// state (\d+)\s+if \(cycle == (\d+)\) begin(.*?)end',
        text, re.DOTALL
    )

    def parse_assignments(block: str) -> dict[str, str]:
        assigns = {}
        for m in re.finditer(
            r'UUT\.(?:dut\.|dut_fixed\.)?(\w+)\s*(?:<=|=)\s*([^;]+);',
            block
        ):
            sig = m.group(1)
            val = m.group(2).strip()
            # compress long binary literals
            if len(val) > 40:
                val = val[:37] + "..."
            # convert plain binary to hex if long
            assigns[sig] = val
        return assigns

    # Initial state at step -1 (the combinational state before first clock)
    init_assigns = parse_assignments(init_text)
    rows[0] = init_assigns  # represents "before step 1" / initial values

    for state_str, cycle_str, block in cycle_blocks:
        cycle = int(cycle_str) + 1  # cycle N in driver fires on posedge of cycle N
        assigns = parse_assignments(block)
        rows[cycle] = assigns

    # Collect all signal names seen
    all_sigs: list[str] = []
    for r in rows.values():
        for s in r:
            if s not in all_sigs:
                all_sigs.append(s)

    # Filter to key signals only if the trace is large
    if len(all_sigs) > 20:
        display_sigs = [s for s in all_sigs if s in key_sigs]
        if not display_sigs:
            display_sigs = all_sigs[:10]
    else:
        display_sigs = all_sigs

    if not display_sigs:
        return "[No readable signal assignments found in trace]"

    # Build table
    header = f"{'Cycle':>5} | " + " | ".join(f"{s[:14]:>14}" for s in display_sigs)
    sep    = "-" * len(header)
    table_rows = [header, sep]
    for cyc in sorted(rows.keys()):
        row_data = rows[cyc]
        vals = " | ".join(
            f"{row_data.get(s, '-')[:14]:>14}"
            for s in display_sigs
        )
        table_rows.append(f"{cyc:>5} | {vals}")

    return "\n".join(table_rows)


# ---------------------------------------------------------------------------
# Build prompt
# ---------------------------------------------------------------------------

def build_prompt(case: dict) -> str:
    rtl_context = extract_rtl_context(
        case.get("source_file", case.get("mutant_file", "")),
        case.get("source_line", 0)
    )
    trace_table = extract_trace_table(case)

    return PROMPT_TEMPLATE.format(
        failing_assertion_text=case.get("failing_assertion_text", ""),
        failing_assertion_name=case.get("failing_assertion_name", ""),
        failing_assertion_file=case.get("failing_assertion_file", ""),
        failing_assertion_line=case.get("failing_assertion_line", ""),
        original_snippet=case.get("original_snippet", ""),
        mutated_snippet=case.get("mutated_snippet", ""),
        target_module=case.get("target_module", ""),
        source_line=case.get("source_line", ""),
        mutation_class=case.get("mutation_class", ""),
        rtl_context=rtl_context,
        trace_table=trace_table,
        first_bad_cycle=case.get("first_bad_cycle", "?"),  # R1: step anchor
    )


# ---------------------------------------------------------------------------
# API call
# ---------------------------------------------------------------------------

def call_llm(prompt: str, model: str) -> str:
    try:
        import anthropic  # type: ignore
    except ImportError:
        print("[cns_agent] anthropic package not installed. Run: pip install anthropic", file=sys.stderr)
        sys.exit(1)

    client = anthropic.Anthropic(api_key=os.environ["LLM_API_KEY"])
    message = client.messages.create(
        model=model,
        max_tokens=1024,
        messages=[{"role": "user", "content": prompt}],
    )
    return message.content[0].text


def run_case(case: dict, model: str) -> str:
    """Run CNS for one case and return the response text."""
    case_id   = case["case_id"]
    resp_file = RESP_DIR / f"{case_id}.txt"

    if resp_file.exists():
        print(f"[cns_agent] {case_id}: cached response found at {resp_file}")
        return resp_file.read_text()

    prompt = build_prompt(case)

    api_key = os.environ.get("LLM_API_KEY", "")
    if api_key:
        print(f"[cns_agent] {case_id}: calling {model} …")
        response = call_llm(prompt, model)
        resp_file.write_text(response)
        print(f"[cns_agent] {case_id}: saved → {resp_file}")
    else:
        prompt_file = RESP_DIR / f"{case_id}.prompt"
        prompt_file.write_text(prompt)
        print(f"[cns_agent] {case_id}: LLM_API_KEY not set. Prompt saved → {prompt_file}")
        response = ""

    return response


# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------

MECHANISM_CLASSES = {
    "missing_state_transition",
    "stuck_signal",
    "overflow_flag_error",
    "handshake_failure",
    "pointer_index_bug",
    "timing_progression_error",
}


def score_response(gt: dict, response: str) -> dict:
    """
    Score a CNS response against one ground-truth entry.
    Returns dict with binary scores.
    """
    response_l = response.lower()

    # ── 1. correct_cycle ─────────────────────────────────────────────────────
    gt_cycle = gt["first_bad_cycle"]
    cycle_pattern = re.compile(r'cycle\s*[:#]?\s*(\d+)', re.IGNORECASE)
    found_cycles = [int(m.group(1)) for m in cycle_pattern.finditer(response)]
    correct_cycle = any(abs(c - gt_cycle) <= 1 for c in found_cycles)

    # ── 2. correct_signal ────────────────────────────────────────────────────
    key_sigs = [s.lower() for s in gt["key_signals"]]
    correct_signal = any(s in response_l for s in key_sigs)

    # ── 3. correct_mechanism ─────────────────────────────────────────────────
    gt_mech = gt["root_cause_class"]
    # Accept the exact class name or its human-readable equivalent
    mech_aliases: dict[str, list[str]] = {
        "missing_state_transition": ["missing state transition", "missing_state_transition", "state transition"],
        "stuck_signal":             ["stuck signal", "stuck_signal", "stuck at"],
        "overflow_flag_error":      ["overflow flag", "overflow_flag_error", "ovf", "spurious overflow"],
        "handshake_failure":        ["handshake failure", "handshake_failure", "handshake"],
        "pointer_index_bug":        ["pointer index", "pointer_index_bug", "index bug", "shift register slice"],
        "timing_progression_error": ["timing progression", "timing_progression_error", "counter inversion",
                                     "terminal count", "baud", "counter-done"],
    }
    aliases = mech_aliases.get(gt_mech, [gt_mech])
    correct_mechanism = any(alias in response_l for alias in aliases)

    # ── 4. unsupported_claims ────────────────────────────────────────────────
    # Signals mentioned in response that are NOT visible in trace OR RTL context.
    # Strategy: build an allowed set from key_signals + every identifier that
    # appears in the RTL context extracted for this GT entry, then check.
    sig_candidates = re.findall(r'\b([A-Za-z_][A-Za-z0-9_]{2,})\b', response)

    all_trace_sigs = {s.lower() for s in gt["key_signals"]}

    # Extract all identifiers visible in the RTL context for this case.
    _src_file = gt.get("source_file", gt.get("mutant_file", ""))
    _src_line = gt.get("source_line", 0)
    if _src_file:
        rtl_ctx = extract_rtl_context(_src_file, _src_line)
    else:
        rtl_ctx = ""
    rtl_identifiers = {tok.lower() for tok in re.findall(r'\b([A-Za-z_][A-Za-z0-9_]+)\b', rtl_ctx)}

    # Also allow identifiers appearing in the failing assertion text itself.
    assertion_identifiers = {
        tok.lower()
        for tok in re.findall(r'\b([A-Za-z_][A-Za-z0-9_]+)\b', gt.get("failing_assertion_text", ""))
    }

    # General allowed vocabulary (non-signal terms always present in explanations)
    generic_allowed = {
        gt["target_module"].lower(), "cycle", "assert", "property",
        gt["failing_assertion_name"].lower(),
        "original", "mutated", "mutation", "register", "signal",
        "inverted", "inversion", "predicate", "assertion", "boundary",
        "terminal", "counter", "period", "liveness", "trace", "state",
        "strobe", "guard", "block", "value", "chain", "position", "window",
        "clock", "edge", "posedge", "bit", "byte", "frame", "tick",
        "width", "slice", "order", "phase", "count", "path", "arm",
        "case", "module", "flip", "spurious", "first", "last",
        "inverting", "flipping", "replacing", "narrowing", "widening",
        "setting", "clearing", "gating", "sampling", "capturing",
    }

    allowed = all_trace_sigs | rtl_identifiers | assertion_identifiers | generic_allowed

    # Flag identifiers that look like signal/state names (snake_case or internal CamelCase)
    # but are not in the combined allowed set.  Require underscore OR internal uppercase
    # (not just a leading capital, which catches plain English sentences).
    unsupported = [
        s for s in sig_candidates
        if s.lower() not in allowed
        and s.lower() not in MECHANISM_CLASSES
        and len(s) > 3
        and (re.search(r'_', s) or re.search(r'[A-Z]', s[1:]))  # snake_case OR internal CamelCase
    ]
    unsupported_count = len(set(unsupported))

    overall_faithful = (
        correct_cycle and correct_signal and correct_mechanism and unsupported_count == 0
    )

    return {
        "case_id":            gt["case_id"],
        "correct_cycle":      int(correct_cycle),
        "correct_signal":     int(correct_signal),
        "correct_mechanism":  int(correct_mechanism),
        "unsupported_claims": unsupported_count,
        "overall_faithful":   int(overall_faithful),
        "found_cycles":       found_cycles,
        "gt_cycle":           gt_cycle,
        "gt_mechanism":       gt["root_cause_class"],
    }


def score_all(gt_cases: list[dict]) -> list[dict]:
    # Build a lookup of case JSON files so we can supply source_file for RTL context.
    case_files = {f.stem: f for f in sorted(CASES_DIR.glob("C*.json"))}

    results = []
    for gt in gt_cases:
        resp_file = RESP_DIR / f"{gt['case_id']}.txt"
        if not resp_file.exists():
            print(f"[score] {gt['case_id']}: no response file, skipping")
            continue
        response = resp_file.read_text()

        # Enrich GT with source_file / source_line from the case file (if available)
        if gt["case_id"] in case_files:
            try:
                case_data = json.loads(case_files[gt["case_id"]].read_text())
                gt = {**gt, **{k: case_data[k] for k in ("source_file", "source_line") if k in case_data}}
            except Exception:
                pass

        scored = score_response(gt, response)
        out_file = SCORED_DIR / f"{gt['case_id']}.json"
        out_file.write_text(json.dumps(scored, indent=2))
        results.append(scored)
        print(f"[score] {gt['case_id']}: C={scored['correct_cycle']} "
              f"S={scored['correct_signal']} M={scored['correct_mechanism']} "
              f"U={scored['unsupported_claims']} Faith={scored['overall_faithful']}")
    return results


def print_summary_table(results: list[dict]) -> None:
    if not results:
        print("No scored results found.")
        return
    print("\n" + "=" * 70)
    print(f"{'CaseID':8} {'Cyc':>4} {'Sig':>4} {'Mech':>5} {'Unsup':>6} {'Faith':>6}")
    print("-" * 70)
    for r in results:
        print(f"{r['case_id']:8} {r['correct_cycle']:>4} {r['correct_signal']:>4} "
              f"{r['correct_mechanism']:>5} {r['unsupported_claims']:>6} "
              f"{r['overall_faithful']:>6}")
    n = len(results)
    print("-" * 70)
    print(f"{'TOTAL':8} {sum(r['correct_cycle'] for r in results):>4}/{n} "
          f"{sum(r['correct_signal'] for r in results):>3}/{n} "
          f"{sum(r['correct_mechanism'] for r in results):>4}/{n} "
          f"{sum(r['unsupported_claims'] for r in results):>5}  "
          f"{sum(r['overall_faithful'] for r in results):>4}/{n}")
    print("=" * 70)


# ---------------------------------------------------------------------------
# Case JSON helpers
# ---------------------------------------------------------------------------

def load_case(path: Path) -> dict:
    return json.loads(path.read_text())


def load_all_cases() -> list[dict]:
    files = sorted(CASES_DIR.glob("C*.json"))
    if not files:
        print(f"[cns_agent] No case files found in {CASES_DIR}", file=sys.stderr)
        sys.exit(1)
    return [load_case(f) for f in files]


def load_gt() -> list[dict]:
    if not GT_FILE.exists():
        print(f"[cns_agent] Ground truth file not found: {GT_FILE}", file=sys.stderr)
        sys.exit(1)
    data = json.loads(GT_FILE.read_text())
    return data["cases"]


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description="CNS agent for formal-failure analysis")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--case",  metavar="FILE",  help="Path to a single case JSON file")
    group.add_argument("--all",   action="store_true", help="Run all cases in cns/cases/")
    group.add_argument("--score", action="store_true", help="Score existing responses vs ground truth")
    parser.add_argument("--model", default=DEFAULT_MODEL, help=f"LLM model ID (default: {DEFAULT_MODEL})")
    parser.add_argument(
        "--round", type=int, default=2,
        help="Refinement round number; controls output subdirectory (default: 2)",
    )
    args = parser.parse_args()

    # Override module-level path globals so all helpers use the versioned dirs.
    global RESP_DIR, SCORED_DIR
    RESP_DIR   = BASE / f"responses_r{args.round}"
    SCORED_DIR = BASE / f"scored_r{args.round}"
    RESP_DIR.mkdir(parents=True, exist_ok=True)
    SCORED_DIR.mkdir(parents=True, exist_ok=True)
    print(f"[cns_agent] Round {args.round}  →  responses: {RESP_DIR}  scored: {SCORED_DIR}")

    if args.score:
        gt_cases = load_gt()
        results  = score_all(gt_cases)
        print_summary_table(results)
        return

    if args.all:
        cases = load_all_cases()
    else:
        cases = [load_case(Path(args.case))]

    for case in cases:
        run_case(case, args.model)


if __name__ == "__main__":
    main()
