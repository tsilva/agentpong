#!/bin/bash
#
# agentpong - Kickass Installation Script v2.0.0
# Version: 2.0.0
#
# The ultimate macOS notification installer for Claude Code & OpenCode.
# Features: dry-run, uninstall, auto-detection, health checks, rollback, wizard mode.
#
# Usage:
#   Remote:  curl -fsSL https://raw.githubusercontent.com/tsilva/agentpong/main/install.sh | bash
#   Local:   ./install.sh [flags]
#
# Flags:
#   --dry-run       Preview changes without applying
#   --uninstall     Remove agentpong completely
#   --update        Only update changed files (skip prompts)
#   --force         Force reinstall even if up to date
#   --quiet         Minimal output (for CI/automation)
#   --verbose       Maximum output with debug info
#   --wizard        Interactive TUI configuration
#   --health-check  Run post-install verification only
#   --help          Show this help
#

set -e

# =============================================================================
# VERSION & CONFIGURATION
# =============================================================================

AGENTPONG_VERSION="2.0.0"
REPO_URL="https://github.com/tsilva/agentpong"
BRANCH="main"
TEMP_DIR=""
INSTALL_LOG=""

# Mode flags
DRY_RUN=false
UNINSTALL_MODE=false
UPDATE_MODE=false
FORCE_INSTALL=false
QUIET_MODE=false
VERBOSE_MODE=false
WIZARD_MODE=false
HEALTH_CHECK_ONLY=false

# Tracking for rollback
ROLLBACK_ACTIONS=()
INSTALL_SUCCEEDED=false

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Logging to file
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    if [[ -n "$INSTALL_LOG" ]]; then
        echo "[$timestamp] [$level] $message" >> "$INSTALL_LOG"
    fi
    if [[ "$VERBOSE_MODE" == true ]]; then
        case "$level" in
            "ERROR") echo "[DEBUG] $message" >&2 ;;
            "WARN") echo "[DEBUG] $message" >&2 ;;
            *) echo "[DEBUG] $message" ;;
        esac
    fi
}

# Cleanup on exit
cleanup() {
    printf "\033[?25h\033[0m" 2>/dev/null  # Restore cursor/colors even if style.sh wasn't sourced
    log "INFO" "Cleanup started"
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
        log "INFO" "Cleaned up temp directory: $TEMP_DIR"
    fi
    
    # If install failed and we have actions to rollback, do it
    if [[ "$INSTALL_SUCCEEDED" == false && ${#ROLLBACK_ACTIONS[@]} -gt 0 && "$DRY_RUN" == false ]]; then
        log "WARN" "Install failed, performing rollback"
        echo ""
        section "Rolling back changes..."
        for ((i=${#ROLLBACK_ACTIONS[@]}-1; i>=0; i--)); do
            eval "${ROLLBACK_ACTIONS[$i]}"
        done
        success "Rollback complete"
    fi
    log "INFO" "Cleanup finished"
}

trap cleanup EXIT

# Add action to rollback queue
add_rollback() {
    ROLLBACK_ACTIONS+=("$1")
    log "INFO" "Added rollback action: $1"
}

# =============================================================================
# STYLING (Early definition for remote runs)
# =============================================================================

# Minimal styling for remote runs (before we have the full style library)
init_remote_styling() {
    _C_BOLD='\033[1m'
    _C_RESET='\033[0m'
    _C_BRAND='\033[38;5;141m'   # Purple
    _C_PINK='\033[38;5;212m'     # Pink
    _C_BLUE='\033[38;5;117m'    # Blue
    _C_CYAN='\033[38;5;122m'    # Cyan
    _C_SUCCESS='\033[38;5;114m'
    _C_ERROR='\033[38;5;203m'
    _C_WARN='\033[38;5;221m'
    _C_INFO='\033[38;5;117m'
    _C_MUTED='\033[38;5;244m'
}

# Check if we're running via curl pipe
is_remote_run() {
    # First check: if src directory exists alongside the script, we're local
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -d "$script_dir/src" ]]; then
        # We have a local src directory, definitely local
        return 1
    fi
    
    # Second check: if stdin is not a TTY, we might be piped
    if [[ ! -t 0 ]]; then
        return 0
    fi
    
    return 1
}

# Download repository
download_repo() {
    TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/agentpong.XXXXXX")
    log "INFO" "Downloading from ${REPO_URL}/archive/refs/heads/${BRANCH}.tar.gz"
    
    if ! curl -fsSL "${REPO_URL}/archive/refs/heads/${BRANCH}.tar.gz" -o "$TEMP_DIR/agentpong.tar.gz" 2>/dev/null; then
        log "ERROR" "Failed to download repository"
        return 1
    fi
    
    tar -xzf "$TEMP_DIR/agentpong.tar.gz" -C "$TEMP_DIR"
    local extracted_dir=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "agentpong-*" | head -1)
    
    if [[ -z "$extracted_dir" ]]; then
        log "ERROR" "Failed to extract repository"
        return 1
    fi
    
    echo "$extracted_dir"
}

# =============================================================================
# PREFLIGHT VALIDATION
# =============================================================================

run_preflight() {
    log "INFO" "Starting preflight validation"

    section "System Scan" "" "" "◎"

    # Fatal checks first (before dashboard)
    if [[ "$OSTYPE" != "darwin"* ]]; then
        error "This tool only works on macOS (detected: $OSTYPE)"
        log "ERROR" "Unsupported OS: $OSTYPE"
        return 1
    fi

    if [[ ! -w "$HOME" ]]; then
        error "Cannot write to home directory: $HOME"
        log "ERROR" "No write permission to $HOME"
        return 1
    fi

    local test_dir="$HOME/.claude"
    if [[ -d "$test_dir" && ! -w "$test_dir" ]]; then
        error "Cannot write to $test_dir"
        log "ERROR" "No write permission to $test_dir"
        return 1
    fi

    # Build scan dashboard checks
    local -a scan_args=()

    scan_args+=("Operating System" "echo \"macOS $(sw_vers -productVersion)\"")
    scan_args+=("Architecture" "uname -m | sed 's/arm64/Apple Silicon/' | sed 's/x86_64/Intel/'")
    scan_args+=("Permissions" "echo OK")
    scan_args+=("Claude Code" "command -v claude >/dev/null 2>&1 && claude --version 2>/dev/null | head -1 || { [[ -d \"\$HOME/.claude\" ]] && echo 'Detected' || return 1; }")
    scan_args+=("terminal-notifier" "command -v terminal-notifier >/dev/null 2>&1 && echo 'Installed' || return 1")
    scan_args+=("jq" "command -v jq >/dev/null 2>&1 && jq --version 2>/dev/null | sed 's/jq-//' || return 1")
    scan_args+=("AeroSpace" "{ command -v aerospace >/dev/null 2>&1 || [[ -x /opt/homebrew/bin/aerospace ]] || [[ -x /usr/local/bin/aerospace ]]; } && { aerospace --version 2>/dev/null | head -1 || echo 'Installed'; } || return 1")
    scan_args+=("OpenCode" "{ [[ -d \"\$HOME/.opencode\" ]] || [[ -d \"\$HOME/.config/opencode\" ]] || command -v opencode >/dev/null 2>&1; } && echo 'Detected' || return 1")
    scan_args+=("Homebrew" "command -v brew >/dev/null 2>&1 && echo 'Installed' || return 1")

    if [[ "${INSTALL_SANDBOX:-false}" == true ]]; then
        scan_args+=("Port 19223" "! lsof -Pi :19223 -sTCP:LISTEN -t >/dev/null 2>&1 && echo 'Available' || { echo 'In use'; return 1; }")
    fi

    echo ""
    scan_dashboard "${scan_args[@]}"

    log "INFO" "Preflight checks passed"
    return 0
}

# =============================================================================
# SMART DETECTION
# =============================================================================

detect_installed_tools() {
    log "INFO" "Detecting installed tools"
    
    # Detect OpenCode
    if [[ -d "$HOME/.opencode" ]] || [[ -d "$HOME/.config/opencode" ]] || command -v opencode &> /dev/null 2>&1; then
        DETECTED_OPENCODE=true
        log "INFO" "OpenCode detected"
    else
        DETECTED_OPENCODE=false
    fi
    
    # Detect sandbox
    if [[ -d "$HOME/.claude-sandbox" ]] || [[ -f "$HOME/.claude-sandbox/claude-config/settings.json" ]]; then
        DETECTED_SANDBOX=true
        log "INFO" "claude-sandbox detected"
    else
        DETECTED_SANDBOX=false
    fi
    
    # Detect AeroSpace
    if command -v aerospace &> /dev/null || [ -x "/opt/homebrew/bin/aerospace" ] || [ -x "/usr/local/bin/aerospace" ]; then
        DETECTED_AEROSPACE=true
        log "INFO" "AeroSpace detected"
    else
        DETECTED_AEROSPACE=false
    fi
}

# =============================================================================
# COMMAND LINE PARSING
# =============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                log "INFO" "Dry-run mode enabled"
                shift
                ;;
            --uninstall)
                UNINSTALL_MODE=true
                log "INFO" "Uninstall mode enabled"
                shift
                ;;
            --update)
                UPDATE_MODE=true
                log "INFO" "Update mode enabled"
                shift
                ;;
            --force|-f)
                FORCE_INSTALL=true
                log "INFO" "Force install enabled"
                shift
                ;;
            --quiet|-q)
                QUIET_MODE=true
                export STYLE_VERBOSE=0
                log "INFO" "Quiet mode enabled"
                shift
                ;;
            --verbose|-v)
                VERBOSE_MODE=true
                export STYLE_VERBOSE=2
                log "INFO" "Verbose mode enabled"
                shift
                ;;
            --wizard|-w)
                WIZARD_MODE=true
                log "INFO" "Wizard mode enabled"
                shift
                ;;
            --health-check)
                HEALTH_CHECK_ONLY=true
                log "INFO" "Health check mode enabled"
                shift
                ;;
            --version|-V)
                echo "agentpong installer v$AGENTPONG_VERSION"
                exit 0
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                echo "Run with --help for usage information" >&2
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << 'EOF'
agentpong Installer - The ultimate macOS notification system for Claude Code & OpenCode

USAGE:
    curl -fsSL https://raw.githubusercontent.com/tsilva/agentpong/main/install.sh | bash
    ./install.sh [FLAGS]

FLAGS:
    --dry-run          Preview all changes without applying them
    --uninstall        Remove agentpong completely (with confirmation)
    --update           Only update changed files, skip all prompts
    --force, -f        Force reinstall even if already up to date
    --quiet, -q        Minimal output (for CI/automation)
    --verbose, -v      Maximum output with debug logging
    --wizard, -w       Interactive TUI configuration mode
    --health-check     Run post-install verification only
    --version, -V      Show version and exit
    --help, -h         Show this help message

EXAMPLES:
    # Standard install with auto-detection
    ./install.sh

    # Preview what would be installed
    ./install.sh --dry-run

    # Quiet install for automation
    ./install.sh --quiet --update

    # Full interactive setup
    ./install.sh --wizard

    # Remove everything
    ./install.sh --uninstall

EOF
}

# =============================================================================
# FILE OPERATIONS WITH DRY-RUN SUPPORT
# =============================================================================

dry_aware_copy() {
    local src="$1" dst="$2" desc="$3"
    
    if [[ "$DRY_RUN" == true ]]; then
        dim "[DRY-RUN] Would copy: $desc"
        log "DRY-RUN" "Would copy $src to $dst"
        return 0
    fi
    
    cp "$src" "$dst"
    chmod +x "$dst"
    log "INFO" "Copied $src to $dst"
}

dry_aware_remove() {
    local file="$1" desc="$2"
    
    if [[ "$DRY_RUN" == true ]]; then
        dim "[DRY-RUN] Would remove: $desc"
        log "DRY-RUN" "Would remove $file"
        return 0
    fi
    
    if [[ -f "$file" ]]; then
        rm "$file"
        log "INFO" "Removed $file"
    fi
}

dry_aware_mkdir() {
    local dir="$1"
    
    if [[ "$DRY_RUN" == true ]]; then
        log "DRY-RUN" "Would create directory: $dir"
        return 0
    fi
    
    mkdir -p "$dir"
    log "INFO" "Created directory: $dir"
}

dry_aware_jq() {
    local filter="$1" input="$2" output="$3"
    
    if [[ "$DRY_RUN" == true ]]; then
        log "DRY-RUN" "Would run jq on $input"
        return 0
    fi
    
    jq "$filter" "$input" > "$output"
    log "INFO" "Executed jq filter on $input"
}

# =============================================================================
# COLORED DIFF DISPLAY
# =============================================================================

show_json_diff() {
    local file="$1" operation="$2" hook_data="$3"
    
    if [[ "$QUIET_MODE" == true ]]; then
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        info "Proposed changes to $(basename "$file"):"
    else
        info "Changes to $(basename "$file"):"
    fi
    
    if [[ "$operation" == "add" ]]; then
        echo "  ${_C_SUCCESS}+${_C_RESET} ${_C_SUCCESS}Add hooks (Stop, PermissionRequest)${_C_RESET}"
    elif [[ "$operation" == "modify" ]]; then
        echo "  ${_C_WARN}~${_C_RESET} ${_C_WARN}Modify existing hooks${_C_RESET}"
    fi
    
    # Show preview of what the new config will look like
    if [[ -f "$file" ]]; then
        local preview=$(jq '.hooks | keys' "$file" 2>/dev/null || echo "[]")
        dim "  Current hooks: $preview"
    else
        dim "  File doesn't exist yet"
    fi
}

# =============================================================================
# UNINSTALL MODE
# =============================================================================

run_uninstall() {
    log "INFO" "Starting uninstallation"
    
    section "Uninstallation Preview"
    
    # Check what will be removed
    local items_to_remove=()
    
    if [[ -f "$NOTIFY_SCRIPT" ]]; then
        list_item "Remove" "$NOTIFY_SCRIPT"
        items_to_remove+=("$NOTIFY_SCRIPT")
    fi
    
    if [[ -f "$STYLE_SCRIPT" ]]; then
        list_item "Remove" "$STYLE_SCRIPT"
        items_to_remove+=("$STYLE_SCRIPT")
    fi
    
    if [[ -f "$FOCUS_SCRIPT_DST" ]]; then
        list_item "Remove" "$FOCUS_SCRIPT_DST"
        items_to_remove+=("$FOCUS_SCRIPT_DST")
    fi
    
    if [[ -f "$PONG_SCRIPT_DST" ]]; then
        list_item "Remove" "$PONG_SCRIPT_DST"
        items_to_remove+=("$PONG_SCRIPT_DST")
    fi
    
    if [[ -f "$SANDBOX_HANDLER" ]]; then
        list_item "Remove" "$SANDBOX_HANDLER"
        items_to_remove+=("$SANDBOX_HANDLER")
    fi
    
    if [[ -f "$SANDBOX_PLIST" ]]; then
        list_item "Unload & Remove" "launchd service"
    fi
    
    # Check hooks
    if [[ -f "$SETTINGS_FILE" ]] && command -v jq &> /dev/null; then
        if jq -e '.hooks.Stop' "$SETTINGS_FILE" > /dev/null 2>&1; then
            list_item "Remove" "Stop hook from settings.json"
        fi
        if jq -e '.hooks.PermissionRequest' "$SETTINGS_FILE" > /dev/null 2>&1; then
            list_item "Remove" "PermissionRequest hook from settings.json"
        fi
    fi
    
    # OpenCode cleanup
    if [[ -f "$OPENCODE_NOTIFY_SCRIPT" ]]; then
        list_item "Remove" "$OPENCODE_NOTIFY_SCRIPT"
    fi
    if [[ -f "$OPENCODE_PLUGIN_FILE" ]]; then
        list_item "Remove" "OpenCode plugin"
    fi
    
    if [[ ${#items_to_remove[@]} -eq 0 ]]; then
        info "Nothing to uninstall - agentpong doesn't appear to be installed"
        return 0
    fi
    
    echo ""
    
    if [[ "$DRY_RUN" == true ]]; then
        info "Dry-run mode - no changes made"
        return 0
    fi
    
    if [[ "$QUIET_MODE" != true ]]; then
        confirm "Proceed with uninstallation?"
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Uninstallation cancelled"
            return 0
        fi
    fi
    
    section "Removing files..."
    
    # Remove files
    for file in "${items_to_remove[@]}"; do
        if [[ -f "$file" ]]; then
            dry_aware_remove "$file" "$(basename "$file")"
            success "Removed $(basename "$file")"
        fi
    done
    
    # Remove hooks from settings.json
    if [[ -f "$SETTINGS_FILE" ]] && command -v jq &> /dev/null; then
        step "Cleaning up settings.json..."
        
        if [[ ! -f "$SETTINGS_FILE.backup" ]]; then
            cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"
            add_rollback "mv '$SETTINGS_FILE.backup' '$SETTINGS_FILE' 2>/dev/null || true"
        fi
        
        local modified=false
        
        if jq -e '.hooks.Stop' "$SETTINGS_FILE" > /dev/null 2>&1; then
            dry_aware_jq 'del(.hooks.Stop)' "$SETTINGS_FILE" "$SETTINGS_FILE.tmp"
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
            success "Removed Stop hook"
            modified=true
        fi
        
        if jq -e '.hooks.PermissionRequest' "$SETTINGS_FILE" > /dev/null 2>&1; then
            dry_aware_jq 'del(.hooks.PermissionRequest)' "$SETTINGS_FILE" "$SETTINGS_FILE.tmp"
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
            success "Removed PermissionRequest hook"
            modified=true
        fi
        
        # Clean up empty hooks object
        if [[ "$modified" == true ]] && jq -e '.hooks == {}' "$SETTINGS_FILE" > /dev/null 2>&1; then
            dry_aware_jq 'del(.hooks)' "$SETTINGS_FILE" "$SETTINGS_FILE.tmp"
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
        fi
        
        if [[ "$modified" == false ]]; then
            dim "No hooks to remove"
        fi
    fi
    
    # Unload launchd service
    if [[ -f "$SANDBOX_PLIST" ]]; then
        step "Unloading launchd service..."
        if [[ "$DRY_RUN" == false ]]; then
            launchctl unload "$SANDBOX_PLIST" 2>/dev/null || true
            dry_aware_remove "$SANDBOX_PLIST" "launchd plist"
            success "Removed launchd service"
        fi
    fi
    
    # Remove sandbox files
    if [[ -f "$SANDBOX_NOTIFY_SCRIPT" ]]; then
        dry_aware_remove "$SANDBOX_NOTIFY_SCRIPT" "sandbox notify script"
        success "Removed sandbox notify script"
    fi
    
    # Clean up OpenCode
    if [[ -f "$OPENCODE_NOTIFY_SCRIPT" ]]; then
        dry_aware_remove "$OPENCODE_NOTIFY_SCRIPT" "opencode notify script"
        success "Removed OpenCode notify script"
    fi
    if [[ -f "$OPENCODE_PLUGIN_FILE" ]]; then
        dry_aware_remove "$OPENCODE_PLUGIN_FILE" "opencode plugin"
        success "Removed OpenCode plugin"
    fi
    
    banner "Uninstallation complete!"
    
    note "terminal-notifier was not removed (you may have other uses for it)."
    dim "To fully remove it: brew uninstall terminal-notifier"
    
    INSTALL_SUCCEEDED=true
    log "INFO" "Uninstallation completed successfully"
}

# =============================================================================
# HEALTH CHECK
# =============================================================================

run_health_check() {
    log "INFO" "Running health check"
    
    section "Health Check" "" "" "◎"
    
    local all_ok=true
    
    # Check core files
    step "Checking core files..."
    local core_files=(
        "$NOTIFY_SCRIPT"
        "$STYLE_SCRIPT"
        "$FOCUS_SCRIPT_DST"
        "$PONG_SCRIPT_DST"
    )
    
    for file in "${core_files[@]}"; do
        if [[ -f "$file" && -x "$file" ]]; then
            success "$(basename "$file") present and executable"
        elif [[ -f "$file" ]]; then
            warn "$(basename "$file") present but not executable"
            all_ok=false
        else
            error "$(basename "$file") missing"
            all_ok=false
        fi
    done
    
    # Check settings.json hooks
    step "Checking Claude Code hooks..."
    if [[ -f "$SETTINGS_FILE" ]]; then
        if command -v jq &> /dev/null; then
            if jq -e '.hooks.Stop' "$SETTINGS_FILE" > /dev/null 2>&1; then
                success "Stop hook configured"
            else
                warn "Stop hook not found"
                all_ok=false
            fi
            
            if jq -e '.hooks.PermissionRequest' "$SETTINGS_FILE" > /dev/null 2>&1; then
                success "PermissionRequest hook configured"
            else
                warn "PermissionRequest hook not found"
                all_ok=false
            fi
        else
            warn "Cannot verify hooks (jq not installed)"
        fi
    else
        error "settings.json not found"
        all_ok=false
    fi
    
    # Check dependencies
    step "Checking dependencies..."
    if command -v terminal-notifier &> /dev/null; then
        success "terminal-notifier installed"
    else
        error "terminal-notifier not found"
        all_ok=false
    fi
    
    if command -v jq &> /dev/null; then
        success "jq installed"
    else
        warn "jq not installed (required for some features)"
    fi
    
    # Check AeroSpace
    if command -v aerospace &> /dev/null || [[ -x "/opt/homebrew/bin/aerospace" ]] || [[ -x "/usr/local/bin/aerospace" ]]; then
        success "AeroSpace detected (window focus enabled)"
    else
        dim "AeroSpace not installed (window focus disabled)"
    fi
    
    # Check sandbox (if installed)
    if [[ -f "$SANDBOX_PLIST" ]]; then
        step "Checking sandbox service..."
        if launchctl list | grep -q "com.agentpong.sandbox"; then
            success "Sandbox launchd service is running"
        else
            warn "Sandbox launchd service not running"
            all_ok=false
        fi
    fi
    
    # Check OpenCode (if installed)
    if [[ -f "$OPENCODE_NOTIFY_SCRIPT" ]]; then
        step "Checking OpenCode integration..."
        if [[ -f "$OPENCODE_PLUGIN_FILE" ]]; then
            success "OpenCode plugin installed"
        else
            warn "OpenCode plugin missing"
            all_ok=false
        fi
    fi
    
    echo ""
    if [[ "$all_ok" == true ]]; then
        banner "All systems operational!"
        return 0
    else
        warn "Some issues detected. Run with --verbose for details."
        return 1
    fi
}

# =============================================================================
# NOTIFICATION TEST
# =============================================================================

test_notification() {
    if [[ "$QUIET_MODE" == true ]]; then
        return 0
    fi
    
    echo ""
    section "Live Test" "" "" "▸"
    
    info "Sending test notification..."
    
    if [[ -x "$NOTIFY_SCRIPT" ]]; then
        # Show a brief table animation
        table_animation 1 "Test notification sent!"
        CLAUDE_PROJECT_DIR="$HOME" "$NOTIFY_SCRIPT" "Test notification from agentpong" &
        success "Check your notification center!"
        dim "Click the notification to test window focus"
        sleep 0.5
    else
        error "Cannot test - notify.sh not found or not executable"
    fi
}

# =============================================================================
# WIZARD MODE
# =============================================================================

run_wizard() {
    log "INFO" "Starting wizard mode"
    
    header "Configuration Wizard"
    
    info "Welcome! Let's set up your notifications."
    echo ""
    
    # Hook selection with toggles
    section "Configure Hooks"
    
    if toggle "Enable Stop hook (when Claude finishes)" "yes"; then
        ENABLE_STOP_HOOK=true
        # Get custom message
        local stop_msg=$(input "Stop hook message:" "Ready for input")
        [[ -n "$stop_msg" ]] && STOP_MESSAGE="$stop_msg"
    else
        ENABLE_STOP_HOOK=false
    fi
    
    if toggle "Enable Permission hook" "yes"; then
        ENABLE_PERMISSION_HOOK=true
        local perm_msg=$(input "Permission hook message:" "Permission required")
        [[ -n "$perm_msg" ]] && PERMISSION_MESSAGE="$perm_msg"
    else
        ENABLE_PERMISSION_HOOK=false
    fi
    
    # Optional integrations with multi-select
    section "Select Integrations"
    
    local integration_options=()
    [[ "$DETECTED_OPENCODE" == true ]] && integration_options+=("OpenCode (detected)")
    [[ "$DETECTED_SANDBOX" == true ]] && integration_options+=("claude-sandbox (detected)")
    [[ "$DETECTED_OPENCODE" != true ]] && integration_options+=("OpenCode (install anyway)")
    [[ "$DETECTED_SANDBOX" != true ]] && integration_options+=("claude-sandbox (install anyway)")
    
    if [[ ${#integration_options[@]} -gt 0 ]]; then
        local selected=$(choose_multi "Select integrations to install:" "${integration_options[@]}")
        
        [[ "$selected" == *"OpenCode"* ]] && INSTALL_OPENCODE=true
        [[ "$selected" == *"sandbox"* ]] && INSTALL_SANDBOX=true
    fi
    
    # Keybinding suggestion
    if [[ "$DETECTED_AEROSPACE" == true ]]; then
        section "Keybinding Setup"
        info "AeroSpace detected!"
        if toggle "Suggest alt+n keybinding for cycling notifications?" "yes"; then
            SUGGEST_KEYBINDING=true
        fi
    fi
    
    echo ""
    info "Configuration complete! Starting installation..."
    table_animation 1 "Let's go!"
}

# =============================================================================
# MAIN INSTALLATION
# =============================================================================

run_install() {
    log "INFO" "Starting installation"
    
    # Pong intro animation + tagline
    ring_bell
    pong_intro "$AGENTPONG_VERSION"
    typewrite "Agents ping. You pong back."
    
    if [[ "$UPDATE_MODE" == true ]]; then
        info "Update mode: only updating changed files"
    fi
    
    # Phase 1: Detection
    if ! run_preflight; then
        error "Pre-flight checks failed. Aborting."
        return 1
    fi
    
    # Detect installed tools
    detect_installed_tools
    
    # Run wizard if requested
    if [[ "$WIZARD_MODE" == true ]]; then
        run_wizard
    fi
    
    # Show architecture flow diagram
    flow_diagram true "$DETECTED_OPENCODE" "$DETECTED_SANDBOX"

    # Phase 2: Dependencies
    section "Installing Dependencies" "" "" "↯"
    
    # Check for jq
    if ! command -v jq &> /dev/null; then
        if [[ "$UPDATE_MODE" == true ]]; then
            error "jq is required but not installed. Install manually: brew install jq"
            return 1
        fi
        
        warn "jq is required for configuration"
        confirm "Install jq via Homebrew?"
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if [[ "$DRY_RUN" == false ]]; then
                spin "Installing jq..." brew install jq
                add_rollback "brew uninstall jq 2>/dev/null || true"
            fi
        else
            error "Please install jq manually: brew install jq"
            return 1
        fi
    else
        success "jq already installed"
    fi
    
    # Check for terminal-notifier
    if ! command -v terminal-notifier &> /dev/null; then
        if [[ "$UPDATE_MODE" == true ]]; then
            error "terminal-notifier is required but not installed"
            return 1
        fi
        
        warn "terminal-notifier is required for notifications"
        confirm "Install terminal-notifier via Homebrew?"
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if [[ "$DRY_RUN" == false ]]; then
                spin "Installing terminal-notifier..." brew install terminal-notifier
            fi
        else
            error "Please install terminal-notifier manually: brew install terminal-notifier"
            return 1
        fi
    else
        success "terminal-notifier already installed"
    fi
    
    # Install core files
    section "Setting up Claude Code integration" "" "" "⚙"
    
    dry_aware_mkdir "$CLAUDE_DIR"
    add_rollback "rmdir '$CLAUDE_DIR' 2>/dev/null || true"
    
    # Copy notify.sh
    step "Checking notify.sh..."
    if needs_update "$SRC_DIR/notify.sh" "$NOTIFY_SCRIPT"; then
        if [[ -f "$NOTIFY_SCRIPT" && ! -f "$NOTIFY_SCRIPT.backup" ]]; then
            cp "$NOTIFY_SCRIPT" "$NOTIFY_SCRIPT.backup"
            add_rollback "mv '$NOTIFY_SCRIPT.backup' '$NOTIFY_SCRIPT' 2>/dev/null || true"
        fi
        dry_aware_copy "$SRC_DIR/notify.sh" "$NOTIFY_SCRIPT" "notify.sh"
        success "Installed notify.sh"
    else
        dim "notify.sh is up to date"
    fi
    
    # Copy style.sh
    step "Checking style.sh..."
    if needs_update "$SRC_DIR/style.sh" "$STYLE_SCRIPT"; then
        if [[ -f "$STYLE_SCRIPT" && ! -f "$STYLE_SCRIPT.backup" ]]; then
            cp "$STYLE_SCRIPT" "$STYLE_SCRIPT.backup"
            add_rollback "mv '$STYLE_SCRIPT.backup' '$STYLE_SCRIPT' 2>/dev/null || true"
        fi
        dry_aware_copy "$SRC_DIR/style.sh" "$STYLE_SCRIPT" "style.sh"
        success "Installed style.sh"
    else
        dim "style.sh is up to date"
    fi
    
    # Copy focus-window.sh
    step "Checking focus-window.sh..."
    if [[ -f "$FOCUS_SCRIPT_DST" ]]; then
        if needs_update "$FOCUS_SCRIPT_SRC" "$FOCUS_SCRIPT_DST"; then
            if [[ ! -f "$FOCUS_SCRIPT_DST.backup" ]]; then
                cp "$FOCUS_SCRIPT_DST" "$FOCUS_SCRIPT_DST.backup"
                add_rollback "mv '$FOCUS_SCRIPT_DST.backup' '$FOCUS_SCRIPT_DST' 2>/dev/null || true"
            fi
            dry_aware_copy "$FOCUS_SCRIPT_SRC" "$FOCUS_SCRIPT_DST" "focus-window.sh"
            success "Updated focus-window.sh"
        else
            dim "focus-window.sh is up to date"
        fi
    else
        dry_aware_copy "$FOCUS_SCRIPT_SRC" "$FOCUS_SCRIPT_DST" "focus-window.sh"
        success "Installed focus-window.sh"
    fi
    
    # Copy pong.sh
    step "Checking pong.sh..."
    if [[ -f "$PONG_SCRIPT_DST" ]]; then
        if needs_update "$PONG_SCRIPT_SRC" "$PONG_SCRIPT_DST"; then
            if [[ ! -f "$PONG_SCRIPT_DST.backup" ]]; then
                cp "$PONG_SCRIPT_DST" "$PONG_SCRIPT_DST.backup"
                add_rollback "mv '$PONG_SCRIPT_DST.backup' '$PONG_SCRIPT_DST' 2>/dev/null || true"
            fi
            dry_aware_copy "$PONG_SCRIPT_SRC" "$PONG_SCRIPT_DST" "pong.sh"
            success "Updated pong.sh"
        else
            dim "pong.sh is up to date"
        fi
    else
        dry_aware_copy "$PONG_SCRIPT_SRC" "$PONG_SCRIPT_DST" "pong.sh"
        success "Installed pong.sh"
    fi
    
    # Configure settings.json
    step "Configuring Claude Code hooks..."
    
    # Default messages (can be overridden by wizard)
    STOP_MESSAGE="${STOP_MESSAGE:-Ready for input}"
    PERMISSION_MESSAGE="${PERMISSION_MESSAGE:-Permission required}"
    
    STOP_HOOK_COMMAND="$NOTIFY_SCRIPT '$STOP_MESSAGE'"
    STOP_HOOK_CONFIG='{
      "matcher": "",
      "hooks": [
        {
          "type": "command",
          "command": "'"$NOTIFY_SCRIPT"' '\''"$STOP_MESSAGE"'\''"
        }
      ]
    }'
    
    PERMISSION_HOOK_COMMAND="$NOTIFY_SCRIPT '$PERMISSION_MESSAGE'"
    PERMISSION_HOOK_CONFIG='{
      "matcher": "",
      "hooks": [
        {
          "type": "command",
          "command": "'"$NOTIFY_SCRIPT"' '\''"$PERMISSION_MESSAGE"'\''"
        }
      ]
    }'
    
    local settings_modified=false
    
    if [[ -f "$SETTINGS_FILE" ]]; then
        # Backup existing settings
        if [[ ! -f "$SETTINGS_FILE.backup" ]]; then
            cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"
            add_rollback "mv '$SETTINGS_FILE.backup' '$SETTINGS_FILE' 2>/dev/null || true"
        fi
        
        # Check and update Stop hook
        if [[ "${ENABLE_STOP_HOOK:-true}" == true ]]; then
            if hook_exists_with_value "$SETTINGS_FILE" "Stop" "$STOP_HOOK_COMMAND"; then
                dim "Stop hook already configured correctly"
            else
                # Determine if we're modifying or adding
                if jq -e '.hooks.Stop' "$SETTINGS_FILE" > /dev/null 2>&1; then
                    show_json_diff "$SETTINGS_FILE" "modify"
                    local should_update=true
                    if [[ "$QUIET_MODE" != true && "$UPDATE_MODE" != true && "$FORCE_INSTALL" != true ]]; then
                        confirm "Replace existing Stop hook?"
                        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                            info "Keeping existing Stop hook"
                            should_update=false
                        fi
                    fi
                    if [[ "$should_update" == true && "$DRY_RUN" == false ]]; then
                        jq --argjson hook "[$STOP_HOOK_CONFIG]" '.hooks.Stop = $hook' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
                        mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
                        success "Updated Stop hook"
                        settings_modified=true
                    fi
                else
                    show_json_diff "$SETTINGS_FILE" "add"
                    if [[ "$DRY_RUN" == false ]]; then
                        jq --argjson hook "[$STOP_HOOK_CONFIG]" '.hooks.Stop = $hook' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
                        mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
                        success "Added Stop hook"
                        settings_modified=true
                    fi
                fi
            fi
        fi
        
        # Check and update PermissionRequest hook
        if [[ "${ENABLE_PERMISSION_HOOK:-true}" == true ]]; then
            if hook_exists_with_value "$SETTINGS_FILE" "PermissionRequest" "$PERMISSION_HOOK_COMMAND"; then
                dim "PermissionRequest hook already configured correctly"
            else
                # Determine if we're modifying or adding
                if jq -e '.hooks.PermissionRequest' "$SETTINGS_FILE" > /dev/null 2>&1; then
                    show_json_diff "$SETTINGS_FILE" "modify"
                    local should_update_perm=true
                    if [[ "$QUIET_MODE" != true && "$UPDATE_MODE" != true && "$FORCE_INSTALL" != true ]]; then
                        confirm "Replace existing PermissionRequest hook?"
                        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                            info "Keeping existing PermissionRequest hook"
                            should_update_perm=false
                        fi
                    fi
                    if [[ "$should_update_perm" == true && "$DRY_RUN" == false ]]; then
                        jq --argjson hook "[$PERMISSION_HOOK_CONFIG]" '.hooks.PermissionRequest = $hook' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
                        mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
                        success "Updated PermissionRequest hook"
                        settings_modified=true
                    fi
                else
                    show_json_diff "$SETTINGS_FILE" "add"
                    if [[ "$DRY_RUN" == false ]]; then
                        jq --argjson hook "[$PERMISSION_HOOK_CONFIG]" '.hooks.PermissionRequest = $hook' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
                        mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
                        success "Added PermissionRequest hook"
                        settings_modified=true
                    fi
                fi
            fi
        fi
    else
        # Create new settings.json
        show_json_diff "$SETTINGS_FILE" "add"
        if [[ "$DRY_RUN" == false ]]; then
            echo "{\"hooks\":{\"Stop\":[$STOP_HOOK_CONFIG],\"PermissionRequest\":[$PERMISSION_HOOK_CONFIG]}}" | jq '.' > "$SETTINGS_FILE"
            success "Created settings.json with hooks"
            settings_modified=true
            add_rollback "rm '$SETTINGS_FILE' 2>/dev/null || true"
        fi
    fi
    
    if [[ "$settings_modified" == false ]]; then
        dim "All hooks are already configured correctly"
    fi
    
    # Restart terminal-notifier
    step "Restarting terminal-notifier..."
    if [[ "$DRY_RUN" == false ]]; then
        killall terminal-notifier 2>/dev/null && success "Restarted terminal-notifier" || dim "No running terminal-notifier processes"
    fi
    
    # OpenCode support
    if [[ "${INSTALL_OPENCODE:-$DETECTED_OPENCODE}" == true ]]; then
        install_opencode_support
    elif [[ "$UPDATE_MODE" != true && "$QUIET_MODE" != true && "$DETECTED_OPENCODE" == false ]]; then
        echo ""
        confirm "Install OpenCode support?"
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_opencode_support
        fi
    fi
    
    # Sandbox support
    if [[ "${INSTALL_SANDBOX:-$DETECTED_SANDBOX}" == true ]]; then
        install_sandbox_support
    elif [[ "$UPDATE_MODE" != true && "$QUIET_MODE" != true && "$DETECTED_SANDBOX" == false ]]; then
        echo ""
        confirm "Install claude-sandbox support?"
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_sandbox_support
        fi
    fi
    
    # Show summary with status grid
    section "Installation Complete" "" "" "◆"
    
    local summary_items=(
        "Notifications" "✓ Enabled"
        "Window Focus" "$([[ "$DETECTED_AEROSPACE" == true ]] && echo "✓ Enabled" || echo "○ Disabled")"
    )
    
    if [[ "${INSTALL_OPENCODE:-false}" == true || -f "$OPENCODE_PLUGIN_FILE" ]]; then
        summary_items+=("OpenCode" "✓ Enabled")
    fi
    
    if [[ "${INSTALL_SANDBOX:-false}" == true || -f "$SANDBOX_PLIST" ]]; then
        summary_items+=("Sandbox" "✓ Enabled")
    fi
    
    show_status_grid "${summary_items[@]}"
    
    # Keybinding suggestion
    if [[ "${SUGGEST_KEYBINDING:-false}" == true && "$DETECTED_AEROSPACE" == true ]]; then
        echo ""
        info "Suggested AeroSpace keybinding:"
        dim "  Add to ~/.config/aerospace/aerospace.toml:"
        dim "  alt-n = 'exec-and-forget ~/.claude/pong.sh'"
    fi
    
    # Test notification
    if [[ "$DRY_RUN" == false ]]; then
        test_notification
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        banner "Dry-run complete!" "info"
        info "No changes were made. Run without --dry-run to apply."
    else
        ring_bell

        echo ""
        section "Installation Complete" "" "" "◆"

        echo ""
        section "Quick Start" "" "" "▸"
        
        cascade_success \
            "Notifications enabled for Claude Code" \
            "Click notifications to focus window" \
            "Use 'pong.sh' to cycle notifications"
        
        echo ""
        typewrite "Ready to pong."
        echo ""
        info "Cursor/VS Code: Works automatically"
        dim "Start a new Claude session to test"
        echo ""
        info "iTerm2: Set up Triggers for standalone use"
        dim "iTerm > Settings > Profiles > Advanced > Triggers"
    fi
    
    INSTALL_SUCCEEDED=true
    log "INFO" "Installation completed successfully"
}

# =============================================================================
# HELPER FUNCTIONS (needed for install)
# =============================================================================

needs_update() {
    local src="$1" dst="$2"
    
    if [[ "$FORCE_INSTALL" == true ]]; then
        return 0
    fi
    
    if [[ ! -f "$dst" ]]; then
        return 0
    fi
    
    if command -v shasum &> /dev/null; then
        local src_hash=$(shasum -a 256 "$src" 2>/dev/null | cut -d' ' -f1)
        local dst_hash=$(shasum -a 256 "$dst" 2>/dev/null | cut -d' ' -f1)
        if [[ "$src_hash" == "$dst_hash" ]]; then
            return 1
        fi
    else
        if diff -q "$src" "$dst" > /dev/null 2>&1; then
            return 1
        fi
    fi
    
    return 0
}

hook_exists_with_value() {
    local settings_file="$1" hook_name="$2" expected_value="$3"
    
    if [[ ! -f "$settings_file" ]]; then
        return 1
    fi
    
    if ! command -v jq &> /dev/null; then
        return 1
    fi
    
    local existing_command
    existing_command=$(jq -r ".hooks.${hook_name}[0].hooks[0].command // empty" "$settings_file" 2>/dev/null)
    
    if [[ "$existing_command" == "$expected_value" ]]; then
        return 0
    fi
    
    return 1
}

install_opencode_support() {
    log "INFO" "Installing OpenCode support"
    
    section "Installing OpenCode support" "" "" "⚙"
    
    local opencode_updated=false
    
    # Create directories
    dry_aware_mkdir "$OPENCODE_DIR"
    dry_aware_mkdir "$OPENCODE_PLUGIN_DIR"
    
    # Copy files
    if needs_update "$SRC_DIR/notify.sh" "$OPENCODE_NOTIFY_SCRIPT"; then
        dry_aware_copy "$SRC_DIR/notify.sh" "$OPENCODE_NOTIFY_SCRIPT" "notify.sh"
        success "Installed notify.sh"
        opencode_updated=true
    else
        dim "notify.sh is up to date"
    fi
    
    if needs_update "$SRC_DIR/style.sh" "$OPENCODE_STYLE_SCRIPT"; then
        dry_aware_copy "$SRC_DIR/style.sh" "$OPENCODE_STYLE_SCRIPT" "style.sh"
        success "Installed style.sh"
        opencode_updated=true
    else
        dim "style.sh is up to date"
    fi
    
    if needs_update "$FOCUS_SCRIPT_SRC" "$OPENCODE_FOCUS_SCRIPT"; then
        dry_aware_copy "$FOCUS_SCRIPT_SRC" "$OPENCODE_FOCUS_SCRIPT" "focus-window.sh"
        success "Installed focus-window.sh"
        opencode_updated=true
    else
        dim "focus-window.sh is up to date"
    fi
    
    if needs_update "$PONG_SCRIPT_SRC" "$OPENCODE_PONG_SCRIPT"; then
        dry_aware_copy "$PONG_SCRIPT_SRC" "$OPENCODE_PONG_SCRIPT" "pong.sh"
        success "Installed pong.sh"
        opencode_updated=true
    else
        dim "pong.sh is up to date"
    fi
    
    # Install plugin
    if needs_update "$PLUGINS_DIR/opencode/agentpong.ts" "$OPENCODE_PLUGIN_FILE"; then
        dry_aware_copy "$PLUGINS_DIR/opencode/agentpong.ts" "$OPENCODE_PLUGIN_FILE" "agentpong.ts"
        success "Installed OpenCode plugin"
        opencode_updated=true
    else
        dim "OpenCode plugin is up to date"
    fi
    
    # Clean up legacy hooks
    for config_file in "$OPENCODE_SETTINGS_FILE" "$OPENCODE_CONFIG_SETTINGS"; do
        if [[ -f "$config_file" ]] && command -v jq &> /dev/null; then
            if jq -e '.hooks.Stop // .hooks.PermissionRequest' "$config_file" > /dev/null 2>&1; then
                dim "Cleaning up legacy hooks from $config_file..."
                cp "$config_file" "$config_file.backup"
                jq 'del(.hooks.Stop) | del(.hooks.PermissionRequest)' "$config_file" > "$config_file.tmp"
                mv "$config_file.tmp" "$config_file"
                if jq -e '.hooks == {}' "$config_file" > /dev/null 2>&1; then
                    jq 'del(.hooks)' "$config_file" > "$config_file.tmp"
                    mv "$config_file.tmp" "$config_file"
                fi
                success "Removed legacy hooks"
            fi
        fi
    done
    
    if [[ "$opencode_updated" == true && "$DRY_RUN" == false ]]; then
        banner "OpenCode support installed!"
        info "OpenCode notifications will appear with workspace names."
    elif [[ "$DRY_RUN" == true && "$opencode_updated" == true ]]; then
        dim "OpenCode: Would update files"
    else
        dim "OpenCode support is already up to date"
    fi
    
    INSTALL_OPENCODE=true
}

install_sandbox_support() {
    log "INFO" "Installing sandbox support"
    
    section "Installing sandbox support" "" "" "⚙"
    
    local sandbox_updated=false
    
    # Create directories
    dry_aware_mkdir "$SANDBOX_CONFIG_DIR"
    dry_aware_mkdir "$HOME/Library/LaunchAgents"
    
    # Copy handler script
    if needs_update "$SRC_DIR/notify-handler.sh" "$SANDBOX_HANDLER"; then
        dry_aware_copy "$SRC_DIR/notify-handler.sh" "$SANDBOX_HANDLER" "notify-handler.sh"
        success "Updated notify-handler.sh"
        sandbox_updated=true
    else
        dim "notify-handler.sh is up to date"
    fi
    
    # Copy sandbox notify script
    if needs_update "$SRC_DIR/notify-sandbox.sh" "$SANDBOX_NOTIFY_SCRIPT"; then
        dry_aware_copy "$SRC_DIR/notify-sandbox.sh" "$SANDBOX_NOTIFY_SCRIPT" "notify-sandbox.sh"
        success "Updated notify-sandbox.sh"
        sandbox_updated=true
    else
        dim "notify-sandbox.sh is up to date"
    fi
    
    # Generate and install plist
    step "Checking launchd service..."
    local temp_plist=$(mktemp "${TMPDIR:-/tmp}/agentpong.plist.XXXXXX")
    sed "s|__HOME__|$HOME|g" "$SANDBOX_PLIST_TEMPLATE" > "$temp_plist"
    
    if needs_update "$temp_plist" "$SANDBOX_PLIST"; then
        if [[ "$DRY_RUN" == false ]]; then
            cp "$temp_plist" "$SANDBOX_PLIST"
            success "Updated launchd service configuration"
            sandbox_updated=true
            
            # Unload existing service if running
            launchctl unload "$SANDBOX_PLIST" 2>/dev/null || true
            
            # Load the service
            launchctl load "$SANDBOX_PLIST"
            success "Started launchd service (TCP listener on localhost:19223)"
        fi
    else
        dim "launchd service is up to date"
    fi
    rm -f "$temp_plist"
    
    # Configure sandbox hooks
    step "Configuring sandbox hooks..."
    
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
    
    if [[ -f "$SANDBOX_SETTINGS_FILE" ]]; then
        if [[ ! -f "$SANDBOX_SETTINGS_FILE.backup" ]]; then
            cp "$SANDBOX_SETTINGS_FILE" "$SANDBOX_SETTINGS_FILE.backup"
        fi
        
        local stop_needs_update=true
        local perm_needs_update=true
        
        if hook_exists_with_value "$SANDBOX_SETTINGS_FILE" "Stop" "$SANDBOX_STOP_HOOK_COMMAND"; then
            stop_needs_update=false
            dim "Sandbox Stop hook already configured"
        fi
        
        if hook_exists_with_value "$SANDBOX_SETTINGS_FILE" "PermissionRequest" "$SANDBOX_PERMISSION_HOOK_COMMAND"; then
            perm_needs_update=false
            dim "Sandbox PermissionRequest hook already configured"
        fi
        
        if [[ "$stop_needs_update" == true || "$perm_needs_update" == true ]]; then
            if [[ "$DRY_RUN" == false ]]; then
                jq --argjson stop "[$SANDBOX_STOP_HOOK_CONFIG]" --argjson perm "[$SANDBOX_PERMISSION_HOOK_CONFIG]" \
                    '.hooks.Stop = $stop | .hooks.PermissionRequest = $perm' \
                    "$SANDBOX_SETTINGS_FILE" > "$SANDBOX_SETTINGS_FILE.tmp"
                mv "$SANDBOX_SETTINGS_FILE.tmp" "$SANDBOX_SETTINGS_FILE"
                success "Updated sandbox hooks"
                sandbox_updated=true
            fi
        fi
    else
        if [[ "$DRY_RUN" == false ]]; then
            echo "{\"hooks\":{\"Stop\":[$SANDBOX_STOP_HOOK_CONFIG],\"PermissionRequest\":[$SANDBOX_PERMISSION_HOOK_CONFIG]}}" | jq '.' > "$SANDBOX_SETTINGS_FILE"
            success "Created sandbox settings.json"
            sandbox_updated=true
        fi
    fi
    
    if [[ "$sandbox_updated" == true && "$DRY_RUN" == false ]]; then
        banner "Sandbox support installed!"
        note "If you haven't already, rebuild claude-sandbox to include netcat:"
        dim "  cd <path-to-claude-sandbox> && ./docker/build.sh && ./docker/install.sh"
    elif [[ "$DRY_RUN" == true && "$sandbox_updated" == true ]]; then
        dim "Sandbox: Would update configuration"
    else
        dim "Sandbox support is already up to date"
    fi
    
    INSTALL_SANDBOX=true
}

# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

main() {
    # Initialize log file
    INSTALL_LOG="${TMPDIR:-/tmp}/agentpong-install-$(date +%Y%m%d-%H%M%S).log"
    touch "$INSTALL_LOG"
    log "INFO" "agentpong installer v$AGENTPONG_VERSION started"
    log "INFO" "Command: $0 $*"
    
    # Parse arguments early (needed for remote runs too)
    parse_arguments "$@"
    
    # Handle remote runs
    if is_remote_run; then
        init_remote_styling
        
        # Show pong-themed logo
        echo ""
        echo -e "${_C_BRAND}○ ════════════════════════════ ○${_C_RESET}"
        echo -e "${_C_PINK}        PING    ○    PONG${_C_RESET}"
        echo -e "${_C_BLUE}              v${AGENTPONG_VERSION}${_C_RESET}"
        echo -e "${_C_CYAN}     ○ ════════════════════════════ ○${_C_RESET}"
        echo ""
        
        # Quick OS check
        if [[ "$OSTYPE" != "darwin"* ]]; then
            echo -e "  ${_C_ERROR}✗ This tool only works on macOS.${_C_RESET}"
            exit 1
        fi
        
        echo -e "  ${_C_MUTED}→ Downloading agentpong from GitHub...${_C_RESET}"
        
        EXTRACTED_DIR=$(download_repo)
        
        if [[ -z "$EXTRACTED_DIR" ]]; then
            echo -e "  ${_C_ERROR}✗ Failed to download agentpong${_C_RESET}"
            exit 1
        fi
        
        echo -e "  ${_C_SUCCESS}✓ Download complete${_C_RESET}"
        echo ""
        
        # Re-execute from downloaded copy with all arguments
        cd "$EXTRACTED_DIR"
        exec bash "$EXTRACTED_DIR/install.sh" "$@"
    fi
    
    # We're in local mode - source the style library
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SRC_DIR="$SCRIPT_DIR/src"
    CONFIG_DIR="$SCRIPT_DIR/config"
    PLUGINS_DIR="$SCRIPT_DIR/plugins"
    
    # Source styling library
    source "$SRC_DIR/style.sh" 2>/dev/null || true

    # Re-register combined trap (style.sh overwrites install.sh's cleanup trap)
    trap 'style_cleanup; cleanup' EXIT INT TERM HUP QUIT

    # Define all paths
    CLAUDE_DIR="$HOME/.claude"
    NOTIFY_SCRIPT="$CLAUDE_DIR/notify.sh"
    STYLE_SCRIPT="$CLAUDE_DIR/style.sh"
    SETTINGS_FILE="$CLAUDE_DIR/settings.json"
    FOCUS_SCRIPT_SRC="$SRC_DIR/focus-window.sh"
    FOCUS_SCRIPT_DST="$CLAUDE_DIR/focus-window.sh"
    PONG_SCRIPT_SRC="$SRC_DIR/pong.sh"
    PONG_SCRIPT_DST="$CLAUDE_DIR/pong.sh"
    
    # Sandbox paths
    SANDBOX_DIR="$HOME/.claude-sandbox"
    SANDBOX_CONFIG_DIR="$SANDBOX_DIR/claude-config"
    SANDBOX_NOTIFY_SCRIPT="$SANDBOX_CONFIG_DIR/notify.sh"
    SANDBOX_SETTINGS_FILE="$SANDBOX_CONFIG_DIR/settings.json"
    SANDBOX_HANDLER="$CLAUDE_DIR/notify-handler.sh"
    SANDBOX_PLIST_TEMPLATE="$CONFIG_DIR/com.agentpong.sandbox.plist.template"
    SANDBOX_PLIST="$HOME/Library/LaunchAgents/com.agentpong.sandbox.plist"
    
    # OpenCode paths
    OPENCODE_DIR="$HOME/.opencode"
    OPENCODE_NOTIFY_SCRIPT="$OPENCODE_DIR/notify.sh"
    OPENCODE_STYLE_SCRIPT="$OPENCODE_DIR/style.sh"
    OPENCODE_FOCUS_SCRIPT="$OPENCODE_DIR/focus-window.sh"
    OPENCODE_PONG_SCRIPT="$OPENCODE_DIR/pong.sh"
    OPENCODE_PLUGIN_DIR="$HOME/.config/opencode/plugins"
    OPENCODE_PLUGIN_FILE="$OPENCODE_PLUGIN_DIR/agentpong.ts"
    OPENCODE_SETTINGS_FILE="$OPENCODE_DIR/settings.json"
    OPENCODE_CONFIG_SETTINGS="$HOME/.config/opencode/settings.json"
    
    # Route to appropriate mode
    if [[ "$UNINSTALL_MODE" == true ]]; then
        run_uninstall
    elif [[ "$HEALTH_CHECK_ONLY" == true ]]; then
        run_health_check
    else
        run_install
    fi
    
    # Show log location if in verbose mode
    if [[ "$VERBOSE_MODE" == true ]]; then
        echo ""
        dim "Install log saved to: $INSTALL_LOG"
    fi
}

# Run main
main "$@"
