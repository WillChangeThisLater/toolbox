#!/bin/bash

set -euo pipefail

echo "$1 $(pbpaste)" | llm
