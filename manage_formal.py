import os
import sys
import subprocess
import argparse
from extract_complexity_metrics import analyze_complexity


def run_yosys_stats(top_module, v_files, ys_file, dump_file):
    """Run Yosys and save the full log."""
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
    """Use the existing extractor script to produce clean JSON."""
    print("[FRAMEWORK] Extracting clean JSON statistics...")

    with open(dump_file, "r") as fin, open(json_file, "w") as fout:
        subprocess.run(
            ["python3", extractor_script],
            stdin=fin,
            stdout=fout,
            text=True,
            check=True
        )

    return json_file


def select_solver(metrics, k_depth):
    """Rule-based solver selector based on current 6-benchmark evidence."""
    w_norm = metrics["W_norm"]
    da = metrics["D_A"]
    dm = metrics["D_M"]
    dr_norm = metrics["D_R_norm"]
    ic = metrics["I_C"]
    chi = metrics["CHI_NORM"]

    if w_norm > 0.50:
        return "smtbmc bitwuzla", f"Wide-word datapath detected (W_norm={w_norm:.2f})."

    if dm > 0.35:
        return "smtbmc yices", f"High control density detected (D_M={dm:.2f})."

    if da > 0.25:
        return "smtbmc bitwuzla", f"Arithmetic-heavy datapath detected (D_A={da:.2f})."

    if ic > 0.35:
        return "smtbmc bitwuzla", f"High index/interface complexity detected (I_C={ic:.2f})."

    if dr_norm > 0.30:
        return "smtbmc yices", f"Memory-heavy design detected (D_R_norm={dr_norm:.2f})."

    if chi > 0.25:
        return "smtbmc bitwuzla", f"Elevated normalized complexity detected (Chi={chi:.2f})."

    return "smtbmc yices", f"Defaulting to Yices for general control-oriented RTL (Chi={chi:.2f})."

def generate_sby(top_module, v_files, engine, k_depth, sby_file, formal_sv=None, formal_top=None, prep_flags=""):
    """Write the .sby configuration file."""
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