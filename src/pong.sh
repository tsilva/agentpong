#!/bin/bash
#
# agentpong - Notification Cycling Script (pong.sh)
# Cycles through pending agentpong notifications one at a time.
# Each invocation focuses the oldest pending notification's workspace
# and dismisses it. Bind to a keyboard shortcut to rapidly cycle.
#
# Usage: pong.sh
#   Press once: focuses workspace A, dismisses its notification
#   Press again: focuses workspace B, dismisses its notification
#   No pending notifications: exits silently
#

# Add Homebrew paths (keyboard shortcuts run with minimal PATH)
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Get list of pending notifications (tab-separated: GroupID, Title, ...)
# Skip the header line, take the first data line (oldest notification)
LINE=$(terminal-notifier -list ALL 2>/dev/null | tail -n +2 | head -1)

# Exit silently if no pending notifications
[ -z "$LINE" ] && exit 0

# Parse tab-separated fields
WORKSPACE=$(echo "$LINE" | cut -f1)
TITLE=$(echo "$LINE" | cut -f2)

# Exit if we couldn't parse a workspace
[ -z "$WORKSPACE" ] && exit 0

# Determine tool directory from notification title
if echo "$TITLE" | grep -q "OpenCode"; then
    TOOL_DIR=".opencode"
else
    TOOL_DIR=".claude"
fi

# Focus the workspace window
FOCUS_SCRIPT="$HOME/$TOOL_DIR/focus-window.sh"
if [ -x "$FOCUS_SCRIPT" ]; then
    "$FOCUS_SCRIPT" "$WORKSPACE" > /dev/null 2>&1
fi

# Dismiss the notification
terminal-notifier -remove "$WORKSPACE" 2>/dev/null

exit 0
