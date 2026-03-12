import json
import sys

# -----------------------------
# Normalization / weighting knobs
# -----------------------------
W_REF = 64
DR_REF = 1048576   # 1 Mbit reference
EPS = 1e-9

W_WEIGHT = 0.40
DM_WEIGHT = 0.35
DA_WEIGHT = 0.15
DR_WEIGHT = 0.05
IC_WEIGHT = 0.05


def analyze_complexity(filename):
    with open(filename, "r") as f:
        stats = json.load(f)

    design = stats["design"]

    # Define cell categories
    arith_types = [
        "$add", "$sub", "$mul", "$alu",
        "$shl", "$shr", "$lt", "$le",
        "$eq", "$ne", "$gt", "$ge"
    ]
    mux_types = ["$mux", "$pmux"]
    ignored_types = ["$meminit_v2", "$meminit"]  # Static data, not logic

    cells = design["num_cells_by_type"]

    # Total logic cells: remove ignored memory-init cells and submodule refs
    total_logic_cells = design["num_cells"]
    for cell_type, count in cells.items():
        if cell_type in ignored_types:
            total_logic_cells -= count
        elif not cell_type.startswith("$"):
            total_logic_cells -= count

    # Count arithmetic / mux cells
    da_count = sum(cells.get(t, 0) for t in arith_types)
    dm_count = sum(cells.get(t, 0) for t in mux_types)

    # Structural densities
    da = da_count / total_logic_cells if total_logic_cells > 0 else 0.0
    dm = dm_count / total_logic_cells if total_logic_cells > 0 else 0.0

    # Word size (excluding ports)
    int_wires = design["num_wires"] - design["num_ports"]
    int_bits = design["num_wire_bits"] - design["num_port_bits"]
    w = round(int_bits / int_wires) if int_wires > 0 else 1

    # Memory bits
    dr = design.get("num_memory_bits", 0)

    # Index complexity
    num_wire_bits = design["num_wire_bits"]
    ic = design["num_port_bits"] / num_wire_bits if num_wire_bits > 0 else 0.0

    # -----------------------------
    # Original analytic chi
    # chi = (D_A * W) + D_M + (D_R / I_C)
    # -----------------------------
    chi_analytic = (da * w) + dm + (dr / max(ic, EPS))

    # -----------------------------
    # Fixed-reference normalization
    # -----------------------------
    w_norm = min(w / W_REF, 1.0)
    dr_norm = min(dr / DR_REF, 1.0)

    # -----------------------------
    # Normalized weighted chi
    # -----------------------------
    chi_norm = (
        W_WEIGHT * w_norm +
        DM_WEIGHT * dm +
        DA_WEIGHT * da +
        DR_WEIGHT * dr_norm +
        IC_WEIGHT * ic
    )

    return {
        "D_A": round(da, 6),
        "D_M": round(dm, 6),
        "W": w,
        "W_norm": round(w_norm, 6),
        "D_R": dr,
        "D_R_norm": round(dr_norm, 6),
        "I_C": round(ic, 6),
        "Logic_Cells": total_logic_cells,
        "CHI_ANALYTIC": round(chi_analytic, 6),
        "CHI_NORM": round(chi_norm, 6),
    }


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 extract_complexity_metrics.py <design_stats.json>")
        sys.exit(1)

    filename = sys.argv[1]
    metrics = analyze_complexity(filename)

    print("\nComplexity Metrics")
    print("------------------")
    for k, v in metrics.items():
        print(f"{k}: {v}")