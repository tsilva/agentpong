#!/bin/bash
#
# agentpong - Remote Installation Script
# Downloads and installs agentpong from GitHub
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/tsilva/agentpong/main/install-remote.sh | bash
#   
#   Or with explicit options:
#   curl -fsSL ... | bash -s -- --branch develop
#

set -e

AGENTPONG_VERSION="1.0.0"
REPO_URL="https://github.com/tsilva/agentpong"
TEMP_DIR=""
FORCE_INSTALL=false
BRANCH="main"

# Parse arguments (when not running via curl)
while [[ $# -gt 0 ]]; do
    case $1 in
        --force|-f)
            FORCE_INSTALL=true
            shift
            ;;
        --branch|-b)
            BRANCH="$2"
            shift 2
            ;;
        --version|-v)
            echo "agentpong installer v$AGENTPONG_VERSION"
            exit 0
            ;;
        --help|-h)
            cat << 'EOF'
agentpong Remote Installer

Usage:
    curl -fsSL https://raw.githubusercontent.com/tsilva/agentpong/main/install-remote.sh | bash

Options:
    --force, -f      Force reinstallation even if already installed
    --branch, -b     Install from specific branch (default: main)
    --version, -v    Show installer version
    --help, -h       Show this help message

Alternative (download first, inspect, then run):
    curl -fsSL -o install-agentpong.sh https://raw.githubusercontent.com/tsilva/agentpong/main/install-remote.sh
    # Inspect the script...
    bash install-agentpong.sh

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

# Color codes for output
_C_BOLD='\033[1m'
_C_RESET='\033[0m'
_C_BRAND='\033[38;5;141m'
_C_SUCCESS='\033[38;5;114m'
_C_ERROR='\033[38;5;203m'
_C_MUTED='\033[38;5;244m'

header() {
    echo ""
    echo -e "${_C_BOLD}${_C_BRAND}    ___    _       _       ___   ___   _   _  __      ${_C_RESET}"
    echo -e "${_C_BOLD}${_C_BRAND}   / _ \  / \     | |     / _ \ / _ \ | \ | |/ /      ${_C_RESET}"
    echo -e "${_C_BOLD}${_C_BRAND}  / /_\/ / _ \    | |    / /_\\// /_\\/|  \| / /_      ${_C_RESET}"
    echo -e "${_C_BOLD}${_C_BRAND} / /_\\\/ ___ \   | |___/ /_\\\/ /_\\ \| |\  / /_\\     ${_C_RESET}"
    echo -e "${_C_BOLD}${_C_BRAND} \____/\/   \_/   |_____\____/\____/ |_| \_/____/     ${_C_RESET}"
    echo -e "${_C_MUTED}                                                      ${_C_RESET}"
    echo -e "${_C_BOLD}${_C_BRAND}  macOS notifications for Claude Code & OpenCode   ${_C_RESET}"
    echo ""
}

cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

# Check for macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${_C_ERROR}✗ This tool only works on macOS.${_C_RESET}"
    exit 1
fi

header

echo -e "${_C_MUTED}→ Downloading agentpong from GitHub...${_C_RESET}"

# Create temp directory
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/agentpong.XXXXXX")

# Download repository as tarball
echo -e "${_C_MUTED}  Fetching $BRANCH branch...${_C_RESET}"
if ! curl -fsSL "${REPO_URL}/archive/refs/heads/${BRANCH}.tar.gz" -o "$TEMP_DIR/agentpong.tar.gz"; then
    echo -e "${_C_ERROR}✗ Failed to download agentpong from GitHub${_C_RESET}"
    echo -e "${_C_MUTED}  Please check your internet connection and try again.${_C_RESET}"
    exit 1
fi

# Extract
echo -e "${_C_MUTED}  Extracting...${_C_RESET}"
tar -xzf "$TEMP_DIR/agentpong.tar.gz" -C "$TEMP_DIR"

# Find extracted directory
EXTRACTED_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "agentpong-*" | head -1)

if [[ -z "$EXTRACTED_DIR" ]]; then
    echo -e "${_C_ERROR}✗ Failed to extract agentpong${_C_RESET}"
    exit 1
fi

echo -e "${_C_SUCCESS}✓ Download complete${_C_RESET}"
echo ""

# Check if already installed
if [[ -d "$HOME/.claude/notify.sh" ]] || [[ -f "$HOME/.claude/settings.json" ]]; then
    if [[ "$FORCE_INSTALL" == "true" ]]; then
        echo -e "${_C_MUTED}→ Force reinstall requested${_C_RESET}"
    else
        echo -e "${_C_MUTED}→ agentpong appears to be already installed${_C_RESET}"
        echo -e "${_C_MUTED}  Run with --force to reinstall, or run ~/.claude/uninstall.sh first${_C_RESET}"
        echo ""
        
        # Check if running via curl (no TTY)
        if [[ ! -t 0 ]]; then
            echo -e "${_C_ERROR}✗ Cannot prompt for confirmation when running via curl${_C_RESET}"
            echo -e "${_C_MUTED}  To reinstall, run:${_C_RESET}"
            echo -e "${_C_MUTED}    curl -fsSL ${REPO_URL}/raw/main/install-remote.sh | bash -s -- --force${_C_RESET}"
            exit 0
        fi
        
        read -p "Continue with installation? [y/N] " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${_C_MUTED}Installation cancelled.${_C_RESET}"
            exit 0
        fi
    fi
fi

# Run the local install script
echo ""
echo -e "${_C_MUTED}→ Running installer...${_C_RESET}"
echo ""

cd "$EXTRACTED_DIR"
if [[ "$FORCE_INSTALL" == "true" ]]; then
    ./install.sh --force
else
    ./install.sh
fi

INSTALL_EXIT=$?

if [[ $INSTALL_EXIT -eq 0 ]]; then
    echo ""
    echo -e "${_C_SUCCESS}✓ agentpong v${AGENTPONG_VERSION} installed successfully!${_C_RESET}"
    echo ""
    echo -e "${_C_MUTED}To uninstall later, run:${_C_RESET}"
    echo -e "${_C_MUTED}  curl -fsSL ${REPO_URL}/raw/main/uninstall.sh | bash${_C_RESET}"
    echo ""
else
    echo ""
    echo -e "${_C_ERROR}✗ Installation failed (exit code: $INSTALL_EXIT)${_C_RESET}"
    exit $INSTALL_EXIT
fi
