#!/bin/bash
#
# Claude Code Notify - Sandbox Handler (TCP Listener)
# Listens on a TCP port and displays notifications via terminal-notifier.
#
# This script runs as a persistent launchd daemon, accepting connections
# on port 19223 and requiring a shared token for each message.
#
# Input format: "token|workspace|message" (one per connection)
#

# Add Homebrew paths (launchd has minimal PATH)
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

PORT=19223
TOKEN_FILE="$HOME/.claude-sandbox/claude-config/agentpong.token"

[ -f "$TOKEN_FILE" ] || exit 1
TOKEN="$(tr -d '\n' < "$TOKEN_FILE")"
[ -n "$TOKEN" ] || exit 1

# Listen for connections and process each one
while true; do
    # nc -l listens for one connection, outputs received data
    line=$(nc -l 0.0.0.0 $PORT 2>/dev/null)

    # Parse token, workspace, and message
    token="${line%%|*}"
    remainder="${line#*|}"
    [ "$remainder" = "$line" ] && continue

    workspace="${remainder%%|*}"
    message="${remainder#*|}"

    # Skip empty messages
    [ -z "$workspace" ] && continue
    [ "$token" = "$TOKEN" ] || continue

    # Default message if none provided
    [ -z "$message" ] && message="Ready for input"

    # Delegate to notify.sh (single terminal-notifier codepath)
    CLAUDE_PROJECT_DIR="/fake/$workspace" "$HOME/.claude/notify.sh" "$message" &
done
