#!/bin/bash
set -e

BASE_IMAGE="alourenco/swelancer:latest"

# Automatically acknowledge GNU Parallel citation
yes "will cite" | parallel --citation > /dev/null 2>&1 || true

# Get current architecture
CURRENT_ARCH=$(uname -m)
case "$CURRENT_ARCH" in
  x86_64)
    DOCKER_ARCH="amd64"
    ;;
  aarch64|arm64)
    DOCKER_ARCH="arm64"
    ;;
  *)
    DOCKER_ARCH="$CURRENT_ARCH"
    ;;
esac

echo "Starting to build images for issues 1-237 for $DOCKER_ARCH architecture..."

# Function to build a single image
build_image() {
  ISSUE_ID=$1
  BASE_IMG=$2
  
  # Use architecture-specific tag
  ARCH_TAG="alourenco/swelancer:issue-$ISSUE_ID-$DOCKER_ARCH"
  
  # Check if the architecture-specific image already exists
  if docker manifest inspect $ARCH_TAG > /dev/null 2>&1; then
    echo "Image $ARCH_TAG already exists, skipping..."
    return 0
  fi
  
  echo "Building image for ISSUE_ID: $ISSUE_ID for $DOCKER_ARCH architecture"
  
  # Create a temporary Dockerfile in the current directory
  cat > Dockerfile.tmp.$ISSUE_ID << EOF
FROM $BASE_IMG

WORKDIR /app/expensify

# Set the ISSUE_ID environment variable
ENV ISSUE_ID=$ISSUE_ID
ENV DEBIAN_FRONTEND=noninteractive
ENV NVM_DIR=/root/.nvm
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app/tests
ENV DISPLAY=:99
ENV LIBGL_ALWAYS_INDIRECT=1

# Copy the setup playbook
COPY runtime_scripts/setup_expensify.yml /app/runtime_scripts/

# Run the setup playbook during image build
RUN cd /app && \\
    ansible-playbook /app/runtime_scripts/setup_expensify.yml

# Label the image with issue information
LABEL issue_id="$ISSUE_ID"
LABEL architecture="$DOCKER_ARCH"
EOF
  
  # Build the Docker image using standard docker build with platform flag
  docker build \
    --platform linux/$DOCKER_ARCH \
    --add-host=host.docker.internal:host-gateway \
    -f Dockerfile.tmp.$ISSUE_ID \
    -t $ARCH_TAG . || return 1
  
  # Push the architecture-specific image
  if ! docker push $ARCH_TAG; then
    echo "Failed to push image $ARCH_TAG"
    return 1
  fi
  
  # Remove the temporary Dockerfile
  rm Dockerfile.tmp.$ISSUE_ID
  
  # Remove the local image to save disk space
  docker rmi $ARCH_TAG
  
  echo "Successfully built and pushed image $ARCH_TAG"
  return 0
}

export -f build_image
export BASE_IMAGE
export DOCKER_ARCH

# Build images in parallel (adjust -j to control the number of parallel jobs)
# Use --halt soon,fail=1 to stop if any build fails
seq 1 237 | parallel --halt soon,fail=1 -j 4 "build_image {} $BASE_IMAGE"

echo "All $DOCKER_ARCH architecture images built successfully!" 