#!/bin/bash

set -euo pipefail

SAVE_TO="/tmp/ss.png"
gnome-screenshot --file="$SAVE_TO"

#set -x
llm "$@" -a "$SAVE_TO"
