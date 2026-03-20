#!/usr/bin/env python3
"""
generate_metrics_table.py  –  Batch complexity profiler for all benchmark designs.

Walks the examples/ directory tree, finds every design_stats.json produced by
Yosys (via manage_formal.py or a manual 'yosys -s get_stats.ys' run), computes
structural metrics for each design, pretty-prints a table to stdout, and saves
the results to metrics_table.csv.

Usage:
  python3 generate_metrics_table.py

Output:
  metrics_table.csv  (written to the current directory)
"""

import os
import csv
from extract_complexity_metrics import analyze_complexity

ROOT = "examples"  # root directory to scan for design_stats.json files

results = []

for root, dirs, files in os.walk(ROOT):
    if "design_stats.json" in files:
        path = os.path.join(root, "design_stats.json")
        design = os.path.basename(root)

        metrics = analyze_complexity(path)
        metrics["Design"] = design
        results.append(metrics)

# Sort for deterministic order
results.sort(key=lambda x: x["Design"].lower())

header = [
    "Design",
    "D_A",
    "D_M",
    "W",
    "W_norm",
    "I_C",
    "D_R",
    "D_R_norm",
    "CHI_ANALYTIC",
    "CHI_NORM"
]

print("\nMetrics Table\n")

# Column formatting
row_format = "{:<18} {:>8} {:>8} {:>5} {:>8} {:>8} {:>10} {:>10} {:>15} {:>10}"

print(row_format.format(*header))
print("-" * 105)

for r in results:
    print(row_format.format(
        r["Design"],
        r["D_A"],
        r["D_M"],
        r["W"],
        r["W_norm"],
        r["I_C"],
        r["D_R"],
        r["D_R_norm"],
        r["CHI_ANALYTIC"],
        r["CHI_NORM"]
    ))

# -------------------------
# Save CSV for analysis
# -------------------------
with open("metrics_table.csv", "w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=header)
    writer.writeheader()
    for r in results:
        writer.writerow({h: r[h] for h in header})

print("\nSaved metrics_table.csv")