#!/bin/bash
#
# agentpong - Kimi Code Notification Handler
# Receives hook event JSON on stdin (configured via [[hooks]] in
# ~/.kimi-code/config.toml) and sends a desktop notification via notify.sh.
#
# Usage: agentpong.sh [stop|permission]     (hook event JSON on stdin)
#
# Always exits 0: Kimi hooks are fail-open and the Stop event is blockable,
# so a failing notification must never interrupt the agent's turn.
#

EVENT_KIND="${1:-stop}"
case "$EVENT_KIND" in
    stop) MESSAGE="Ready for input" ;;
    *)    MESSAGE="Permission required" ;;
esac

# Read the hook payload from stdin (skip when run interactively without a pipe)
PAYLOAD=""
if [[ ! -t 0 ]]; then
    PAYLOAD="$(cat 2>/dev/null)"
fi

# Extract the project directory from the payload (fallback: current directory)
PROJECT_DIR="$PWD"
if [[ -n "$PAYLOAD" ]] && command -v jq &> /dev/null; then
    PARSED_DIR="$(printf '%s' "$PAYLOAD" | jq -r '.cwd // empty' 2>/dev/null)"
    [[ -n "$PARSED_DIR" ]] && PROJECT_DIR="$PARSED_DIR"
fi

# Find notify.sh (installed alongside this script, or in another tool's dir)
NOTIFY_SCRIPT="$HOME/.kimi-code/notify.sh"
if [[ ! -x "$NOTIFY_SCRIPT" ]]; then
    for alt in "$HOME/.claude/notify.sh" "$HOME/.codex/notify.sh" "$HOME/.opencode/notify.sh"; do
        if [[ -x "$alt" ]]; then
            NOTIFY_SCRIPT="$alt"
            break
        fi
    done
fi

if [[ -x "$NOTIFY_SCRIPT" ]]; then
    KIMI_PROJECT_DIR="$PROJECT_DIR" KIMI=1 "$NOTIFY_SCRIPT" "$MESSAGE" &> /dev/null || true
fi

exit 0
