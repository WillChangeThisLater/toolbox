#!/bin/sh
# pbcopy wrapper for Linux + macOS
# If real pbcopy exists, call it; otherwise use wl-copy/xclip/xsel.

if command -v pbcopy.real >/dev/null 2>&1; then
  exec pbcopy.real "$@"
fi

# If we’re on macOS and pbcopy exists in PATH, use it.
if command -v /usr/bin/pbcopy >/dev/null 2>&1; then
  exec /usr/bin/pbcopy "$@"
fi

if command -v pbcopy >/dev/null 2>&1; then
  # Avoid recursion if this script shadows pbcopy
  case "$(command -v pbcopy)" in
    */pbcopy) ;;
    *) exec pbcopy "$@" ;;
  esac
fi

if command -v wl-copy >/dev/null 2>&1; then
  exec wl-copy "$@"
elif command -v xclip >/dev/null 2>&1; then
  exec xclip -selection clipboard
elif command -v xsel >/dev/null 2>&1; then
  exec xsel --clipboard --input
else
  echo "pbcopy: no clipboard utility found (wl-copy/xclip/xsel)" >&2
  exit 1
fi
