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
        URL_SCHEME="cursor"
    elif [[ "$PARENT_COMM" == *"Code"* ]]; then
        URL_SCHEME="vscode"
    else
        # Fallback: check grandparent process
        GRANDPARENT_COMM=$(ps -p $(ps -p $PPID -o ppid= 2>/dev/null) -o comm= 2>/dev/null)
        if [[ "$GRANDPARENT_COMM" == *"Cursor"* ]]; then
            URL_SCHEME="cursor"
        elif pgrep -q "Cursor"; then
            URL_SCHEME="cursor"
        else
            URL_SCHEME="vscode"
        fi
    fi

    # Use URL scheme to focus the correct workspace window
    terminal-notifier \
        -title "Claude Code [$WORKSPACE]" \
        -message "$MESSAGE" \
        -sound default \
        -open "${URL_SCHEME}://file${PWD}"
    exit 0
fi

# Fallback for other terminals
terminal-notifier \
    -title "Claude Code [$WORKSPACE]" \
    -message "$MESSAGE" \
    -sound default
