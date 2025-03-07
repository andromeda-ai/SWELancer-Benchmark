#!/bin/bash
set -e

BASE_IMAGE="alourenco/swelancer:latest"

# Automatically acknowledge GNU Parallel citation
yes "will cite" | parallel --citation > /dev/null 2>&1 || true

echo "Starting to build images for issues 1-237..."

# Function to build a single image
build_image() {
  ISSUE_ID=$1
  BASE_IMG=$2
  
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
  
  # Check if the image already exists on Docker Hub for the current architecture
  if docker manifest inspect alourenco/swelancer:issue-$ISSUE_ID > /dev/null 2>&1; then
    # Check if the manifest contains the current architecture
    if docker manifest inspect alourenco/swelancer:issue-$ISSUE_ID | grep -q "\"architecture\":\"$DOCKER_ARCH\""; then
      echo "Image for ISSUE_ID: $ISSUE_ID already exists for $DOCKER_ARCH architecture, skipping..."
      return 0
    else
      echo "Image for ISSUE_ID: $ISSUE_ID exists but not for $DOCKER_ARCH architecture, building..."
    fi
  else
    echo "Image for ISSUE_ID: $ISSUE_ID does not exist, building..."
  fi
  
  echo "Building image for ISSUE_ID: $ISSUE_ID"
  
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
EOF
  
  # Build the Docker image using standard docker build
  docker build \
    -f Dockerfile.tmp.$ISSUE_ID \
    -t alourenco/swelancer:issue-$ISSUE_ID . || return 1
  
  # Push the image to Docker Hub and check if successful
  if ! docker push alourenco/swelancer:issue-$ISSUE_ID; then
    echo "Failed to push image for ISSUE_ID: $ISSUE_ID"
    return 1
  fi
  
  # Remove the temporary Dockerfile
  rm Dockerfile.tmp.$ISSUE_ID
  
  # Remove the local image to save disk space
  docker rmi alourenco/swelancer:issue-$ISSUE_ID
  
  echo "Successfully built and pushed image alourenco/swelancer:issue-$ISSUE_ID"
  return 0
}

export -f build_image
export BASE_IMAGE

# Build images in parallel (adjust -j to control the number of parallel jobs)
# Use --halt soon,fail=1 to stop if any build fails
seq 1 237 | parallel --halt soon,fail=1 -j 4 "build_image {} $BASE_IMAGE"

echo "All images built successfully!" 