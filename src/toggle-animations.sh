#!/bin/bash

# macOS Animation Toggle Script
# Disables/enables animations that affect tiling window manager responsiveness
# Usage: ./toggle-animations.sh [on|off]

if [ "$1" = "off" ]; then
    echo "Disabling macOS animations..."

    # Window opening/closing animations
    defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false

    # Mission Control / workspace transition speed
    defaults write com.apple.dock expose-animation-duration -float 0

    # Dock auto-hide delay and animation
    defaults write com.apple.dock autohide-delay -float 0
    defaults write com.apple.dock autohide-time-modifier -float 0

    # Window resize animation
    defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

    # Reduce Motion (disables minimize/unminimize animations)
    # com.apple.Accessibility is SIP-protected; requires Full Disk Access for Terminal
    if defaults write com.apple.Accessibility ReduceMotionEnabled -bool true 2>/dev/null; then
        true
    else
        echo "Could not set Reduce Motion (com.apple.Accessibility is protected)."
        echo "  To fix: System Settings > Privacy & Security > Full Disk Access > enable Terminal"
        echo "  Or manually: System Settings > Accessibility > Display > enable Reduce Motion"
    fi

    # Use scale effect instead of genie for faster minimize
    defaults write com.apple.dock mineffect -string scale

    # Scroll animations
    defaults write NSGlobalDomain NSScrollAnimationEnabled -bool false

    # Quick Look panel animation
    defaults write NSGlobalDomain QLPanelAnimationDuration -float 0

    # Document revision animation
    defaults write NSGlobalDomain NSDocumentRevisionsWindowTransformAnimation -bool false

    # Toolbar fullscreen animation
    defaults write NSGlobalDomain NSToolbarFullScreenAnimationDuration -float 0

    # Finder column browser animation
    defaults write NSGlobalDomain NSBrowserColumnAnimationSpeedMultiplier -float 0

    # Launchpad animations
    defaults write com.apple.dock springboard-show-duration -float 0
    defaults write com.apple.dock springboard-hide-duration -float 0
    defaults write com.apple.dock springboard-page-duration -float 0

    # Finder animations
    defaults write com.apple.finder DisableAllAnimations -bool true

    # Mail animations
    defaults write com.apple.Mail DisableSendAnimations -bool true
    defaults write com.apple.Mail DisableReplyAnimations -bool true

    # Rubber-band scrolling
    defaults write NSGlobalDomain NSScrollViewRubberbanding -bool false

    killall Dock 2>/dev/null || true
    killall Finder 2>/dev/null || true

    echo "Animations disabled. Log out and back in for full effect."

elif [ "$1" = "on" ]; then
    echo "Re-enabling macOS animations..."

    defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool true
    defaults write com.apple.dock expose-animation-duration -float 0.1
    defaults delete com.apple.dock autohide-delay 2>/dev/null || true
    defaults delete com.apple.dock autohide-time-modifier 2>/dev/null || true
    defaults delete NSGlobalDomain NSWindowResizeTime 2>/dev/null || true

    # Reduce Motion
    if defaults write com.apple.Accessibility ReduceMotionEnabled -bool false 2>/dev/null; then
        true
    else
        echo "Could not restore Reduce Motion (com.apple.Accessibility is protected)."
        echo "  To fix: System Settings > Privacy & Security > Full Disk Access > enable Terminal"
        echo "  Or manually: System Settings > Accessibility > Display > disable Reduce Motion"
    fi

    # Minimize effect
    defaults write com.apple.dock mineffect -string genie

    # Scroll animations
    defaults write NSGlobalDomain NSScrollAnimationEnabled -bool true

    # Quick Look panel animation
    defaults delete NSGlobalDomain QLPanelAnimationDuration 2>/dev/null || true

    # Document revision animation
    defaults delete NSGlobalDomain NSDocumentRevisionsWindowTransformAnimation 2>/dev/null || true

    # Toolbar fullscreen animation
    defaults delete NSGlobalDomain NSToolbarFullScreenAnimationDuration 2>/dev/null || true

    # Finder column browser animation
    defaults delete NSGlobalDomain NSBrowserColumnAnimationSpeedMultiplier 2>/dev/null || true

    # Launchpad animations
    defaults delete com.apple.dock springboard-show-duration 2>/dev/null || true
    defaults delete com.apple.dock springboard-hide-duration 2>/dev/null || true
    defaults delete com.apple.dock springboard-page-duration 2>/dev/null || true

    # Finder animations
    defaults delete com.apple.finder DisableAllAnimations 2>/dev/null || true

    # Mail animations
    defaults delete com.apple.Mail DisableSendAnimations 2>/dev/null || true
    defaults delete com.apple.Mail DisableReplyAnimations 2>/dev/null || true

    # Rubber-band scrolling
    defaults delete NSGlobalDomain NSScrollViewRubberbanding 2>/dev/null || true

    killall Dock 2>/dev/null || true
    killall Finder 2>/dev/null || true

    echo "Animations re-enabled. Log out and back in for full effect."

else
    echo "Usage: $0 [on|off]"
    echo "  off  - Disable all animations (snappy mode)"
    echo "  on   - Re-enable default animations"
    exit 1
fi
