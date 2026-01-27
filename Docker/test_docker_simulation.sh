#!/bin/bash
set -e

# Image name
IMAGE_NAME="danchitnis/digital-tools"

# Determine the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Path to examples (one level up from Docker directory)
EXAMPLES_DIR="${SCRIPT_DIR}/../examples/and2bit"

echo "Running simulation using Docker image: $IMAGE_NAME"

# Run the simulation inside the container
# We copy to a temp directory to avoid creating root-owned artifacts on the host
docker run --rm \
    -v "$EXAMPLES_DIR":/workspace:ro \
    $IMAGE_NAME \
    sh -c "cp -r /workspace /tmp/sandbox && cd /tmp/sandbox && iverilog -g2012 -o and2bit_test and2bit.v tb_and2bit.v && vvp and2bit_test"

if [ $? -eq 0 ]; then
    echo "Simulation completed successfully!"
else
    echo "Simulation failed!"
    exit 1
fi
