#!/usr/bin/env python3
"""Resolve a stable cvc5 git tag.

Behavior:
- If env var CVC5_TAG is set and non-empty, prints it.
- Otherwise, queries tags from the cvc5 upstream repo and prints the highest
  stable tag matching: cvc5-X.Y.Z

This is kept as a standalone script so it can be unit-tested outside Docker and
keeps the Dockerfile readable.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from typing import Iterable


_STABLE_TAG_RE = re.compile(r"^cvc5-(\d+)\.(\d+)\.(\d+)$")


def _pick_highest_stable(tags: Iterable[str]) -> str:
    best_version: tuple[int, int, int] | None = None
    best_tag: str | None = None

    for tag in tags:
        tag = tag.strip()
        if not tag:
            continue
        match = _STABLE_TAG_RE.match(tag)
        if not match:
            continue

        version = (int(match.group(1)), int(match.group(2)), int(match.group(3)))
        if best_version is None or version > best_version:
            best_version = version
            best_tag = tag

    if best_tag is None:
        raise RuntimeError("No stable tags found matching cvc5-X.Y.Z")

    return best_tag


def _tags_from_git_ls_remote(repo: str, pattern: str) -> list[str]:
    out = subprocess.check_output(
        ["git", "ls-remote", "--tags", "--refs", repo, pattern],
        text=True,
    )

    tags: list[str] = []
    for line in out.splitlines():
        parts = line.split()
        if len(parts) != 2:
            continue
        ref = parts[1]
        if not ref.startswith("refs/tags/"):
            continue
        tags.append(ref.removeprefix("refs/tags/"))

    return tags


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--repo",
        default="https://github.com/cvc5/cvc5.git",
        help="Remote repo URL to query for tags.",
    )
    parser.add_argument(
        "--pattern",
        default="cvc5-*",
        help="git ls-remote pattern used to filter tags.",
    )
    parser.add_argument(
        "--from-stdin",
        action="store_true",
        help="Read tags (one per line) from stdin instead of querying git.",
    )
    args = parser.parse_args()

    explicit = os.environ.get("CVC5_TAG", "").strip()
    if explicit:
        print(explicit)
        return 0

    if args.from_stdin:
        tags = [line.strip() for line in sys.stdin]
    else:
        tags = _tags_from_git_ls_remote(args.repo, args.pattern)

    try:
        print(_pick_highest_stable(tags))
        return 0
    except Exception as exc:  # noqa: BLE001
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
