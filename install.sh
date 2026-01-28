#!/bin/bash
#
# Claude Code Notify - Installation Script
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
NOTIFY_SCRIPT="$CLAUDE_DIR/notify.sh"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
FOCUS_SYMLINK="$CLAUDE_DIR/focus-window.sh"

# Sandbox support paths
SANDBOX_DIR="$HOME/.claude-sandbox"
SANDBOX_CONFIG_DIR="$SANDBOX_DIR/claude-config"
SANDBOX_NOTIFY_SCRIPT="$SANDBOX_CONFIG_DIR/notify.sh"
SANDBOX_SETTINGS_FILE="$SANDBOX_CONFIG_DIR/settings.json"
SANDBOX_HANDLER="$CLAUDE_DIR/notify-handler.sh"
SANDBOX_PLIST_TEMPLATE="$SCRIPT_DIR/com.claude-code-notify.sandbox.plist.template"
SANDBOX_PLIST="$HOME/Library/LaunchAgents/com.claude-code-notify.sandbox.plist"

echo "Claude Code Notify - Installer"
echo "==============================="
echo ""

# Check for macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Error: This tool only works on macOS."
    exit 1
fi

# Check for aerospace-setup dependency (provides focus-window.sh symlink)
echo "Checking for aerospace-setup..."
if [ ! -L "$FOCUS_SYMLINK" ]; then
    echo ""
    echo "ERROR: aerospace-setup is required for click-to-focus functionality."
    echo ""
    echo "The symlink ~/.claude/focus-window.sh was not found."
    echo ""
    echo "Please install aerospace-setup first:"
    echo "  git clone https://github.com/tsilva/aerospace-setup.git"
    echo "  cd aerospace-setup"
    echo "  ./install.sh"
    echo ""
    echo "Then run this installer again."
    exit 1
fi
echo "✓ aerospace-setup is installed (focus-window.sh symlink found)"
echo ""

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
    echo "✓ terminal-notifier is already installed"
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

# Stop hook - fires when Claude finishes a task
STOP_HOOK_CONFIG='{
  "matcher": "",
  "hooks": [
    {
      "type": "command",
      "command": "'"$NOTIFY_SCRIPT"' '\''Ready for input'\''"
    }
  ]
}'

# PermissionRequest hook - fires when permission dialog is shown
PERMISSION_HOOK_CONFIG='{
  "matcher": "",
  "hooks": [
    {
      "type": "command",
      "command": "'"$NOTIFY_SCRIPT"' '\''Permission required'\''"
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
            jq --argjson hook "[$STOP_HOOK_CONFIG]" '.hooks.Stop = $hook' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
        else
            echo "Keeping existing Stop hook."
        fi
    else
        jq --argjson hook "[$STOP_HOOK_CONFIG]" '.hooks.Stop = $hook' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
        mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    fi

    # Check if PermissionRequest hook already exists
    if jq -e '.hooks.PermissionRequest' "$SETTINGS_FILE" > /dev/null 2>&1; then
        echo "PermissionRequest hook already exists in settings.json"
        read -p "Replace existing PermissionRequest hook? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            jq --argjson hook "[$PERMISSION_HOOK_CONFIG]" '.hooks.PermissionRequest = $hook' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
        else
            echo "Keeping existing PermissionRequest hook."
        fi
    else
        jq --argjson hook "[$PERMISSION_HOOK_CONFIG]" '.hooks.PermissionRequest = $hook' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
        mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    fi
else
    # Create new settings.json with both hooks
    echo "{\"hooks\":{\"Stop\":[$STOP_HOOK_CONFIG],\"PermissionRequest\":[$PERMISSION_HOOK_CONFIG]}}" | jq '.' > "$SETTINGS_FILE"
fi

echo ""
echo "Installation complete!"
echo ""
echo "Features enabled:"
echo "  - Notifications: Yes"
echo "  - Window focus across workspaces: Yes (via aerospace-setup)"
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

# === claude-sandbox Integration (Optional) ===
install_sandbox_support() {
    echo ""
    echo "Installing claude-sandbox notification support..."
    echo ""

    # Create directories
    mkdir -p "$SANDBOX_CONFIG_DIR"
    mkdir -p "$HOME/Library/LaunchAgents"

    # Copy handler script to ~/.claude/
    cp "$SCRIPT_DIR/notify-handler.sh" "$SANDBOX_HANDLER"
    chmod +x "$SANDBOX_HANDLER"
    echo "Installed $SANDBOX_HANDLER"

    # Copy sandbox notify script to ~/.claude-sandbox/claude-config/
    cp "$SCRIPT_DIR/notify-sandbox.sh" "$SANDBOX_NOTIFY_SCRIPT"
    chmod +x "$SANDBOX_NOTIFY_SCRIPT"
    echo "Installed $SANDBOX_NOTIFY_SCRIPT"

    # Generate plist with expanded $HOME paths
    sed "s|__HOME__|$HOME|g" "$SANDBOX_PLIST_TEMPLATE" > "$SANDBOX_PLIST"
    echo "Installed $SANDBOX_PLIST"

    # Unload existing service if running (ignore errors)
    launchctl unload "$SANDBOX_PLIST" 2>/dev/null || true

    # Load the launchd service (starts TCP listener on port 19223)
    launchctl load "$SANDBOX_PLIST"
    echo "Started launchd service (TCP listener on localhost:19223)"

    # Configure hooks in sandbox settings.json
    echo "Configuring sandbox hooks..."

    # Note: Use container path, not host path
    # ~/.claude-sandbox/claude-config on host is mounted to /home/claude/.claude in container
    SANDBOX_STOP_HOOK_CONFIG='{
      "matcher": "",
      "hooks": [
        {
          "type": "command",
          "command": "/home/claude/.claude/notify.sh '\''Ready for input'\''"
        }
      ]
    }'

    SANDBOX_PERMISSION_HOOK_CONFIG='{
      "matcher": "",
      "hooks": [
        {
          "type": "command",
          "command": "/home/claude/.claude/notify.sh '\''Permission required'\''"
        }
      ]
    }'

    if [ -f "$SANDBOX_SETTINGS_FILE" ]; then
        # Backup existing settings
        cp "$SANDBOX_SETTINGS_FILE" "$SANDBOX_SETTINGS_FILE.backup"

        # Add/update hooks
        jq --argjson stop "[$SANDBOX_STOP_HOOK_CONFIG]" --argjson perm "[$SANDBOX_PERMISSION_HOOK_CONFIG]" \
            '.hooks.Stop = $stop | .hooks.PermissionRequest = $perm' \
            "$SANDBOX_SETTINGS_FILE" > "$SANDBOX_SETTINGS_FILE.tmp"
        mv "$SANDBOX_SETTINGS_FILE.tmp" "$SANDBOX_SETTINGS_FILE"
    else
        # Create new settings.json
        echo "{\"hooks\":{\"Stop\":[$SANDBOX_STOP_HOOK_CONFIG],\"PermissionRequest\":[$SANDBOX_PERMISSION_HOOK_CONFIG]}}" | jq '.' > "$SANDBOX_SETTINGS_FILE"
    fi
    echo "Configured hooks in $SANDBOX_SETTINGS_FILE"

    echo ""
    echo "Sandbox support installed!"
    echo ""
    echo "Note: If you haven't already, rebuild claude-sandbox to include netcat:"
    echo "  cd <path-to-claude-sandbox> && ./docker/build.sh && ./docker/install.sh"
    echo ""
}

echo ""
echo "Do you use claude-sandbox (containerized Claude Code)?"
read -p "Enable sandbox notification support? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    install_sandbox_support
fi
