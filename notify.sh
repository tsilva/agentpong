#!/bin/bash
#
# Claude Code Notification Script
# Sends a macOS notification when Claude Code is ready for input.
# Clicking the notification focuses the correct IDE window.
#
# Supported terminals:
#   - Cursor: Full support (notification + window focus)
#   - VS Code: Full support (notification + window focus)
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
if [ "$TERM_PROGRAM" = "vscode" ] || [ "$TERM_PROGRAM" = "cursor" ]; then
    # Detect which editor by checking parent process
    PARENT_COMM=$(ps -p $PPID -o comm= 2>/dev/null)

    if [[ "$PARENT_COMM" == *"Cursor"* ]]; then
        PROCESS_NAME="Cursor"
    elif [[ "$PARENT_COMM" == *"Code"* ]]; then
        PROCESS_NAME="Code"
    else
        # Fallback: check grandparent process
        GRANDPARENT_COMM=$(ps -p $(ps -p $PPID -o ppid= 2>/dev/null) -o comm= 2>/dev/null)
        if [[ "$GRANDPARENT_COMM" == *"Cursor"* ]]; then
            PROCESS_NAME="Cursor"
        elif pgrep -q "Cursor"; then
            PROCESS_NAME="Cursor"
        else
            PROCESS_NAME="Code"
        fi
    fi

    # Build AppleScript command to focus specific window by workspace name
    # Uses System Events to find window whose title contains the workspace folder name
    FOCUS_CMD="osascript -e 'tell application \"System Events\" to tell process \"$PROCESS_NAME\" to set frontmost to true' -e 'tell application \"System Events\" to tell process \"$PROCESS_NAME\" to perform action \"AXRaise\" of (first window whose name contains \"$WORKSPACE\")'"

    terminal-notifier \
        -title "Claude Code [$WORKSPACE]" \
        -message "$MESSAGE" \
        -sound default \
        -execute "$FOCUS_CMD"
    exit 0
fi

# Fallback for other terminals
terminal-notifier \
    -title "Claude Code [$WORKSPACE]" \
    -message "$MESSAGE" \
    -sound default
