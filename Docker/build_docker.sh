#!/bin/bash
set -e

# Determine the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Go to the root of the repository (parent of Docker directory)
REPO_ROOT="${SCRIPT_DIR}/.."

# Image name
IMAGE_NAME="danchitnis/digital-tools"

echo "Building Docker image: $IMAGE_NAME"

# Build the image
# Context is set to the repository root
docker build -t "$IMAGE_NAME" -f "${SCRIPT_DIR}/Dockerfile" "$REPO_ROOT"

echo "Build complete!"
