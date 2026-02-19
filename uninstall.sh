#!/bin/bash
#
# agentpong - Uninstallation Script
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
CLAUDE_DIR="$HOME/.claude"
NOTIFY_SCRIPT="$CLAUDE_DIR/notify.sh"
STYLE_SCRIPT="$CLAUDE_DIR/style.sh"
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
SANDBOX_PLIST="$HOME/Library/LaunchAgents/com.agentpong.sandbox.plist"

# OpenCode support paths
OPENCODE_DIR="$HOME/.opencode"
OPENCODE_NOTIFY_SCRIPT="$OPENCODE_DIR/notify.sh"
OPENCODE_STYLE_SCRIPT="$OPENCODE_DIR/style.sh"
OPENCODE_FOCUS_SCRIPT="$OPENCODE_DIR/focus-window.sh"
OPENCODE_SETTINGS_FILE="$OPENCODE_DIR/settings.json"
OPENCODE_PLUGIN_FILE="$HOME/.config/opencode/plugins/agentpong.ts"
OPENCODE_CONFIG_SETTINGS="$HOME/.config/opencode/settings.json"

# Source styling library (graceful fallback to plain echo)
source "$SRC_DIR/style.sh" 2>/dev/null || true

header "agentpong" "Uninstaller"

# === Preview what will be done ===
section "Actions to perform"

# Check notify.sh
if [ -f "$NOTIFY_SCRIPT" ]; then
    list_item "Remove" "$NOTIFY_SCRIPT"
fi

# Check style.sh
if [ -f "$STYLE_SCRIPT" ]; then
    list_item "Remove" "$STYLE_SCRIPT"
fi

# Check focus-window.sh
if [ -f "$FOCUS_SCRIPT" ]; then
    list_item "Remove" "$FOCUS_SCRIPT"
fi

# Check settings.json hooks
if [ -f "$SETTINGS_FILE" ] && command -v jq &> /dev/null; then
    if jq -e '.hooks.Stop' "$SETTINGS_FILE" > /dev/null 2>&1; then
        list_item "Remove" "Stop hook from settings.json"
    fi
    if jq -e '.hooks.PermissionRequest' "$SETTINGS_FILE" > /dev/null 2>&1; then
        list_item "Remove" "PermissionRequest hook from settings.json"
    fi
    if jq -e '.hooks.Notification' "$SETTINGS_FILE" > /dev/null 2>&1; then
        list_item "Remove" "legacy Notification hook from settings.json"
    fi
elif [ -f "$SETTINGS_FILE" ]; then
    warn "jq not installed, cannot check/remove hooks automatically"
fi

# Check legacy Hammerspoon
if [ -f "$HAMMERSPOON_MODULE" ]; then
    list_item "Remove" "$HAMMERSPOON_MODULE"
fi
if [ -f "$HAMMERSPOON_INIT" ] && grep -q 'require("claude-notify")' "$HAMMERSPOON_INIT" 2>/dev/null; then
    list_item "Remove" "claude-notify from Hammerspoon config"
fi

# Check opencode support
if [ -f "$OPENCODE_NOTIFY_SCRIPT" ]; then
    list_item "Remove" "$OPENCODE_NOTIFY_SCRIPT"
fi
if [ -f "$OPENCODE_STYLE_SCRIPT" ]; then
    list_item "Remove" "$OPENCODE_STYLE_SCRIPT"
fi
if [ -f "$OPENCODE_FOCUS_SCRIPT" ]; then
    list_item "Remove" "$OPENCODE_FOCUS_SCRIPT"
fi
if [ -f "$OPENCODE_PLUGIN_FILE" ]; then
    list_item "Remove" "$OPENCODE_PLUGIN_FILE"
fi
if [ -f "$OPENCODE_SETTINGS_FILE" ] && command -v jq &> /dev/null; then
    if jq -e '.hooks.Stop // .hooks.PermissionRequest' "$OPENCODE_SETTINGS_FILE" > /dev/null 2>&1; then
        list_item "Remove" "legacy hooks from ~/.opencode/settings.json"
    fi
fi
if [ -f "$OPENCODE_CONFIG_SETTINGS" ] && command -v jq &> /dev/null; then
    if jq -e '.hooks.Stop // .hooks.PermissionRequest' "$OPENCODE_CONFIG_SETTINGS" > /dev/null 2>&1; then
        list_item "Remove" "legacy hooks from ~/.config/opencode/settings.json"
    fi
fi

# Check sandbox support
if [ -f "$SANDBOX_PLIST" ]; then
    list_item "Remove" "launchd service"
fi
if [ -f "$SANDBOX_HANDLER" ]; then
    list_item "Remove" "$SANDBOX_HANDLER"
fi
if [ -f "$SANDBOX_NOTIFY_SCRIPT" ]; then
    list_item "Remove" "$SANDBOX_NOTIFY_SCRIPT"
fi
if [ -f "$SANDBOX_SETTINGS_FILE" ] && command -v jq &> /dev/null; then
    if jq -e '.hooks.Stop' "$SANDBOX_SETTINGS_FILE" > /dev/null 2>&1; then
        list_item "Remove" "hooks from sandbox settings.json"
    fi
fi

echo ""
confirm "Proceed with uninstallation?"

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Uninstallation cancelled."
    exit 0
fi

# === Remove Claude Code Integration ===
section "Removing Claude Code integration"

# Remove notify.sh
if [ -f "$NOTIFY_SCRIPT" ]; then
    rm "$NOTIFY_SCRIPT"
    success "Removed $NOTIFY_SCRIPT"
else
    dim "notify.sh not found (already removed?)"
fi

# Remove style.sh
if [ -f "$STYLE_SCRIPT" ]; then
    rm "$STYLE_SCRIPT"
    success "Removed $STYLE_SCRIPT"
else
    dim "style.sh not found (already removed?)"
fi

# Remove focus-window.sh
if [ -f "$FOCUS_SCRIPT" ]; then
    rm "$FOCUS_SCRIPT"
    success "Removed $FOCUS_SCRIPT"
else
    dim "focus-window.sh not found (already removed?)"
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
            success "Removed Stop hook from settings.json"
        else
            dim "No Stop hook found in settings.json"
        fi

        # Remove PermissionRequest hook
        if jq -e '.hooks.PermissionRequest' "$SETTINGS_FILE" > /dev/null 2>&1; then
            jq 'del(.hooks.PermissionRequest)' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
            success "Removed PermissionRequest hook from settings.json"
        else
            dim "No PermissionRequest hook found in settings.json"
        fi

        # Remove legacy Notification hook (if present from older versions)
        if jq -e '.hooks.Notification' "$SETTINGS_FILE" > /dev/null 2>&1; then
            jq 'del(.hooks.Notification)' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
            success "Removed legacy Notification hook from settings.json"
        fi

        # Clean up empty hooks object if needed
        if jq -e '.hooks == {}' "$SETTINGS_FILE" > /dev/null 2>&1; then
            jq 'del(.hooks)' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
        fi
    else
        warn "jq not installed, cannot automatically remove hooks from settings.json"
        dim "Please manually remove the Stop and PermissionRequest hooks from $SETTINGS_FILE"
    fi
else
    dim "settings.json not found"
fi

# === Remove Legacy Hammerspoon Integration (if present) ===
section "Cleaning up legacy Hammerspoon integration"

# Remove the Lua module
if [ -f "$HAMMERSPOON_MODULE" ]; then
    rm "$HAMMERSPOON_MODULE"
    success "Removed $HAMMERSPOON_MODULE"
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

        success "Removed claude-notify from Hammerspoon config"

        # Reload Hammerspoon config if running
        if pgrep -x "Hammerspoon" > /dev/null; then
            step "Reloading Hammerspoon config..."
            osascript -e 'tell application "Hammerspoon" to execute lua code "hs.reload()"' 2>/dev/null || true
        fi
    fi
fi

# === Remove OpenCode Support (if installed) ===
section "Cleaning up opencode support"

# Remove opencode notify.sh
if [ -f "$OPENCODE_NOTIFY_SCRIPT" ]; then
    rm "$OPENCODE_NOTIFY_SCRIPT"
    success "Removed $OPENCODE_NOTIFY_SCRIPT"
else
    dim "opencode notify.sh not found (already removed?)"
fi

# Remove opencode style.sh
if [ -f "$OPENCODE_STYLE_SCRIPT" ]; then
    rm "$OPENCODE_STYLE_SCRIPT"
    success "Removed $OPENCODE_STYLE_SCRIPT"
else
    dim "opencode style.sh not found (already removed?)"
fi

# Remove opencode focus-window.sh
if [ -f "$OPENCODE_FOCUS_SCRIPT" ]; then
    rm "$OPENCODE_FOCUS_SCRIPT"
    success "Removed $OPENCODE_FOCUS_SCRIPT"
else
    dim "opencode focus-window.sh not found (already removed?)"
fi

# Remove OpenCode plugin
if [ -f "$OPENCODE_PLUGIN_FILE" ]; then
    rm "$OPENCODE_PLUGIN_FILE"
    success "Removed $OPENCODE_PLUGIN_FILE"
else
    dim "opencode plugin not found (already removed?)"
fi

# Clean up legacy hooks from ~/.opencode/settings.json
if [ -f "$OPENCODE_SETTINGS_FILE" ] && command -v jq &> /dev/null; then
    if jq -e '.hooks.Stop // .hooks.PermissionRequest' "$OPENCODE_SETTINGS_FILE" > /dev/null 2>&1; then
        cp "$OPENCODE_SETTINGS_FILE" "$OPENCODE_SETTINGS_FILE.backup"
        jq 'del(.hooks.Stop) | del(.hooks.PermissionRequest)' "$OPENCODE_SETTINGS_FILE" > "$OPENCODE_SETTINGS_FILE.tmp"
        mv "$OPENCODE_SETTINGS_FILE.tmp" "$OPENCODE_SETTINGS_FILE"
        if jq -e '.hooks == {}' "$OPENCODE_SETTINGS_FILE" > /dev/null 2>&1; then
            jq 'del(.hooks)' "$OPENCODE_SETTINGS_FILE" > "$OPENCODE_SETTINGS_FILE.tmp"
            mv "$OPENCODE_SETTINGS_FILE.tmp" "$OPENCODE_SETTINGS_FILE"
        fi
        success "Removed legacy hooks from ~/.opencode/settings.json"
    fi
fi

# Clean up legacy hooks from ~/.config/opencode/settings.json
if [ -f "$OPENCODE_CONFIG_SETTINGS" ] && command -v jq &> /dev/null; then
    if jq -e '.hooks.Stop // .hooks.PermissionRequest' "$OPENCODE_CONFIG_SETTINGS" > /dev/null 2>&1; then
        cp "$OPENCODE_CONFIG_SETTINGS" "$OPENCODE_CONFIG_SETTINGS.backup"
        jq 'del(.hooks.Stop) | del(.hooks.PermissionRequest)' "$OPENCODE_CONFIG_SETTINGS" > "$OPENCODE_CONFIG_SETTINGS.tmp"
        mv "$OPENCODE_CONFIG_SETTINGS.tmp" "$OPENCODE_CONFIG_SETTINGS"
        if jq -e '.hooks == {}' "$OPENCODE_CONFIG_SETTINGS" > /dev/null 2>&1; then
            jq 'del(.hooks)' "$OPENCODE_CONFIG_SETTINGS" > "$OPENCODE_CONFIG_SETTINGS.tmp"
            mv "$OPENCODE_CONFIG_SETTINGS.tmp" "$OPENCODE_CONFIG_SETTINGS"
        fi
        success "Removed legacy hooks from ~/.config/opencode/settings.json"
    fi
fi

# === Remove Sandbox Support (if installed) ===
section "Cleaning up sandbox support"

# Unload and remove launchd service
if [ -f "$SANDBOX_PLIST" ]; then
    launchctl unload "$SANDBOX_PLIST" 2>/dev/null || true
    rm "$SANDBOX_PLIST"
    success "Removed launchd service"
fi

# Remove handler script
if [ -f "$SANDBOX_HANDLER" ]; then
    rm "$SANDBOX_HANDLER"
    success "Removed $SANDBOX_HANDLER"
fi

# Remove sandbox notify script
if [ -f "$SANDBOX_NOTIFY_SCRIPT" ]; then
    rm "$SANDBOX_NOTIFY_SCRIPT"
    success "Removed $SANDBOX_NOTIFY_SCRIPT"
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

        success "Removed hooks from sandbox settings.json"
    fi
fi

banner "Uninstallation complete!"

note "terminal-notifier was not removed (you may have other uses for it)."
dim "To fully remove it:"
dim "  brew uninstall terminal-notifier"
echo ""
note "If you set up iTerm Triggers, remove them manually:"
dim "  iTerm > Settings > Profiles > Advanced > Triggers"
