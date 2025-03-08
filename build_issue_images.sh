#!/bin/bash
set -e

# Automatically acknowledge GNU Parallel citation
yes "will cite" | parallel --citation > /dev/null 2>&1 || true

echo "Starting to build multi-architecture images for issues 1-237..."

# Use the existing multiarch builder
docker buildx use multiarch

# Function to build a single image for both architectures
build_image() {
  ISSUE_ID=$1
  
  # Use a common tag for the multi-architecture image
  IMAGE_TAG="alourenco/swelancer:paper-issue-$ISSUE_ID"
  
  echo "DEBUG: Checking if image $IMAGE_TAG already exists..."
  
  # Check if the multi-arch image already exists
  if docker manifest inspect $IMAGE_TAG > /dev/null 2>&1; then
    echo "Image $IMAGE_TAG already exists, skipping..."
    return 0
  fi
  
  # Force flush stdout to ensure messages appear in real-time
  echo "Building multi-architecture image for ISSUE_ID: $ISSUE_ID" 
  echo "Using tag: $IMAGE_TAG"
  
  # Create a temporary Dockerfile with architecture-specific FROM
  cat > Dockerfile.tmp.$ISSUE_ID << EOF
# syntax=docker/dockerfile:1.4

# Use different base images depending on target architecture
FROM alourenco/swelancer:latest-base-paper-\${TARGETARCH}

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
LABEL architecture="\${TARGETARCH}"
EOF
  
  echo "DEBUG: Building multi-architecture image..."
  
  # Build for both architectures using a single buildx command
  docker buildx build \
    --platform linux/amd64,linux/arm64 \
    -f Dockerfile.tmp.$ISSUE_ID \
    --push \
    -t $IMAGE_TAG . || return 1
  
  echo "DEBUG: Cleaning up..."
  
  # Remove temporary Dockerfile
  rm Dockerfile.tmp.$ISSUE_ID

  #remove local image to save space
  #docker rmi $IMAGE_TAG
  
  echo "Successfully built and pushed multi-architecture image $IMAGE_TAG"
  return 0
}

export -f build_image

# Make sure parallel outputs in real-time
export PARALLEL_SHELL="/bin/bash"

# Build images in parallel
seq 1 237 | parallel --ungroup --halt soon,fail=1 -j 4 "build_image {}"

echo "All multi-architecture images built successfully!" 