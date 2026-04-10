#!/usr/bin/env python3
"""
audit_runner.py

Prototype audit runner for Mutation-Guided Refinement (MGR).

Responsibilities:
- Read manifest.json from mutant_generator.py
- For each mutant:
    - create isolated workspace
    - copy full RTL set + harness + .sby
    - replace the targeted RTL file with the mutant
    - run `sby -f <file.sby>`
    - classify result as:
        KILLED     -> FAIL
        SURVIVED   -> PASS
        TIMEOUT
        INVALID
        INCONCLUSIVE
- Emit summary.json and summary.csv

Example:
    python audit_runner.py \
        --manifest ./mgr_out/uart_tx_mutants/manifest.json \
        --rtl-files /mnt/data/uart_full.v /mnt/data/uart_rx.v /mnt/data/uart_tx.v \
        --harness-files /mnt/data/uart_full_formal.sv \
        --sby /path/to/uart_full_prove.sby \
        --workdir ./mgr_runs/uart_tx_audit \
        --timeout 120
"""

from __future__ import annotations

import argparse
import csv
import json
import shutil
import subprocess
from pathlib import Path
from typing import Dict, List


def load_json(path: Path) -> Dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: Dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")


def copy_files(files: List[Path], dst_dir: Path) -> None:
    dst_dir.mkdir(parents=True, exist_ok=True)
    for src in files:
        shutil.copy2(src, dst_dir / src.name)


def classify_run(returncode: int, stdout: str, stderr: str, timed_out: bool) -> str:
    text = "\n".join([stdout, stderr])

    if timed_out:
        return "TIMEOUT"

    lowered = text.lower()

    # SBY/Yosys style signals
    if (
        "syntax error" in lowered
        or "parse error" in lowered
        or "failed to elaborate" in lowered
        or "task failed. error" in lowered
        or "did not return a status" in lowered
        or "done (error" in lowered
        or "error:" in lowered
    ):
        return "INVALID"
    if "status: failed" in lowered or "assert failed" in lowered or "counterexample" in lowered:
        return "KILLED"
    if "status: passed" in lowered or "successful proof" in lowered:
        return "SURVIVED"

    if returncode != 0:
        return "INCONCLUSIVE"

    return "INCONCLUSIVE"


def run_cmd(cmd: List[str], cwd: Path, timeout_sec: int) -> Dict:
    try:
        proc = subprocess.run(
            cmd,
            cwd=str(cwd),
            capture_output=True,
            text=True,
            timeout=timeout_sec,
            check=False,
        )
        return {
            "returncode": proc.returncode,
            "stdout": proc.stdout,
            "stderr": proc.stderr,
            "timed_out": False,
        }
    except subprocess.TimeoutExpired as e:
        # e.stdout/stderr are bytes even when text=True — decode defensively
        raw_out = e.stdout or b""
        raw_err = e.stderr or b""
        if isinstance(raw_out, bytes):
            raw_out = raw_out.decode("utf-8", errors="replace")
        if isinstance(raw_err, bytes):
            raw_err = raw_err.decode("utf-8", errors="replace")
        return {
            "returncode": -1,
            "stdout": raw_out,
            "stderr": raw_err,
            "timed_out": True,
        }


def patch_target_rtl(workspace_src_dir: Path, original_source_file: Path, mutant_file: Path) -> None:
    """
    Replace the original RTL file in workspace/src with the mutant content,
    preserving the original filename expected by the .sby flow.
    """
    dst_file = workspace_src_dir / original_source_file.name
    mutant_text = mutant_file.read_text(encoding="utf-8")
    dst_file.write_text(mutant_text, encoding="utf-8")


def compute_summary(rows: List[Dict]) -> Dict:
    counts: Dict[str, int] = {}
    for row in rows:
        counts[row["result"]] = counts.get(row["result"], 0) + 1

    total = len(rows)
    killed = counts.get("KILLED", 0)
    survived = counts.get("SURVIVED", 0)
    effective = total - counts.get("INVALID", 0)

    summary = {
        "total_mutants": total,
        "counts": counts,
        "raw_kill_rate": (killed / total) if total else 0.0,
        "effective_mutants": effective,
        "effective_kill_rate": (killed / effective) if effective else 0.0,
        "survived_mutants": [r["mutant_id"] for r in rows if r["result"] == "SURVIVED"],
    }
    return summary


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, help="Path to manifest.json")
    parser.add_argument("--rtl-files", nargs="+", required=True, help="All RTL files used by the DUT")
    parser.add_argument("--harness-files", nargs="+", required=True, help="Formal harness .sv files")
    parser.add_argument("--sby", required=True, help="SBY file path")
    parser.add_argument("--workdir", required=True, help="Working directory for audit runs")
    parser.add_argument("--timeout", type=int, default=120, help="Timeout per mutant in seconds")
    parser.add_argument("--sby-bin", default="sby", help="Path to sby executable")
    args = parser.parse_args()

    manifest_path = Path(args.manifest).resolve()
    sby_path = Path(args.sby).resolve()
    workdir = Path(args.workdir).resolve()

    rtl_files = [Path(p).resolve() for p in args.rtl_files]
    harness_files = [Path(p).resolve() for p in args.harness_files]

    manifest = load_json(manifest_path)
    original_source_file = Path(manifest["source_file"]).resolve()

    results_rows: List[Dict] = []
    workdir.mkdir(parents=True, exist_ok=True)

    for mutant in manifest["mutants"]:
        mutant_id = mutant["mutant_id"]
        mutant_file = Path(mutant["mutant_file"]).resolve()

        mutant_run_dir = workdir / mutant_id
        logs_dir = mutant_run_dir / "logs"

        if mutant_run_dir.exists():
            shutil.rmtree(mutant_run_dir)

        mutant_run_dir.mkdir(parents=True, exist_ok=True)
        logs_dir.mkdir(parents=True, exist_ok=True)

        # Copy baseline sources alongside the .sby so bare filenames resolve
        copy_files(rtl_files, mutant_run_dir)
        copy_files(harness_files, mutant_run_dir)
        shutil.copy2(sby_path, mutant_run_dir / sby_path.name)

        # Patch mutated file into the run dir (overwrites the baseline copy)
        patch_target_rtl(mutant_run_dir, original_source_file, mutant_file)

        # Run SBY
        cmd = [args.sby_bin, "-f", sby_path.name]
        run = run_cmd(cmd, cwd=mutant_run_dir, timeout_sec=args.timeout)
        result = classify_run(
            returncode=run["returncode"],
            stdout=run["stdout"],
            stderr=run["stderr"],
            timed_out=run["timed_out"],
        )

        # Persist logs
        (logs_dir / "stdout.log").write_text(run["stdout"], encoding="utf-8")
        (logs_dir / "stderr.log").write_text(run["stderr"], encoding="utf-8")

        row = {
            "mutant_id": mutant_id,
            "mutation_class": mutant["mutation_class"],
            "line_no": mutant["line_no"],
            "original_snippet": mutant["original_snippet"],
            "mutated_snippet": mutant["mutated_snippet"],
            "result": result,
            "run_dir": str(mutant_run_dir),
        }
        results_rows.append(row)

        print(f"[{mutant_id}] {result} :: line {mutant['line_no']} :: {mutant['mutation_class']}")

    # Write CSV
    csv_path = workdir / "summary.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "mutant_id",
                "mutation_class",
                "line_no",
                "original_snippet",
                "mutated_snippet",
                "result",
                "run_dir",
            ],
        )
        writer.writeheader()
        writer.writerows(results_rows)

    summary = compute_summary(results_rows)
    summary["rows"] = results_rows
    write_json(workdir / "summary.json", summary)

    print("\n=== Audit Summary ===")
    print(json.dumps(summary, indent=2))
    print(f"\n[OK] CSV: {csv_path}")
    print(f"[OK] JSON: {workdir / 'summary.json'}")


if __name__ == "__main__":
    main()