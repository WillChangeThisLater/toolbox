#!/bin/bash

set -euo pipefail

DEFAULT=$(cat <<EOF
The user has invoked you with some pasted content.
Respond in a reasonable way given what they pasted.
Some suggestions:

  * If the user pasted a traceback: they probably want to know
    what might be causing the issue
  * If the user pasted a big blob of text: they might want it summarized
  * If the user posted a bunch of bash commands: they probably want to
    know what to do next

If you're not sure, you can tell the user to provide more specific information.
If you do this, use the following prompt exactly:

    It looks like you provided me with <summarize the content you see in a few words>. I do not have enough context to understand what to do with this. Please invoke me again with 'c "<context>"' to provide some info on what you are looking for
EOF
)

echo "${1:-$DEFAULT} $(pbpaste)" | llm
