#!/bin/bash
#
# agentpong - Installation Script
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
CONFIG_DIR="$SCRIPT_DIR/config"
PLUGINS_DIR="$SCRIPT_DIR/plugins"

CLAUDE_DIR="$HOME/.claude"
NOTIFY_SCRIPT="$CLAUDE_DIR/notify.sh"
STYLE_SCRIPT="$CLAUDE_DIR/style.sh"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
FOCUS_SCRIPT_SRC="$SRC_DIR/focus-window.sh"
FOCUS_SCRIPT_DST="$CLAUDE_DIR/focus-window.sh"
PONG_SCRIPT_SRC="$SRC_DIR/pong.sh"
PONG_SCRIPT_DST="$CLAUDE_DIR/pong.sh"

# Sandbox support paths
SANDBOX_DIR="$HOME/.claude-sandbox"
SANDBOX_CONFIG_DIR="$SANDBOX_DIR/claude-config"
SANDBOX_NOTIFY_SCRIPT="$SANDBOX_CONFIG_DIR/notify.sh"
SANDBOX_SETTINGS_FILE="$SANDBOX_CONFIG_DIR/settings.json"
SANDBOX_HANDLER="$CLAUDE_DIR/notify-handler.sh"
SANDBOX_PLIST_TEMPLATE="$CONFIG_DIR/com.agentpong.sandbox.plist.template"
SANDBOX_PLIST="$HOME/Library/LaunchAgents/com.agentpong.sandbox.plist"

# Source styling library (graceful fallback to plain echo)
source "$SRC_DIR/style.sh" 2>/dev/null || true

header "agentpong" "Installer"

# Check for macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    error "This tool only works on macOS."
    exit 1
fi

section "Checking dependencies"

# Check for AeroSpace (optional — enables cross-workspace window focus)
HAS_AEROSPACE=false
step "Checking for AeroSpace..."
if command -v aerospace &> /dev/null || [ -x "/opt/homebrew/bin/aerospace" ] || [ -x "/usr/local/bin/aerospace" ]; then
    HAS_AEROSPACE=true
    success "AeroSpace is installed (cross-workspace window focus enabled)"
else
    warn "AeroSpace not found (optional — notifications will still work)"
    dim "Install AeroSpace for cross-workspace window focus:"
    dim "  brew install --cask nikitabobko/tap/aerospace"
fi

# Check for jq (needed for JSON manipulation)
if ! command -v jq &> /dev/null; then
    warn "jq is required but not installed."
    confirm "Install jq via Homebrew?"
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        spin "Installing jq..." brew install jq
    else
        error "Please install jq manually: brew install jq"
        exit 1
    fi
fi

# Check for terminal-notifier
step "Checking for terminal-notifier..."
if ! command -v terminal-notifier &> /dev/null; then
    warn "terminal-notifier is required for notifications."
    confirm "Install terminal-notifier via Homebrew?"
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        spin "Installing terminal-notifier..." brew install terminal-notifier
    else
        error "Please install terminal-notifier manually: brew install terminal-notifier"
        exit 1
    fi
else
    success "terminal-notifier is already installed"
fi

section "Setting up Claude Code integration"

# Create .claude directory if needed
mkdir -p "$CLAUDE_DIR"

# Copy notify.sh
step "Installing notify.sh..."
cp "$SRC_DIR/notify.sh" "$NOTIFY_SCRIPT"
chmod +x "$NOTIFY_SCRIPT"

# Copy style.sh (used by notify.sh for styled errors)
step "Installing style.sh..."
cp "$SRC_DIR/style.sh" "$STYLE_SCRIPT"
chmod +x "$STYLE_SCRIPT"

# Install focus-window.sh
step "Installing focus-window.sh..."
if [ -f "$FOCUS_SCRIPT_DST" ]; then
    # Update existing file
    cp "$FOCUS_SCRIPT_SRC" "$FOCUS_SCRIPT_DST"
    chmod +x "$FOCUS_SCRIPT_DST"
    success "Updated focus-window.sh"
else
    # Fresh install
    cp "$FOCUS_SCRIPT_SRC" "$FOCUS_SCRIPT_DST"
    chmod +x "$FOCUS_SCRIPT_DST"
    success "Installed focus-window.sh"
fi

# Install pong.sh (notification cycling)
step "Installing pong.sh..."
if [ -f "$PONG_SCRIPT_DST" ]; then
    cp "$PONG_SCRIPT_SRC" "$PONG_SCRIPT_DST"
    chmod +x "$PONG_SCRIPT_DST"
    success "Updated pong.sh"
else
    cp "$PONG_SCRIPT_SRC" "$PONG_SCRIPT_DST"
    chmod +x "$PONG_SCRIPT_DST"
    success "Installed pong.sh"
fi

# Configure settings.json
step "Configuring Claude Code hooks..."

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
    dim "Backed up existing settings to $SETTINGS_FILE.backup"

    # Check if Stop hook already exists
    if jq -e '.hooks.Stop' "$SETTINGS_FILE" > /dev/null 2>&1; then
        warn "Stop hook already exists in settings.json"
        confirm "Replace existing Stop hook?"
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            jq --argjson hook "[$STOP_HOOK_CONFIG]" '.hooks.Stop = $hook' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
        else
            info "Keeping existing Stop hook."
        fi
    else
        jq --argjson hook "[$STOP_HOOK_CONFIG]" '.hooks.Stop = $hook' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
        mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    fi

    # Check if PermissionRequest hook already exists
    if jq -e '.hooks.PermissionRequest' "$SETTINGS_FILE" > /dev/null 2>&1; then
        warn "PermissionRequest hook already exists in settings.json"
        confirm "Replace existing PermissionRequest hook?"
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            jq --argjson hook "[$PERMISSION_HOOK_CONFIG]" '.hooks.PermissionRequest = $hook' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
        else
            info "Keeping existing PermissionRequest hook."
        fi
    else
        jq --argjson hook "[$PERMISSION_HOOK_CONFIG]" '.hooks.PermissionRequest = $hook' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
        mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    fi
else
    # Create new settings.json with both hooks
    echo "{\"hooks\":{\"Stop\":[$STOP_HOOK_CONFIG],\"PermissionRequest\":[$PERMISSION_HOOK_CONFIG]}}" | jq '.' > "$SETTINGS_FILE"
fi

# Restart terminal-notifier (kill lingering processes so next notification starts fresh)
step "Restarting terminal-notifier..."
killall terminal-notifier 2>/dev/null && success "Restarted terminal-notifier" || dim "No running terminal-notifier processes"

banner "Installation complete!"

info "Features enabled:"
list_item "Notifications" "Yes"
if [ "$HAS_AEROSPACE" = true ]; then
    list_item "Window focus" "Yes (AeroSpace detected)"
else
    list_item "Window focus" "No (install AeroSpace for cross-workspace focus)"
fi
echo ""

section "Usage"

info "Cursor/VS Code: Notifications work automatically."
dim "Start a new Claude session and you'll get notifications"
dim "when Claude is ready for input."
echo ""
info "iTerm2: Claude Code hooks don't work in standalone terminals."
dim "Set up iTerm Triggers instead:"
dim "  1. iTerm > Settings > Profiles > Advanced > Triggers > Edit"
dim "  2. Add a trigger:"
dim "       Regex: ^[[:space:]]*>"
dim "       Action: Run Command..."
dim "       Parameters: $NOTIFY_SCRIPT \"Ready for input\""
dim "       Check: Instant"
echo ""
info "Notification cycling: Bind pong.sh to a shortcut to cycle through pending notifications."
dim "  AeroSpace (via aerospace-setup): alt+n is auto-detected during install"
dim "  skhd: Add to ~/.skhdrc:"
dim "    alt - n : ~/.claude/pong.sh"
dim "  Raycast/macOS Shortcuts: Run Shell Script -> ~/.claude/pong.sh"

# === opencode Integration (Optional) ===
install_opencode_support() {
    section "Installing opencode support"

    # OpenCode config paths
    OPENCODE_DIR="$HOME/.opencode"
    OPENCODE_NOTIFY_SCRIPT="$OPENCODE_DIR/notify.sh"
    OPENCODE_STYLE_SCRIPT="$OPENCODE_DIR/style.sh"
    OPENCODE_SETTINGS_FILE="$OPENCODE_DIR/settings.json"
    OPENCODE_FOCUS_SCRIPT="$OPENCODE_DIR/focus-window.sh"

    # Create .opencode directory if needed
    mkdir -p "$OPENCODE_DIR"

    # Copy notify.sh
    step "Installing notify.sh to opencode directory..."
    cp "$SRC_DIR/notify.sh" "$OPENCODE_NOTIFY_SCRIPT"
    chmod +x "$OPENCODE_NOTIFY_SCRIPT"

    # Copy style.sh (used by notify.sh for styled errors)
    step "Installing style.sh to opencode directory..."
    cp "$SRC_DIR/style.sh" "$OPENCODE_STYLE_SCRIPT"
    chmod +x "$OPENCODE_STYLE_SCRIPT"

    # Copy focus-window.sh
    step "Installing focus-window.sh to opencode directory..."
    cp "$SRC_DIR/focus-window.sh" "$OPENCODE_FOCUS_SCRIPT"
    chmod +x "$OPENCODE_FOCUS_SCRIPT"

    # Copy pong.sh
    step "Installing pong.sh to opencode directory..."
    cp "$SRC_DIR/pong.sh" "$OPENCODE_DIR/pong.sh"
    chmod +x "$OPENCODE_DIR/pong.sh"

    # Install OpenCode plugin
    OPENCODE_PLUGIN_DIR="$HOME/.config/opencode/plugins"
    OPENCODE_PLUGIN_FILE="$OPENCODE_PLUGIN_DIR/agentpong.ts"
    step "Installing OpenCode plugin..."
    mkdir -p "$OPENCODE_PLUGIN_DIR"
    cp "$PLUGINS_DIR/opencode/agentpong.ts" "$OPENCODE_PLUGIN_FILE"
    success "Installed OpenCode plugin to $OPENCODE_PLUGIN_FILE"

    # Clean up legacy broken hooks from ~/.opencode/settings.json
    OPENCODE_CONFIG_SETTINGS="$HOME/.config/opencode/settings.json"
    if [ -f "$OPENCODE_SETTINGS_FILE" ] && command -v jq &> /dev/null; then
        if jq -e '.hooks.Stop // .hooks.PermissionRequest' "$OPENCODE_SETTINGS_FILE" > /dev/null 2>&1; then
            dim "Cleaning up legacy hooks from $OPENCODE_SETTINGS_FILE..."
            cp "$OPENCODE_SETTINGS_FILE" "$OPENCODE_SETTINGS_FILE.backup"
            jq 'del(.hooks.Stop) | del(.hooks.PermissionRequest)' "$OPENCODE_SETTINGS_FILE" > "$OPENCODE_SETTINGS_FILE.tmp"
            mv "$OPENCODE_SETTINGS_FILE.tmp" "$OPENCODE_SETTINGS_FILE"
            if jq -e '.hooks == {}' "$OPENCODE_SETTINGS_FILE" > /dev/null 2>&1; then
                jq 'del(.hooks)' "$OPENCODE_SETTINGS_FILE" > "$OPENCODE_SETTINGS_FILE.tmp"
                mv "$OPENCODE_SETTINGS_FILE.tmp" "$OPENCODE_SETTINGS_FILE"
            fi
            success "Removed legacy hooks from $OPENCODE_SETTINGS_FILE"
        fi
    fi

    # Clean up legacy broken hooks from ~/.config/opencode/settings.json
    if [ -f "$OPENCODE_CONFIG_SETTINGS" ] && command -v jq &> /dev/null; then
        if jq -e '.hooks.Stop // .hooks.PermissionRequest' "$OPENCODE_CONFIG_SETTINGS" > /dev/null 2>&1; then
            dim "Cleaning up legacy hooks from $OPENCODE_CONFIG_SETTINGS..."
            cp "$OPENCODE_CONFIG_SETTINGS" "$OPENCODE_CONFIG_SETTINGS.backup"
            jq 'del(.hooks.Stop) | del(.hooks.PermissionRequest)' "$OPENCODE_CONFIG_SETTINGS" > "$OPENCODE_CONFIG_SETTINGS.tmp"
            mv "$OPENCODE_CONFIG_SETTINGS.tmp" "$OPENCODE_CONFIG_SETTINGS"
            if jq -e '.hooks == {}' "$OPENCODE_CONFIG_SETTINGS" > /dev/null 2>&1; then
                jq 'del(.hooks)' "$OPENCODE_CONFIG_SETTINGS" > "$OPENCODE_CONFIG_SETTINGS.tmp"
                mv "$OPENCODE_CONFIG_SETTINGS.tmp" "$OPENCODE_CONFIG_SETTINGS"
            fi
            success "Removed legacy hooks from $OPENCODE_CONFIG_SETTINGS"
        fi
    fi

    success "Configured OpenCode plugin"
    banner "opencode support installed!"

    info "OpenCode notifications will appear with workspace names."
    dim "Start a new OpenCode session and you'll get notifications"
    dim "when OpenCode is ready for input."
}

# === claude-sandbox Integration (Optional) ===
install_sandbox_support() {
    section "Installing sandbox support"

    # Create directories
    mkdir -p "$SANDBOX_CONFIG_DIR"
    mkdir -p "$HOME/Library/LaunchAgents"

    # Copy handler script to ~/.claude/
    cp "$SRC_DIR/notify-handler.sh" "$SANDBOX_HANDLER"
    chmod +x "$SANDBOX_HANDLER"
    step "Installed $SANDBOX_HANDLER"

    # Copy sandbox notify script to ~/.claude-sandbox/claude-config/
    cp "$SRC_DIR/notify-sandbox.sh" "$SANDBOX_NOTIFY_SCRIPT"
    chmod +x "$SANDBOX_NOTIFY_SCRIPT"
    step "Installed $SANDBOX_NOTIFY_SCRIPT"

    # Generate plist with expanded $HOME paths
    sed "s|__HOME__|$HOME|g" "$SANDBOX_PLIST_TEMPLATE" > "$SANDBOX_PLIST"
    step "Installed $SANDBOX_PLIST"

    # Unload existing service if running (ignore errors)
    launchctl unload "$SANDBOX_PLIST" 2>/dev/null || true

    # Load the launchd service (starts TCP listener on port 19223)
    launchctl load "$SANDBOX_PLIST"
    success "Started launchd service (TCP listener on localhost:19223)"

    # Configure hooks in sandbox settings.json
    step "Configuring sandbox hooks..."

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
    success "Configured hooks in sandbox settings"

    banner "Sandbox support installed!"

    note "If you haven't already, rebuild claude-sandbox to include netcat:"
    dim "  cd <path-to-claude-sandbox> && ./docker/build.sh && ./docker/install.sh"
}

echo ""
confirm "Do you use opencode? Enable opencode notification support?"
if [[ $REPLY =~ ^[Yy]$ ]]; then
    install_opencode_support
fi

echo ""
confirm "Do you use claude-sandbox? Enable sandbox notification support?"
if [[ $REPLY =~ ^[Yy]$ ]]; then
    install_sandbox_support
fi
