#!/bin/bash
#
# Claude Code Notification Script
# Sends a macOS notification when Claude Code is ready for input.
# Clicking the notification focuses the correct IDE window.
#
# Supported terminals:
#   - Cursor: Full support (notification + window focus)
#   - iTerm2: Notification only (hooks don't fire, use iTerm Triggers)
#
# Usage: notify.sh [message]
#

WORKSPACE="${PWD##*/}"
MESSAGE="${1:-Ready for input}"

# iTerm2
if [ "$TERM_PROGRAM" = "iTerm.app" ]; then
    terminal-notifier \
        -title "Claude Code [$WORKSPACE]" \
        -message "$MESSAGE" \
        -sound default \
        -activate com.googlecode.iterm2
    exit 0
fi

# VS Code / Cursor
if [ "$TERM_PROGRAM" = "cursor" ]; then
    # Use AppleScript to activate app and raise the specific workspace window
    SCRIPT="tell application Cursor to activate
tell application \"System Events\" to tell process Cursor
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
