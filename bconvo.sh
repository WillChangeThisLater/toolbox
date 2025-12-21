#!/bin/bash

set -euo pipefail

# Parse arguments
APPROVE=true
ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bypass)
      APPROVE=false
      shift
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

COMMAND="$(convo "${ARGS[@]}" --schema "reasoning string, bash string" | jq -r '.bash')"

echo -e "\`\`\`bash\n$COMMAND\n\`\`\`\n"
if [[ "$APPROVE" == "true" ]]; then
  read -p "Approve execution? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Command execution cancelled."
    exit 1
  fi
fi
