#!/bin/bash
#
# Claude Code Notification Script
# Sends a macOS notification when Claude Code is ready for input.
# Clicking the notification focuses the correct IDE window (even across Spaces).
#
# Supported terminals:
#   - Cursor: Full support via Hammerspoon (notification + window focus across Spaces)
#   - VS Code: Full support via Hammerspoon (notification + window focus across Spaces)
#   - iTerm2: Notification only (hooks don't fire, use iTerm Triggers)
#
# Usage: notify.sh [message]
#

# Use Claude's project directory (launch path), fall back to PWD for manual testing
LAUNCH_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
WORKSPACE="${LAUNCH_DIR##*/}"
MESSAGE="${1:-Ready for input}"

# Escape single quotes for Lua string
escape_lua_string() {
    echo "$1" | sed "s/'/\\\\'/g"
}

WORKSPACE_ESCAPED=$(escape_lua_string "$WORKSPACE")
MESSAGE_ESCAPED=$(escape_lua_string "$MESSAGE")

# Use Hammerspoon if the 'hs' CLI is available
if command -v hs &> /dev/null; then
    hs -c "claudeNotify('$WORKSPACE_ESCAPED', '$MESSAGE_ESCAPED')" 2>/dev/null
    exit 0
fi

# Fallback: terminal-notifier (won't switch Spaces properly)
if ! command -v terminal-notifier &> /dev/null; then
    echo "Error: Neither Hammerspoon CLI (hs) nor terminal-notifier is installed."
    echo "Run install.sh to set up Hammerspoon, or install terminal-notifier manually."
    exit 1
fi

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
