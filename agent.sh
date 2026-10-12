#!/bin/bash
# agent — hand off token-intensive work to a headless pi agent, get results back.
#
# Thin wrapper over `pi -p`. Defaults are tuned for delegation from another agent:
#   - own session dir (~/.pi/agent/agent-runs) so worker noise stays auditable
#     but out of the main session list
#   - read-only toolset by default (trawling shouldn't mutate anything)
#   - --full unlocks write/edit tools for tasks that mutate things
# Effort level: phrase it in the prompt (e.g. "be thorough", "one-shot, minimal").
#
# Usage:
#   agent "find sessions where the browser CLI tool fails unexpectedly"
#   agent --full "update the README in ~/repos/foo"
#   cat log.jsonl | agent "find anomalies"
set -e

SESSION_DIR="$HOME/.pi/agent/agent-runs"
mkdir -p "$SESSION_DIR"

if [ "$1" = "--full" ]; then
    shift
    exec pi -p --session-dir "$SESSION_DIR" "$@"
else
    exec pi -p --session-dir "$SESSION_DIR" --tools read,grep,find,ls "$@"
fi
