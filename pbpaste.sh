#!/bin/sh
# pbpaste wrapper for Linux + macOS
# If real pbpaste exists, call it; otherwise use wl-paste/xclip/xsel.

if command -v pbpaste.real >/dev/null 2>&1; then
  exec pbpaste.real "$@"
fi

if command -v /usr/bin/pbpaste >/dev/null 2>&1; then
  exec /usr/bin/pbpaste "$@"
fi

if command -v pbpaste >/dev/null 2>&1; then
  case "$(command -v pbpaste)" in
    */pbpaste) ;;
    *) exec pbpaste "$@" ;;
  esac
fi

if command -v wl-paste >/dev/null 2>&1; then
  exec wl-paste "$@"
elif command -v xclip >/dev/null 2>&1; then
  exec xclip -selection clipboard -o
elif command -v xsel >/dev/null 2>&1; then
  exec xsel --clipboard --output
else
  echo "pbpaste: no clipboard utility found (wl-paste/xclip/xsel)" >&2
  exit 1
fi
