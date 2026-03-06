#!/bin/bash
#
# Claude Code Notify - Sandbox Handler (TCP Listener)
# Listens on a TCP port and displays notifications via terminal-notifier.
#
# This script runs as a persistent launchd daemon, accepting connections
# on localhost:19223 and spawning terminal-notifier for each message.
#
# Input format: "workspace|message" (one per connection)
#

# Add Homebrew paths (launchd has minimal PATH)
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

PORT=19223

# Listen for connections and process each one
while true; do
    # nc -l listens for one connection, outputs received data
    line=$(nc -l 0.0.0.0 $PORT 2>/dev/null)

    # Parse workspace and message
    workspace="${line%%|*}"
    message="${line#*|}"

    # Skip empty messages
    [ -z "$workspace" ] && continue

    # Default message if none provided
    [ -z "$message" ] && message="Ready for input"

    # Delegate to notify.sh (single terminal-notifier codepath)
    CLAUDE_PROJECT_DIR="/fake/$workspace" "$HOME/.claude/notify.sh" "$message" &
done
