#!/bin/bash
#
# agentpong - Installation Script
# Version: 1.0.0
#
# Idempotent installation script that works both remotely (via curl) and locally.
# When run via curl, it downloads the repository first, then executes the install.
# When run locally, it uses the existing source files.
#
# Usage:
#   Remote:  curl -fsSL https://raw.githubusercontent.com/tsilva/agentpong/main/install.sh | bash
#   Local:   ./install.sh
#

set -e

# Version tracking for idempotency
AGENTPONG_VERSION="1.0.0"
REPO_URL="https://github.com/tsilva/agentpong"
FORCE_INSTALL=false
BRANCH="main"
TEMP_DIR=""

# Check if we're running via curl pipe (stdin not a TTY, no local files)
# or if the script is being piped/redirected
is_remote_run() {
    # If stdin is not a TTY, likely running via curl
    if [[ ! -t 0 ]]; then
        return 0
    fi
    # If script directory doesn't contain src/ subdirectory, we're not in the repo
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ ! -d "$script_dir/src" ]]; then
        return 0
    fi
    return 1
}

# Download and extract the repository
download_repo() {
    TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/agentpong.XXXXXX")
    
    # Download tarball
    if ! curl -fsSL "${REPO_URL}/archive/refs/heads/${BRANCH}.tar.gz" -o "$TEMP_DIR/agentpong.tar.gz" 2>/dev/null; then
        return 1
    fi
    
    # Extract
    tar -xzf "$TEMP_DIR/agentpong.tar.gz" -C "$TEMP_DIR"
    
    # Find extracted directory
    local extracted_dir
    extracted_dir=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "agentpong-*" | head -1)
    
    if [[ -z "$extracted_dir" ]]; then
        return 1
    fi
    
    echo "$extracted_dir"
}

# Cleanup function
cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

# If running remotely, download and re-execute
if is_remote_run; then
    # Minimal output styling for remote run (before we have the style library)
    _C_BOLD='\033[1m'
    _C_RESET='\033[0m'
    _C_BRAND='\033[38;5;141m'
    _C_SUCCESS='\033[38;5;114m'
    _C_ERROR='\033[38;5;203m'
    _C_MUTED='\033[38;5;244m'
    
    echo ""
    echo -e "${_C_BOLD}${_C_BRAND}    ___    _       _       ___   ___   _   _  __      ${_C_RESET}"
    echo -e "${_C_BOLD}${_C_BRAND}   / _ \  / \     | |     / _ \ / _ \ | \ | |/ /      ${_C_RESET}"
    echo -e "${_C_BOLD}${_C_BRAND}  / /_\/ / _ \    | |    / /_\\// /_\\/|  \| / /_      ${_C_RESET}"
    echo -e "${_C_BOLD}${_C_BRAND} / /_\\\/ ___ \   | |___/ /_\\\/ /_\\ \| |\  / /_\\     ${_C_RESET}"
    echo -e "${_C_BOLD}${_C_BRAND} \____/\/   \_/   |_____\____/\____/ |_| \_/____/     ${_C_RESET}"
    echo -e "${_C_MUTED}                                                      ${_C_RESET}"
    echo -e "${_C_BOLD}${_C_BRAND}  macOS notifications for Claude Code & OpenCode   ${_C_RESET}"
    echo ""
    
    # Check for macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo -e "${_C_ERROR}✗ This tool only works on macOS.${_C_RESET}"
        exit 1
    fi
    
    echo -e "${_C_MUTED}→ Downloading agentpong from GitHub...${_C_RESET}"
    
    EXTRACTED_DIR=$(download_repo)
    
    if [[ -z "$EXTRACTED_DIR" ]]; then
        echo -e "${_C_ERROR}✗ Failed to download agentpong from GitHub${_C_RESET}"
        echo -e "${_C_MUTED}  Please check your internet connection and try again.${_C_RESET}"
        exit 1
    fi
    
    echo -e "${_C_SUCCESS}✓ Download complete${_C_RESET}"
    echo ""
    
    # Check if already installed
    if [[ -f "$HOME/.claude/notify.sh" ]] && [[ "$FORCE_INSTALL" != "true" ]]; then
        echo -e "${_C_MUTED}→ agentpong appears to be already installed${_C_RESET}"
        echo -e "${_C_MUTED}  Use --force to reinstall${_C_RESET}"
        echo ""
    fi
    
    # Re-execute the install script from the downloaded copy
    # This will run the local section below with proper paths
    echo -e "${_C_MUTED}→ Running installer...${_C_RESET}"
    echo ""
    
    cd "$EXTRACTED_DIR"
    exec bash "$EXTRACTED_DIR/install.sh" "$@"
fi

# =============================================================================
# LOCAL INSTALLATION SECTION
# This runs when the script is executed from within the repository
# =============================================================================

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

header "agentpong" "Installer v${AGENTPONG_VERSION}"

# Check for macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    error "This tool only works on macOS."
    exit 1
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force|-f)
            FORCE_INSTALL=true
            shift
            ;;
        --version|-v)
            echo "agentpong installer v$AGENTPONG_VERSION"
            exit 0
            ;;
        --help|-h)
            cat << 'EOF'
agentpong Installer

Usage:
    curl -fsSL https://raw.githubusercontent.com/tsilva/agentpong/main/install.sh | bash
    ./install.sh [options]

Options:
    --force, -f      Force reinstall even if already up to date
    --version, -v    Show installer version
    --help, -h       Show this help message

EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Run with --help for usage information" >&2
            exit 1
            ;;
    esac
done

# Function to check if a file needs updating
# Returns 0 if file needs update, 1 if identical
needs_update() {
    local src="$1" dst="$2"
    
    # If force install, always update
    if [[ "$FORCE_INSTALL" == "true" ]]; then
        return 0
    fi
    
    # If destination doesn't exist, needs update
    if [[ ! -f "$dst" ]]; then
        return 0
    fi
    
    # Compare content using checksum
    if command -v shasum &> /dev/null; then
        local src_hash=$(shasum -a 256 "$src" 2>/dev/null | cut -d' ' -f1)
        local dst_hash=$(shasum -a 256 "$dst" 2>/dev/null | cut -d' ' -f1)
        if [[ "$src_hash" == "$dst_hash" ]]; then
            return 1  # Identical, no update needed
        fi
    else
        # Fallback to diff
        if diff -q "$src" "$dst" > /dev/null 2>&1; then
            return 1  # Identical, no update needed
        fi
    fi
    
    return 0  # Needs update
}

# Function to copy file with idempotency check
copy_if_needed() {
    local src="$1" dst="$2" name="$3"
    
    if needs_update "$src" "$dst"; then
        cp "$src" "$dst"
        chmod +x "$dst"
        return 0  # Updated
    else
        return 1  # Skipped (identical)
    fi
}

# Function to check if a JSON hook already exists with correct value
hook_exists_with_value() {
    local settings_file="$1" hook_name="$2" expected_value="$3"
    
    if [[ ! -f "$settings_file" ]]; then
        return 1  # File doesn't exist
    fi
    
    if ! command -v jq &> /dev/null; then
        return 1  # Can't check without jq
    fi
    
    # Check if hook exists and has the expected command
    local existing_command
    existing_command=$(jq -r ".hooks.${hook_name}[0].hooks[0].command // empty" "$settings_file" 2>/dev/null)
    
    if [[ "$existing_command" == "$expected_value" ]]; then
        return 0  # Hook exists with correct value
    fi
    
    return 1  # Hook doesn't exist or has different value
}

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
step "Checking notify.sh..."
if copy_if_needed "$SRC_DIR/notify.sh" "$NOTIFY_SCRIPT" "notify.sh"; then
    success "Installed notify.sh"
else
    dim "notify.sh is up to date"
fi

# Copy style.sh (used by notify.sh for styled errors)
step "Checking style.sh..."
if copy_if_needed "$SRC_DIR/style.sh" "$STYLE_SCRIPT" "style.sh"; then
    success "Installed style.sh"
else
    dim "style.sh is up to date"
fi

# Install focus-window.sh
step "Checking focus-window.sh..."
if [[ -f "$FOCUS_SCRIPT_DST" ]]; then
    if copy_if_needed "$FOCUS_SCRIPT_SRC" "$FOCUS_SCRIPT_DST" "focus-window.sh"; then
        success "Updated focus-window.sh"
    else
        dim "focus-window.sh is up to date"
    fi
else
    cp "$FOCUS_SCRIPT_SRC" "$FOCUS_SCRIPT_DST"
    chmod +x "$FOCUS_SCRIPT_DST"
    success "Installed focus-window.sh"
fi

# Install pong.sh (notification cycling)
step "Checking pong.sh..."
if [[ -f "$PONG_SCRIPT_DST" ]]; then
    if copy_if_needed "$PONG_SCRIPT_SRC" "$PONG_SCRIPT_DST" "pong.sh"; then
        success "Updated pong.sh"
    else
        dim "pong.sh is up to date"
    fi
else
    cp "$PONG_SCRIPT_SRC" "$PONG_SCRIPT_DST"
    chmod +x "$PONG_SCRIPT_DST"
    success "Installed pong.sh"
fi

# Configure settings.json
step "Configuring Claude Code hooks..."

# Stop hook - fires when Claude finishes a task
STOP_HOOK_COMMAND="$NOTIFY_SCRIPT 'Ready for input'"
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
PERMISSION_HOOK_COMMAND="$NOTIFY_SCRIPT 'Permission required'"
PERMISSION_HOOK_CONFIG='{
  "matcher": "",
  "hooks": [
    {
      "type": "command",
      "command": "'"$NOTIFY_SCRIPT"' '\''Permission required'\''"
    }
  ]
}'

SETTINGS_UPDATED=false

if [ -f "$SETTINGS_FILE" ]; then
    # Backup existing settings (only once, don't backup if backup already exists)
    if [[ ! -f "$SETTINGS_FILE.backup" ]]; then
        cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"
        dim "Backed up existing settings to $SETTINGS_FILE.backup"
    fi
    
    # Check and add Stop hook if needed
    if hook_exists_with_value "$SETTINGS_FILE" "Stop" "$STOP_HOOK_COMMAND"; then
        dim "Stop hook already configured correctly"
    else
        # Check if Stop hook exists with different value
        if jq -e '.hooks.Stop' "$SETTINGS_FILE" > /dev/null 2>&1; then
            warn "Stop hook exists with different configuration"
            confirm "Replace existing Stop hook?"
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                jq --argjson hook "[$STOP_HOOK_CONFIG]" '.hooks.Stop = $hook' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
                mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
                success "Updated Stop hook"
                SETTINGS_UPDATED=true
            else
                info "Keeping existing Stop hook."
            fi
        else
            # Add new Stop hook
            jq --argjson hook "[$STOP_HOOK_CONFIG]" '.hooks.Stop = $hook' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
            success "Added Stop hook"
            SETTINGS_UPDATED=true
        fi
    fi
    
    # Check and add PermissionRequest hook if needed
    if hook_exists_with_value "$SETTINGS_FILE" "PermissionRequest" "$PERMISSION_HOOK_COMMAND"; then
        dim "PermissionRequest hook already configured correctly"
    else
        # Check if PermissionRequest hook exists with different value
        if jq -e '.hooks.PermissionRequest' "$SETTINGS_FILE" > /dev/null 2>&1; then
            warn "PermissionRequest hook exists with different configuration"
            confirm "Replace existing PermissionRequest hook?"
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                jq --argjson hook "[$PERMISSION_HOOK_CONFIG]" '.hooks.PermissionRequest = $hook' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
                mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
                success "Updated PermissionRequest hook"
                SETTINGS_UPDATED=true
            else
                info "Keeping existing PermissionRequest hook."
            fi
        else
            # Add new PermissionRequest hook
            jq --argjson hook "[$PERMISSION_HOOK_CONFIG]" '.hooks.PermissionRequest = $hook' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
            success "Added PermissionRequest hook"
            SETTINGS_UPDATED=true
        fi
    fi
else
    # Create new settings.json with both hooks
    echo "{\"hooks\":{\"Stop\":[$STOP_HOOK_CONFIG],\"PermissionRequest\":[$PERMISSION_HOOK_CONFIG]}}" | jq '.' > "$SETTINGS_FILE"
    success "Created settings.json with hooks"
    SETTINGS_UPDATED=true
fi

if [[ "$SETTINGS_UPDATED" == "false" ]]; then
    dim "All hooks are already configured correctly"
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
    
    local OPENCODE_UPDATED=false

    # OpenCode config paths
    OPENCODE_DIR="$HOME/.opencode"
    OPENCODE_NOTIFY_SCRIPT="$OPENCODE_DIR/notify.sh"
    OPENCODE_STYLE_SCRIPT="$OPENCODE_DIR/style.sh"
    OPENCODE_SETTINGS_FILE="$OPENCODE_DIR/settings.json"
    OPENCODE_FOCUS_SCRIPT="$OPENCODE_DIR/focus-window.sh"

    # Create .opencode directory if needed
    mkdir -p "$OPENCODE_DIR"

    # Copy notify.sh
    step "Checking notify.sh for opencode..."
    if copy_if_needed "$SRC_DIR/notify.sh" "$OPENCODE_NOTIFY_SCRIPT" "notify.sh"; then
        success "Installed notify.sh to opencode directory"
        OPENCODE_UPDATED=true
    else
        dim "notify.sh is up to date"
    fi

    # Copy style.sh
    step "Checking style.sh for opencode..."
    if copy_if_needed "$SRC_DIR/style.sh" "$OPENCODE_STYLE_SCRIPT" "style.sh"; then
        success "Installed style.sh to opencode directory"
        OPENCODE_UPDATED=true
    else
        dim "style.sh is up to date"
    fi

    # Copy focus-window.sh
    step "Checking focus-window.sh for opencode..."
    if copy_if_needed "$SRC_DIR/focus-window.sh" "$OPENCODE_FOCUS_SCRIPT" "focus-window.sh"; then
        success "Installed focus-window.sh to opencode directory"
        OPENCODE_UPDATED=true
    else
        dim "focus-window.sh is up to date"
    fi

    # Copy pong.sh
    step "Checking pong.sh for opencode..."
    if copy_if_needed "$SRC_DIR/pong.sh" "$OPENCODE_DIR/pong.sh" "pong.sh"; then
        success "Installed pong.sh to opencode directory"
        OPENCODE_UPDATED=true
    else
        dim "pong.sh is up to date"
    fi

    # Install OpenCode plugin
    OPENCODE_PLUGIN_DIR="$HOME/.config/opencode/plugins"
    OPENCODE_PLUGIN_FILE="$OPENCODE_PLUGIN_DIR/agentpong.ts"
    
    step "Checking OpenCode plugin..."
    if needs_update "$PLUGINS_DIR/opencode/agentpong.ts" "$OPENCODE_PLUGIN_FILE"; then
        mkdir -p "$OPENCODE_PLUGIN_DIR"
        cp "$PLUGINS_DIR/opencode/agentpong.ts" "$OPENCODE_PLUGIN_FILE"
        success "Installed/updated OpenCode plugin"
        OPENCODE_UPDATED=true
    else
        dim "OpenCode plugin is up to date"
    fi

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

    if [[ "$OPENCODE_UPDATED" == "true" ]]; then
        success "Configured OpenCode plugin"
        banner "opencode support installed!"
        info "OpenCode notifications will appear with workspace names."
        dim "Start a new OpenCode session and you'll get notifications"
        dim "when OpenCode is ready for input."
    else
        dim "opencode support is already up to date"
    fi
}

# === claude-sandbox Integration (Optional) ===
install_sandbox_support() {
    section "Installing sandbox support"
    
    local SANDBOX_UPDATED=false

    # Create directories
    mkdir -p "$SANDBOX_CONFIG_DIR"
    mkdir -p "$HOME/Library/LaunchAgents"

    # Copy handler script to ~/.claude/
    step "Checking notify-handler.sh..."
    if needs_update "$SRC_DIR/notify-handler.sh" "$SANDBOX_HANDLER"; then
        cp "$SRC_DIR/notify-handler.sh" "$SANDBOX_HANDLER"
        chmod +x "$SANDBOX_HANDLER"
        success "Updated notify-handler.sh"
        SANDBOX_UPDATED=true
    else
        dim "notify-handler.sh is up to date"
    fi

    # Copy sandbox notify script to ~/.claude-sandbox/claude-config/
    step "Checking notify-sandbox.sh..."
    if needs_update "$SRC_DIR/notify-sandbox.sh" "$SANDBOX_NOTIFY_SCRIPT"; then
        cp "$SRC_DIR/notify-sandbox.sh" "$SANDBOX_NOTIFY_SCRIPT"
        chmod +x "$SANDBOX_NOTIFY_SCRIPT"
        success "Updated notify-sandbox.sh"
        SANDBOX_UPDATED=true
    else
        dim "notify-sandbox.sh is up to date"
    fi

    # Generate plist with expanded $HOME paths
    step "Checking launchd service..."
    local temp_plist
    temp_plist=$(mktemp "${TMPDIR:-/tmp}/agentpong.plist.XXXXXX")
    sed "s|__HOME__|$HOME|g" "$SANDBOX_PLIST_TEMPLATE" > "$temp_plist"
    
    if needs_update "$temp_plist" "$SANDBOX_PLIST"; then
        cp "$temp_plist" "$SANDBOX_PLIST"
        success "Updated launchd service configuration"
        SANDBOX_UPDATED=true
        
        # Unload existing service if running (ignore errors)
        launchctl unload "$SANDBOX_PLIST" 2>/dev/null || true
        
        # Load the launchd service
        launchctl load "$SANDBOX_PLIST"
        success "Started launchd service (TCP listener on localhost:19223)"
    else
        dim "launchd service is up to date"
    fi
    rm -f "$temp_plist"

    # Configure hooks in sandbox settings.json
    step "Configuring sandbox hooks..."
    
    # Note: Use container path, not host path
    # ~/.claude-sandbox/claude-config on host is mounted to /home/claude/.claude in container
    SANDBOX_STOP_HOOK_COMMAND="/home/claude/.claude/notify.sh 'Ready for input'"
    SANDBOX_STOP_HOOK_CONFIG='{
      "matcher": "",
      "hooks": [
        {
          "type": "command",
          "command": "/home/claude/.claude/notify.sh '\''Ready for input'\''"
        }
      ]
    }'

    SANDBOX_PERMISSION_HOOK_COMMAND="/home/claude/.claude/notify.sh 'Permission required'"
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
        if [[ ! -f "$SANDBOX_SETTINGS_FILE.backup" ]]; then
            cp "$SANDBOX_SETTINGS_FILE" "$SANDBOX_SETTINGS_FILE.backup"
        fi
        
        # Check if hooks need updating
        local stop_needs_update=true
        local perm_needs_update=true
        
        if hook_exists_with_value "$SANDBOX_SETTINGS_FILE" "Stop" "$SANDBOX_STOP_HOOK_COMMAND"; then
            stop_needs_update=false
            dim "Sandbox Stop hook already configured correctly"
        fi
        
        if hook_exists_with_value "$SANDBOX_SETTINGS_FILE" "PermissionRequest" "$SANDBOX_PERMISSION_HOOK_COMMAND"; then
            perm_needs_update=false
            dim "Sandbox PermissionRequest hook already configured correctly"
        fi
        
        if [[ "$stop_needs_update" == "true" ]] || [[ "$perm_needs_update" == "true" ]]; then
            # Add/update hooks
            jq --argjson stop "[$SANDBOX_STOP_HOOK_CONFIG]" --argjson perm "[$SANDBOX_PERMISSION_HOOK_CONFIG]" \
                '.hooks.Stop = $stop | .hooks.PermissionRequest = $perm' \
                "$SANDBOX_SETTINGS_FILE" > "$SANDBOX_SETTINGS_FILE.tmp"
            mv "$SANDBOX_SETTINGS_FILE.tmp" "$SANDBOX_SETTINGS_FILE"
            success "Updated hooks in sandbox settings"
            SANDBOX_UPDATED=true
        fi
    else
        # Create new settings.json
        echo "{\"hooks\":{\"Stop\":[$SANDBOX_STOP_HOOK_CONFIG],\"PermissionRequest\":[$SANDBOX_PERMISSION_HOOK_CONFIG]}}" | jq '.' > "$SANDBOX_SETTINGS_FILE"
        success "Created sandbox settings.json with hooks"
        SANDBOX_UPDATED=true
    fi
    
    if [[ "$SANDBOX_UPDATED" == "true" ]]; then
        banner "Sandbox support installed!"
        note "If you haven't already, rebuild claude-sandbox to include netcat:"
        dim "  cd <path-to-claude-sandbox> && ./docker/build.sh && ./docker/install.sh"
    else
        dim "Sandbox support is already up to date"
    fi
}

echo ""
confirm "Do you use OpenCode (the open-source AI coding assistant)? This will send notifications when OpenCode is ready for input."
if [[ $REPLY =~ ^[Yy]$ ]]; then
    install_opencode_support
fi

echo ""
confirm "Do you use claude-sandbox (containerized Claude Code for isolated development)? This enables notifications from sandboxed sessions."
if [[ $REPLY =~ ^[Yy]$ ]]; then
    install_sandbox_support
fi
