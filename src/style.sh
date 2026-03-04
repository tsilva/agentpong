#!/bin/bash
#
# style.sh - AgentPong Terminal UI Library v3.0
#
# A beautiful, pong-themed terminal UI library with rich visual feedback.
# Features: gradient colors, animations, progress indicators, interactive elements.
#
# Usage: source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/style.sh"
#

# =============================================================================
# ENVIRONMENT DETECTION
# =============================================================================

# Respect NO_COLOR (https://no-color.org) and non-TTY output
if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
    _STYLE_HAS_COLOR=false
else
    _STYLE_HAS_COLOR=true
fi

# Truecolor detection
_STYLE_HAS_TRUECOLOR=false
if [[ "$_STYLE_HAS_COLOR" == true ]]; then
    case "${COLORTERM:-}" in
        truecolor|24bit) _STYLE_HAS_TRUECOLOR=true ;;
    esac
fi

# Detect gum (charm.sh TUI library)
if command -v gum &> /dev/null && [[ "$_STYLE_HAS_COLOR" == true ]]; then
    _STYLE_HAS_GUM=true
else
    _STYLE_HAS_GUM=false
fi

# Dynamic terminal width
_STYLE_COLS="${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}"

# Verbosity: 0=quiet, 1=normal, 2=verbose
_STYLE_VERBOSITY="${STYLE_VERBOSE:-1}"

# Animation state
_STYLE_ANIMATION_PID=""

# =============================================================================
# COLOR PALETTE - Pong-Themed Gradients
# =============================================================================

if [[ "$_STYLE_HAS_COLOR" == true ]]; then
    if [[ "$_STYLE_HAS_TRUECOLOR" == true ]]; then
        # Truecolor gradient palette (purple → pink → blue)
        _C_PURPLE=$'\033[38;2;175;135;255m'      # #AF87FF
        _C_PINK=$'\033[38;2;255;135;215m'       # #FF87D7
        _C_BLUE=$'\033[38;2;135;206;255m'       # #87CEFF
        _C_CYAN=$'\033[38;2;135;255;215m'       # #87FFD7
        
        # Semantic colors
        _C_BRAND=$'\033[38;2;175;135;255m'      # Purple
        _C_SUCCESS=$'\033[38;2;135;215;135m'    # Soft green
        _C_ERROR=$'\033[38;2;255;95;95m'        # Warm red
        _C_WARN=$'\033[38;2;255;215;95m'        # Amber
        _C_INFO=$'\033[38;2;135;206;235m'       # Sky blue
        _C_MUTED=$'\033[38;2;128;128;128m'      # Gray
        _C_WHITE=$'\033[38;2;255;255;255m'      # White
    else
        # ANSI 256 fallback
        _C_PURPLE=$'\033[38;5;141m'
        _C_PINK=$'\033[38;5;212m'
        _C_BLUE=$'\033[38;5;117m'
        _C_CYAN=$'\033[38;5;122m'
        
        _C_BRAND=$'\033[38;5;141m'
        _C_SUCCESS=$'\033[38;5;114m'
        _C_ERROR=$'\033[38;5;203m'
        _C_WARN=$'\033[38;5;221m'
        _C_INFO=$'\033[38;5;117m'
        _C_MUTED=$'\033[38;5;244m'
        _C_WHITE=$'\033[38;5;255m'
    fi
    
    _C_BOLD=$'\033[1m'
    _C_DIM=$'\033[2m'
    _C_ITALIC=$'\033[3m'
    _C_UNDERLINE=$'\033[4m'
    _C_BLINK=$'\033[5m'
    _C_RESET=$'\033[0m'
else
    _C_PURPLE="" _C_PINK="" _C_BLUE="" _C_CYAN=""
    _C_BRAND="" _C_SUCCESS="" _C_ERROR="" _C_WARN=""
    _C_INFO="" _C_MUTED="" _C_WHITE=""
    _C_BOLD="" _C_DIM="" _C_ITALIC="" _C_UNDERLINE=""
    _C_BLINK="" _C_RESET=""
fi

# =============================================================================
# GRADIENT & EFFECT FUNCTIONS
# =============================================================================

# Apply gradient to text (left to right color transition)
# Usage: gradient_text "text" [start_color] [end_color]
gradient_text() {
    local text="$1"
    local start_color="${2:-purple}"
    local end_color="${3:-blue}"
    local len=${#text}
    local result=""
    
    [[ "$_STYLE_HAS_TRUECOLOR" != true ]] && { echo "$text"; return; }
    
    local start_r=175 start_g=135 start_b=255  # Purple default
    local end_r=135 end_g=206 end_b=255       # Blue default
    
    case "$start_color" in
        pink) start_r=255; start_g=135; start_b=215 ;;
        blue) start_r=135; start_g=206; start_b=255 ;;
        cyan) start_r=135; start_g=255; start_b=215 ;;
        purple|brand) start_r=175; start_g=135; start_b=255 ;;
    esac
    
    case "$end_color" in
        pink) end_r=255; end_g=135; end_b=215 ;;
        blue) end_r=135; end_g=206; end_b=255 ;;
        cyan) end_r=135; end_g=255; end_b=215 ;;
        purple|brand) end_r=175; end_g=135; end_b=255 ;;
    esac
    
    for (( i=0; i<len; i++ )); do
        local char="${text:i:1}"
        local ratio=$(( i * 100 / len ))
        local r=$(( start_r + (end_r - start_r) * ratio / 100 ))
        local g=$(( start_g + (end_g - start_g) * ratio / 100 ))
        local b=$(( start_b + (end_b - start_b) * ratio / 100 ))
        result+="\033[38;2;${r};${g};${b}m${char}"
    done
    result+="$_C_RESET"
    
    # Use printf to interpret the escape sequences
    printf "%b" "$result"
}

# Pulse/glow effect (print with oscillating brightness)
# Usage: pulse_text "text" [duration_seconds]
pulse_text() {
    local text="$1"
    local duration="${2:-0.5}"
    
    [[ "$_STYLE_HAS_COLOR" != true ]] && { echo "$text"; return; }
    [[ -t 1 ]] || { echo "$text"; return; }
    
    local end_time=$(($(date +%s) + duration))
    local frame=0
    
    while [[ $(date +%s) -lt $end_time ]]; do
        local intensity=$(( 128 + 127 * (frame % 20 - 10) / 10 ))
        (( intensity < 128 )) && intensity=$(( 256 - intensity ))
        
        printf "\r\033[38;2;%d;%d;%d%s\033[K" "$intensity" "$intensity" "$intensity" "m${text}"
        ((frame++))
        sleep 0.05
    done
    printf "\r%s\033[K\n" "$_C_WHITE${text}$_C_RESET"
}

# =============================================================================
# HEADER & BRANDING
# =============================================================================

# Pong-themed ASCII art header
show_logo() {
    local version="${1:-}"
    local show_gradient="${2:-true}"
    
    # Logo ASCII
    local line1="○ ════════════════════════════ ○     "
    local line2="        PING    ○    PONG            "
    local line3="              v${version}              "
    local line4="     ○ ════════════════════════════ ○     "
    
    if [[ "$_STYLE_HAS_TRUECOLOR" == true && "$show_gradient" == true ]]; then
        echo ""
        gradient_text "$line1" purple blue
        echo ""
        gradient_text "$line2" pink cyan
        echo ""
        if [[ -n "$version" ]]; then
            gradient_text "$line3" blue purple
            echo ""
        fi
        gradient_text "$line4" cyan purple
        echo ""
    else
        echo ""
        echo "${_C_PURPLE}${line1}${_C_RESET}"
        echo "${_C_PINK}${line2}${_C_RESET}"
        if [[ -n "$version" ]]; then
            echo "${_C_BLUE}${line3}${_C_RESET}"
        fi
        echo "${_C_CYAN}${line4}${_C_RESET}"
        echo ""
    fi
}

# Rounded border header with title
header() {
    local title="${1:-}"
    local subtitle="${2:-}"
    local full_text="$title"
    [[ -n "$subtitle" ]] && full_text="$title  $subtitle"
    
    if [[ "$_STYLE_HAS_GUM" == true ]]; then
        local width=${#full_text}
        (( width < 40 )) && width=40
        (( width += 6 ))
        
        gum style \
            --border rounded \
            --border-foreground 141 \
            --foreground 141 \
            --bold \
            --padding "1 3" \
            --margin "0 0 1 0" \
            --width "$width" \
            --align center \
            "$full_text"
    else
        local len=${#full_text}
        local pad=6
        local total=$((len + pad))
        local line=$(printf '─%.0s' $(seq 1 $total))
        
        echo ""
        echo "  ${_C_PURPLE}╭${line}╮${_C_RESET}"
        echo "  ${_C_PURPLE}│${_C_RESET}   ${_C_BOLD}${_C_BRAND}${full_text}${_C_RESET}   ${_C_PURPLE}│${_C_RESET}"
        echo "  ${_C_PURPLE}╰${line}╯${_C_RESET}"
        echo ""
    fi
}

# =============================================================================
# SECTION DIVIDERS
# =============================================================================

# Section divider with progress indicator and optional icon
# Usage: section "text" [phase] [total] [icon]
# Icons: ◎ (scan), ⚙ (config), ◆ (complete), ▸ (action), ↯ (deps)
section() {
    local text="${1:-}"
    local phase="${2:-}"
    local total="${3:-}"
    local icon="${4:-}"

    local prefix=""
    if [[ -n "$icon" ]]; then
        if [[ -n "$phase" && -n "$total" ]]; then
            prefix="━━ ${icon} Phase ${phase}/${total}: ${text} "
        else
            prefix="━━ ${icon} ${text} "
        fi
    else
        if [[ -n "$phase" && -n "$total" ]]; then
            prefix="━━ Phase ${phase}/${total}: ${text} "
        else
            prefix="━━ ${text} "
        fi
    fi

    local prefix_len=$(( ${#prefix} ))
    local trail_len=$(( _STYLE_COLS - prefix_len - 2 ))
    (( trail_len < 4 )) && trail_len=4
    local trail=$(printf '━%.0s' $(seq 1 $trail_len))

    echo ""
    echo "  ${_C_PURPLE}${_C_BOLD}${prefix}${trail}${_C_RESET}"
}

# Progress pipeline showing all phases with current highlighted
show_pipeline() {
    local current="${1:-0}"
    local total="${2:-5}"
    shift 2
    local phases=("$@")
    
    [[ ${#phases[@]} -eq 0 ]] && phases=("detect" "deps" "config" "hooks" "verify")
    
    local line="  "
    for (( i=0; i<${#phases[@]}; i++ )); do
        local phase_name="${phases[$i]}"
        if (( i < current )); then
            line+="${_C_SUCCESS}●${_C_RESET} ${phase_name} "
        elif (( i == current )); then
            line+="${_C_BRAND}${_C_BLINK}●${_C_RESET}${_C_BRAND} ${phase_name}${_C_RESET} "
        else
            line+="${_C_MUTED}○${phase_name}${_C_RESET} "
        fi
        
        if (( i < ${#phases[@]} - 1 )); then
            if (( i < current )); then
                line+="${_C_SUCCESS}→${_C_RESET} "
            else
                line+="${_C_MUTED}→${_C_RESET} "
            fi
        fi
    done
    
    echo ""
    echo "$line"
    echo ""
}

# =============================================================================
# STATUS MESSAGES
# =============================================================================

success() {
    echo "  ${_C_SUCCESS}✓${_C_RESET} ${_C_SUCCESS}$1${_C_RESET}"
}

error() {
    echo "  ${_C_ERROR}✗${_C_RESET} ${_C_ERROR}$1${_C_RESET}"
}

warn() {
    echo "  ${_C_WARN}⚠${_C_RESET} ${_C_WARN}$1${_C_RESET}"
}

info() {
    echo "  ${_C_INFO}●${_C_RESET} ${_C_INFO}$1${_C_RESET}"
}

step() {
    [[ "$_STYLE_VERBOSITY" -eq 0 ]] && return 0
    echo "  ${_C_MUTED}→ $1${_C_RESET}"
}

dim() {
    [[ "$_STYLE_VERBOSITY" -eq 0 ]] && return 0
    echo "  ${_C_MUTED}$1${_C_RESET}"
}

note() {
    echo "  ${_C_MUTED}Note: $1${_C_RESET}"
}

# =============================================================================
# STATUS GRID DASHBOARD
# =============================================================================

# Show a grid of feature statuses
show_status_grid() {
    local -a items=("$@")
    [[ ${#items[@]} -eq 0 ]] && return 0
    
    # Draw as a simple list
    echo ""
    local i=0
    while [[ $i -lt ${#items[@]} ]]; do
        local label="${items[$i]}"
        ((i++))
        local item_status="${items[$i]:-}"
        ((i++))
        
        local color="${_C_SUCCESS}"
        [[ "$item_status" == *"Skip"* || "$item_status" == *"No"* ]] && color="${_C_MUTED}"
        [[ "$item_status" == *"Warn"* || "$item_status" == *"Error"* ]] && color="${_C_WARN}"
        
        echo "  ${_C_BRAND}•${_C_RESET} ${label}: ${color}${item_status}${_C_RESET}"
    done
    echo ""
}

# =============================================================================
# ANIMATIONS
# =============================================================================

# Stop any running animation
stop_animation() {
    if [[ -n "$_STYLE_ANIMATION_PID" ]]; then
        kill "$_STYLE_ANIMATION_PID" 2>/dev/null || true
        wait "$_STYLE_ANIMATION_PID" 2>/dev/null || true
        _STYLE_ANIMATION_PID=""
        echo -e "\033[2K\r"  # Clear line
    fi
}

# Bouncing ball animation (for "detecting" phase)
bounce_ball() {
    local duration="${1:-1}"
    local message="${2:-Detecting...}"
    local width=30
    
    [[ "$_STYLE_HAS_COLOR" != true ]] && { echo "$message"; sleep "$duration"; return; }
    [[ -t 1 ]] || { echo "$message"; sleep "$duration"; return; }
    
    local end_time=$(($(date +%s) + duration))
    local pos=0
    local dir=1
    
    (
        while [[ $(date +%s) -lt $end_time ]]; do
            local line="  ${_C_MUTED}"
            for (( i=0; i<width; i++ )); do
                if [[ $i -eq $pos ]]; then
                    line+="${_C_BRAND}${_C_BOLD}○${_C_MUTED}"
                else
                    line+="─"
                fi
            done
            line+="${_C_RESET}"
            
            printf "\r%s %s" "$line" "$_C_MUTED${message}${_C_RESET}"
            
            (( pos += dir ))
            (( pos >= width - 1 )) && dir=-1
            (( pos <= 0 )) && dir=1
            
            sleep 0.08
        done
        printf "\r\033[2K\r"
    ) &
    
    _STYLE_ANIMATION_PID=$!
    sleep "$duration"
    stop_animation
}

# Ping-pong table animation
table_animation() {
    local duration="${1:-0.5}"
    local message="${2:-Ready}"
    
    [[ "$_STYLE_HAS_COLOR" != true ]] && { echo "$message"; sleep "$duration"; return; }
    
    local frames=(
        "  ╔════════════════════════╗"
        "  ║  PING  ○           ○   ║"
        "  ║       ○ ○              ║"
        "  ║  ════════  PONG  ══════║"
        "  ╚════════════════════════╝"
    )
    
    local end_time=$(($(date +%s) + duration))
    local frame_idx=0
    
    (
        while [[ $(date +%s) -lt $end_time ]]; do
            printf "\r\033[4A"  # Move up 4 lines
            for line in "${frames[@]}"; do
                local colored=""
                if [[ "$line" == *"PING"* ]]; then
                    colored="${_C_PINK}${line}${_C_RESET}"
                elif [[ "$line" == *"PONG"* ]]; then
                    colored="${_C_CYAN}${line}${_C_RESET}"
                elif [[ "$line" == *"○"* ]]; then
                    colored="${_C_BRAND}${line}${_C_RESET}"
                else
                    colored="${_C_MUTED}${line}${_C_RESET}"
                fi
                echo "$colored"
            done
            
            # Cycle frames (simulate ball movement)
            frames[1]="  ║  PING  ○           ○   ║"
            frames[2]="  ║       ○ ○              ║"
            
            sleep 0.2
        done
        
        # Final frame
        printf "\r\033[4A"
        echo "  ${_C_SUCCESS}╔════════════════════════╗${_C_RESET}"
        echo "  ${_C_SUCCESS}║     ${message}        ║${_C_RESET}"
        echo "  ${_C_SUCCESS}║                        ║${_C_RESET}"
        echo "  ${_C_SUCCESS}╚════════════════════════╝${_C_RESET}"
    )
    
    sleep "$duration"
}

# Success cascade animation
cascade_success() {
    local items=("$@")
    
    for item in "${items[@]}"; do
        echo "  ${_C_MUTED}○ ${item}${_C_RESET}"
    done
    
    # Animate checkmarks appearing
    for (( i=${#items[@]}-1; i>=0; i-- )); do
        printf "\033[%dA" 1  # Move up one line
        printf "\r  ${_C_SUCCESS}✓${_C_RESET} ${_C_SUCCESS}%s${_C_RESET}\033[K\n" "${items[$i]}"
        sleep 0.15
    done
}

# =============================================================================
# INTERACTIVE ELEMENTS
# =============================================================================

# Styled confirmation prompt
confirm() {
    local prompt="${1:-Continue?}"
    local timeout="${2:-}"
    local affirmative="${3:-Y}"
    local negative="${4:-n}"
    
    if [[ "$_STYLE_HAS_GUM" == true ]]; then
        local -a gum_args=(--prompt.foreground 141)
        [[ -n "$timeout" ]] && gum_args+=(--timeout "${timeout}s")
        [[ -n "$affirmative" ]] && gum_args+=(--affirmative "$affirmative")
        [[ -n "$negative" ]] && gum_args+=(--negative "$negative")
        
        if gum confirm "${gum_args[@]}" "$prompt"; then
            REPLY="y"
        else
            REPLY="n"
        fi
    else
        printf "  ${_C_BRAND}▸${_C_RESET} %s ${_C_MUTED}(${affirmative}/${negative})${_C_RESET} " "$prompt"
        
        if [[ -n "$timeout" ]]; then
            read -t "$timeout" -n 1 -r || REPLY="n"
        else
            read -n 1 -r
        fi
        echo ""
    fi
}

# Single choice selection (radio style)
choose() {
    local header="${1:-Select an option}"
    shift
    local options=("$@")
    
    if [[ "$_STYLE_HAS_GUM" == true ]]; then
        gum choose --header "  $header" --cursor "  ▸ " \
            --header.foreground 141 --cursor.foreground 141 \
            --selected.foreground 212 \
            "${options[@]}"
        return $?
    else
        echo "  ${_C_BRAND}${_C_BOLD}${header}:${_C_RESET}"
        local i=1
        for opt in "${options[@]}"; do
            echo "  ${_C_MUTED}${i}.${_C_RESET} $opt"
            ((i++))
        done
        
        local total=${#options[@]}
        local choice
        while true; do
            printf "  ${_C_BRAND}▸${_C_RESET} ${_C_MUTED}[1-%d]:${_C_RESET} " "$total"
            read -r choice < /dev/tty
            if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= total )); then
                echo "${options[$((choice-1))]}"
                return 0
            fi
            echo "  ${_C_ERROR}Invalid choice${_C_RESET}"
        done
    fi
}

# Multi-select with checkboxes
choose_multi() {
    local header="${1:-Select options (space to toggle, enter to confirm)}"
    shift
    local options=("$@")
    
    if [[ "$_STYLE_HAS_GUM" == true ]]; then
        gum choose --header "  $header" --cursor "  ▸ " \
            --header.foreground 141 --cursor.foreground 141 \
            --selected.foreground 212 --no-limit \
            "${options[@]}"
        return $?
    else
        echo "  ${_C_BRAND}${_C_BOLD}${header}:${_C_RESET}"
        local selected=()
        
        while true; do
            local i=1
            for opt in "${options[@]}"; do
                local checked="○"
                for sel in "${selected[@]}"; do
                    [[ "$sel" == "$opt" ]] && checked="●"
                done
                echo "  ${checked} ${i}. $opt"
                ((i++))
            done
            
            echo ""
            echo "  ${_C_MUTED}Enter number to toggle, 'd' when done${_C_RESET}"
            printf "  ${_C_BRAND}▸${_C_RESET} "
            read -r choice < /dev/tty
            
            [[ "$choice" == "d" ]] && break
            
            if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
                local idx=$((choice-1))
                local opt="${options[$idx]}"
                local found=false
                local new_selected=()
                for sel in "${selected[@]}"; do
                    if [[ "$sel" == "$opt" ]]; then
                        found=true
                    else
                        new_selected+=("$sel")
                    fi
                done
                [[ "$found" != true ]] && new_selected+=("$opt")
                selected=("${new_selected[@]}")
            fi
            
            printf "\033[%dA" $(( ${#options[@]} + 3 ))  # Move cursor up
        done
        
        printf "%s\n" "${selected[@]}"
    fi
}

# Toggle switch (yes/no)
toggle() {
    local prompt="${1:-}"
    local default="${2:-yes}"
    
    if [[ "$_STYLE_HAS_GUM" == true ]]; then
        gum choose --header "  $prompt" --cursor "  ▸ " \
            --header.foreground 141 --cursor.foreground 141 \
            "Yes" "No"
        [[ "$(gum choose --header "  $prompt" --cursor "  ▸ " \
            --header.foreground 141 --cursor.foreground 141 \
            "Yes" "No")" == "Yes" ]] && return 0 || return 1
    else
        local state="$default"
        while true; do
            local display="${_C_SUCCESS}ON"
            [[ "$state" == "no" ]] && display="${_C_MUTED}OFF"
            printf "  ${_C_BRAND}▸${_C_RESET} %s [${display}${_C_RESET}] ${_C_MUTED}(y/n/enter to confirm)${_C_RESET} " "$prompt"
            
            read -n 1 -r < /dev/tty
            echo ""
            
            case "$REPLY" in
                y|Y) state="yes" ;;
                n|N) state="no" ;;
                '') break ;;
            esac
        done
        
        [[ "$state" == "yes" ]] && return 0 || return 1
    fi
}

# Styled text input
input() {
    local prompt="${1:-}"
    local placeholder="${2:-}"
    local is_password=false
    [[ "$3" == "--password" ]] && is_password=true
    
    if [[ "$_STYLE_HAS_GUM" == true ]]; then
        local -a gum_args=(--prompt "  $prompt " --prompt.foreground 141)
        [[ -n "$placeholder" ]] && gum_args+=(--placeholder "$placeholder")
        [[ "$is_password" == true ]] && gum_args+=(--password)
        
        gum input "${gum_args[@]}"
        return $?
    else
        printf "  ${_C_BRAND}▸${_C_RESET} %s " "$prompt"
        [[ -n "$placeholder" ]] && printf "${_C_MUTED}(%s)${_C_RESET} " "$placeholder"
        
        local value
        if [[ "$is_password" == true ]]; then
            read -rs value < /dev/tty
            echo ""
        else
            read -r value < /dev/tty
        fi
        echo "$value"
    fi
}

# =============================================================================
# PROGRESS INDICATORS
# =============================================================================

# Inline progress bar
progress_bar() {
    local current="${1:-0}"
    local total="${2:-100}"
    local label="${3:-}"
    local width="${4:-40}"
    
    (( total <= 0 )) && total=1
    (( width > _STYLE_COLS - 20 )) && width=$((_STYLE_COLS - 20))
    
    local pct=$(( current * 100 / total ))
    (( pct > 100 )) && pct=100
    
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    
    local bar_filled=$(printf '█%.0s' $(seq 1 $filled))
    local bar_empty=$(printf '░%.0s' $(seq 1 $empty))
    
    printf "\r  ${_C_BRAND}${bar_filled}${_C_MUTED}${bar_empty}${_C_RESET} ${_C_BOLD}%3d%%${_C_RESET} %s\033[K" \
        "$pct" "$label"
    
    (( current >= total )) && echo ""
}

# Spinner with title
spin() {
    local title="$1"
    shift
    
    if [[ "$_STYLE_HAS_GUM" == true ]]; then
        gum spin --spinner dot --title "  $title" --show-error -- "$@"
        return $?
    else
        local spin_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
        local tmpfile=$(mktemp)
        
        "$@" > "$tmpfile" 2>&1 &
        local pid=$!
        
        local i=0
        while kill -0 "$pid" 2>/dev/null; do
            local char="${spin_chars:i%${#spin_chars}:1}"
            printf "\r  ${_C_BRAND}%s${_C_RESET} %s\033[K" "$char" "$title" >&2
            ((i++))
            sleep 0.1
        done
        
        wait "$pid"
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            printf "\r  ${_C_SUCCESS}✓${_C_RESET} %s\033[K\n" "$title" >&2
        else
            printf "\r  ${_C_ERROR}✗${_C_RESET} %s\033[K\n" "$title" >&2
            [[ -s "$tmpfile" ]] && while IFS= read -r line; do
                echo "    ${_C_MUTED}${line}${_C_RESET}" >&2
            done < "$tmpfile"
        fi
        
        rm -f "$tmpfile"
        return $exit_code
    fi
}

# =============================================================================
# LAYOUT ELEMENTS
# =============================================================================

# Bordered completion banner
banner() {
    local text="${1:-}"
    local color="${2:-success}"
    local color_code="$_C_SUCCESS"
    [[ "$color" == "brand" ]] && color_code="$_C_BRAND"
    [[ "$color" == "info" ]] && color_code="$_C_INFO"
    
    if [[ "$_STYLE_HAS_GUM" == true ]]; then
        gum style \
            --border rounded \
            --border-foreground 114 \
            --foreground 114 \
            --bold \
            --padding "1 4" \
            --margin "1 0" \
            --align center \
            "$text"
    else
        local len=${#text}
        local pad=6
        local total=$((len + pad))
        local line=$(printf '━%.0s' $(seq 1 $total))
        
        echo ""
        echo "  ${color_code}╭${line}╮${_C_RESET}"
        echo "  ${color_code}│${_C_RESET}   ${color_code}${_C_BOLD}${text}${_C_RESET}   ${color_code}│${_C_RESET}"
        echo "  ${color_code}╰${line}╯${_C_RESET}"
        echo ""
    fi
}

# List item with bullet
list_item() {
    local label="${1:-}"
    local value="${2:-}"
    echo "  ${_C_BRAND}•${_C_RESET} ${_C_BOLD}${label}:${_C_RESET} ${_C_MUTED}${value}${_C_RESET}"
}

# Error block with red border
error_block() {
    echo ""
    if [[ "$_STYLE_HAS_GUM" == true ]]; then
        local content=""
        for line in "$@"; do
            [[ -n "$content" ]] && content+=$'\n'
            content+="  $line"
        done
        gum style \
            --border thick \
            --border-foreground 203 \
            --foreground 203 \
            --padding "1 2" \
            --margin "1" \
            "$content"
    else
        echo "  ${_C_ERROR}╭────────────────────────────────╮${_C_RESET}"
        for line in "$@"; do
            printf "  ${_C_ERROR}│${_C_RESET} %-28s ${_C_ERROR}│${_C_RESET}\n" "$line"
        done
        echo "  ${_C_ERROR}╰────────────────────────────────╯${_C_RESET}"
    fi
    echo ""
}

# =============================================================================
# UTILITY
# =============================================================================

# Print a table
table() {
    [[ $# -lt 2 ]] && return 1
    local header_row="$1"
    shift
    local rows=("$@")
    
    if [[ "$_STYLE_HAS_GUM" == true ]]; then
        {
            echo "$header_row"
            for row in "${rows[@]}"; do
                echo "$row"
            done
        } | gum table --border.foreground 141 --header.foreground 141 --header.bold
        return $?
    else
        echo "  ${_C_MUTED}Table view requires 'gum' to be installed${_C_RESET}"
        echo "  ${_C_MUTED}Run: brew install gum${_C_RESET}"
        return 1
    fi
}

# Clear screen and show header
clear_with_header() {
    clear
    show_logo
    header "$1" "$2"
}

# Cleanup function (call on script exit)
style_cleanup() {
    stop_animation
}

# Set trap for cleanup
trap style_cleanup EXIT INT TERM

# =============================================================================
# PONG INTRO ANIMATION (The Viral Moment)
# =============================================================================

# Self-playing pong game intro - 3 seconds of animated pong
# Falls back to show_logo on non-TTY/NO_COLOR
pong_intro() {
    local version="${1:-}"
    local duration="${2:-1}"

    # Fallback for non-interactive
    if [[ "$_STYLE_HAS_COLOR" != true ]] || [[ ! -t 1 ]]; then
        show_logo "$version"
        return
    fi

    # Save cursor position and hide cursor
    printf "\033[s\033[?25l"

    # Game field dimensions
    local field_w=48
    local field_h=11
    local pad_h=3

    # Ball state (multiplied by 10 for sub-character precision)
    local bx=240 by=55  # center-ish
    local bdx=18 bdy=12 # velocity

    # Paddle positions (y of top of paddle)
    local lp=4 rp=4

    # Score
    local ls=0 rs=0

    # Trail buffer (last 6 positions)
    local -a trail_x=() trail_y=()
    local trail_len=6

    # Unicode blocks for smooth rendering
    local ball_char="●"
    local pad_char="█"

    # Reserve space by printing the full frame first (with newlines)
    local total_lines=$((field_h + 4))
    local i
    for (( i=0; i<total_lines; i++ )); do 
        echo ""
    done
    
    # Move cursor back to start of reserved space
    printf "\033[%dA" "$total_lines"

    local frames=$((duration * 30))
    local frame=0

    while (( frame < frames )); do
        # --- AI paddle tracking ---
        local ball_y_cell=$(( by / 10 ))
        local lp_center=$(( lp + pad_h / 2 ))
        local rp_center=$(( rp + pad_h / 2 ))
        (( ball_y_cell > lp_center && lp + pad_h < field_h )) && (( lp++ ))
        (( ball_y_cell < lp_center && lp > 1 )) && (( lp-- ))
        (( ball_y_cell > rp_center && rp + pad_h < field_h )) && (( rp++ ))
        (( ball_y_cell < rp_center && rp > 1 )) && (( rp-- ))

        # --- Ball physics ---
        (( bx += bdx ))
        (( by += bdy ))

        # Top/bottom bounce
        if (( by <= 10 )); then by=10; (( bdy = -bdy )); fi
        if (( by >= (field_h - 1) * 10 )); then by=$(( (field_h - 1) * 10 )); (( bdy = -bdy )); fi

        # Left paddle hit
        local bx_cell=$(( bx / 10 ))
        local by_cell=$(( by / 10 ))
        if (( bx_cell <= 3 && by_cell >= lp && by_cell < lp + pad_h )); then
            bx=30; (( bdx = -bdx ))
            # Add spin based on where ball hits paddle
            local hit_pos=$(( by_cell - lp ))
            (( hit_pos == 0 )) && bdy=$(( bdy > 0 ? bdy : -bdy - 2 ))
            (( hit_pos == pad_h - 1 )) && bdy=$(( bdy < 0 ? bdy : -bdy + 2 ))
        fi

        # Right paddle hit
        if (( bx_cell >= field_w - 4 && by_cell >= rp && by_cell < rp + pad_h )); then
            bx=$(( (field_w - 4) * 10 )); (( bdx = -bdx ))
            local hit_pos=$(( by_cell - rp ))
            (( hit_pos == 0 )) && bdy=$(( bdy > 0 ? bdy : -bdy - 2 ))
            (( hit_pos == pad_h - 1 )) && bdy=$(( bdy < 0 ? bdy : -bdy + 2 ))
        fi

        # Score (ball past paddles)
        if (( bx <= 0 )); then
            (( rs++ )); bx=240; by=55; bdx=18; bdy=$((RANDOM % 15 + 8))
            (( RANDOM % 2 == 0 )) && bdy=$(( -bdy ))
        fi
        if (( bx >= field_w * 10 )); then
            (( ls++ )); bx=240; by=55; bdx=-18; bdy=$((RANDOM % 15 + 8))
            (( RANDOM % 2 == 0 )) && bdy=$(( -bdy ))
        fi

        # Clamp velocity
        (( bdy > 20 )) && bdy=20
        (( bdy < -20 )) && bdy=-20

        # Update trail
        trail_x+=("$bx_cell")
        trail_y+=("$by_cell")
        (( ${#trail_x[@]} > trail_len )) && trail_x=("${trail_x[@]:1}") && trail_y=("${trail_y[@]:1}")

        # --- Render ---
        # Clear from cursor to end of screen, then restore cursor position
        printf "\033[J\033[u\033[s"

        # Color-shifting based on frame
        local hue_phase=$(( frame * 3 % 360 ))
        local br=$(( 175 + 80 * (frame % 20 - 10) / 10 ))
        (( br < 135 )) && br=135
        (( br > 255 )) && br=255
        local bg=$(( 135 + 70 * ((frame + 7) % 20 - 10) / 10 ))
        (( bg < 100 )) && bg=100
        (( bg > 255 )) && bg=255
        local bb=$(( 215 + 40 * ((frame + 14) % 20 - 10) / 10 ))
        (( bb < 175 )) && bb=175
        (( bb > 255 )) && bb=255

        bx_cell=$(( bx / 10 ))
        by_cell=$(( by / 10 ))

        # Top border with score
        local score_display
        printf -v score_display "  ${_C_MUTED}╭──────────────────────%s──────────────────────╮${_C_RESET}" \
            "$(printf " ${_C_PINK}%d${_C_MUTED} : ${_C_CYAN}%d${_C_MUTED} " "$ls" "$rs")"
        echo "$score_display"

        # Field rows
        local row col
        for (( row=0; row<field_h; row++ )); do
            local line="  ${_C_MUTED}│${_C_RESET}"
            for (( col=0; col<field_w; col++ )); do
                local ch=" "
                local color=""

                # Center line
                if (( col == field_w / 2 )); then
                    if (( row % 2 == 0 )); then
                        ch="┊"
                        color="${_C_MUTED}"
                    fi
                fi

                # Left paddle
                if (( col >= 1 && col <= 2 && row >= lp && row < lp + pad_h )); then
                    ch="$pad_char"
                    color="${_C_PINK}"
                fi

                # Right paddle
                if (( col >= field_w - 3 && col <= field_w - 2 && row >= rp && row < rp + pad_h )); then
                    ch="$pad_char"
                    color="${_C_CYAN}"
                fi

                # Trail
                local ti
                for (( ti=0; ti<${#trail_x[@]}; ti++ )); do
                    if (( trail_x[ti] == col && trail_y[ti] == row )); then
                        local fade=$(( 60 + ti * 25 ))
                        (( fade > 180 )) && fade=180
                        ch="·"
                        if [[ "$_STYLE_HAS_TRUECOLOR" == true ]]; then
                            color="\033[38;2;${fade};${fade};${fade}m"
                        else
                            color="${_C_MUTED}"
                        fi
                    fi
                done

                # Ball (overwrites trail)
                if (( bx_cell == col && by_cell == row )); then
                    ch="$ball_char"
                    if [[ "$_STYLE_HAS_TRUECOLOR" == true ]]; then
                        color="\033[38;2;${br};${bg};${bb}m"
                    else
                        color="${_C_BRAND}"
                    fi
                fi

                if [[ -n "$color" ]]; then
                    printf "%b%s%b" "$color" "$ch" "${_C_RESET}"
                else
                    printf "%s" "$ch"
                fi
            done
            echo "${_C_MUTED}│${_C_RESET}"
        done

        # Bottom border
        echo "  ${_C_MUTED}╰────────────────────────────────────────────────╯${_C_RESET}"

        # Title line
        if [[ "$_STYLE_HAS_TRUECOLOR" == true ]]; then
            local title_r=$(( 175 + (135 - 175) * (frame % 60) / 60 ))
            local title_g=$(( 135 + (206 - 135) * (frame % 60) / 60 ))
            local title_b=255
            printf "  \033[38;2;%d;%d;%dm  a g e n t p o n g${_C_RESET}" "$title_r" "$title_g" "$title_b"
            if [[ -n "$version" ]]; then
                printf "  ${_C_MUTED}v%s${_C_RESET}" "$version"
            fi
        else
            printf "  ${_C_BRAND}  a g e n t p o n g${_C_RESET}"
            if [[ -n "$version" ]]; then
                printf "  ${_C_MUTED}v%s${_C_RESET}" "$version"
            fi
        fi
        echo ""

        (( frame++ ))
        sleep 0.016
    done

    # Show cursor and move to new line
    printf "\033[?25h"
    echo ""
}

# =============================================================================
# TYPEWRITER EFFECT
# =============================================================================

# Print text character by character with dramatic pacing
# Usage: typewrite "text" [char_delay] [end_pause]
typewrite() {
    local text="$1"
    local char_delay="${2:-0.02}"
    local end_pause="${3:-0.2}"

    if [[ "$_STYLE_HAS_COLOR" != true ]] || [[ ! -t 1 ]]; then
        echo "  $text"
        return
    fi

    printf "  "
    local i
    for (( i=0; i<${#text}; i++ )); do
        local ch="${text:i:1}"
        if [[ "$ch" == "." ]]; then
            printf "%b%s%b" "${_C_BRAND}" "$ch" "${_C_RESET}"
            sleep 0.2
        elif [[ "$ch" == " " ]]; then
            printf " "
            sleep "$char_delay"
        else
            printf "%b%s%b" "${_C_WHITE}" "$ch" "${_C_RESET}"
            sleep "$char_delay"
        fi
    done
    sleep "$end_pause"
    echo ""
}

# =============================================================================
# TERMINAL BELL
# =============================================================================

# Ring terminal bell (respects AGENTPONG_SOUND env var)
ring_bell() {
    if [[ "${AGENTPONG_SOUND:-true}" == "false" ]]; then
        return
    fi
    if [[ -t 1 ]]; then
        printf "\a"
    fi
}

# =============================================================================
# SCAN DASHBOARD (Hacker-Movie Boot Sequence)
# =============================================================================

# Real-time system scan with animated dot-fill
# Usage: scan_dashboard "label1" "command1" "label2" "command2" ...
# Each command should echo its result value on success or return non-zero on failure
scan_dashboard() {
    local -a labels=()
    local -a commands=()
    local -a results=()
    local -a statuses=()

    # Parse label/command pairs
    while [[ $# -ge 2 ]]; do
        labels+=("$1")
        commands+=("$2")
        shift 2
    done

    local count=${#labels[@]}
    [[ $count -eq 0 ]] && return 0

    # Non-interactive fallback
    if [[ "$_STYLE_HAS_COLOR" != true ]] || [[ ! -t 1 ]]; then
        local i
        for (( i=0; i<count; i++ )); do
            local result
            result=$(eval "${commands[$i]}" 2>/dev/null) && statuses+=("ok") || statuses+=("skip")
            echo "  ${labels[$i]}: ${result:-N/A}"
        done
        return 0
    fi

    local max_label_len=0
    local i
    for (( i=0; i<count; i++ )); do
        (( ${#labels[$i]} > max_label_len )) && max_label_len=${#labels[$i]}
    done

    local dot_width=$(( 44 - max_label_len ))
    (( dot_width < 8 )) && dot_width=8

    printf "\033[?25l"

    local start_time=$SECONDS
    local passed=0 skipped=0

    for (( i=0; i<count; i++ )); do
        local label="${labels[$i]}"
        local cmd="${commands[$i]}"

        # Print label with padding
        local pad=$(( max_label_len - ${#label} ))
        printf "  ${_C_WHITE}%s${_C_RESET}%*s " "$label" "$pad" ""

        # Animate dots filling in
        local d
        for (( d=0; d<dot_width; d++ )); do
            if [[ "$_STYLE_HAS_TRUECOLOR" == true ]]; then
                local brightness=$(( 80 + d * 3 ))
                (( brightness > 160 )) && brightness=160
                printf "\033[38;2;%d;%d;%dm·\033[0m" "$brightness" "$brightness" "$brightness"
            else
                printf "${_C_MUTED}·${_C_RESET}"
            fi
            # Faster dots for snappier feel
            sleep 0.008
        done

        # Execute the check command
        local result
        if result=$(eval "$cmd" 2>/dev/null); then
            results+=("$result")
            statuses+=("ok")
            (( passed++ ))
            # Print result on the right
            printf " ${_C_WHITE}%-14s${_C_RESET} ${_C_SUCCESS}✓${_C_RESET}\n" "$result"
        else
            result="${result:-Not found}"
            results+=("$result")
            statuses+=("skip")
            (( skipped++ ))
            printf " ${_C_MUTED}%-14s${_C_RESET} ${_C_MUTED}○${_C_RESET}\n" "$result"
        fi
    done

    # Summary line
    local elapsed=$(( SECONDS - start_time ))
    (( elapsed < 1 )) && elapsed=1
    local total=$count
    local sep=$(printf '─%.0s' $(seq 1 $(( max_label_len + dot_width + 22 ))))
    echo "  ${_C_MUTED}${sep}${_C_RESET}"
    printf "  ${_C_WHITE}%d/%d checks passed${_C_RESET}%*s${_C_MUTED}%d.%ds${_C_RESET}\n" \
        "$passed" "$total" $(( max_label_len + dot_width + 2 - 18 )) "" "$elapsed" "$(( RANDOM % 10 ))"

    printf "\033[?25h"
    echo ""
}

# =============================================================================
# CELEBRATION PARTICLES
# =============================================================================

# Starburst particle effect radiating from center
# Usage: celebration [duration_seconds]
celebration() {
    local duration="${1:-0.8}"
    local banner_text="${2:-}"

    if [[ "$_STYLE_HAS_COLOR" != true ]] || [[ ! -t 1 ]]; then
        [[ -n "$banner_text" ]] && banner "$banner_text"
        return
    fi

    local width=50
    local height=7
    local cx=$(( width / 2 ))
    local cy=$(( height / 2 ))
    local particles="✦ ✧ ✵ · ⋆ ✫ +"
    local -a particle_arr
    IFS=' ' read -ra particle_arr <<< "$particles"
    local num_particles=24

    # Generate particles with random angles
    local -a px=() py=() pvx=() pvy=()
    for (( p=0; p<num_particles; p++ )); do
        px+=("$((cx * 10))")
        py+=("$((cy * 10))")
        # Random velocity in 8+ directions
        local angle=$(( RANDOM % 628 ))  # 0 to 2*pi*100
        # Approximate sin/cos with lookup
        local speed=$(( RANDOM % 15 + 8 ))
        case $(( angle / 79 )) in
            0) pvx+=("$speed"); pvy+=("0") ;;
            1) pvx+=("$((speed * 7 / 10))"); pvy+=("$((speed * 7 / 10))") ;;
            2) pvx+=("0"); pvy+=("$speed") ;;
            3) pvx+=("$((-speed * 7 / 10))"); pvy+=("$((speed * 7 / 10))") ;;
            4) pvx+=("$((-speed))"); pvy+=("0") ;;
            5) pvx+=("$((-speed * 7 / 10))"); pvy+=("$((-speed * 7 / 10))") ;;
            6) pvx+=("0"); pvy+=("$((-speed))") ;;
            *) pvx+=("$((speed * 7 / 10))"); pvy+=("$((-speed * 7 / 10))") ;;
        esac
    done

    printf "\033[?25l"

    # Reserve space
    local total_lines=$((height + 2))
    for (( i=0; i<total_lines; i++ )); do echo ""; done

    local frames=$(( ${duration%.*} * 20 + 10 ))
    local frame=0

    while (( frame < frames )); do
        printf "\033[%dA" "$total_lines"

        # Build frame buffer (simple approach: render line by line)
        local -A field
        for (( row=0; row<height; row++ )); do
            for (( col=0; col<width; col++ )); do
                field["$row,$col"]=" "
            done
        done

        # Banner text in center
        if [[ -n "$banner_text" ]]; then
            local bstart=$(( cx - ${#banner_text} / 2 ))
            for (( c=0; c<${#banner_text}; c++ )); do
                local bc=$(( bstart + c ))
                (( bc >= 0 && bc < width )) && field["$cy,$bc"]="${banner_text:c:1}"
            done
        fi

        # Update and place particles
        for (( p=0; p<num_particles; p++ )); do
            (( px[p] += pvx[p] ))
            (( py[p] += pvy[p] ))
            local pcol=$(( px[p] / 10 ))
            local prow=$(( py[p] / 10 ))

            if (( prow >= 0 && prow < height && pcol >= 0 && pcol < width )); then
                # Distance from center for fade
                local dist=$(( (pcol - cx) * (pcol - cx) + (prow - cy) * (prow - cy) ))
                local pidx=$(( p % ${#particle_arr[@]} ))
                field["$prow,$pcol"]="${particle_arr[$pidx]}|$dist|$frame"
            fi
        done

        # Render
        for (( row=0; row<height; row++ )); do
            printf "  "
            for (( col=0; col<width; col++ )); do
                local cell="${field["$row,$col"]}"
                if [[ "$cell" == *"|"* ]]; then
                    local pchar="${cell%%|*}"
                    local rest="${cell#*|}"
                    local pdist="${rest%%|*}"
                    # Fade brightness with distance and time
                    local brightness=$(( 255 - pdist * 3 - frame * 4 ))
                    (( brightness < 40 )) && brightness=40
                    (( brightness > 255 )) && brightness=255
                    # Gradient from purple to pink based on distance
                    local pr=$(( 175 + pdist * 2 ))
                    (( pr > 255 )) && pr=255
                    local pg=$(( 135 ))
                    local pb=$(( 255 - pdist ))
                    (( pb < 135 )) && pb=135
                    # Apply brightness fade
                    pr=$(( pr * brightness / 255 ))
                    pg=$(( pg * brightness / 255 ))
                    pb=$(( pb * brightness / 255 ))
                    if [[ "$_STYLE_HAS_TRUECOLOR" == true ]]; then
                        printf "\033[38;2;%d;%d;%dm%s\033[0m" "$pr" "$pg" "$pb" "$pchar"
                    else
                        printf "${_C_BRAND}%s${_C_RESET}" "$pchar"
                    fi
                elif [[ "$cell" != " " && -n "$banner_text" ]]; then
                    printf "${_C_SUCCESS}${_C_BOLD}%s${_C_RESET}" "$cell"
                else
                    printf " "
                fi
            done
            echo ""
        done

        (( frame++ ))
        sleep 0.05
    done

    printf "\033[?25h"
}

# =============================================================================
# ARCHITECTURE FLOW DIAGRAM
# =============================================================================

# Animated flow diagram showing agentpong data flow
# Usage: flow_diagram [claude_code_active] [opencode_active] [sandbox_active]
flow_diagram() {
    local cc_active="${1:-true}"
    local oc_active="${2:-false}"
    local sb_active="${3:-false}"

    if [[ "$_STYLE_HAS_COLOR" != true ]] || [[ ! -t 1 ]]; then
        return
    fi

    echo ""
    local dim="${_C_MUTED}"
    local lit="${_C_SUCCESS}"
    local brand="${_C_BRAND}"

    # Colors for each node based on active state
    local cc_color="$dim"
    [[ "$cc_active" == true ]] && cc_color="$lit"
    local notify_color="$dim"
    [[ "$cc_active" == true || "$oc_active" == true || "$sb_active" == true ]] && notify_color="$lit"
    local desktop_color="$dim"
    [[ "$cc_active" == true || "$oc_active" == true || "$sb_active" == true ]] && desktop_color="$lit"

    # Line 1: main flow
    printf "  ${cc_color}╭─────────────╮${_C_RESET}"
    printf "  ${dim}hook${_C_RESET}  "
    printf "${notify_color}╭────────────╮${_C_RESET}"
    printf "  ${dim}notify${_C_RESET}  "
    printf "${desktop_color}╭──────────╮${_C_RESET}\n"

    printf "  ${cc_color}│ Claude Code │${_C_RESET}"
    printf "${dim}──────▶${_C_RESET}"
    printf "${notify_color}│ notify.sh  │${_C_RESET}"
    printf "${dim}────────▶${_C_RESET}"
    printf "${desktop_color}│ Desktop  │${_C_RESET}\n"

    printf "  ${cc_color}╰─────────────╯${_C_RESET}"
    printf "        "
    printf "${notify_color}╰────────────╯${_C_RESET}"
    printf "          "
    printf "${desktop_color}╰──────────╯${_C_RESET}\n"

    # OpenCode line (if active)
    if [[ "$oc_active" == true ]]; then
        local oc_color="$lit"
        printf "  ${oc_color}╭─────────────╮${_C_RESET}"
        printf "${dim}──plugin──▶    ${dim}│${_C_RESET}\n"
        printf "  ${oc_color}│  OpenCode   │${_C_RESET}"
        printf "              ${dim}│${_C_RESET}\n"
        printf "  ${oc_color}╰─────────────╯${_C_RESET}\n"
    fi

    echo ""
}
