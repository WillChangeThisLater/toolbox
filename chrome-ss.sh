#!/bin/bash

set -euo pipefail


URL="$1"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
SS_PATH="/tmp/screenshot-${TIMESTAMP}.png"
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --headless --screenshot="$SS_PATH" --window-size=1920,1080 --hide-scrollbars "$URL" >/dev/null 2>&1
echo "$SS_PATH"
