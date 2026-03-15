#!/bin/bash
#
# Claude Code Notification Script (Sandbox Version)
# Sends notifications via TCP to the host system.
#
# This script runs inside claude-sandbox containers where terminal-notifier
# is not available. It connects to a TCP listener on the host.
#
# Usage: notify.sh [message]
#

# Skip notifications for SDK-spawned sessions
if [ -n "$CLAUDE_CODE_BRIDGE" ]; then
    exit 0
fi

# Use Claude's project directory (launch path), fall back to PWD
LAUNCH_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
WORKSPACE="${LAUNCH_DIR##*/}"
MESSAGE="${1:-Ready for input}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOKEN_FILE="$SCRIPT_DIR/agentpong.token"

# host.docker.internal resolves to the Docker host on macOS/Windows
HOST="host.docker.internal"
PORT=19223

# Require the shared token so the host listener can reject unauthenticated traffic.
if [ ! -f "$TOKEN_FILE" ]; then
    echo "agentpong sandbox token not found: $TOKEN_FILE" >&2
    exit 1
fi

TOKEN="$(tr -d '\n' < "$TOKEN_FILE")"
[ -z "$TOKEN" ] && exit 1

# Send to TCP listener (fire-and-forget)
(echo "${TOKEN}|${WORKSPACE}|${MESSAGE}" | nc -w1 "$HOST" "$PORT" &) 2>/dev/null

exit 0
