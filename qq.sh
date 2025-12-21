#!/bin/zsh

source ~/.zshrc >/dev/null 2>&1
set -euo pipefail

# Parse flags: recognize --all anywhere on the command line.
all_flag=false
args=()
while (( $# )); do
  case $1 in
    --all)
      all_flag=true
      shift
      ;;
    --)
      shift
      args+=("$@")
      break
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

# args[1] (zsh arrays are 1-based) is the filter passed to 'filter' and forwarded to llm
filter_arg="${args[1]:-}"

# Choose which fs invocation to use
if $all_flag; then
  base_dir="$(fs --all 2>/dev/null || true)"
  relevant_tabs=($(ls -d "${base_dir}/"* 2>/dev/null | filter "$filter_arg" 2>/dev/null))
else
  relevant_tabs=("$(fs 2>/dev/null || true)")
fi


# Complain if no relevant tabs
if (( ${#relevant_tabs[@]} == 0 )); then
  print -u2 "No relevant tabs found."
  exit 1
fi

# Ensure llm CLI is available
if ! command -v llm >/dev/null 2>&1; then
  print -u2 "Error: 'llm' CLI not found in PATH."
  exit 2
fi

# Build attachment args safely
attachments=()
for tab in "${relevant_tabs[@]}"; do
  [[ -e "$tab" ]] && attachments+=(-a "$tab")
done

if (( ${#attachments[@]} == 0 )); then
  print -u2 "Matched tab names, but no files exist."
  exit 1
fi

# Execute llm with any remaining args and attachments
exec llm "${args[@]}" "${attachments[@]}"


##!/bin/zsh
##
#
#source ~/.zshrc >/dev/null 2>&1
#set -euo pipefail
#
#relevant_tabs=($(ls -d "$(fs --all)/"* 2>/dev/null | filter "$1" 2>/dev/null))
#
## Complain if no relevant tabs
#if (( ${#relevant_tabs[@]} == 0 )); then
#  print -u2 "No relevant tabs found."
#  exit 1
#fi
#
## Ensure llm CLI is available
#if ! command -v llm >/dev/null 2>&1; then
#  print -u2 "Error: 'llm' CLI not found in PATH."
#  exit 2
#fi
#
## Build attachment args safely
#attachments=()
#for tab in "${relevant_tabs[@]}"; do
#  [[ -e "$tab" ]] && attachments+=(-a "$tab")
#done
#
#if (( ${#attachments[@]} == 0 )); then
#  print -u2 "Matched tab names, but no files exist."
#  exit 1
#fi
#
## Generate & execute:
#exec llm "$1" "${attachments[@]}"
