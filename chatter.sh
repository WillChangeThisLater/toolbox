#!/bin/bash

set -euo pipefail

# requires that both convo and shot are installed
convo "$@" -a "$(shot)"
