#!/usr/bin/env sh
set -eu

# Offline test of semver resolution (no network required).
# Expected: 1.10.0 is the max, not 1.3.10.

out="$(
  printf '%s\n' \
    cvc5-1.0.0 \
    cvc5-1.3.2 \
    cvc5-1.3.10 \
    cvc5-1.10.0 \
    cvc5-2.0.0-rc1 \
    not-a-tag \
  | python3 Docker/scripts/resolve_cvc5_tag.py --from-stdin
)"

[ "$out" = "cvc5-1.10.0" ]

echo "PASS: resolved $out"
