#!/bin/bash

set -euo pipefail

# This script is a hack. It lets you share relatively tiny folders
# with a huge variety of tools via a custom bash command.
#
# Usage:
#
# ```bash
# docker run --rm -it --name testtest nginx /bin/bash -c "$(./smuggle.sh)"            # drops contents of current working dir to container
# ```
#
# ```bash
# docker run --rm -it --name testtest nginx /bin/bash -c "$(./smuggle.sh README.md)"  # drops README.md to container
# ```
#
#
# CAVEATS:
#
# * There's an upper limit to the amount of data you can share. usually dictated by ARG_MAX or something similar



set +u
file="$1"
if [ -z "$1" ]; then
  file="."
fi
set -u

# on the client side, unpack is responsible for
# tarring the file/folder and injecting the base64
# encoded version of the file's contents into the unpack function
# a literal EOF (cat <<'EOF') is used to prevent bash from
# interpreting anything as a shell command
#
# on the remote side, cat will read the literal base64-encoded
# contents, decode them, and untar them
echo "function unpack() {"
    echo "cat <<'EOF' | base64 -d | tar -xzf -"
    tar -czf - "$file" 2>/dev/null | base64
    echo "EOF"
echo "}"

# main functio. is the entry point to everything
function main() {

  # unpack the folder
  unpack

  # enable this if you want to run bash in an interactive shell
  /bin/bash
}

# all functions have to be declared to be used
declare -f main

# this is what actually runs the 'setup' function
echo "main"
