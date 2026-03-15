#!/bin/bash
#
# agentpong - Kickass Installation Script v3.0.0
# Version: 3.0.0
#
# macOS developer workspace management + AI agent notifications, powered by AeroSpace.
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

AGENTPONG_VERSION="3.0.0"
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

    scan_args+=("Operating System" "echo \"macOS \$(sw_vers -productVersion)\"")
    scan_args+=("Architecture" "uname -m | sed 's/arm64/Apple Silicon/' | sed 's/x86_64/Intel/'")
    scan_args+=("Permissions" "echo OK")
    scan_args+=("Claude Code" "command -v claude >/dev/null 2>&1 && claude --version 2>/dev/null | head -1 || { [[ -d \"\$HOME/.claude\" ]] && echo 'Detected' || return 1; }")
    scan_args+=("terminal-notifier" "command -v terminal-notifier >/dev/null 2>&1 && echo 'Installed' || return 1")
    scan_args+=("jq" "command -v jq >/dev/null 2>&1 && jq --version 2>/dev/null | sed 's/jq-//' || return 1")
    scan_args+=("AeroSpace" "{ command -v aerospace >/dev/null 2>&1 || [[ -x /opt/homebrew/bin/aerospace ]] || [[ -x /usr/local/bin/aerospace ]]; } && { aerospace --version 2>/dev/null | head -1 || echo 'Installed'; } || return 1")
    scan_args+=("Alfred" "{ [[ -d \"\$HOME/Library/Application Support/Alfred\" ]] || [[ -d \"/Applications/Alfred 5.app\" ]]; } && echo 'Detected' || return 1")
    scan_args+=("OpenCode" "{ [[ -d \"\$HOME/.opencode\" ]] || [[ -d \"\$HOME/.config/opencode\" ]] || command -v opencode >/dev/null 2>&1; } && echo 'Detected' || return 1")
    scan_args+=("Codex CLI" "{ [[ -d \"\$HOME/.codex\" ]] || command -v codex >/dev/null 2>&1; } && echo 'Detected' || return 1")
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
    
    # Detect Codex CLI
    if [[ -d "$HOME/.codex" ]] || command -v codex &> /dev/null 2>&1; then
        DETECTED_CODEX=true
        log "INFO" "Codex CLI detected"
    else
        DETECTED_CODEX=false
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

    # Detect Alfred
    if [[ -d "$HOME/Library/Application Support/Alfred" ]] || [[ -d "/Applications/Alfred 5.app" ]]; then
        DETECTED_ALFRED=true
        log "INFO" "Alfred detected"
    else
        DETECTED_ALFRED=false
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
agentpong Installer - macOS developer workspace management + AI agent notifications

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

    local uninstall_args=()
    [[ "$DRY_RUN" == true ]] && uninstall_args+=(--dry-run)
    [[ "$FORCE_INSTALL" == true ]] && uninstall_args+=(--force)
    [[ "$QUIET_MODE" == true ]] && uninstall_args+=(--quiet)

    exec bash "$SCRIPT_DIR/uninstall.sh" "${uninstall_args[@]}"
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
    
    # Check AeroSpace (required)
    if command -v aerospace &> /dev/null || [[ -x "/opt/homebrew/bin/aerospace" ]] || [[ -x "/usr/local/bin/aerospace" ]]; then
        success "AeroSpace installed"
    else
        error "AeroSpace not installed (required)"
        all_ok=false
    fi

    # Check AeroSpace config
    if [[ -f "$HOME/.aerospace.toml" ]]; then
        success "AeroSpace config present"
    else
        warn "AeroSpace config not found (~/.aerospace.toml)"
        all_ok=false
    fi

    # Check AeroSpace scripts
    step "Checking AeroSpace scripts..."
    local aero_scripts=("sort-workspaces.sh" "open-project.sh" "list-all-repos.sh" "toggle-animations.sh" "alfred-search.sh")
    for script in "${aero_scripts[@]}"; do
        if [[ -f "$HOME/.config/aerospace/$script" && -x "$HOME/.config/aerospace/$script" ]]; then
            success "$script present and executable"
        elif [[ -f "$HOME/.config/aerospace/$script" ]]; then
            warn "$script present but not executable"
            all_ok=false
        else
            warn "$script missing"
            all_ok=false
        fi
    done
    
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
        success "Test notification sent!"
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
    [[ "$DETECTED_CODEX" == true ]] && integration_options+=("Codex CLI (detected)")
    [[ "$DETECTED_SANDBOX" == true ]] && integration_options+=("claude-sandbox (detected)")
    [[ "$DETECTED_OPENCODE" != true ]] && integration_options+=("OpenCode (install anyway)")
    [[ "$DETECTED_CODEX" != true ]] && integration_options+=("Codex CLI (install anyway)")
    [[ "$DETECTED_SANDBOX" != true ]] && integration_options+=("claude-sandbox (install anyway)")
    
    if [[ ${#integration_options[@]} -gt 0 ]]; then
        local selected=$(choose_multi "Select integrations to install:" "${integration_options[@]}")
        
        [[ "$selected" == *"OpenCode"* ]] && INSTALL_OPENCODE=true
        [[ "$selected" == *"Codex"* ]] && INSTALL_CODEX=true
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
    success "Let's go!"
}

# =============================================================================
# MAIN INSTALLATION
# =============================================================================

run_install() {
    log "INFO" "Starting installation"
    
    ring_bell
    
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

    # Check for AeroSpace
    if [[ "$DETECTED_AEROSPACE" != true ]]; then
        if [[ "$UPDATE_MODE" == true ]]; then
            error "AeroSpace is required but not installed. Install with: brew install --cask nikitabobko/tap/aerospace"
            return 1
        fi

        warn "AeroSpace is required for workspace management and window focusing"
        confirm "Install AeroSpace via Homebrew?"
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if [[ "$DRY_RUN" == false ]]; then
                spin "Installing AeroSpace..." brew install --cask nikitabobko/tap/aerospace
                DETECTED_AEROSPACE=true
            fi
        else
            error "Please install AeroSpace manually: brew install --cask nikitabobko/tap/aerospace"
            return 1
        fi
    else
        success "AeroSpace already installed"
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
    STOP_HOOK_CONFIG=$(jq -n --arg cmd "$NOTIFY_SCRIPT '$STOP_MESSAGE'" \
        '{matcher: "", hooks: [{type: "command", command: $cmd}]}')

    PERMISSION_HOOK_COMMAND="$NOTIFY_SCRIPT '$PERMISSION_MESSAGE'"
    PERMISSION_HOOK_CONFIG=$(jq -n --arg cmd "$NOTIFY_SCRIPT '$PERMISSION_MESSAGE'" \
        '{matcher: "", hooks: [{type: "command", command: $cmd}]}')
    
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

    # Phase 3: AeroSpace Config
    install_aerospace_config

    # Phase 5: Alfred Workflow (optional)
    if [[ "$DETECTED_ALFRED" == true ]]; then
        install_alfred_workflow
    else
        section "Alfred Workflow" "" "" "⚙"
        dim "Alfred not detected, skipping workflow installation"
        dim "Install Alfred to get the Cursor project switcher workflow"
    fi

    # Phase 6: Performance
    if [[ "$UPDATE_MODE" != true && "$QUIET_MODE" != true ]]; then
        section "Performance Tuning" "" "" "⚡"
        echo ""
        confirm "Disable macOS animations for snappier workspace switching?"
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if [[ "$DRY_RUN" == false ]]; then
                step "Disabling macOS animations..."
                bash "$SRC_DIR/toggle-animations.sh" off > /dev/null 2>&1
                success "Animations disabled (log out and back in for full effect)"
            else
                dim "[DRY-RUN] Would disable macOS animations"
            fi
        else
            dim "Keeping default animations"
        fi
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
    
    # Codex CLI support
    if [[ "${INSTALL_CODEX:-$DETECTED_CODEX}" == true ]]; then
        install_codex_support
    elif [[ "$UPDATE_MODE" != true && "$QUIET_MODE" != true && "$DETECTED_CODEX" == false ]]; then
        echo ""
        confirm "Install Codex CLI support?"
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_codex_support
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
        "AeroSpace" "✓ Configured"
        "Notifications" "✓ Enabled"
        "Window Focus" "✓ Enabled"
    )

    if [[ "${INSTALL_OPENCODE:-false}" == true || -f "$OPENCODE_PLUGIN_FILE" ]]; then
        summary_items+=("OpenCode" "✓ Enabled")
    fi

    if [[ "${INSTALL_CODEX:-false}" == true || -f "$CODEX_PLUGIN_FILE" ]]; then
        summary_items+=("Codex CLI" "✓ Enabled")
    fi

    if [[ "${INSTALL_SANDBOX:-false}" == true || -f "$SANDBOX_PLIST" ]]; then
        summary_items+=("Sandbox" "✓ Enabled")
    fi

    if [[ "$DETECTED_ALFRED" == true ]]; then
        summary_items+=("Alfred" "✓ Workflow installed")
    fi

    show_status_grid "${summary_items[@]}"

    # Keybinding table
    echo ""
    info "Keybindings (configured in ~/.aerospace.toml):"
    dim "  alt+1..9      Switch to workspace 1-9"
    dim "  alt+s         Sort/organize Cursor windows by priority"
    dim "  alt+n         Focus next pending notification"
    dim "  alt+p         Open project switcher (Alfred)"
    dim "  alt+f         Toggle fullscreen"
    dim "  alt+left/right  Previous/next workspace"
    
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
        
        success "AeroSpace workspace management configured"
        success "Notifications enabled for Claude Code"
        success "Click notifications to focus window"
        success "Press alt+n to cycle pending notifications"
        success "Press alt+s to organize Cursor windows"

        echo ""
        gradient_text "  Ready to pong." purple cyan
        echo ""
        info "Cursor: Works automatically"
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

install_aerospace_config() {
    log "INFO" "Installing AeroSpace configuration"

    section "Setting up AeroSpace workspace management" "" "" "⚙"

    # Create config directory
    dry_aware_mkdir "$AEROSPACE_CONFIG_DIR"

    # Copy aerospace.toml
    step "Checking aerospace.toml..."
    if [[ -f "$AEROSPACE_TOML_DST" ]]; then
        if needs_update "$AEROSPACE_TOML_SRC" "$AEROSPACE_TOML_DST"; then
            if [[ "$QUIET_MODE" != true && "$UPDATE_MODE" != true ]]; then
                warn "~/.aerospace.toml already exists and differs from agentpong's config"
                confirm "Overwrite with agentpong's aerospace.toml? (backup will be created)"
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    info "Keeping existing aerospace.toml"
                else
                    if [[ "$DRY_RUN" == false ]]; then
                        cp "$AEROSPACE_TOML_DST" "$AEROSPACE_TOML_DST.backup.$(date +%Y%m%d-%H%M%S)"
                        add_rollback "mv '$AEROSPACE_TOML_DST.backup.'* '$AEROSPACE_TOML_DST' 2>/dev/null || true"
                    fi
                    dry_aware_copy "$AEROSPACE_TOML_SRC" "$AEROSPACE_TOML_DST" "aerospace.toml"
                    success "Updated aerospace.toml (backup created)"
                fi
            else
                if [[ ! -f "$AEROSPACE_TOML_DST.backup" ]]; then
                    cp "$AEROSPACE_TOML_DST" "$AEROSPACE_TOML_DST.backup.$(date +%Y%m%d-%H%M%S)"
                fi
                dry_aware_copy "$AEROSPACE_TOML_SRC" "$AEROSPACE_TOML_DST" "aerospace.toml"
                success "Updated aerospace.toml"
            fi
        else
            dim "aerospace.toml is up to date"
        fi
    else
        dry_aware_copy "$AEROSPACE_TOML_SRC" "$AEROSPACE_TOML_DST" "aerospace.toml"
        success "Installed aerospace.toml"
        add_rollback "rm '$AEROSPACE_TOML_DST' 2>/dev/null || true"
    fi

    # Copy scripts to ~/.config/aerospace/
    step "Installing AeroSpace scripts..."
    for script in "${AEROSPACE_SCRIPTS[@]}"; do
        local src="$SRC_DIR/$script"
        local dst="$AEROSPACE_CONFIG_DIR/$script"
        if [[ -f "$src" ]]; then
            if needs_update "$src" "$dst"; then
                dry_aware_copy "$src" "$dst" "$script"
                success "Installed $script"
            else
                dim "$script is up to date"
            fi
        else
            warn "Source script not found: $script"
        fi
    done

    # Reload AeroSpace config
    if [[ "$DRY_RUN" == false ]]; then
        step "Reloading AeroSpace config..."
        if command -v aerospace &> /dev/null || [[ -x "/opt/homebrew/bin/aerospace" ]] || [[ -x "/usr/local/bin/aerospace" ]]; then
            local aero_bin
            aero_bin=$(command -v aerospace 2>/dev/null || echo "/opt/homebrew/bin/aerospace")
            "$aero_bin" reload-config 2>/dev/null && success "AeroSpace config reloaded" || dim "AeroSpace not running, config will load on next start"
        fi
    fi

    log "INFO" "AeroSpace configuration complete"
}

install_alfred_workflow() {
    log "INFO" "Installing Alfred workflow"

    section "Installing Alfred workflow" "" "" "⚙"

    local workflow_src="$ALFRED_DIR/$ALFRED_WORKFLOW_NAME"
    local workflow_dst="$ALFRED_WORKFLOWS_DIR/com.tsilva.$ALFRED_WORKFLOW_NAME"

    if [[ ! -d "$ALFRED_WORKFLOWS_DIR" ]]; then
        # Try to find Alfred preferences directory
        ALFRED_WORKFLOWS_DIR=$(find "$HOME/Library/Application Support/Alfred" -type d -name "workflows" 2>/dev/null | head -1)
        if [[ -z "$ALFRED_WORKFLOWS_DIR" ]]; then
            dim "Alfred workflows directory not found, skipping"
            return 0
        fi
        workflow_dst="$ALFRED_WORKFLOWS_DIR/com.tsilva.$ALFRED_WORKFLOW_NAME"
    fi

    if [[ -d "$workflow_src" ]]; then
        step "Installing Cursor Project Switcher workflow..."
        dry_aware_mkdir "$workflow_dst"

        # Copy info.plist with __HOME__ substitution
        if [[ "$DRY_RUN" == false ]]; then
            sed "s|__HOME__|$HOME|g" "$workflow_src/info.plist" > "$workflow_dst/info.plist"
            success "Installed Alfred workflow (keyword: p)"
            add_rollback "rm -rf '$workflow_dst' 2>/dev/null || true"
        else
            dim "[DRY-RUN] Would install Alfred workflow to $workflow_dst"
        fi
    else
        warn "Alfred workflow source not found: $workflow_src"
    fi
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

install_codex_support() {
    log "INFO" "Installing Codex CLI support"
    
    section "Installing Codex CLI support" "" "" "⚙"
    
    local codex_updated=false
    
    # Create directory
    dry_aware_mkdir "$CODEX_DIR"
    
    # Copy files
    if needs_update "$SRC_DIR/notify.sh" "$CODEX_NOTIFY_SCRIPT"; then
        dry_aware_copy "$SRC_DIR/notify.sh" "$CODEX_NOTIFY_SCRIPT" "notify.sh"
        success "Installed notify.sh"
        codex_updated=true
    else
        dim "notify.sh is up to date"
    fi
    
    if needs_update "$SRC_DIR/style.sh" "$CODEX_STYLE_SCRIPT"; then
        dry_aware_copy "$SRC_DIR/style.sh" "$CODEX_STYLE_SCRIPT" "style.sh"
        success "Installed style.sh"
        codex_updated=true
    else
        dim "style.sh is up to date"
    fi
    
    if needs_update "$FOCUS_SCRIPT_SRC" "$CODEX_FOCUS_SCRIPT"; then
        dry_aware_copy "$FOCUS_SCRIPT_SRC" "$CODEX_FOCUS_SCRIPT" "focus-window.sh"
        success "Installed focus-window.sh"
        codex_updated=true
    else
        dim "focus-window.sh is up to date"
    fi
    
    if needs_update "$PONG_SCRIPT_SRC" "$CODEX_PONG_SCRIPT"; then
        dry_aware_copy "$PONG_SCRIPT_SRC" "$CODEX_PONG_SCRIPT" "pong.sh"
        success "Installed pong.sh"
        codex_updated=true
    else
        dim "pong.sh is up to date"
    fi
    
    # Install plugin
    if needs_update "$PLUGINS_DIR/codex/agentpong.py" "$CODEX_PLUGIN_FILE"; then
        dry_aware_copy "$PLUGINS_DIR/codex/agentpong.py" "$CODEX_PLUGIN_FILE" "agentpong.py"
        success "Installed Codex plugin"
        codex_updated=true
    else
        dim "Codex plugin is up to date"
    fi
    
    # Make plugin executable
    if [[ -f "$CODEX_PLUGIN_FILE" && "$DRY_RUN" == false ]]; then
        chmod +x "$CODEX_PLUGIN_FILE"
    fi
    
    if [[ "$codex_updated" == true && "$DRY_RUN" == false ]]; then
        banner "Codex CLI support installed!"
        info "Codex notifications will appear with workspace names."
        echo ""
        dim "To enable notifications, add this to ~/.codex/config.toml:"
        dim ""
        dim 'notify = ["python3", "'"$HOME/.codex/agentpong.py"'"]'
        echo ""
    elif [[ "$DRY_RUN" == true && "$codex_updated" == true ]]; then
        dim "Codex: Would update files"
    else
        dim "Codex CLI support is already up to date"
    fi
    
    INSTALL_CODEX=true
}

install_sandbox_support() {
    log "INFO" "Installing sandbox support"
    
    section "Installing sandbox support" "" "" "⚙"
    
    local sandbox_updated=false
    
    # Create directories
    dry_aware_mkdir "$SANDBOX_CONFIG_DIR"
    dry_aware_mkdir "$HOME/Library/LaunchAgents"

    step "Ensuring sandbox notification token..."
    if [[ -f "$SANDBOX_TOKEN_FILE" ]]; then
        if [[ "$DRY_RUN" == false ]]; then
            chmod 600 "$SANDBOX_TOKEN_FILE" 2>/dev/null || true
        fi
        dim "Sandbox notification token is already present"
    elif [[ "$DRY_RUN" == false ]]; then
        openssl rand -hex 16 > "$SANDBOX_TOKEN_FILE"
        chmod 600 "$SANDBOX_TOKEN_FILE"
        success "Created sandbox notification token"
        sandbox_updated=true
    else
        dim "[DRY-RUN] Would create sandbox notification token"
    fi
    
    # Copy handler script
    if needs_update "$SRC_DIR/notify-listener.sh" "$SANDBOX_HANDLER"; then
        dry_aware_copy "$SRC_DIR/notify-listener.sh" "$SANDBOX_HANDLER" "notify-listener.sh"
        success "Updated notify-listener.sh"
        sandbox_updated=true
    else
        dim "notify-listener.sh is up to date"
    fi
    
    # Copy sandbox notify script
    if needs_update "$SRC_DIR/notify-container.sh" "$SANDBOX_NOTIFY_SCRIPT"; then
        dry_aware_copy "$SRC_DIR/notify-container.sh" "$SANDBOX_NOTIFY_SCRIPT" "notify-container.sh"
        success "Updated notify-container.sh"
        sandbox_updated=true
    else
        dim "notify-container.sh is up to date"
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
            success "Started launchd service (token-protected TCP listener on port 19223)"
        fi
    else
        dim "launchd service is up to date"
    fi
    rm -f "$temp_plist"
    
    # Configure sandbox hooks
    step "Configuring sandbox hooks..."
    
    SANDBOX_STOP_HOOK_COMMAND="/home/claude/.claude/notify.sh 'Ready for input'"
    SANDBOX_STOP_HOOK_CONFIG=$(jq -n --arg cmd "$SANDBOX_STOP_HOOK_COMMAND" \
        '{matcher: "", hooks: [{type: "command", command: $cmd}]}')

    SANDBOX_PERMISSION_HOOK_COMMAND="/home/claude/.claude/notify.sh 'Permission required'"
    SANDBOX_PERMISSION_HOOK_CONFIG=$(jq -n --arg cmd "$SANDBOX_PERMISSION_HOOK_COMMAND" \
        '{matcher: "", hooks: [{type: "command", command: $cmd}]}')
    
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
    SANDBOX_HANDLER="$CLAUDE_DIR/notify-listener.sh"
    SANDBOX_PLIST_TEMPLATE="$CONFIG_DIR/com.agentpong.sandbox.plist.template"
    SANDBOX_PLIST="$HOME/Library/LaunchAgents/com.agentpong.sandbox.plist"
    SANDBOX_TOKEN_FILE="$SANDBOX_CONFIG_DIR/agentpong.token"
    
    # AeroSpace paths
    AEROSPACE_CONFIG_DIR="$HOME/.config/aerospace"
    AEROSPACE_TOML_DST="$HOME/.aerospace.toml"
    AEROSPACE_TOML_SRC="$CONFIG_DIR/aerospace.toml"
    AEROSPACE_SCRIPTS=(
        "sort-workspaces.sh"
        "open-project.sh"
        "list-all-repos.sh"
        "toggle-animations.sh"
        "alfred-search.sh"
    )

    # Alfred paths
    ALFRED_DIR="$SCRIPT_DIR/alfred"
    ALFRED_WORKFLOWS_DIR="$HOME/Library/Application Support/Alfred/Alfred.alfredpreferences/workflows"
    ALFRED_WORKFLOW_NAME="cursor-project-switcher"

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
    
    # Codex paths
    CODEX_DIR="$HOME/.codex"
    CODEX_NOTIFY_SCRIPT="$CODEX_DIR/notify.sh"
    CODEX_STYLE_SCRIPT="$CODEX_DIR/style.sh"
    CODEX_FOCUS_SCRIPT="$CODEX_DIR/focus-window.sh"
    CODEX_PONG_SCRIPT="$CODEX_DIR/pong.sh"
    CODEX_PLUGIN_FILE="$CODEX_DIR/agentpong.py"
    CODEX_CONFIG_FILE="$HOME/.codex/config.toml"
    
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
