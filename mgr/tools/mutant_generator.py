#!/usr/bin/env python3
"""
mutant_generator.py

Prototype mutation generator for RTL mutation-guided refinement (MGR).

Scope:
- Targets a single Verilog/SystemVerilog file
- Generates one-change-only mutants
- Uses conservative, line-local text transformations
- Emits:
    1. mutated RTL files
    2. manifest.json with mutation metadata

Recommended first use:
    python mutant_generator.py \
        --rtl /mnt/data/uart_tx.v \
        --out ./mgr_out/uart_tx_mutants \
        --design uart_tx
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple


@dataclass
class MutationRecord:
    mutant_id: str
    design: str
    source_file: str
    mutant_file: str
    line_no: int
    mutation_class: str
    original_snippet: str
    mutated_snippet: str
    status: str


@dataclass
class MutationCandidate:
    line_no: int
    mutation_class: str
    original_snippet: str
    mutated_snippet: str
    priority: int


# ----------------------------
# Helpers
# ----------------------------

def load_lines(path: Path) -> List[str]:
    return path.read_text(encoding="utf-8").splitlines(keepends=True)


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def is_comment_or_blank(line: str) -> bool:
    s = line.strip()
    return (not s) or s.startswith("//")


def is_structural_declaration(line: str) -> bool:
    stripped = line.strip()
    if re.match(r"^(reg|logic)\b", stripped):
        return True
    if re.match(r"^wire\b", stripped) and "=" not in stripped:
        return True
    return False


def discover_state_symbols(lines: List[str]) -> List[str]:
    symbols: List[str] = []
    seen: Set[str] = set()

    for line in lines:
        stripped = line.strip()
        m_case = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*begin", stripped)
        if m_case:
            sym = m_case.group(1)
            if sym not in seen:
                seen.add(sym)
                symbols.append(sym)

    if symbols:
        return symbols

    for line in lines:
        m = re.search(r"\blocalparam\b.*?\b([A-Z][A-Za-z0-9_]*)\s*=", line)
        if m:
            sym = m.group(1)
            if sym not in seen:
                seen.add(sym)
                symbols.append(sym)
    return symbols


def compute_line_contexts(lines: List[str]) -> Dict[int, Dict[str, object]]:
    contexts: Dict[int, Dict[str, object]] = {}
    in_reset_block = False
    current_case_label: Optional[str] = None

    for idx, line in enumerate(lines, start=1):
        stripped = line.strip()

        if re.match(r"^\w+\s*:\s*begin", stripped):
            current_case_label = stripped.split(":", 1)[0].strip()
        elif stripped.startswith("endcase"):
            current_case_label = None

        if re.search(r"\bif\s*\(\s*!?\s*(rst|reset)\s*\)\s*begin", stripped):
            in_reset_block = True

        contexts[idx] = {
            "in_reset_block": in_reset_block,
            "case_label": current_case_label,
        }

        if in_reset_block and re.search(r"\bend\s+else\s+begin\b", stripped):
            in_reset_block = False

    return contexts


def replace_first_once(pattern: str, repl: str, text: str) -> Optional[str]:
    new_text, n = re.subn(pattern, repl, text, count=1)
    if n == 1 and new_text != text:
        return new_text
    return None


# ----------------------------
# Mutation generators
# ----------------------------

def score_candidate(mutation_class: str, line: str, context: Dict[str, object]) -> int:
    base = {
        "state_retarget": 130,
        "predicate_inversion": 120,
        "equality_flip": 110,
        "bit_literal_flip": 100,
        "arithmetic_step_flip": 95,
        "index_shift": 90,
        "constant_perturbation": 85,
        "boolean_operator": 75,
    }.get(mutation_class, 50)

    if context.get("in_reset_block"):
        base -= 45

    if is_structural_declaration(line):
        base -= 80

    if any(tok in line for tok in ["state", "baud_tick", "tx_serial", "tx_busy", "bit_idx", "shift_reg"]):
        base += 10

    if context.get("case_label") in {"SIdle", "SStart", "SData", "SStop"}:
        base += 8

    return base

def gen_predicate_inversion(line: str) -> List[Tuple[str, str, str]]:
    """
    Match simple if (...) lines and invert the predicate.
    Returns list of (mutation_class, original, mutated_line)
    """
    results = []
    if "if" not in line:
        return results

    m = re.search(r"\bif\s*\((.+)\)", line)
    if not m:
        return results

    cond = m.group(1).strip()

    # Avoid already-negated simple cases for now to keep mutations interpretable
    if cond.startswith("!"):
        return results

    original = line.rstrip("\n")
    mutated = line.replace(f"if ({cond})", f"if (!({cond}))", 1)
    if mutated != line:
        results.append(("predicate_inversion", original, mutated.rstrip("\n")))
    return results


def gen_equality_mutations(line: str) -> List[Tuple[str, str, str]]:
    results = []
    if "==" in line:
        mutated = line.replace("==", "!=", 1)
        if mutated != line:
            results.append(("equality_flip", line.rstrip("\n"), mutated.rstrip("\n")))
    elif "!=" in line:
        mutated = line.replace("!=", "==", 1)
        if mutated != line:
            results.append(("equality_flip", line.rstrip("\n"), mutated.rstrip("\n")))
    return results


def gen_boolean_operator_mutations(line: str) -> List[Tuple[str, str, str]]:
    """
    Conservative operator mutations.
    Only mutate one operator per line.
    """
    candidates = [
        (r"(?<![|])&(?![&])", "|"),     # single &
        (r"(?<![&])\|(?![|])", "&"),    # single |
        (r"(?<!\^)\^(?!\^)", "~^"),     # ^
        (r"~\^", "^"),                  # ~^
    ]

    results = []
    for pattern, repl in candidates:
        mutated = replace_first_once(pattern, repl, line)
        if mutated is not None:
            results.append(("boolean_operator", line.rstrip("\n"), mutated.rstrip("\n")))
    return results


def gen_bit_literal_flips(line: str) -> List[Tuple[str, str, str]]:
    results = []

    for old, new in [("1'b0", "1'b1"), ("1'b1", "1'b0")]:
        if old in line:
            mutated = line.replace(old, new, 1)
            if mutated != line:
                results.append(("bit_literal_flip", line.rstrip("\n"), mutated.rstrip("\n")))
            break

    m = re.search(r"(\b\d+'d)(\d+)\b", line)
    if m:
        width = int(m.group(1).split("'", 1)[0])
        value = int(m.group(2))
        alt_value = 1 if value == 0 else value - 1
        if 0 <= alt_value < (1 << width):
            mutated = line[:m.start(2)] + str(alt_value) + line[m.end(2):]
            if mutated != line:
                results.append(("bit_literal_flip", line.rstrip("\n"), mutated.rstrip("\n")))

    return results


def gen_arithmetic_step_mutations(line: str) -> List[Tuple[str, str, str]]:
    results = []
    patterns = [
        (r"\+\s*1'b1", "+ 1'b0"),
        (r"\+\s*1'b1", "- 1'b1"),
        (r"\+\s*1\b", "+ 0"),
        (r"\+\s*1\b", "- 1"),
    ]

    for pattern, repl in patterns:
        mutated = replace_first_once(pattern, repl, line)
        if mutated is not None:
            results.append(("arithmetic_step_flip", line.rstrip("\n"), mutated.rstrip("\n")))
            break

    return results


def gen_index_shift_mutations(line: str) -> List[Tuple[str, str, str]]:
    results = []
    replacements = [
        (r"\[0\]", "[1]"),
        (r"\[7:1\]", "[6:0]"),
        (r"\[6:0\]", "[7:1]"),
    ]

    for pattern, repl in replacements:
        mutated = replace_first_once(pattern, repl, line)
        if mutated is not None:
            results.append(("index_shift", line.rstrip("\n"), mutated.rstrip("\n")))
            break

    return results


def gen_state_retarget_mutations(line: str, state_symbols: List[str]) -> List[Tuple[str, str, str]]:
    results = []
    m = re.search(r"\bstate\s*<=\s*([A-Za-z_][A-Za-z0-9_]*)", line)
    if not m:
        return results

    current = m.group(1)
    if current not in state_symbols:
        return results

    alternatives = [sym for sym in state_symbols if sym != current]
    if not alternatives:
        return results

    mutated = line.replace(current, alternatives[0], 1)
    if mutated != line:
        results.append(("state_retarget", line.rstrip("\n"), mutated.rstrip("\n")))
    return results


def gen_constant_perturbations(line: str) -> List[Tuple[str, str, str]]:
    """
    Mutate decimal literals conservatively.
    Examples:
      3'd7  -> 3'd8
      10    -> 11

    Avoid mutating:
    - parameter declarations
    - localparam declarations
    - timescale
    - comments-only lines
    """
    stripped = line.strip()
    if any(tok in stripped for tok in ["parameter", "localparam", "`timescale"]):
        return []

    if is_structural_declaration(line):
        return []

    results = []

    # Width-qualified decimal, e.g. 3'd7
    m = re.search(r"(\b\d+'d)(\d+)\b", line)
    if m:
        width = int(m.group(1).split("'", 1)[0])
        old_num = int(m.group(2))
        candidate_values = [old_num - 1, old_num + 1]
        for new_num in candidate_values:
            if 0 <= new_num < (1 << width):
                mutated = line[:m.start(2)] + str(new_num) + line[m.end(2):]
                if mutated != line:
                    results.append(("constant_perturbation", line.rstrip("\n"), mutated.rstrip("\n")))
                    break
        return results

    # Plain decimal integer, but avoid literal width noise such as 1'b1.
    if "'" in line:
        return results

    # Require it to appear in expressions / comparisons / assignments.
    if any(sym in line for sym in ["==", "!=", "<", ">", "<=", ">=", "=", "+", "-"]):
        m2 = re.search(r"\b(\d+)\b", line)
        if m2:
            old_num = int(m2.group(1))
            candidate_values = [old_num - 1, old_num + 1]
            for new_num in candidate_values:
                if new_num >= 0:
                    mutated = line[:m2.start(1)] + str(new_num) + line[m2.end(1):]
                    if mutated != line:
                        results.append(("constant_perturbation", line.rstrip("\n"), mutated.rstrip("\n")))
                        break

    return results


def generate_mutations_for_line(
    line: str,
    line_no: int,
    state_symbols: List[str],
    context: Dict[str, object],
) -> List[MutationCandidate]:
    if is_comment_or_blank(line):
        return []

    mutations: List[Tuple[str, str, str]] = []
    if context.get("case_label") != "default":
        mutations.extend(gen_state_retarget_mutations(line, state_symbols))
    mutations.extend(gen_predicate_inversion(line))
    mutations.extend(gen_equality_mutations(line))
    mutations.extend(gen_boolean_operator_mutations(line))
    mutations.extend(gen_bit_literal_flips(line))
    mutations.extend(gen_arithmetic_step_mutations(line))
    mutations.extend(gen_index_shift_mutations(line))
    mutations.extend(gen_constant_perturbations(line))

    # Deduplicate by mutated line content
    seen = set()
    unique: List[MutationCandidate] = []
    for mutation_class, original, mutated_line in mutations:
        key = (mutation_class, mutated_line)
        if key not in seen:
            seen.add(key)
            unique.append(
                MutationCandidate(
                    line_no=line_no,
                    mutation_class=mutation_class,
                    original_snippet=original,
                    mutated_snippet=mutated_line,
                    priority=score_candidate(mutation_class, line, context),
                )
            )
    return unique


# ----------------------------
# Main generation flow
# ----------------------------

def build_mutant_text(lines: List[str], line_no_1based: int, mutated_line_no_nl: str) -> str:
    new_lines = list(lines)
    new_lines[line_no_1based - 1] = mutated_line_no_nl + "\n"
    return "".join(new_lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--rtl", required=True, help="Path to target RTL file, e.g. uart_tx.v")
    parser.add_argument("--out", required=True, help="Output directory for mutants and manifest")
    parser.add_argument("--design", required=True, help="Design name, e.g. uart_tx")
    parser.add_argument("--max-mutants", type=int, default=30, help="Maximum mutants to emit")
    parser.add_argument("--exclude-classes", nargs="*", default=[], metavar="CLASS",
                        help="Mutation classes to exclude, e.g. arithmetic_step_flip")
    args = parser.parse_args()

    rtl_path = Path(args.rtl).resolve()
    out_dir = Path(args.out).resolve()
    mutants_dir = out_dir / "mutants"
    manifest_path = out_dir / "manifest.json"

    lines = load_lines(rtl_path)
    state_symbols = discover_state_symbols(lines)
    contexts = compute_line_contexts(lines)

    records: List[MutationRecord] = []
    candidates: List[MutationCandidate] = []

    for idx, line in enumerate(lines, start=1):
        candidates.extend(generate_mutations_for_line(line, idx, state_symbols, contexts[idx]))

    candidates.sort(key=lambda c: (-c.priority, c.line_no, c.mutation_class, c.mutated_snippet))

    if args.exclude_classes:
        excluded = set(args.exclude_classes)
        before = len(candidates)
        candidates = [c for c in candidates if c.mutation_class not in excluded]
        print(f"[INFO] Excluded {before - len(candidates)} candidates from classes: {excluded}")

    mutant_counter = 1
    seen_mutants: Set[str] = set()
    for cand in candidates:
        mutant_text = build_mutant_text(lines, cand.line_no, cand.mutated_snippet)
        if mutant_text in seen_mutants:
            continue
        seen_mutants.add(mutant_text)

        mutant_id = f"M{mutant_counter:03d}"
        mutant_filename = f"{rtl_path.stem}__{mutant_id}.v"
        mutant_path = mutants_dir / mutant_filename

        write_text(mutant_path, mutant_text)

        records.append(
            MutationRecord(
                mutant_id=mutant_id,
                design=args.design,
                source_file=str(rtl_path),
                mutant_file=str(mutant_path),
                line_no=cand.line_no,
                mutation_class=cand.mutation_class,
                original_snippet=cand.original_snippet,
                mutated_snippet=cand.mutated_snippet,
                status="generated",
            )
        )

        mutant_counter += 1
        if len(records) >= args.max_mutants:
            break

    out_dir.mkdir(parents=True, exist_ok=True)
    manifest = {
        "design": args.design,
        "source_file": str(rtl_path),
        "total_mutants": len(records),
        "mutants": [asdict(r) for r in records],
    }
    write_text(manifest_path, json.dumps(manifest, indent=2))

    print(f"[OK] Generated {len(records)} mutants")
    print(f"[OK] Manifest: {manifest_path}")
    print(f"[OK] Mutants dir: {mutants_dir}")


if __name__ == "__main__":
    main()