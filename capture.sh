#!/bin/bash

set -euo pipefail

# Function to show the usage message
show_help() {
    echo "Usage: capture [-p pane_index] [-n num_lines] [-h] [-v]"
    echo ""
    echo "Options:"
    echo "  -p pane_index   Specify the pane index to capture from. Defaults to the current pane."
    echo "  -n num_lines    Specify the number of lines to display. Defaults to 250."
    echo "  -v              Capture only the visible portion of the pane."
    echo "  -h              Show this help message."
}

# Default values
pane_index=""
num_lines="250"
capture_visible_only=false

# Parse command line arguments
while getopts ":p:n:vh" opt; do
    case ${opt} in
        p)
            pane_index="$OPTARG"
            ;;
        n)
            num_lines="$OPTARG"
            ;;
        v)
            capture_visible_only=true
            ;;
        h)
            show_help
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            show_help
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            show_help
            exit 1
            ;;
    esac
done

# Default to current pane if no pane_index is set
if [ -z "$pane_index" ]; then
    pane_index="$(tmux display-message -p '#{pane_index}')"
fi

# Check if the specified pane_id is valid
if ! tmux list-panes -F "#{pane_index}" | grep -q "^${pane_index}$"; then
    echo "Error: Invalid pane index '$pane_index'." >&2
    exit 1
fi

# Determine the start line for capturing
start_line="-250"
if [ "$capture_visible_only" = true ]; then
    start_line="0"
fi

# Execute tmux command with the provided parameters
tmux capture-pane -t "$pane_index" -p -S "$start_line" | tail -n "$num_lines"
