#!/bin/bash
#
# Claude Code Notify - Installation Script
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
NOTIFY_SCRIPT="$CLAUDE_DIR/notify.sh"
FOCUS_SCRIPT="$CLAUDE_DIR/focus-window.sh"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

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

# === AeroSpace Setup ===
echo "Checking for AeroSpace..."
echo ""

AEROSPACE_INSTALLED=false

if command -v aerospace &> /dev/null; then
    AEROSPACE_INSTALLED=true
    echo "AeroSpace is already installed."
else
    echo "AeroSpace is a tiling window manager that provides reliable window"
    echo "focusing across workspaces on macOS (including Sequoia 15.x)."
    echo ""
    read -p "Install AeroSpace via Homebrew? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Installing AeroSpace..."
        brew install --cask nikitabobko/tap/aerospace
        AEROSPACE_INSTALLED=true
        echo ""
        echo "AeroSpace installed. You'll need to:"
        echo "  1. Start AeroSpace (it should start automatically)"
        echo "  2. Grant Accessibility permissions when prompted"
        echo ""
    else
        echo ""
        echo "Skipping AeroSpace installation."
        echo "Note: Without AeroSpace, window focusing won't work across workspaces."
        echo "You can install it later: brew install --cask nikitabobko/tap/aerospace"
        echo ""
    fi
fi

# === terminal-notifier Setup ===
echo "Checking for terminal-notifier..."

if ! command -v terminal-notifier &> /dev/null; then
    echo "terminal-notifier is required for notifications."
    read -p "Install terminal-notifier via Homebrew? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        brew install terminal-notifier
    else
        echo "Please install terminal-notifier manually: brew install terminal-notifier"
        exit 1
    fi
else
    echo "terminal-notifier is already installed."
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

# Copy focus-window.sh
echo "Installing focus-window.sh..."
cp "$SCRIPT_DIR/focus-window.sh" "$FOCUS_SCRIPT"
chmod +x "$FOCUS_SCRIPT"

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
if [ "$AEROSPACE_INSTALLED" = true ]; then
    echo "Status: Full functionality enabled (AeroSpace)"
    echo "  - Notifications: Yes"
    echo "  - Window focus across workspaces: Yes"
else
    echo "Status: Limited functionality (AeroSpace not installed)"
    echo "  - Notifications: Yes"
    echo "  - Window focus across workspaces: No"
    echo ""
    echo "To enable full functionality:"
    echo "  brew install --cask nikitabobko/tap/aerospace"
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
