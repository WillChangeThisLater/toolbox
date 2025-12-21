#!/bin/bash

# Check if any arguments were provided
if [ $# -eq 0 ]; then
  echo "Usage: $0 command [arguments]"
  exit 1
fi

# Join all arguments into a single command string
cmd="$*"

# Echo the command being run
echo -e "\n"
echo -e "\n"
echo "\`\`\`bash"
echo "> $cmd"

# Execute the command using eval to support pipes, redirections, etc.
eval "$cmd"
echo "\`\`\`"
echo -e "\n"
echo -e "\n"
