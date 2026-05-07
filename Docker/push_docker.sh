#!/bin/bash
set -e

# Image repo
IMAGE_REPO="danchitnis/eedigits"
IMAGE_TAG="${IMAGE_TAG:-latest}"
IMAGE_NAME="${IMAGE_REPO}:${IMAGE_TAG}"

MERGE=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --merge) MERGE=true; shift ;;
        --tag) IMAGE_TAG="$2"; IMAGE_NAME="${IMAGE_REPO}:${IMAGE_TAG}"; shift 2 ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
done

echo "Checking for local images to push..."

# Check for amd64 image
if docker image inspect "${IMAGE_REPO}:amd64" >/dev/null 2>&1; then
    echo "Found local AMD64 image. Pushing..."
    docker push "${IMAGE_REPO}:amd64"
else
    echo "AMD64 image not found locally."
fi

# Check for arm64 image
if docker image inspect "${IMAGE_REPO}:arm64" >/dev/null 2>&1; then
    echo "Found local ARM64 image. Pushing..."
    docker push "${IMAGE_REPO}:arm64"
else
    echo "ARM64 image not found locally."
fi

if [ "$MERGE" = true ]; then
    echo "Merging manifests to create ${IMAGE_NAME}..."
    # Note: imagetools create works with images already in the registry
    docker buildx imagetools create \
        -t "$IMAGE_NAME" \
        "${IMAGE_REPO}:amd64" \
        "${IMAGE_REPO}:arm64"
    
    echo "Verifying multi-arch image..."
    docker buildx imagetools inspect "$IMAGE_NAME"
fi

echo "Process complete!"
