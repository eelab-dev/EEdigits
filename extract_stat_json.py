#!/usr/bin/env python3
import sys

MARKER = "Finished fast OPT passes"

def extract_balanced_json(text: str, start: int) -> str:
    depth = 0
    in_string = False
    escape = False

    for i, ch in enumerate(text[start:], start=start):
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
                return text[start:i+1]

    raise SystemExit("Unbalanced braces while extracting JSON.")

def main():
    s = sys.stdin.read()

    # 1) Find marker line, then find the first '{' after it
    m = s.find(MARKER)
    if m == -1:
        raise SystemExit(f"Marker not found: {MARKER!r}. Did the log format change?")

    start = s.find("{", m)
    if start == -1:
        raise SystemExit("No '{' found after marker. Did stat -json run?")

    sys.stdout.write(extract_balanced_json(s, start))

if __name__ == "__main__":
    main()