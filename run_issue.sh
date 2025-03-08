#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <ISSUE_ID>"
  exit 1
fi

ISSUE_ID=$1

# Check if the image exists
if ! docker image inspect expensify-ready:issue-$ISSUE_ID &> /dev/null; then
  echo "Error: Image for issue $ISSUE_ID not found."
  echo "Please run build_issue_images.sh first to create the images."
  exit 1
fi

echo "Starting container for ISSUE_ID: $ISSUE_ID"

# Run the container with the pre-built image
docker run -it --rm \
  -p 8080:8080 \
  -e PUSHER_APP_KEY="${PUSHER_APP_KEY}" \
  -e USE_WEB_PROXY="${USE_WEB_PROXY}" \
  -e EXPENSIFY_URL="${EXPENSIFY_URL}" \
  -e NEW_EXPENSIFY_URL="${NEW_EXPENSIFY_URL}" \
  expensify-ready:issue-$ISSUE_ID 