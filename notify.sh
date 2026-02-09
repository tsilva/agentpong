#!/bin/bash
#
# Claude Code Notification Script
# Sends a macOS notification when Claude Code is ready for input.
# If focus-window.sh is installed, clicking the notification focuses the
# correct IDE window (requires AeroSpace for cross-workspace support).
#
# Prerequisites:
#   - terminal-notifier (brew install terminal-notifier)
#
# Optional:
#   - AeroSpace (for cross-workspace window focus on click)
#
# Supported terminals:
#   - Cursor: Full support (notification + optional window focus)
#   - VS Code: Full support (notification + optional window focus)
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

# Build notification arguments
NOTIFY_ARGS=(
    "${ICON_ARGS[@]}"
    -title "Claude Code [$WORKSPACE]"
    -message "$MESSAGE"
    -sound default
    -group "$WORKSPACE"
)

# Add click-to-focus if focus-window.sh is available
FOCUS_SCRIPT="$HOME/.claude/focus-window.sh"
if [ -x "$FOCUS_SCRIPT" ]; then
    NOTIFY_ARGS+=(-execute "$FOCUS_SCRIPT '$WORKSPACE' && terminal-notifier -remove '$WORKSPACE'")
else
    NOTIFY_ARGS+=(-execute "terminal-notifier -remove '$WORKSPACE'")
fi

# Send notification
terminal-notifier "${NOTIFY_ARGS[@]}"
