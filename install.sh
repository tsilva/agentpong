#!/bin/bash
#
# Claude Code Notify - Installation Script
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
NOTIFY_SCRIPT="$CLAUDE_DIR/notify.sh"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
HAMMERSPOON_DIR="$HOME/.hammerspoon"
HAMMERSPOON_INIT="$HAMMERSPOON_DIR/init.lua"
HAMMERSPOON_MODULE="$HAMMERSPOON_DIR/claude-notify.lua"

echo "Claude Code Notify - Installer"
echo "==============================="
echo ""

# Check for macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Error: This tool only works on macOS."
    exit 1
fi

# Check for jq (needed for JSON manipulation)
if ! command -v jq &> /dev/null; then
    echo "jq is required but not installed."
    read -p "Install via Homebrew? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        brew install jq
    else
        echo "Please install jq manually: brew install jq"
        exit 1
    fi
fi

# === Hammerspoon Setup ===
echo "Setting up Hammerspoon (required for window focusing across Spaces)..."
echo ""

# Check if Hammerspoon is installed
HAMMERSPOON_INSTALLED=false
if [ -d "/Applications/Hammerspoon.app" ] || [ -d "$HOME/Applications/Hammerspoon.app" ]; then
    HAMMERSPOON_INSTALLED=true
fi

if [ "$HAMMERSPOON_INSTALLED" = false ]; then
    echo "Hammerspoon is not installed."
    read -p "Install via Homebrew? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        brew install --cask hammerspoon
        HAMMERSPOON_INSTALLED=true
        echo ""
        echo "Hammerspoon installed. You'll need to:"
        echo "  1. Open Hammerspoon from Applications"
        echo "  2. Grant Accessibility permissions when prompted"
        echo ""
        read -p "Press Enter once Hammerspoon is running with permissions..." -r
    else
        echo ""
        echo "Skipping Hammerspoon installation."
        echo "Note: Without Hammerspoon, window focusing won't work across Spaces."
        echo "You can install it later: brew install --cask hammerspoon"
        echo ""
    fi
fi

# Setup Hammerspoon module if installed
if [ "$HAMMERSPOON_INSTALLED" = true ]; then
    # Create .hammerspoon directory if needed
    mkdir -p "$HAMMERSPOON_DIR"

    # Copy the Lua module
    echo "Installing Hammerspoon module..."
    cp "$SCRIPT_DIR/claude-notify.lua" "$HAMMERSPOON_MODULE"

    # Create init.lua if it doesn't exist
    if [ ! -f "$HAMMERSPOON_INIT" ]; then
        echo '-- Hammerspoon configuration' > "$HAMMERSPOON_INIT"
        echo 'require("hs.ipc")' >> "$HAMMERSPOON_INIT"
        echo "" >> "$HAMMERSPOON_INIT"
    fi

    # Add require for claude-notify if not already present
    if ! grep -q 'require("claude-notify")' "$HAMMERSPOON_INIT" 2>/dev/null; then
        echo "" >> "$HAMMERSPOON_INIT"
        echo '-- Claude Code notifications' >> "$HAMMERSPOON_INIT"
        echo 'require("claude-notify")' >> "$HAMMERSPOON_INIT"
        echo "Added claude-notify to Hammerspoon config"
    else
        echo "claude-notify already in Hammerspoon config"
    fi

    # Install hs CLI if not present
    if ! command -v hs &> /dev/null; then
        echo "Installing Hammerspoon CLI tool..."
        # Try to install via hs.ipc.cliInstall()
        if pgrep -x "Hammerspoon" > /dev/null; then
            # Hammerspoon is running, try to install CLI
            osascript -e 'tell application "Hammerspoon" to execute lua code "hs.ipc.cliInstall()"' 2>/dev/null || true
            echo "CLI installation attempted. If 'hs' command is not available,"
            echo "run this in Hammerspoon console: hs.ipc.cliInstall()"
        else
            echo "Note: Start Hammerspoon and run hs.ipc.cliInstall() in the console"
            echo "to enable the 'hs' command line tool."
        fi
    else
        echo "Hammerspoon CLI (hs) is already installed"
    fi

    # Reload Hammerspoon config
    if pgrep -x "Hammerspoon" > /dev/null; then
        echo "Reloading Hammerspoon config..."
        osascript -e 'tell application "Hammerspoon" to execute lua code "hs.reload()"' 2>/dev/null || true
    fi
fi

# === Claude Code Setup ===
echo ""
echo "Setting up Claude Code integration..."

# Create .claude directory if needed
mkdir -p "$CLAUDE_DIR"

# Copy notify.sh
echo "Installing notify.sh..."
cp "$SCRIPT_DIR/notify.sh" "$NOTIFY_SCRIPT"
chmod +x "$NOTIFY_SCRIPT"

# Configure settings.json
echo "Configuring Claude Code hooks..."

HOOK_CONFIG='{
  "matcher": "",
  "hooks": [
    {
      "type": "command",
      "command": "'"$NOTIFY_SCRIPT"' '\''Ready for input'\''"
    }
  ]
}'

if [ -f "$SETTINGS_FILE" ]; then
    # Backup existing settings
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"
    echo "Backed up existing settings to $SETTINGS_FILE.backup"

    # Check if Stop hook already exists
    if jq -e '.hooks.Stop' "$SETTINGS_FILE" > /dev/null 2>&1; then
        echo "Stop hook already exists in settings.json"
        read -p "Replace existing Stop hook? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Replace Stop hook
            jq --argjson hook "[$HOOK_CONFIG]" '.hooks.Stop = $hook' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
        else
            echo "Keeping existing Stop hook."
        fi
    else
        # Add Stop hook to existing hooks
        jq --argjson hook "[$HOOK_CONFIG]" '.hooks.Stop = $hook' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
        mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    fi
else
    # Create new settings.json
    echo "{\"hooks\":{\"Stop\":[$HOOK_CONFIG]}}" | jq '.' > "$SETTINGS_FILE"
fi

echo ""
echo "Installation complete!"
echo ""

# Check what features are available
if command -v hs &> /dev/null; then
    echo "Status: Full functionality enabled (Hammerspoon)"
    echo "  - Notifications: Yes"
    echo "  - Window focus across Spaces: Yes"
else
    echo "Status: Limited functionality (Hammerspoon CLI not available)"
    echo "  - Notifications: Yes (via terminal-notifier fallback)"
    echo "  - Window focus across Spaces: No"
    echo ""
    echo "To enable full functionality:"
    echo "  1. Start Hammerspoon"
    echo "  2. Run in Hammerspoon console: hs.ipc.cliInstall()"
    echo "  3. Restart your terminal"
fi

echo ""
echo "Usage:"
echo "  - Cursor/VS Code: Notifications work automatically."
echo "    Start a new Claude session and you'll get notifications"
echo "    when Claude is ready for input."
echo ""
echo "  - iTerm2: Claude Code hooks don't work in standalone terminals."
echo "    Set up iTerm Triggers instead:"
echo "    1. iTerm > Settings > Profiles > Advanced > Triggers > Edit"
echo "    2. Add a trigger:"
echo "       Regex: ^[[:space:]]*>"
echo "       Action: Run Command..."
echo "       Parameters: $NOTIFY_SCRIPT \"Ready for input\""
echo "       Check: Instant"
echo ""
