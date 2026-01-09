#!/bin/bash
#
# Claude Code Notify - AeroSpace Window Focusing Script
# Executed when user clicks a notification to focus the correct IDE window.
#
# Usage: focus-window.sh <workspace-name>
#

WORKSPACE="$1"

# Find window ID for Cursor/Code with workspace in title
WINDOW_INFO=$(aerospace list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' | \
    grep -E '(Cursor|Code)' | \
    grep -i "$WORKSPACE" | \
    head -1)

if [ -z "$WINDOW_INFO" ]; then
    # Fallback: first Cursor window
    WINDOW_INFO=$(aerospace list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' | \
        grep -E '(Cursor|Code)' | \
        head -1)
fi

if [ -n "$WINDOW_INFO" ]; then
    WINDOW_ID=$(echo "$WINDOW_INFO" | cut -d'|' -f1)
    WINDOW_WORKSPACE=$(echo "$WINDOW_INFO" | cut -d'|' -f4)

    # Switch workspace and focus window
    [ -n "$WINDOW_WORKSPACE" ] && aerospace workspace "$WINDOW_WORKSPACE"
    aerospace focus --window-id "$WINDOW_ID"
else
    # Last resort: just activate Cursor
    osascript -e 'tell application "Cursor" to activate' 2>/dev/null
fi
