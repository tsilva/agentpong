#!/bin/bash
#
# agentpong - Kickass Uninstallation Script v2.0.0
#
# Usage:
#   ./uninstall.sh [flags]
#
# Flags:
#   --dry-run    Preview what would be removed
#   --force, -f  Skip confirmation prompts
#   --quiet, -q  Minimal output
#   --help, -h   Show help
#

set -e

# =============================================================================
# CONFIGURATION
# =============================================================================

UNINSTALL_VERSION="2.0.0"
INSTALL_LOG=""
DRY_RUN=false
FORCE_MODE=false
QUIET_MODE=false

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force|-f)
                FORCE_MODE=true
                shift
                ;;
            --quiet|-q)
                QUIET_MODE=true
                export STYLE_VERBOSE=0
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << 'EOF'
agentpong Uninstaller

USAGE:
    ./uninstall.sh [FLAGS]

FLAGS:
    --dry-run      Preview what would be removed
    --force, -f    Skip confirmation prompts
    --quiet, -q    Minimal output
    --help, -h     Show this help

EOF
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

log() {
    local level="$1" message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    if [[ -n "$INSTALL_LOG" ]]; then
        echo "[$timestamp] [$level] $message" >> "$INSTALL_LOG"
    fi
}

dry_aware_remove() {
    local file="$1" desc="$2"
    if [[ "$DRY_RUN" == true ]]; then
        dim "[DRY-RUN] Would remove: $desc"
        log "DRY-RUN" "Would remove $file"
    else
        if [[ -f "$file" ]]; then
            rm "$file"
            log "INFO" "Removed $file"
        fi
    fi
}

# =============================================================================
# PATHS
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
CLAUDE_DIR="$HOME/.claude"
NOTIFY_SCRIPT="$CLAUDE_DIR/notify.sh"
STYLE_SCRIPT="$CLAUDE_DIR/style.sh"
FOCUS_SCRIPT="$CLAUDE_DIR/focus-window.sh"
PONG_SCRIPT="$CLAUDE_DIR/pong.sh"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# Sandbox paths
SANDBOX_DIR="$HOME/.claude-sandbox"
SANDBOX_CONFIG_DIR="$SANDBOX_DIR/claude-config"
SANDBOX_NOTIFY_SCRIPT="$SANDBOX_CONFIG_DIR/notify.sh"
SANDBOX_SETTINGS_FILE="$SANDBOX_CONFIG_DIR/settings.json"
SANDBOX_HANDLER="$CLAUDE_DIR/notify-handler.sh"
SANDBOX_PLIST="$HOME/Library/LaunchAgents/com.agentpong.sandbox.plist"

# OpenCode paths
OPENCODE_DIR="$HOME/.opencode"
OPENCODE_NOTIFY_SCRIPT="$OPENCODE_DIR/notify.sh"
OPENCODE_STYLE_SCRIPT="$OPENCODE_DIR/style.sh"
OPENCODE_FOCUS_SCRIPT="$OPENCODE_DIR/focus-window.sh"
OPENCODE_PONG_SCRIPT="$OPENCODE_DIR/pong.sh"
OPENCODE_SETTINGS_FILE="$OPENCODE_DIR/settings.json"
OPENCODE_PLUGIN_FILE="$HOME/.config/opencode/plugins/agentpong.ts"
OPENCODE_CONFIG_SETTINGS="$HOME/.config/opencode/settings.json"

# Legacy paths

# =============================================================================
# MAIN UNINSTALL
# =============================================================================

main() {
    parse_args "$@"
    
    # Initialize log
    INSTALL_LOG="${TMPDIR:-/tmp}/agentpong-uninstall-$(date +%Y%m%d-%H%M%S).log"
    touch "$INSTALL_LOG"
    log "INFO" "agentpong uninstaller v$UNINSTALL_VERSION started"
    
    # Source styling library
    source "$SRC_DIR/style.sh" 2>/dev/null || true
    
    # Pong intro + tagline
    ring_bell
    pong_intro ""
    typewrite "Time to say goodbye."

    header "agentpong" "Uninstaller v${UNINSTALL_VERSION}"

    if [[ "$DRY_RUN" == true ]]; then
        info "Dry-run mode: no changes will be made"
    fi

    # === Preview what will be done ===
    section "Actions to perform" "" "" "◎"

    local items_to_remove=()
    local hooks_to_remove=()
    local will_unload_launchd=false

    # Check core files
    if [[ -f "$NOTIFY_SCRIPT" ]]; then
        list_item "Remove" "$NOTIFY_SCRIPT"
        items_to_remove+=("$NOTIFY_SCRIPT")
    fi

    if [[ -f "$STYLE_SCRIPT" ]]; then
        list_item "Remove" "$STYLE_SCRIPT"
        items_to_remove+=("$STYLE_SCRIPT")
    fi

    if [[ -f "$FOCUS_SCRIPT" ]]; then
        list_item "Remove" "$FOCUS_SCRIPT"
        items_to_remove+=("$FOCUS_SCRIPT")
    fi

    if [[ -f "$PONG_SCRIPT" ]]; then
        list_item "Remove" "$PONG_SCRIPT"
        items_to_remove+=("$PONG_SCRIPT")
    fi

    # Check settings.json hooks
    if [[ -f "$SETTINGS_FILE" ]] && command -v jq &> /dev/null; then
        if jq -e '.hooks.Stop' "$SETTINGS_FILE" > /dev/null 2>&1; then
            list_item "Remove" "Stop hook from settings.json"
            hooks_to_remove+=("Stop")
        fi
        if jq -e '.hooks.PermissionRequest' "$SETTINGS_FILE" > /dev/null 2>&1; then
            list_item "Remove" "PermissionRequest hook from settings.json"
            hooks_to_remove+=("PermissionRequest")
        fi
    elif [[ -f "$SETTINGS_FILE" ]]; then
        warn "jq not installed, cannot check/remove hooks automatically"
    fi

    # Check sandbox
    if [[ -f "$SANDBOX_PLIST" ]]; then
        list_item "Unload & Remove" "launchd service"
        will_unload_launchd=true
    fi
    if [[ -f "$SANDBOX_HANDLER" ]]; then
        list_item "Remove" "$SANDBOX_HANDLER"
        items_to_remove+=("$SANDBOX_HANDLER")
    fi
    if [[ -f "$SANDBOX_NOTIFY_SCRIPT" ]]; then
        list_item "Remove" "$SANDBOX_NOTIFY_SCRIPT"
        items_to_remove+=("$SANDBOX_NOTIFY_SCRIPT")
    fi

    # Check OpenCode
    if [[ -f "$OPENCODE_NOTIFY_SCRIPT" ]]; then
        list_item "Remove" "$OPENCODE_NOTIFY_SCRIPT"
        items_to_remove+=("$OPENCODE_NOTIFY_SCRIPT")
    fi
    if [[ -f "$OPENCODE_STYLE_SCRIPT" ]]; then
        list_item "Remove" "$OPENCODE_STYLE_SCRIPT"
        items_to_remove+=("$OPENCODE_STYLE_SCRIPT")
    fi
    if [[ -f "$OPENCODE_FOCUS_SCRIPT" ]]; then
        list_item "Remove" "$OPENCODE_FOCUS_SCRIPT"
        items_to_remove+=("$OPENCODE_FOCUS_SCRIPT")
    fi
    if [[ -f "$OPENCODE_PONG_SCRIPT" ]]; then
        list_item "Remove" "$OPENCODE_PONG_SCRIPT"
        items_to_remove+=("$OPENCODE_PONG_SCRIPT")
    fi
    if [[ -f "$OPENCODE_PLUGIN_FILE" ]]; then
        list_item "Remove" "OpenCode plugin"
        items_to_remove+=("$OPENCODE_PLUGIN_FILE")
    fi

    # Validate there's something to remove
    if [[ ${#items_to_remove[@]} -eq 0 && ${#hooks_to_remove[@]} -eq 0 && "$will_unload_launchd" == false ]]; then
        info "Nothing to uninstall - agentpong doesn't appear to be installed"
        exit 0
    fi

    # Confirmation
    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        info "Dry-run complete. No changes were made."
        exit 0
    fi

    if [[ "$FORCE_MODE" != true && "$QUIET_MODE" != true ]]; then
        echo ""
        confirm "Proceed with uninstallation?"

        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Uninstallation cancelled."
            exit 0
        fi
    fi

    # === Execute removal ===
    section "Removing files" "" "" "⚙"

    # Remove core files
    for file in "${items_to_remove[@]}"; do
        if [[ -f "$file" ]]; then
            dry_aware_remove "$file" "$(basename "$file")"
            success "Removed $(basename "$file")"
        fi
    done

    # Remove hooks from settings.json
    if [[ ${#hooks_to_remove[@]} -gt 0 && -f "$SETTINGS_FILE" ]] && command -v jq &> /dev/null; then
        step "Cleaning up settings.json..."
        
        # Backup before modifying
        if [[ ! -f "$SETTINGS_FILE.backup.uninstall" ]]; then
            cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup.uninstall"
        fi

        local modified=false
        
        for hook in "${hooks_to_remove[@]}"; do
            if jq -e ".hooks.$hook" "$SETTINGS_FILE" > /dev/null 2>&1; then
                jq "del(.hooks.$hook)" "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
                mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
                success "Removed $hook hook"
                modified=true
            fi
        done

        # Clean up empty hooks object
        if [[ "$modified" == true ]] && jq -e '.hooks == {}' "$SETTINGS_FILE" > /dev/null 2>&1; then
            jq 'del(.hooks)' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
        fi
        
        if [[ "$modified" == false ]]; then
            dim "No hooks to remove"
        fi
    fi

    # Unload and remove launchd service
    if [[ "$will_unload_launchd" == true ]]; then
        step "Unloading launchd service..."
        launchctl unload "$SANDBOX_PLIST" 2>/dev/null || true
        dry_aware_remove "$SANDBOX_PLIST" "launchd plist"
        success "Removed launchd service"
    fi

    celebration 1.5 "Uninstallation complete!"
    ring_bell
    banner "Uninstallation complete!"

    note "terminal-notifier was not removed (you may have other uses for it)."
    dim "To fully remove it:"
    dim "  brew uninstall terminal-notifier"
    
    log "INFO" "Uninstallation completed successfully"
}

# Run main
main "$@"
