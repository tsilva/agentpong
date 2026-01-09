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
    # Detect which editor by walking up the process tree
    IS_CURSOR=false
    CHECK_PID=$PPID
    for _ in 1 2 3 4 5; do
        COMM=$(ps -p $CHECK_PID -o comm= 2>/dev/null)
        if [[ "$COMM" == *"Cursor"* ]]; then
            IS_CURSOR=true
            break
        fi
        CHECK_PID=$(ps -p $CHECK_PID -o ppid= 2>/dev/null)
        [ -z "$CHECK_PID" ] && break
    done

    # Fallback: check if Cursor is running
    if ! $IS_CURSOR && pgrep -q "Cursor"; then
        IS_CURSOR=true
    fi

    if $IS_CURSOR; then
        URL_SCHEME="cursor://file${PWD}"
    else
        URL_SCHEME="vscode://file${PWD}"
    fi

    terminal-notifier \
        -title "Claude Code [$WORKSPACE]" \
        -message "$MESSAGE" \
        -sound default \
        -open "$URL_SCHEME"
    exit 0
fi

# Fallback for other terminals
terminal-notifier \
    -title "Claude Code [$WORKSPACE]" \
    -message "$MESSAGE" \
    -sound default
