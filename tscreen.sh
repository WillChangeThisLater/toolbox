#!/bin/bash

set -euo pipefail

function get_screen_name() {
    if command -v llm >/dev/null; then
        (llm "Come up with a short, unix compatible file name for the following terminal screen: $(cat $1). A good name is short, unix-compatible, and gives a good quick overview of the session to the reader without being too vague. Examples of good names: 'mitmproxy_capture', 'docker_networking_chat', 'nvidia_driver_problems'. Examples of bad names: 'terminal_session' (too generic), 'debugging python issue' (not unix compatible due to spaces), 'error' (too vague and too short), 'terminal_session_where_the_users_asks_for_help_with_a_script' (too long)" --schema 'name string, explanation string' 2>/dev/null | jq -r '.name') || date +%s
    else
        date +%s
    fi

}

function save_screen() {
    SAVE_DIR="$HOME/.local/state/savescreen"
    DAY="$(date +%Y%m%d)"
    SAVE_PATH="$SAVE_DIR/$DAY"
    
    # make the appropriate directory, if it does not already exist
    mkdir -p "$SAVE_PATH"

    # save file to temporary directory (for now)
    TEMP_DIR="$(mktemp -d)"
    tmux capture-pane -p -S - > "$TEMP_DIR/screen.txt"

    # get a name for the screen
    # llm is best for this; if llm is not available, use date
    SCREEN_NAME="${1:-}"
    if [ -z "$SCREEN_NAME" ]; then
        SCREEN_NAME="$(get_screen_name $TEMP_DIR/screen.txt)"
    fi
    mv "$TEMP_DIR/screen.txt" "$SAVE_PATH/$SCREEN_NAME.txt"
    echo "$SAVE_PATH/$SCREEN_NAME.txt"
}

function load_screen() {
    # load screen
    if ! [ -f "$1" ]; then
        echo "error: $1 does not exist" >&2
        exit 1
    fi

    clear
    cat "$1"
}

# TODO: arg parse and shell out to the right function
# All the following should be supported
# 
# ```bash
# tscreen -l                  # should load latest screen capture
# tscreen -l <path/to/screen> # should load specified capture
# tscreen -s                  # should save screen
# tscreen -s <name>           # should save screen w/ specified name
# ```
case "$1" in
    -l)  # Load latest screen capture
        if [ -z "${2:-}" ]; then
            LATEST=$(ls -t "$HOME/.local/state/savescreen/"*/* | head -n 1)
            load_screen "$LATEST"
        else
            load_screen "$2"  # Load specified capture
        fi
        ;;
    -s) 
        # Save screen
        # If $2 is not defined, save_screen will think of a screen name for us
        SCREEN_NAME="${2:-}"
        save_screen "$SCREEN_NAME"
        ;;
    *)   # Invalid option
        echo "Usage: $0 -l or -s"
        exit 1
        ;;
esac
