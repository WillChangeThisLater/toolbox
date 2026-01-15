#!/bin/bash

set -euo pipefail

# Create a temporary file in /tmp directory
SAVE_TO=$(mktemp /tmp/ss.XXXXXX.png)

gnome-screenshot --file="$SAVE_TO"
echo "$SAVE_TO"
