#!/bin/bash
#
# Claude Code Notify - Uninstallation Script
#

set -e

CLAUDE_DIR="$HOME/.claude"
NOTIFY_SCRIPT="$CLAUDE_DIR/notify.sh"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

echo "Claude Code Notify - Uninstaller"
echo "================================="
echo ""

# Remove notify.sh
if [ -f "$NOTIFY_SCRIPT" ]; then
    rm "$NOTIFY_SCRIPT"
    echo "Removed $NOTIFY_SCRIPT"
else
    echo "notify.sh not found (already removed?)"
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

echo ""
echo "Uninstallation complete!"
echo ""
echo "Note: If you set up iTerm Triggers, remove them manually:"
echo "  iTerm > Settings > Profiles > Advanced > Triggers"
echo ""
