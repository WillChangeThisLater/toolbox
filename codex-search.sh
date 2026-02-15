#!/bin/bash

set -euo pipefail

TOPIC="$1"
MIN_LINKS="${2:-3}"

  codex exec \
    --output-schema <(cat <<'EOF'
    {
      "type": "object",
      "properties": {
        "links": {
          "type": "array",
          "items": {
            "type": "string",
            "pattern": "^https?://"
          }
        }
      },
      "required": ["links"],
      "additionalProperties": false
    }
EOF
    ) \
    "Find at least $MIN_LINKS links relating to $TOPIC" 2>/dev/null | jq -r '.links[]'
