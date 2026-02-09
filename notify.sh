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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use Claude's project directory (launch path), fall back to PWD for manual testing
LAUNCH_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
WORKSPACE="${LAUNCH_DIR##*/}"
MESSAGE="${1:-Ready for input}"

# Source styling library (graceful fallback to plain echo)
source "$SCRIPT_DIR/style.sh" 2>/dev/null || true

# Check for required dependencies
if ! command -v terminal-notifier &> /dev/null; then
    error "terminal-notifier is not installed."
    dim "Run install.sh or install manually: brew install terminal-notifier"
    exit 1
fi

# Use project logo as notification icon if available
ICON_ARGS=()
if [ -f "$LAUNCH_DIR/logo.png" ]; then
    ICON_ARGS=(-contentImage "$LAUNCH_DIR/logo.png")
fi

# Send notification with click-to-focus via aerospace-setup symlink
terminal-notifier \
    "${ICON_ARGS[@]}" \
    -title "Claude Code [$WORKSPACE]" \
    -message "$MESSAGE" \
    -sound default \
    -group "$WORKSPACE" \
    -execute "$HOME/.claude/focus-window.sh '$WORKSPACE' && terminal-notifier -remove '$WORKSPACE'"
