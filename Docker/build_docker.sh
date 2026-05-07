#!/bin/bash
set -e

# Determine the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Go to the root of the repository (parent of Docker directory)
REPO_ROOT="${SCRIPT_DIR}/.."

# Image name
IMAGE_REPO="danchitnis/eedigits"

# Parse arguments
NO_CACHE=""
BUILD_AMD64=false
BUILD_ARM64=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --no-cache) NO_CACHE="--no-cache"; shift ;;
        --amd64) BUILD_AMD64=true; shift ;;
        --arm64) BUILD_ARM64=true; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
done

if [ "$BUILD_AMD64" = false ] && [ "$BUILD_ARM64" = false ]; then
    echo "Please specify an architecture: --amd64 or --arm64"
    echo "Usage: $0 [--amd64] [--arm64] [--no-cache]"
    exit 1
fi

build_args=()
if [ -n "${CVC5_TAG:-}" ]; then
	echo "Using pinned CVC5 tag from env: $CVC5_TAG"
	build_args+=( --build-arg "CVC5_TAG=$CVC5_TAG" )
else
	echo "CVC5_TAG not set; Dockerfile will resolve latest stable tag"
fi

if [ "$BUILD_AMD64" = true ]; then
    echo "Building for AMD64 (local)..."
    docker buildx build \
        $NO_CACHE \
        "${build_args[@]}" \
        --platform linux/amd64 \
        -t "${IMAGE_REPO}:amd64" \
        --load \
        -f "${SCRIPT_DIR}/Dockerfile" \
        "$REPO_ROOT"
fi

if [ "$BUILD_ARM64" = true ]; then
    echo "Building for ARM64 (local)..."
    docker buildx build \
        $NO_CACHE \
        "${build_args[@]}" \
        --platform linux/arm64 \
        -t "${IMAGE_REPO}:arm64" \
        --load \
        -f "${SCRIPT_DIR}/Dockerfile" \
        "$REPO_ROOT"
fi

echo "Build complete!"
