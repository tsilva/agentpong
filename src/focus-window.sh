#!/bin/bash
#
# agentpong - AeroSpace Window Focusing Script
# Executed when user clicks a notification to focus the correct IDE window.
#
# Requires AeroSpace tiling window manager.
#
# Usage: focus-window.sh <workspace-name>
#

WORKSPACE="$1"

# Locate aerospace binary (terminal-notifier runs with minimal PATH)
if [ -x "/opt/homebrew/bin/aerospace" ]; then
    AEROSPACE="/opt/homebrew/bin/aerospace"
elif [ -x "/usr/local/bin/aerospace" ]; then
    AEROSPACE="/usr/local/bin/aerospace"
else
    echo "Error: AeroSpace not found. Install with: brew install --cask nikitabobko/tap/aerospace" >&2
    exit 1
fi

# Find window ID for Cursor/Code with workspace in title
WINDOW_INFO=$("$AEROSPACE" list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' | \
    grep -E '(Cursor|Code)' | \
    grep -i "$WORKSPACE" | \
    head -1)

if [ -z "$WINDOW_INFO" ]; then
    # Fallback: first Cursor/Code window
    WINDOW_INFO=$("$AEROSPACE" list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' | \
        grep -E '(Cursor|Code)' | \
        head -1)
fi

if [ -n "$WINDOW_INFO" ]; then
    WINDOW_ID=$(echo "$WINDOW_INFO" | cut -d'|' -f1)
    WINDOW_WORKSPACE=$(echo "$WINDOW_INFO" | cut -d'|' -f4)

    # Switch workspace and focus window
    [ -n "$WINDOW_WORKSPACE" ] && "$AEROSPACE" workspace "$WINDOW_WORKSPACE"
    "$AEROSPACE" focus --window-id "$WINDOW_ID"
fi
