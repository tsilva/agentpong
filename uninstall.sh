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

# Sandbox support paths
SANDBOX_DIR="$HOME/.claude-sandbox"
SANDBOX_CONFIG_DIR="$SANDBOX_DIR/claude-config"
SANDBOX_NOTIFY_SCRIPT="$SANDBOX_CONFIG_DIR/notify.sh"
SANDBOX_SETTINGS_FILE="$SANDBOX_CONFIG_DIR/settings.json"
SANDBOX_HANDLER="$CLAUDE_DIR/notify-handler.sh"
SANDBOX_PLIST="$HOME/Library/LaunchAgents/com.claude-code-notify.sandbox.plist"

echo "Claude Code Notify - Uninstaller"
echo "================================="
echo ""

# === Preview what will be done ===
echo "This will perform the following actions:"
echo ""

# Check notify.sh
if [ -f "$NOTIFY_SCRIPT" ]; then
    echo "  - Remove $NOTIFY_SCRIPT"
fi

# Check focus-window.sh
if [ -f "$FOCUS_SCRIPT" ]; then
    echo "  - Remove $FOCUS_SCRIPT"
fi

# Check settings.json hooks
if [ -f "$SETTINGS_FILE" ] && command -v jq &> /dev/null; then
    if jq -e '.hooks.Stop' "$SETTINGS_FILE" > /dev/null 2>&1; then
        echo "  - Remove Stop hook from settings.json"
    fi
    if jq -e '.hooks.PermissionRequest' "$SETTINGS_FILE" > /dev/null 2>&1; then
        echo "  - Remove PermissionRequest hook from settings.json"
    fi
    if jq -e '.hooks.Notification' "$SETTINGS_FILE" > /dev/null 2>&1; then
        echo "  - Remove legacy Notification hook from settings.json"
    fi
elif [ -f "$SETTINGS_FILE" ]; then
    echo "  - Warning: jq not installed, cannot check/remove hooks automatically"
fi

# Check legacy Hammerspoon
if [ -f "$HAMMERSPOON_MODULE" ]; then
    echo "  - Remove $HAMMERSPOON_MODULE"
fi
if [ -f "$HAMMERSPOON_INIT" ] && grep -q 'require("claude-notify")' "$HAMMERSPOON_INIT" 2>/dev/null; then
    echo "  - Remove claude-notify from Hammerspoon config"
fi

# Check sandbox support
if [ -f "$SANDBOX_PLIST" ]; then
    echo "  - Unload and remove launchd service"
fi
if [ -f "$SANDBOX_HANDLER" ]; then
    echo "  - Remove $SANDBOX_HANDLER"
fi
if [ -f "$SANDBOX_NOTIFY_SCRIPT" ]; then
    echo "  - Remove $SANDBOX_NOTIFY_SCRIPT"
fi
if [ -f "$SANDBOX_SETTINGS_FILE" ] && command -v jq &> /dev/null; then
    if jq -e '.hooks.Stop' "$SANDBOX_SETTINGS_FILE" > /dev/null 2>&1; then
        echo "  - Remove hooks from sandbox settings.json"
    fi
fi

echo ""
read -p "Proceed with uninstallation? [y/N] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

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

# Remove hooks from settings.json
if [ -f "$SETTINGS_FILE" ]; then
    if command -v jq &> /dev/null; then
        # Backup before modifying
        cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"

        # Remove Stop hook
        if jq -e '.hooks.Stop' "$SETTINGS_FILE" > /dev/null 2>&1; then
            jq 'del(.hooks.Stop)' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
            echo "Removed Stop hook from settings.json"
        else
            echo "No Stop hook found in settings.json"
        fi

        # Remove PermissionRequest hook
        if jq -e '.hooks.PermissionRequest' "$SETTINGS_FILE" > /dev/null 2>&1; then
            jq 'del(.hooks.PermissionRequest)' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
            echo "Removed PermissionRequest hook from settings.json"
        else
            echo "No PermissionRequest hook found in settings.json"
        fi

        # Remove legacy Notification hook (if present from older versions)
        if jq -e '.hooks.Notification' "$SETTINGS_FILE" > /dev/null 2>&1; then
            jq 'del(.hooks.Notification)' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
            echo "Removed legacy Notification hook from settings.json"
        fi

        # Clean up empty hooks object if needed
        if jq -e '.hooks == {}' "$SETTINGS_FILE" > /dev/null 2>&1; then
            jq 'del(.hooks)' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
        fi
    else
        echo "Warning: jq not installed, cannot automatically remove hooks from settings.json"
        echo "Please manually remove the Stop and PermissionRequest hooks from $SETTINGS_FILE"
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

# === Remove Sandbox Support (if installed) ===
echo ""
echo "Cleaning up sandbox support (if any)..."

# Unload and remove launchd service
if [ -f "$SANDBOX_PLIST" ]; then
    launchctl unload "$SANDBOX_PLIST" 2>/dev/null || true
    rm "$SANDBOX_PLIST"
    echo "Removed launchd service"
fi

# Remove handler script
if [ -f "$SANDBOX_HANDLER" ]; then
    rm "$SANDBOX_HANDLER"
    echo "Removed $SANDBOX_HANDLER"
fi

# Remove sandbox notify script
if [ -f "$SANDBOX_NOTIFY_SCRIPT" ]; then
    rm "$SANDBOX_NOTIFY_SCRIPT"
    echo "Removed $SANDBOX_NOTIFY_SCRIPT"
fi

# Remove hooks from sandbox settings.json
if [ -f "$SANDBOX_SETTINGS_FILE" ] && command -v jq &> /dev/null; then
    if jq -e '.hooks.Stop' "$SANDBOX_SETTINGS_FILE" > /dev/null 2>&1 || \
       jq -e '.hooks.PermissionRequest' "$SANDBOX_SETTINGS_FILE" > /dev/null 2>&1; then
        cp "$SANDBOX_SETTINGS_FILE" "$SANDBOX_SETTINGS_FILE.backup"

        # Remove Stop hook
        if jq -e '.hooks.Stop' "$SANDBOX_SETTINGS_FILE" > /dev/null 2>&1; then
            jq 'del(.hooks.Stop)' "$SANDBOX_SETTINGS_FILE" > "$SANDBOX_SETTINGS_FILE.tmp"
            mv "$SANDBOX_SETTINGS_FILE.tmp" "$SANDBOX_SETTINGS_FILE"
        fi

        # Remove PermissionRequest hook
        if jq -e '.hooks.PermissionRequest' "$SANDBOX_SETTINGS_FILE" > /dev/null 2>&1; then
            jq 'del(.hooks.PermissionRequest)' "$SANDBOX_SETTINGS_FILE" > "$SANDBOX_SETTINGS_FILE.tmp"
            mv "$SANDBOX_SETTINGS_FILE.tmp" "$SANDBOX_SETTINGS_FILE"
        fi

        # Clean up empty hooks object
        if jq -e '.hooks == {}' "$SANDBOX_SETTINGS_FILE" > /dev/null 2>&1; then
            jq 'del(.hooks)' "$SANDBOX_SETTINGS_FILE" > "$SANDBOX_SETTINGS_FILE.tmp"
            mv "$SANDBOX_SETTINGS_FILE.tmp" "$SANDBOX_SETTINGS_FILE"
        fi

        echo "Removed hooks from sandbox settings.json"
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
