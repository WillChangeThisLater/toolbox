#!/bin/bash

# tmpopen - Opens files from S3 in a temporary directory and cleans up after
# Usage: tmpopen "s3://bucket/path/to/file"

set -e

if [ -z "$1" ]; then
    echo "Usage: tmpopen s3://bucket/path/to/file"
    exit 1
fi

S3_PATH="$1"
FILENAME=$(basename "$S3_PATH")
TEMP_DIR=$(mktemp -d)
LOCAL_PATH="$TEMP_DIR/$FILENAME"

echo "Downloading $S3_PATH to temporary location..."
aws s3 cp "$S3_PATH" "$LOCAL_PATH"

echo "Opening $FILENAME..."
open "$LOCAL_PATH"

# Wait for the file to be closed
# This is a bit tricky since 'open' returns immediately
echo "File opened. Press Enter when you're done to clean up..."
read -r

# Clean up
echo "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"
echo "Done!"
