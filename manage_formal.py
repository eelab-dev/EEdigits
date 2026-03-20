#!/usr/bin/env python3
"""
manage_formal.py  –  Predictive Solver Portfolio (PSP) orchestrator.

Pipeline (run in order):
  1. run_yosys_stats()      – invoke Yosys on the RTL to produce a full log
                              containing a 'stat -json' block.
  2. extract_clean_json()   – strip the JSON stats block from the raw log
                              using extract_stat_json.py.
  3. analyze_complexity()   – compute structural complexity metrics
                              (D_A, D_M, W, D_R, I_C, CHI_NORM) from the JSON.
  4. select_solver()        – pick the best SMT backend based on the metrics.
  5. generate_sby()         – write a SymbiYosys (.sby) config ready to run.

Usage:
  python3 manage_formal.py <top_module> <k_depth> <rtl_files...>
      [--formal_sv <harness.sv>]
      [--formal_top <formal_top_module>]
      [--prep_flags <extra_yosys_prep_flags>]

Exceptions handled separately:
  - up8_minimal  : requires --prep_flags "-chparam MEM_SIZE 65536" and
                   special read flags in the [script] section (see up8 README).
  - generic_fifo : use RTL from examples/generic_fifo_lfsr/repro_todo2_aw16_d15/active/
"""

import os
import sys
import subprocess
import argparse
from extract_complexity_metrics import analyze_complexity


def run_yosys_stats(top_module, v_files, ys_file, dump_file):
    """
    Write a temporary Yosys script, run it, and save the full stdout log.

    The script runs: read_verilog -> hierarchy -> proc/opt -> stat -json.
    The full log (including the embedded JSON stats block) is written to
    dump_file for downstream parsing by extract_clean_json().
    """
    yosys_script = f"""
read_verilog -sv {' '.join(v_files)}
hierarchy -check -top {top_module}
proc; opt;
stat -json -top {top_module}
"""

    with open(ys_file, "w") as f:
        f.write(yosys_script)

    print("[FRAMEWORK] Running Yosys statistics extraction...")

    result = subprocess.run(
        ["yosys", "-s", ys_file],
        capture_output=True,
        text=True
    )

    with open(dump_file, "w") as f:
        f.write(result.stdout)

    if result.returncode != 0:
        print("[ERROR] Yosys failed.")
        if result.stderr:
            print(result.stderr)
        sys.exit(1)

    print(f"[FRAMEWORK] Yosys log written to {dump_file}")
    return dump_file


def extract_clean_json(dump_file, json_file, extractor_script):
    """
    Parse the raw Yosys log and isolate the 'stat -json' JSON block.

    Calls extract_stat_json.py with the log on stdin; the clean JSON is
    written to json_file and returned for consumption by analyze_complexity().
    """
    print("[FRAMEWORK] Extracting clean JSON statistics...")

    subprocess.run(
        ["python3", extractor_script, dump_file, json_file],
        check=True
    )

    return json_file


def select_solver(metrics, k_depth):
    """
    Rule-based solver selection using structural metrics.

    Current evidence from 8 benchmarks suggests:
      - Bitwuzla is best for very wide datapaths and symbolic-pointer style cases.
      - Yices is best for control-heavy, memory-heavy, and moderate-width pipelined logic.
      - chi_norm is a summary score, not a direct solver selector.

    Decision priority (first matching rule wins):
      1. W_norm > 0.50  (very wide datapath)                -> Bitwuzla
      2. D_M   > 0.35   (high mux/control density)          -> Yices
      3. I_C   > 0.35 AND W_norm < 0.10  (symbolic-pointer) -> Bitwuzla
      4. D_A   > 0.30 AND W_norm < 0.25  (pipelined arith)  -> Yices
      5. D_R_norm > 0.30  (memory-heavy)                    -> Yices
      Default                                               -> Yices
    """
    w_norm = metrics["W_norm"]
    da = metrics["D_A"]
    dm = metrics["D_M"]
    dr_norm = metrics["D_R_norm"]
    ic = metrics["I_C"]

    # 1. Very wide datapaths -> Bitwuzla
    if w_norm > 0.50:
        return "smtbmc bitwuzla", f"Wide-word datapath detected (W_norm={w_norm:.2f})."

    # 2. High mux/control density -> Yices
    if dm > 0.35:
        return "smtbmc yices", f"High control density detected (D_M={dm:.2f})."

    # 3. Symbolic-pointer / high-index narrow designs -> Bitwuzla
    if ic > 0.35 and w_norm < 0.10:
        return "smtbmc bitwuzla", f"High index complexity with narrow datapath detected (I_C={ic:.2f}, W_norm={w_norm:.2f})."

    # 4. Arithmetic-heavy but not wide -> Yices
    if da > 0.30 and w_norm < 0.25:
        return "smtbmc yices", f"Arithmetic-heavy moderate-width pipeline detected (D_A={da:.2f}, W_norm={w_norm:.2f})."

    # 5. Memory-heavy -> Yices
    if dr_norm > 0.30:
        return "smtbmc yices", f"Memory-heavy design detected (D_R_norm={dr_norm:.2f})."

    # Default
    return "smtbmc yices", "Defaulting to Yices for general control-oriented or mixed RTL."

def generate_sby(top_module, v_files, engine, k_depth, sby_file, formal_sv=None, formal_top=None, prep_flags=""):
    """
    Write a SymbiYosys (.sby) configuration file.

    The [script] section uses bare filenames (sby copies all [files] into its
    working directory before running Yosys), so only the basename is needed.
    The [files] section uses paths relative to the .sby file location.
    """
    sby_dir = os.path.dirname(sby_file)

    # [script] section: read RTL by basename, then read formal harness if provided
    script_lines = [f"read -formal {os.path.basename(f)}" for f in v_files]

    if formal_sv:
        script_lines.append(f"read -formal {os.path.basename(formal_sv)}")

    prep_top = formal_top if formal_top else top_module
    script_lines.append(f"prep -top {prep_top} {prep_flags}")

    # [files] section: relative paths from the .sby location
    file_lines = [os.path.relpath(f, start=sby_dir) for f in v_files]

    if formal_sv:
        file_lines.append(os.path.relpath(formal_sv, start=sby_dir))

    sby_content = f"""[options]
mode bmc
depth {k_depth}

[engines]
{engine}

[script]
{chr(10).join(script_lines)}

[files]
{chr(10).join(file_lines)}
"""
    with open(sby_file, "w") as f:
        f.write(sby_content)
    
    return sby_file

def main():
    parser = argparse.ArgumentParser(
        description="Automatically choose a SymbiYosys solver from RTL structural metrics and generate an .sby file."
    )
    parser.add_argument("top_module", help="Top RTL module name")
    parser.add_argument("k_depth", type=int, help="BMC depth")
    parser.add_argument("v_files", nargs="+", help="Verilog/SystemVerilog source files")
    parser.add_argument("--formal_sv", help="Path to formal harness .sv file")
    parser.add_argument("--formal_top", help="Top module name inside the formal harness")
    parser.add_argument("--prep_flags", default="", help="Extra flags appended to prep")

    args = parser.parse_args()

    top = args.top_module
    k = args.k_depth

    # Convert all RTL paths to absolute paths
    v_files = [os.path.abspath(vf) for vf in args.v_files]

    #parser.add_argument("--formal_top", help="Top module name inside the formal harness")
    formal_sv = os.path.abspath(args.formal_sv) if args.formal_sv else None
    formal_top = args.formal_top if args.formal_top else top

    # Put generated artifacts in the directory of the first RTL file
    design_dir = os.path.dirname(v_files[0])
    output_dir = os.path.dirname(formal_sv) if formal_sv else design_dir

    # Path to helper extractor script (same folder as manage_formal.py)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    extractor_script = os.path.join(script_dir, "extract_stat_json.py")

    # Artifact paths inside the design folder
    ys_file = os.path.join(design_dir, "temp_stats.ys")
    dump_file = os.path.join(design_dir, "design_dump.log")
    json_file = os.path.join(design_dir, "design_stats.json")
    sby_file = os.path.join(output_dir, f"{top}_auto.sby")

    # 1. Run Yosys and save full dump
    run_yosys_stats(top, v_files, ys_file, dump_file)

    # 2. Extract clean JSON stats
    extract_clean_json(dump_file, json_file, extractor_script)

    # 3. Analyze complexity
    metrics = analyze_complexity(json_file)
    print(
        f"[FRAMEWORK] Metrics: "
        f"W={metrics['W']}, "
        f"D_A={metrics['D_A']:.2f}, "
        f"D_M={metrics['D_M']:.2f}, "
        f"D_R={metrics['D_R']}, "
        f"Chi={metrics['CHI_NORM']:.2f}"
    )

    # 4. Decide solver
    engine, reason = select_solver(metrics, k)
    solver_name = engine.split()[-1]
    print(f"[FRAMEWORK] {reason} Selecting {solver_name} solver.")

    # 5. Generate SBY
    generate_sby(top, v_files, engine, k, sby_file, formal_sv=formal_sv, formal_top=formal_top,
                   prep_flags=args.prep_flags)
    print(f"[FRAMEWORK] Configuration generated: {sby_file}")
    print(f"[FRAMEWORK] To run: sby -f <sby_file>")


if __name__ == "__main__":
    main()