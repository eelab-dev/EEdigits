#!/usr/bin/env python3
import os
import sys


def main() -> None:
    argv = sys.argv[1:]
    out: list[str] = []

    for arg in argv:
        if arg in ("--smt2", "-smt2"):
            # Map legacy flag to modern Bitwuzla CLI.
            out.extend(["--lang", "smt2"])
        elif arg == "-i":
            # Boolector-style interactive flag used by smtio.py; Bitwuzla reads from
            # stdin by default, so ignore it.
            continue
        else:
            out.append(arg)

    os.execv("/usr/local/bin/bitwuzla-real", ["/usr/local/bin/bitwuzla-real", *out])


if __name__ == "__main__":
    main()
