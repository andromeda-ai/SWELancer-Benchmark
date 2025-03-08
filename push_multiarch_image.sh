#!/bin/bash
set -e

# Image details
IMAGE_NAME="alourenco/swelancer"
TAG="latest"

# Login to Docker Hub (if not already logged in)
docker login

# # Push the AMD64 image
# echo "Pushing AMD64 image..."
# docker push ${IMAGE_NAME}:${TAG}-amd64

# # Push the ARM64 image
# echo "Pushing ARM64 image..."
# docker push ${IMAGE_NAME}:${TAG}-arm64

# Create and push the manifest
echo "Creating and pushing multi-architecture manifest..."
docker manifest create ${IMAGE_NAME}:${TAG} \
  --amend ${IMAGE_NAME}:${TAG}-amd64 \
  --amend ${IMAGE_NAME}:${TAG}-arm64

# Push the manifest
docker manifest push ${IMAGE_NAME}:${TAG}

echo "Successfully pushed multi-architecture image ${IMAGE_NAME}:${TAG}" 