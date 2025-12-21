#!/bin/bash

#set -euox pipefail

# if slink isn't installed, install it
which slink 2>/dev/null || ./slink.sh slink.sh

# install all the other non-setup, non-slink scripts
for file in *.{sh,py}; do
  if [[ "$file" != "slink.sh" && "$file" != "setup.sh" ]]; then 
    slink "$file"
  fi
done
