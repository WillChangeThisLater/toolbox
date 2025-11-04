#!/usr/bin/env bash
# tmux-ask.sh
# Flags:
#   --target=<pane> --context=<text> [--mode=auto|alt|history|visible]
#   [--from-buffer=<bufname> [--delete-buffer]] [--from-file=<path>] [--debug]
set -euo pipefail

: "${CAPTURE_LINES:=500}"   # prefer CAPTURE_LINES over LINES
DEBUG=0
TARGET=""; CONTEXT=""; MODE="auto"
FROM_BUF=""; DELETE_BUF=0; FROM_FILE=""

# Optional trace
TRACE="${TRACE:-0}"
trace(){ [ "$TRACE" = "1" ] && printf '[trace] %s\n' "$*" >&2 || true; }
trace "$0 $*"

for arg in "$@"; do
  case "$arg" in
    --target=*)        TARGET="${arg#*=}";;
    --context=*)       CONTEXT="${arg#*=}";;
    --mode=*)          MODE="${arg#*=}";;
    --from-buffer=*)   FROM_BUF="${arg#*=}";;
    --delete-buffer)   DELETE_BUF=1;;
    --from-file=*)     FROM_FILE="${arg#*=}";;
    --debug)           DEBUG=1;;
    --trace)           TRACE=1;;
  esac
done

TARGET="${TARGET:-$(tmux display -p '#{pane_id}')}"

read_from_buffer() { tmux show-buffer -b "$1"; }
read_from_file()   { cat -- "$1"; }

capture_history() {
  #if ! tmux capture-pane -p -J -S "-$LINES" -t "$TARGET" 2>/dev/null; then
  tmux capture-pane -p -J -t "$TARGET"
  #fi
}

capture_alt() {
  # Capture the alternate screen grid (omit -J to avoid odd wrapping in TUIs)
  tmux capture-pane -p -a -t "$TARGET"
}

capture_visible() {
  # Try visible region directly; if tmux is old, fall back via copy-mode
  if CONTENT="$(tmux capture-pane -p -S - -E - -t "$TARGET" 2>/dev/null)"; then
    printf "%s" "$CONTENT"
  else
    tmux copy-mode -t "$TARGET"
    CONTENT="$(tmux capture-pane -p -S - -E - -t "$TARGET")" || CONTENT=""
    tmux send-keys -t "$TARGET" -X cancel || true
    printf "%s" "$CONTENT"
  fi
}

# Decide content source
CONTENT=""
if [ -n "$FROM_FILE" ]; then
  CONTENT="$(read_from_file "$FROM_FILE")"
elif [ -n "$FROM_BUF" ]; then
  CONTENT="$(read_from_buffer "$FROM_BUF")"
  [ $DELETE_BUF -eq 1 ] && tmux delete-buffer -b "$FROM_BUF" || true
else
  ALT_ON="$(tmux display -pt "$TARGET" '#{alternate_on}' || echo 0)"
  case "$MODE" in
    history) CONTENT="$(capture_history)";;
    alt)     CONTENT="$(capture_alt)";;
    visible) CONTENT="$(capture_visible)";;
    auto|*)
      if [ "$ALT_ON" = "1" ]; then
           CONTENT="$(capture_history)"
           [ -z "$CONTENT" ] && CONTENT="$(capture_alt)"
           [ -z "$CONTENT" ] && CONTENT="$(capture_visible)"
      else
           # Alt screen disabled (common for keeping scrollback) —
           # grab what's actually on the screen, then fall back.
           CONTENT="$(capture_visible)"
           [ -z "$CONTENT" ] && CONTENT="$(capture_history)"
      fi
  esac
fi

# Metadata
SESSION=$(tmux display -pt "$TARGET" '#{session_name}')
WINDOW=$(tmux display -pt "$TARGET" '#{window_index}')
PANE=$(tmux display -pt "$TARGET"   '#{pane_index}')
CWD=$(tmux display -pt "$TARGET"    '#{pane_current_path}')
CMD=$(tmux display -pt "$TARGET"    '#{pane_current_command}')

emit_prompt() {
  printf "The following terminal output is captured from tmux\n"
  printf "Meta: session=%s window=%s pane=%s cwd=%s cmd=%s\n" "$SESSION" "$WINDOW" "$PANE" "$CWD" "$CMD"
  printf "\n--- BEGIN PANE CONTENT ---\n%s\n--- END PANE CONTENT ---\n" "$CONTENT"
  printf "%s\n" "$CONTEXT"
}

if [ "$DEBUG" -eq 1 ]; then
  TMPFILE="${TMPFILE:-/tmp/context.$$.log}"
  # Stream to stderr and save to file; no giant env vars.
  emit_prompt | tee "$TMPFILE" >/dev/stderr
  printf 'output saved at %s\n' "$TMPFILE" >&2

  drop_into_debug_shell() {
    # Export only *small* vars and helpers; avoid exporting CONTENT/payload.
    export TARGET CONTEXT MODE FROM_BUF DELETE_BUF FROM_FILE CAPTURE_LINES TMPFILE
    export -f read_from_buffer read_from_file capture_history capture_alt capture_visible emit_prompt
    export TMUX_DEBUG_BANNER=$'Debug shell.\nVars: $TARGET $MODE $FROM_BUF $FROM_FILE $CAPTURE_LINES\nFns: capture_*, read_from_*\nPayload file: $TMPFILE\nType "exit" to resume.'
    "${SHELL:-/bin/bash}" -i || true
  }
  drop_into_debug_shell
else
  # Stream directly; no temporary storage, no newline trimming.
  emit_prompt | llm 2>&1
fi
