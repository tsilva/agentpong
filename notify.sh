#!/bin/bash
#
# Claude Code Notification Script
# Sends a macOS notification when Claude Code is ready for input.
# Clicking the notification focuses the correct IDE window (even across Spaces).
#
# Supported terminals:
#   - Cursor: Full support via AeroSpace (notification + window focus across workspaces)
#   - VS Code: Full support via AeroSpace (notification + window focus across workspaces)
#   - iTerm2: Notification only (hooks don't fire, use iTerm Triggers)
#
# Usage: notify.sh [message]
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# AeroSpace mode: notification with window focusing on click
if command -v aerospace &> /dev/null; then
    terminal-notifier \
        -title "Claude Code [$WORKSPACE]" \
        -message "$MESSAGE" \
        -sound default \
        -execute "$SCRIPT_DIR/focus-window.sh '$WORKSPACE'"
    exit 0
fi

# Fallback: notification only (no window focusing without AeroSpace)
# iTerm2 fallback
if [ "$TERM_PROGRAM" = "iTerm.app" ]; then
    terminal-notifier \
        -title "Claude Code [$WORKSPACE]" \
        -message "$MESSAGE" \
        -sound default \
        -activate com.googlecode.iterm2
    exit 0
fi

# Cursor/VS Code fallback (AppleScript - doesn't switch Spaces)
if [ "$TERM_PROGRAM" = "vscode" ]; then
    SCRIPT="tell application \"Cursor\" to activate
tell application \"System Events\" to tell process \"Cursor\"
    set frontmost to true
    try
        perform action \"AXRaise\" of (first window whose name contains \"$WORKSPACE\")
    end try
end tell"

    terminal-notifier \
        -title "Claude Code [$WORKSPACE]" \
        -message "$MESSAGE" \
        -sound default \
        -execute "osascript -e '$SCRIPT'"
    exit 0
fi

# Generic fallback
terminal-notifier \
    -title "Claude Code [$WORKSPACE]" \
    -message "$MESSAGE" \
    -sound default
