#!/bin/bash
#
# Claude Code Notify - Installation Script
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
NOTIFY_SCRIPT="$CLAUDE_DIR/notify.sh"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

echo "Claude Code Notify - Installer"
echo "==============================="
echo ""

# Check for macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Error: This tool only works on macOS."
    exit 1
fi

# Check for terminal-notifier
if ! command -v terminal-notifier &> /dev/null; then
    echo "terminal-notifier is required but not installed."
    read -p "Install via Homebrew? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        brew install terminal-notifier
    else
        echo "Please install terminal-notifier manually: brew install terminal-notifier"
        exit 1
    fi
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
echo "Usage:"
echo "  - Cursor/VS Code: Notifications work automatically."
echo "    Start a new Claude session and you'll get notifications"
echo "    when Claude is ready for input."
echo ""
echo "  - iTerm2: Claude Code hooks don't work in standalone terminals."
echo "    Set up iTerm Triggers instead:"
echo "    1. iTerm > Settings > Profiles > Advanced > Triggers > Edit"
echo "    2. Add a trigger:"
echo "       Regex: ^[[:space:]]*❯"
echo "       Action: Run Command..."
echo "       Parameters: $NOTIFY_SCRIPT \"Ready for input\""
echo "       Check: Instant"
echo ""
