#!/bin/bash

#set -euo pipefail

# for now, this script is only configured to run on mac
if ! [[ "$(uname)" == "Darwin" ]]; then
    echo "$0 only works on mac"
    exit 1
fi


LATEST_SS="$(ls -t1 ~/screenshots/ | head -n 1)"
cd ~/screenshots && cp "$LATEST_SS" recent.png >/dev/null 2>&1
echo "Transcribe the following image" | llm -a "/Users/paul.wendt/screenshots/recent.png"
