#!/bin/bash
set -e

# Image name
IMAGE_NAME="danchitnis/digital-tools"

# Determine the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Path to examples (one level up from Docker directory)
EXAMPLES_DIR="${SCRIPT_DIR}/../examples/and2bit"

# Solvers to test (space-separated). Defaults to testing all installed solvers.
# You can override, e.g.: SMT_SOLVERS="z3" or SMT_SOLVERS="bitwuzla cvc5".
SMT_SOLVERS="${SMT_SOLVERS:-z3 bitwuzla cvc5}"

echo "Running formal verification using Docker image: $IMAGE_NAME"

run_formal_for_solver() {
    local solver="$1"
    echo "----------------------------------------"
    echo "Testing SMT solver: $solver"

    docker run --rm \
        -e SMT_SOLVER="$solver" \
        -v "$EXAMPLES_DIR":/workspace:ro \
        "$IMAGE_NAME" \
        sh -c 'set -e; \
            cp -r /workspace /tmp/sandbox; \
            cd /tmp/sandbox/formal; \
            if [ "$SMT_SOLVER" = "z3" ]; then z3 --version >/dev/null; fi; \
            if [ "$SMT_SOLVER" = "bitwuzla" ]; then bitwuzla --version >/dev/null; fi; \
            if [ "$SMT_SOLVER" = "cvc5" ]; then cvc5 --version >/dev/null; fi; \
            sed -i -E "s/^(smtbmc)[[:space:]]+z3$/\\1 ${SMT_SOLVER}/" *.sby; \
            sby -f and2bit_prove.sby; \
            sby -f and2bit_cover.sby'
}

for solver in $SMT_SOLVERS; do
    run_formal_for_solver "$solver"
done

echo "----------------------------------------"
echo "Formal verification completed successfully for: $SMT_SOLVERS"
