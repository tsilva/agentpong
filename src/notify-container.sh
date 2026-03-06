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

# host.docker.internal resolves to the Docker host on macOS/Windows
HOST="host.docker.internal"
PORT=19223

# Send to TCP listener (fire-and-forget)
(echo "${WORKSPACE}|${MESSAGE}" | nc -w1 "$HOST" "$PORT" &) 2>/dev/null

exit 0
