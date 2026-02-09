#!/bin/bash
#
# style.sh - Terminal styling library for claudepong
#
# Source this file in scripts for gorgeous terminal output.
# Uses gum (charmbracelet) when available, falls back to ANSI 256-color + Unicode.
#
# Usage: source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/style.sh" 2>/dev/null || true
#

# ---------------------------------------------------------------------------
# Environment detection
# ---------------------------------------------------------------------------

# Respect NO_COLOR (https://no-color.org) and non-TTY output
if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
    _STYLE_HAS_COLOR=false
else
    _STYLE_HAS_COLOR=true
fi

# Detect gum
if command -v gum &> /dev/null && [[ "$_STYLE_HAS_COLOR" == true ]]; then
    _STYLE_HAS_GUM=true
else
    _STYLE_HAS_GUM=false
fi

# ---------------------------------------------------------------------------
# ANSI 256-color palette
# ---------------------------------------------------------------------------

if [[ "$_STYLE_HAS_COLOR" == true ]]; then
    _C_BRAND=$'\033[38;5;141m'    # #AF87FF soft purple
    _C_SUCCESS=$'\033[38;5;114m'  # #87D787 soft green
    _C_ERROR=$'\033[38;5;203m'    # #FF5F5F warm red
    _C_WARN=$'\033[38;5;221m'     # #FFD75F amber
    _C_INFO=$'\033[38;5;117m'     # #87CEEB sky blue
    _C_MUTED=$'\033[38;5;244m'    # #808080 gray
    _C_BOLD=$'\033[1m'
    _C_RESET=$'\033[0m'
else
    _C_BRAND="" _C_SUCCESS="" _C_ERROR="" _C_WARN="" _C_INFO="" _C_MUTED=""
    _C_BOLD="" _C_RESET=""
fi

# ---------------------------------------------------------------------------
# Styling functions
# ---------------------------------------------------------------------------

# header "brand" "subtitle" — Bordered header with brand color
header() {
    local title="${1:-}" subtitle="${2:-}"
    local full_text="$title"
    [[ -n "$subtitle" ]] && full_text="$title  $subtitle"

    if [[ "$_STYLE_HAS_GUM" == true ]]; then
        gum style \
            --border rounded \
            --border-foreground 141 \
            --foreground 141 \
            --bold \
            --padding "0 2" \
            --margin "0 0" \
            "$full_text"
    else
        local len=${#full_text}
        local pad=4
        local total=$((len + pad))
        local line
        line=$(printf '━%.0s' $(seq 1 "$total"))
        echo ""
        echo "${_C_BRAND}┏${line}┓${_C_RESET}"
        echo "${_C_BRAND}┃${_C_RESET}  ${_C_BRAND}${_C_BOLD}${full_text}${_C_RESET}  ${_C_BRAND}┃${_C_RESET}"
        echo "${_C_BRAND}┗${line}┛${_C_RESET}"
    fi
    echo ""
}

# section "text" — Horizontal rule section divider (━━ text ━━━━)
section() {
    local text="${1:-}"

    if [[ "$_STYLE_HAS_GUM" == true ]]; then
        echo ""
        gum style --foreground 141 --bold "━━ $text ━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    else
        echo ""
        echo "${_C_BRAND}${_C_BOLD}━━ ${text} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━${_C_RESET}"
    fi
    echo ""
}

# success "text" — ✓ green text
success() {
    if [[ "$_STYLE_HAS_GUM" == true ]]; then
        gum style --foreground 114 "  ✓ $1"
    else
        echo "  ${_C_SUCCESS}✓${_C_RESET} ${_C_SUCCESS}$1${_C_RESET}"
    fi
}

# error "text" — ✗ red text
error() {
    if [[ "$_STYLE_HAS_GUM" == true ]]; then
        gum style --foreground 203 "  ✗ $1"
    else
        echo "  ${_C_ERROR}✗${_C_RESET} ${_C_ERROR}$1${_C_RESET}"
    fi
}

# warn "text" — ⚠ amber text
warn() {
    if [[ "$_STYLE_HAS_GUM" == true ]]; then
        gum style --foreground 221 "  ⚠ $1"
    else
        echo "  ${_C_WARN}⚠${_C_RESET} ${_C_WARN}$1${_C_RESET}"
    fi
}

# info "text" — ● blue text
info() {
    if [[ "$_STYLE_HAS_GUM" == true ]]; then
        gum style --foreground 117 "  ● $1"
    else
        echo "  ${_C_INFO}●${_C_RESET} ${_C_INFO}$1${_C_RESET}"
    fi
}

# step "text" — → dimmed action log
step() {
    if [[ "$_STYLE_HAS_GUM" == true ]]; then
        gum style --foreground 244 "  → $1"
    else
        echo "  ${_C_MUTED}→ $1${_C_RESET}"
    fi
}

# note "text" — gray "Note:" prefix
note() {
    if [[ "$_STYLE_HAS_GUM" == true ]]; then
        gum style --foreground 244 "  Note: $1"
    else
        echo "  ${_C_MUTED}Note: $1${_C_RESET}"
    fi
}

# confirm "prompt" — Styled y/n prompt. Sets REPLY variable.
confirm() {
    local prompt="${1:-Continue?}"

    if [[ "$_STYLE_HAS_GUM" == true ]]; then
        if gum confirm --prompt.foreground 141 "$prompt"; then
            REPLY="y"
        else
            REPLY="n"
        fi
    else
        printf "  ${_C_BRAND}▸${_C_RESET} %s ${_C_MUTED}(y/n)${_C_RESET} " "$prompt"
        read -n 1 -r
        echo ""
    fi
}

# banner "text" — Bordered completion message
banner() {
    local text="${1:-}"

    if [[ "$_STYLE_HAS_GUM" == true ]]; then
        echo ""
        gum style \
            --border rounded \
            --border-foreground 114 \
            --foreground 114 \
            --bold \
            --padding "0 2" \
            --margin "0 0" \
            "$text"
    else
        local len=${#text}
        local pad=4
        local total=$((len + pad))
        local line
        line=$(printf '━%.0s' $(seq 1 "$total"))
        echo ""
        echo "${_C_SUCCESS}┏${line}┓${_C_RESET}"
        echo "${_C_SUCCESS}┃${_C_RESET}  ${_C_SUCCESS}${_C_BOLD}${text}${_C_RESET}  ${_C_SUCCESS}┃${_C_RESET}"
        echo "${_C_SUCCESS}┗${line}┛${_C_RESET}"
    fi
    echo ""
}

# error_block "line1" "line2" ... — Multi-line error with red left border
error_block() {
    echo ""
    if [[ "$_STYLE_HAS_GUM" == true ]]; then
        local content=""
        for line in "$@"; do
            [[ -n "$content" ]] && content+=$'\n'
            content+="$line"
        done
        gum style \
            --border thick \
            --border-foreground 203 \
            --foreground 203 \
            --padding "0 1" \
            --margin "0 1" \
            "$content"
    else
        for line in "$@"; do
            echo "  ${_C_ERROR}│${_C_RESET} ${_C_ERROR}$line${_C_RESET}"
        done
    fi
    echo ""
}

# list_item "label" "value" — Colored label: value pair
list_item() {
    local label="${1:-}" value="${2:-}"
    if [[ "$_STYLE_HAS_GUM" == true ]]; then
        echo "  $(gum style --foreground 141 "•") $(gum style --foreground 141 --bold "$label:") $(gum style --foreground 244 "$value")"
    else
        echo "  ${_C_BRAND}•${_C_RESET} ${_C_BRAND}${_C_BOLD}$label:${_C_RESET} ${_C_MUTED}$value${_C_RESET}"
    fi
}

# dim "text" — Gray/muted text
dim() {
    if [[ "$_STYLE_HAS_GUM" == true ]]; then
        gum style --foreground 244 "  $1"
    else
        echo "  ${_C_MUTED}$1${_C_RESET}"
    fi
}
