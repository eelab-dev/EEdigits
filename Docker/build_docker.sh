#!/bin/bash
set -e

# Determine the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Go to the root of the repository (parent of Docker directory)
REPO_ROOT="${SCRIPT_DIR}/.."

# Image name
IMAGE_REPO="danchitnis/eedigits"
IMAGE_TAG="${IMAGE_TAG:-latest}"
IMAGE_NAME="${IMAGE_REPO}:${IMAGE_TAG}"

# Parse arguments
NO_CACHE=""
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --no-cache) NO_CACHE="--no-cache"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
done

echo "Building Docker image: $IMAGE_NAME"

# Build the image
# Context is set to the repository root
build_args=()
if [ -n "${CVC5_TAG:-}" ]; then
	echo "Using pinned CVC5 tag from env: $CVC5_TAG"
	build_args+=( --build-arg "CVC5_TAG=$CVC5_TAG" )
else
	echo "CVC5_TAG not set; Dockerfile will resolve latest stable tag"
fi

docker build \
	$NO_CACHE \
	"${build_args[@]}" \
	-t "$IMAGE_NAME" \
	-f "${SCRIPT_DIR}/Dockerfile" \
	"$REPO_ROOT"

# Convenience: also tag without an explicit tag when using 'latest'
if [ "$IMAGE_TAG" = "latest" ]; then
	docker tag "$IMAGE_NAME" "$IMAGE_REPO"
fi

echo "Build complete!"
