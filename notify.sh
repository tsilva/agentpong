#!/bin/bash
#
# Claude Code Notification Script
# Sends a macOS notification when Claude Code is ready for input.
# Clicking the notification focuses the correct IDE window via aerospace-setup.
#
# Prerequisites:
#   - aerospace-setup (provides ~/.claude/focus-window.sh symlink)
#   - terminal-notifier (brew install terminal-notifier)
#
# Supported terminals:
#   - Cursor: Full support (notification + window focus across workspaces)
#   - VS Code: Full support (notification + window focus across workspaces)
#
# Usage: notify.sh [message]
#

# Skip notifications for SDK-spawned sessions (e.g., claude-code-bridge)
if [ -n "$CLAUDE_CODE_BRIDGE" ]; then
    exit 0
fi

# Use Claude's project directory (launch path), fall back to PWD for manual testing
LAUNCH_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
WORKSPACE="${LAUNCH_DIR##*/}"
MESSAGE="${1:-Ready for input}"

# Check for required dependencies
if ! command -v terminal-notifier &> /dev/null; then
    echo "Error: terminal-notifier is not installed."
    echo "Run install.sh or install manually: brew install terminal-notifier"
    exit 1
fi

# Send notification with click-to-focus via aerospace-setup symlink
terminal-notifier \
    -title "Claude Code [$WORKSPACE]" \
    -message "$MESSAGE" \
    -sound default \
    -execute "$HOME/.claude/focus-window.sh '$WORKSPACE'"
