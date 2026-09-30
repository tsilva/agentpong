#!/bin/bash
#
# agentpong - Kickass Uninstallation Script v3.1.0
#
# Usage:
#   ./uninstall.sh [flags]
#
# Flags:
#   --dry-run    Preview what would be removed
#   --force, -f  Skip confirmation prompts (removes all installed components)
#   --quiet, -q  Minimal output
#   --help, -h   Show help
#

set -e

# =============================================================================
# CONFIGURATION
# =============================================================================

UNINSTALL_VERSION="3.1.0"
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
    --force, -f    Skip confirmation prompts (removes all installed components)
    --quiet, -q    Minimal output
    --help, -h     Show this help

Interactive mode lets you select which components (Claude Code, Codex CLI,
OpenCode, Kimi, claude-sandbox, AeroSpace, Alfred) to remove.

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

# Remove the marker-delimited agentpong block (and any legacy manual
# agentpong `notify = ...` line) from a TOML config file
remove_toml_block() {
    local file="$1" desc="$2"
    [[ -f "$file" ]] || return 0

    if [[ "$DRY_RUN" == true ]]; then
        dim "[DRY-RUN] Would remove agentpong block from $desc"
        return 0
    fi

    if [[ ! -f "$file.backup.uninstall" ]]; then
        cp "$file" "$file.backup.uninstall"
    fi
    sed -i '' '/# >>> agentpong >>>/,/# <<< agentpong <<</d' "$file"
    sed -i '' '/^notify[[:space:]]*=.*agentpong/d' "$file"
    # Tidy a blank first line left behind by a prepended block
    sed -i '' '1{/^$/d;}' "$file"
    log "INFO" "Removed agentpong block from $file"
}

# Precise check: does the codex config point its notify hook at agentpong?
# (A bare `grep agentpong` false-positives on project trust entries.)
codex_config_has_agentpong() {
    [[ -f "$CODEX_CONFIG_FILE" ]] || return 1
    grep -qF '# >>> agentpong >>>' "$CODEX_CONFIG_FILE" 2>/dev/null && return 0
    grep -qE '^notify[[:space:]]*=.*agentpong' "$CODEX_CONFIG_FILE" 2>/dev/null && return 0
    return 1
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
SANDBOX_TOKEN_FILE="$SANDBOX_CONFIG_DIR/agentpong.token"
SANDBOX_HANDLER="$CLAUDE_DIR/notify-listener.sh"
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

# Codex paths
CODEX_DIR="$HOME/.codex"
CODEX_NOTIFY_SCRIPT="$CODEX_DIR/notify.sh"
CODEX_STYLE_SCRIPT="$CODEX_DIR/style.sh"
CODEX_FOCUS_SCRIPT="$CODEX_DIR/focus-window.sh"
CODEX_PONG_SCRIPT="$CODEX_DIR/pong.sh"
CODEX_PLUGIN_FILE="$CODEX_DIR/agentpong.py"
CODEX_CONFIG_FILE="$HOME/.codex/config.toml"

# Kimi paths
KIMI_DIR="$HOME/.kimi-code"
KIMI_NOTIFY_SCRIPT="$KIMI_DIR/notify.sh"
KIMI_STYLE_SCRIPT="$KIMI_DIR/style.sh"
KIMI_FOCUS_SCRIPT="$KIMI_DIR/focus-window.sh"
KIMI_PONG_SCRIPT="$KIMI_DIR/pong.sh"
KIMI_PLUGIN_FILE="$KIMI_DIR/agentpong.sh"
KIMI_CONFIG_FILE="$KIMI_DIR/config.toml"

# AeroSpace paths
AEROSPACE_CONFIG_DIR="$HOME/.config/aerospace"
AEROSPACE_TOML="$HOME/.aerospace.toml"
AEROSPACE_SCRIPTS=(
    "sort-workspaces.sh"
    "open-project.sh"
    "list-all-repos.sh"
    "toggle-animations.sh"
    "alfred-search.sh"
)

# Alfred paths
ALFRED_WORKFLOWS_DIR="$HOME/Library/Application Support/Alfred/Alfred.alfredpreferences/workflows"
ALFRED_WORKFLOW_DIR="$ALFRED_WORKFLOWS_DIR/com.tsilva.cursor-project-switcher"

# =============================================================================
# COMPONENT SELECTION
# =============================================================================

is_selected() {
    local key="$1"
    local c
    for c in "${SELECTED_COMPONENTS[@]}"; do
        [[ "$c" == "$key" ]] && return 0
    done
    return 1
}

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

    # Re-register cleanup trap (style.sh overwrites with its own)
    _uninstall_cleanup() {
        type style_cleanup &>/dev/null && style_cleanup
        printf "\033[?25h\033[0m" 2>/dev/null
    }
    trap _uninstall_cleanup EXIT INT TERM HUP QUIT

    ring_bell

    header "agentpong" "Uninstaller v${UNINSTALL_VERSION}"

    if [[ "$DRY_RUN" == true ]]; then
        info "Dry-run mode: no changes will be made"
    fi

    # === Detect installed components ===
    section "Scanning for installed components" "" "" "◎"

    COMP_CLAUDE=false
    if [[ -f "$NOTIFY_SCRIPT" || -f "$STYLE_SCRIPT" || -f "$FOCUS_SCRIPT" || -f "$PONG_SCRIPT" ]]; then
        COMP_CLAUDE=true
    fi
    if [[ -f "$SETTINGS_FILE" ]] && command -v jq &> /dev/null; then
        if jq -e '.hooks.Stop // .hooks.PermissionRequest' "$SETTINGS_FILE" > /dev/null 2>&1; then
            COMP_CLAUDE=true
        fi
    fi

    COMP_CODEX=false
    if [[ -f "$CODEX_NOTIFY_SCRIPT" || -f "$CODEX_PLUGIN_FILE" ]]; then
        COMP_CODEX=true
    fi
    if codex_config_has_agentpong; then
        COMP_CODEX=true
    fi

    COMP_OPENCODE=false
    if [[ -f "$OPENCODE_NOTIFY_SCRIPT" || -f "$OPENCODE_PLUGIN_FILE" ]]; then
        COMP_OPENCODE=true
    fi

    COMP_KIMI=false
    if [[ -f "$KIMI_NOTIFY_SCRIPT" || -f "$KIMI_PLUGIN_FILE" ]]; then
        COMP_KIMI=true
    fi
    if [[ -f "$KIMI_CONFIG_FILE" ]] && grep -qF '# >>> agentpong >>>' "$KIMI_CONFIG_FILE" 2>/dev/null; then
        COMP_KIMI=true
    fi

    COMP_SANDBOX=false
    if [[ -f "$SANDBOX_PLIST" || -f "$SANDBOX_HANDLER" || -f "$SANDBOX_NOTIFY_SCRIPT" || -f "$SANDBOX_TOKEN_FILE" ]]; then
        COMP_SANDBOX=true
    fi

    COMP_AEROSPACE=false
    for script in "${AEROSPACE_SCRIPTS[@]}"; do
        if [[ -f "$AEROSPACE_CONFIG_DIR/$script" ]]; then
            COMP_AEROSPACE=true
            break
        fi
    done
    if [[ -f "$AEROSPACE_TOML" ]]; then
        COMP_AEROSPACE=true
    fi

    COMP_ALFRED=false
    if [[ -d "$ALFRED_WORKFLOW_DIR" ]]; then
        COMP_ALFRED=true
    fi

    # Validate there's something to remove
    if [[ "$COMP_CLAUDE" == false && "$COMP_CODEX" == false && "$COMP_OPENCODE" == false && "$COMP_KIMI" == false && "$COMP_SANDBOX" == false && "$COMP_AEROSPACE" == false && "$COMP_ALFRED" == false ]]; then
        info "Nothing to uninstall - agentpong doesn't appear to be installed"
        exit 0
    fi

    # === Select which components to remove ===
    SELECTED_COMPONENTS=()

    if [[ "$FORCE_MODE" != true && "$QUIET_MODE" != true && "$DRY_RUN" != true && -t 0 ]]; then
        local -a options=()
        [[ "$COMP_CLAUDE" == true ]] && options+=("Claude Code")
        [[ "$COMP_CODEX" == true ]] && options+=("Codex CLI")
        [[ "$COMP_OPENCODE" == true ]] && options+=("OpenCode")
        [[ "$COMP_KIMI" == true ]] && options+=("Kimi")
        [[ "$COMP_SANDBOX" == true ]] && options+=("claude-sandbox")
        [[ "$COMP_AEROSPACE" == true ]] && options+=("AeroSpace config & scripts")
        [[ "$COMP_ALFRED" == true ]] && options+=("Alfred workflow")

        local joined
        local IFS=','
        joined="${options[*]}"
        unset IFS

        local picked
        if ! picked=$(choose_multi --selected "$joined" "Select components to remove (all pre-selected):" "${options[@]}"); then
            echo ""
            info "Selection cancelled. Nothing was removed."
            exit 0
        fi

        while IFS= read -r line; do
            case "$line" in
                "Claude Code")    SELECTED_COMPONENTS+=("claude") ;;
                "Codex CLI")      SELECTED_COMPONENTS+=("codex") ;;
                "OpenCode")       SELECTED_COMPONENTS+=("opencode") ;;
                "Kimi")           SELECTED_COMPONENTS+=("kimi") ;;
                "claude-sandbox") SELECTED_COMPONENTS+=("sandbox") ;;
                "AeroSpace config & scripts") SELECTED_COMPONENTS+=("aerospace") ;;
                "Alfred workflow") SELECTED_COMPONENTS+=("alfred") ;;
            esac
        done <<< "$picked"

        if [[ ${#SELECTED_COMPONENTS[@]} -eq 0 ]]; then
            info "No components selected. Nothing was removed."
            exit 0
        fi
    else
        # Non-interactive / force / dry-run: select everything installed
        [[ "$COMP_CLAUDE" == true ]] && SELECTED_COMPONENTS+=("claude")
        [[ "$COMP_CODEX" == true ]] && SELECTED_COMPONENTS+=("codex")
        [[ "$COMP_OPENCODE" == true ]] && SELECTED_COMPONENTS+=("opencode")
        [[ "$COMP_KIMI" == true ]] && SELECTED_COMPONENTS+=("kimi")
        [[ "$COMP_SANDBOX" == true ]] && SELECTED_COMPONENTS+=("sandbox")
        [[ "$COMP_AEROSPACE" == true ]] && SELECTED_COMPONENTS+=("aerospace")
        [[ "$COMP_ALFRED" == true ]] && SELECTED_COMPONENTS+=("alfred")
    fi

    # === Preview what will be done ===
    section "Actions to perform" "" "" "◎"

    local preview_count=0

    if is_selected claude; then
        for f in "$NOTIFY_SCRIPT" "$STYLE_SCRIPT" "$FOCUS_SCRIPT" "$PONG_SCRIPT"; do
            if [[ -f "$f" ]]; then
                list_item "Remove" "$f"
                preview_count=$((preview_count + 1))
            fi
        done
        if [[ -f "$SETTINGS_FILE" ]] && command -v jq &> /dev/null; then
            if jq -e '.hooks.Stop' "$SETTINGS_FILE" > /dev/null 2>&1; then
                list_item "Remove" "Stop hook from settings.json"
                preview_count=$((preview_count + 1))
            fi
            if jq -e '.hooks.PermissionRequest' "$SETTINGS_FILE" > /dev/null 2>&1; then
                list_item "Remove" "PermissionRequest hook from settings.json"
                preview_count=$((preview_count + 1))
            fi
        elif [[ -f "$SETTINGS_FILE" ]]; then
            warn "jq not installed, cannot check/remove hooks automatically"
        fi
    fi

    if is_selected codex; then
        for f in "$CODEX_NOTIFY_SCRIPT" "$CODEX_STYLE_SCRIPT" "$CODEX_FOCUS_SCRIPT" "$CODEX_PONG_SCRIPT" "$CODEX_PLUGIN_FILE"; do
            if [[ -f "$f" ]]; then
                list_item "Remove" "$f"
                preview_count=$((preview_count + 1))
            fi
        done
        if codex_config_has_agentpong; then
            list_item "Remove" "agentpong notify hook from codex config.toml"
            preview_count=$((preview_count + 1))
        fi
    fi

    if is_selected opencode; then
        for f in "$OPENCODE_NOTIFY_SCRIPT" "$OPENCODE_STYLE_SCRIPT" "$OPENCODE_FOCUS_SCRIPT" "$OPENCODE_PONG_SCRIPT" "$OPENCODE_PLUGIN_FILE"; do
            if [[ -f "$f" ]]; then
                list_item "Remove" "$f"
                preview_count=$((preview_count + 1))
            fi
        done
    fi

    if is_selected kimi; then
        for f in "$KIMI_NOTIFY_SCRIPT" "$KIMI_STYLE_SCRIPT" "$KIMI_FOCUS_SCRIPT" "$KIMI_PONG_SCRIPT" "$KIMI_PLUGIN_FILE"; do
            if [[ -f "$f" ]]; then
                list_item "Remove" "$f"
                preview_count=$((preview_count + 1))
            fi
        done
        if [[ -f "$KIMI_CONFIG_FILE" ]] && grep -qF '# >>> agentpong >>>' "$KIMI_CONFIG_FILE" 2>/dev/null; then
            list_item "Remove" "agentpong hooks from kimi config.toml"
            preview_count=$((preview_count + 1))
        fi
    fi

    if is_selected sandbox; then
        if [[ -f "$SANDBOX_PLIST" ]]; then
            list_item "Unload & Remove" "launchd service"
            preview_count=$((preview_count + 1))
        fi
        for f in "$SANDBOX_HANDLER" "$SANDBOX_NOTIFY_SCRIPT" "$SANDBOX_TOKEN_FILE"; do
            if [[ -f "$f" ]]; then
                list_item "Remove" "$f"
                preview_count=$((preview_count + 1))
            fi
        done
    fi

    if is_selected aerospace; then
        if [[ -f "$AEROSPACE_TOML" ]]; then
            list_item "Remove" "~/.aerospace.toml (with prompt)"
            preview_count=$((preview_count + 1))
        fi
        for script in "${AEROSPACE_SCRIPTS[@]}"; do
            if [[ -f "$AEROSPACE_CONFIG_DIR/$script" ]]; then
                list_item "Remove" "$AEROSPACE_CONFIG_DIR/$script"
                preview_count=$((preview_count + 1))
            fi
        done
    fi

    if is_selected alfred; then
        if [[ -d "$ALFRED_WORKFLOW_DIR" ]]; then
            list_item "Remove" "Alfred Cursor Project Switcher workflow"
            preview_count=$((preview_count + 1))
        fi
    fi

    if [[ $preview_count -eq 0 ]]; then
        info "Nothing to remove for the selected components"
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

    # --- Claude Code ---
    if is_selected claude; then
        for f in "$NOTIFY_SCRIPT" "$STYLE_SCRIPT" "$FOCUS_SCRIPT" "$PONG_SCRIPT"; do
            if [[ -f "$f" ]]; then
                dry_aware_remove "$f" "$(basename "$f")"
                success "Removed $(basename "$f")"
            fi
        done

        # Remove hooks from settings.json
        if [[ -f "$SETTINGS_FILE" ]] && command -v jq &> /dev/null; then
            step "Cleaning up settings.json..."

            # Backup before modifying
            if [[ ! -f "$SETTINGS_FILE.backup.uninstall" ]]; then
                cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup.uninstall"
            fi

            local modified=false

            for hook in Stop PermissionRequest; do
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
    fi

    # --- Codex CLI ---
    if is_selected codex; then
        for f in "$CODEX_NOTIFY_SCRIPT" "$CODEX_STYLE_SCRIPT" "$CODEX_FOCUS_SCRIPT" "$CODEX_PONG_SCRIPT" "$CODEX_PLUGIN_FILE"; do
            if [[ -f "$f" ]]; then
                dry_aware_remove "$f" "$(basename "$f") (codex)"
                success "Removed $(basename "$f") (codex)"
            fi
        done
        if codex_config_has_agentpong; then
            remove_toml_block "$CODEX_CONFIG_FILE" "codex config.toml"
            success "Removed agentpong hook from codex config.toml"
        fi
    fi

    # --- OpenCode ---
    if is_selected opencode; then
        for f in "$OPENCODE_NOTIFY_SCRIPT" "$OPENCODE_STYLE_SCRIPT" "$OPENCODE_FOCUS_SCRIPT" "$OPENCODE_PONG_SCRIPT" "$OPENCODE_PLUGIN_FILE"; do
            if [[ -f "$f" ]]; then
                dry_aware_remove "$f" "$(basename "$f") (opencode)"
                success "Removed $(basename "$f") (opencode)"
            fi
        done
    fi

    # --- Kimi ---
    if is_selected kimi; then
        for f in "$KIMI_NOTIFY_SCRIPT" "$KIMI_STYLE_SCRIPT" "$KIMI_FOCUS_SCRIPT" "$KIMI_PONG_SCRIPT" "$KIMI_PLUGIN_FILE"; do
            if [[ -f "$f" ]]; then
                dry_aware_remove "$f" "$(basename "$f") (kimi)"
                success "Removed $(basename "$f") (kimi)"
            fi
        done
        if [[ -f "$KIMI_CONFIG_FILE" ]] && grep -qF '# >>> agentpong >>>' "$KIMI_CONFIG_FILE" 2>/dev/null; then
            remove_toml_block "$KIMI_CONFIG_FILE" "kimi config.toml"
            success "Removed agentpong hooks from kimi config.toml"
        fi
    fi

    # --- Sandbox ---
    if is_selected sandbox; then
        if [[ -f "$SANDBOX_PLIST" ]]; then
            step "Unloading launchd service..."
            launchctl unload "$SANDBOX_PLIST" 2>/dev/null || true
            dry_aware_remove "$SANDBOX_PLIST" "launchd plist"
            success "Removed launchd service"
        fi
        for f in "$SANDBOX_HANDLER" "$SANDBOX_NOTIFY_SCRIPT" "$SANDBOX_TOKEN_FILE"; do
            if [[ -f "$f" ]]; then
                dry_aware_remove "$f" "$(basename "$f") (sandbox)"
                success "Removed $(basename "$f") (sandbox)"
            fi
        done
    fi

    # --- AeroSpace ---
    if is_selected aerospace; then
        # Re-enable macOS animations before removing scripts
        if [[ -x "$AEROSPACE_CONFIG_DIR/toggle-animations.sh" ]]; then
            step "Re-enabling macOS animations..."
            bash "$AEROSPACE_CONFIG_DIR/toggle-animations.sh" on > /dev/null 2>&1 || true
            success "Re-enabled macOS animations"
        fi

        # Remove AeroSpace scripts
        for script in "${AEROSPACE_SCRIPTS[@]}"; do
            if [[ -f "$AEROSPACE_CONFIG_DIR/$script" ]]; then
                dry_aware_remove "$AEROSPACE_CONFIG_DIR/$script" "$script"
                success "Removed $script"
            fi
        done

        # Remove ~/.aerospace.toml (user-facing config - prompt)
        if [[ -f "$AEROSPACE_TOML" ]]; then
            if [[ "$FORCE_MODE" == true ]]; then
                dry_aware_remove "$AEROSPACE_TOML" "aerospace.toml"
                success "Removed ~/.aerospace.toml"
            else
                confirm "Remove ~/.aerospace.toml? (you may have customized it)"
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    rm "$AEROSPACE_TOML"
                    success "Removed ~/.aerospace.toml"
                else
                    dim "Keeping ~/.aerospace.toml"
                fi
            fi
        fi
    fi

    # --- Alfred ---
    if is_selected alfred; then
        if [[ -d "$ALFRED_WORKFLOW_DIR" ]]; then
            rm -rf "$ALFRED_WORKFLOW_DIR"
            success "Removed Alfred workflow"
        fi
    fi

    # Reload AeroSpace config (if still installed)
    if [[ "$DRY_RUN" == false ]]; then
        local aero_bin
        aero_bin=$(command -v aerospace 2>/dev/null || echo "/opt/homebrew/bin/aerospace")
        if [[ -x "$aero_bin" ]]; then
            "$aero_bin" reload-config 2>/dev/null || true
        fi
    fi

    ring_bell
    banner "Uninstallation complete!"

    note "terminal-notifier was not removed (you may have other uses for it)."
    dim "To fully remove it:"
    dim "  brew uninstall terminal-notifier"
    echo ""
    note "AeroSpace itself was not removed."
    dim "To uninstall: brew uninstall aerospace"
    
    log "INFO" "Uninstallation completed successfully"
}

# Run main
main "$@"
