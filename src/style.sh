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
    local duration="${2:-2}"
    
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

# Section divider with progress indicator
section() {
    local text="${1:-}"
    local phase="${2:-}"
    local total="${3:-}"
    
    local prefix=""
    if [[ -n "$phase" && -n "$total" ]]; then
        prefix="━━ Phase ${phase}/${total}: ${text} "
    else
        prefix="━━ ${text} "
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
    local duration="${1:-3}"
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
    local duration="${1:-2}"
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
