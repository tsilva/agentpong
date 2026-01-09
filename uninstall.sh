#!/bin/bash
#
# Claude Code Notify - Uninstallation Script
#

set -e

CLAUDE_DIR="$HOME/.claude"
NOTIFY_SCRIPT="$CLAUDE_DIR/notify.sh"
FOCUS_SCRIPT="$CLAUDE_DIR/focus-window.sh"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
HAMMERSPOON_DIR="$HOME/.hammerspoon"
HAMMERSPOON_INIT="$HAMMERSPOON_DIR/init.lua"
HAMMERSPOON_MODULE="$HAMMERSPOON_DIR/claude-notify.lua"

echo "Claude Code Notify - Uninstaller"
echo "================================="
echo ""

# === Remove Claude Code Integration ===

# Remove notify.sh
if [ -f "$NOTIFY_SCRIPT" ]; then
    rm "$NOTIFY_SCRIPT"
    echo "Removed $NOTIFY_SCRIPT"
else
    echo "notify.sh not found (already removed?)"
fi

# Remove focus-window.sh
if [ -f "$FOCUS_SCRIPT" ]; then
    rm "$FOCUS_SCRIPT"
    echo "Removed $FOCUS_SCRIPT"
else
    echo "focus-window.sh not found (already removed?)"
fi

# Remove Stop hook from settings.json
if [ -f "$SETTINGS_FILE" ]; then
    if command -v jq &> /dev/null; then
        if jq -e '.hooks.Stop' "$SETTINGS_FILE" > /dev/null 2>&1; then
            # Backup before modifying
            cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"

            # Remove Stop hook
            jq 'del(.hooks.Stop)' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

            # Clean up empty hooks object if needed
            if jq -e '.hooks == {}' "$SETTINGS_FILE" > /dev/null 2>&1; then
                jq 'del(.hooks)' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
                mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
            fi

            echo "Removed Stop hook from settings.json"
        else
            echo "No Stop hook found in settings.json"
        fi
    else
        echo "Warning: jq not installed, cannot automatically remove hook from settings.json"
        echo "Please manually remove the Stop hook from $SETTINGS_FILE"
    fi
else
    echo "settings.json not found"
fi

# === Remove Legacy Hammerspoon Integration (if present) ===
echo ""
echo "Cleaning up legacy Hammerspoon integration (if any)..."

# Remove the Lua module
if [ -f "$HAMMERSPOON_MODULE" ]; then
    rm "$HAMMERSPOON_MODULE"
    echo "Removed $HAMMERSPOON_MODULE"
fi

# Remove require line from init.lua
if [ -f "$HAMMERSPOON_INIT" ]; then
    if grep -q 'require("claude-notify")' "$HAMMERSPOON_INIT" 2>/dev/null; then
        # Create backup
        cp "$HAMMERSPOON_INIT" "$HAMMERSPOON_INIT.backup"

        # Remove the require line and the comment above it
        sed -i '' '/^-- Claude Code notifications$/d' "$HAMMERSPOON_INIT"
        sed -i '' '/require("claude-notify")/d' "$HAMMERSPOON_INIT"

        # Remove any resulting double blank lines
        sed -i '' '/^$/N;/^\n$/d' "$HAMMERSPOON_INIT"

        echo "Removed claude-notify from Hammerspoon config"

        # Reload Hammerspoon config if running
        if pgrep -x "Hammerspoon" > /dev/null; then
            echo "Reloading Hammerspoon config..."
            osascript -e 'tell application "Hammerspoon" to execute lua code "hs.reload()"' 2>/dev/null || true
        fi
    fi
fi

echo ""
echo "Uninstallation complete!"
echo ""
echo "Note: AeroSpace and terminal-notifier were not removed (you may have other uses for them)."
echo "To fully remove them:"
echo "  brew uninstall --cask nikitabobko/tap/aerospace"
echo "  brew uninstall terminal-notifier"
echo ""
echo "If you set up iTerm Triggers, remove them manually:"
echo "  iTerm > Settings > Profiles > Advanced > Triggers"
echo ""
