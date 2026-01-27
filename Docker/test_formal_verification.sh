#!/bin/bash
set -e

# Image name
IMAGE_NAME="danchitnis/digital-tools"

# Determine the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Path to examples (one level up from Docker directory)
EXAMPLES_DIR="${SCRIPT_DIR}/../examples/and2bit"

echo "Running formal verification using Docker image: $IMAGE_NAME"

# Run the formal verification inside the container
# We copy to a temp directory to avoid creating root-owned artifacts on the host
docker run --rm \
    -v "$EXAMPLES_DIR":/workspace:ro \
    $IMAGE_NAME \
    sh -c "cp -r /workspace /tmp/sandbox && cd /tmp/sandbox/formal && sby -f and2bit_prove.sby && sby -f and2bit_cover.sby"

if [ $? -eq 0 ]; then
    echo "Formal verification completed successfully!"
else
    echo "Formal verification failed!"
    exit 1
fi
