#!/usr/bin/env python3
"""
Extract the Yosys `stat -json` block from a full Yosys log.

Usage:
    python3 extract_stat_json.py design_dump.log design_stats.json
"""

import sys

MARKER = "Finished fast OPT passes"


def extract_json_block(log_text: str) -> str:
    """Extract the balanced JSON object after the Yosys OPT marker."""
    marker_pos = log_text.find(MARKER)
    if marker_pos == -1:
        raise RuntimeError(f"Marker not found: {MARKER!r}")

    start = log_text.find("{", marker_pos)
    if start == -1:
        raise RuntimeError("No JSON object found after the marker.")

    depth = 0
    in_string = False
    escape = False

    for i, ch in enumerate(log_text[start:], start=start):
        if in_string:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_string = False
            continue

        if ch == '"':
            in_string = True
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return log_text[start:i + 1]

    raise RuntimeError("Unbalanced braces while extracting JSON.")


def main() -> None:
    if len(sys.argv) != 3:
        print("Usage: python3 extract_stat_json.py <design_dump.log> <design_stats.json>")
        print("Input: full Yosys log containing 'stat -json' output")
        print("Output: clean JSON stats file")
        sys.exit(1)

    input_log = sys.argv[1]
    output_json = sys.argv[2]

    try:
        with open(input_log, "r") as f:
            log_text = f.read()

        json_text = extract_json_block(log_text)

        with open(output_json, "w") as f:
            f.write(json_text)

        print(f"[INFO] Extracted JSON written to: {output_json}")

    except FileNotFoundError:
        print(f"[ERROR] Input file not found: {input_log}")
        sys.exit(1)
    except RuntimeError as e:
        print(f"[ERROR] {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()