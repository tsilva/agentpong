# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Code Notify is a macOS notification system that alerts users when Claude Code is ready for input. It uses Hammerspoon to send desktop notifications and focus the correct IDE window when clicked - even across multiple macOS Spaces.

## Architecture

Four files form the complete system:

- **claude-notify.lua** - Hammerspoon module that handles notifications and window focusing. Uses `hs.window.filter` to find windows across all Spaces and `hs.window:focus()` to switch Space and focus.
- **notify.sh** - Shell script called by Claude Code hooks. Invokes Hammerspoon via `hs -c "claudeNotify(...)"`. Falls back to terminal-notifier if Hammerspoon isn't available.
- **install.sh** - Installs Hammerspoon (if needed), copies `claude-notify.lua` to `~/.hammerspoon/`, configures `init.lua`, copies `notify.sh` to `~/.claude/`, and configures the `Stop` hook.
- **uninstall.sh** - Removes the notification script, Hammerspoon module, and cleans up configurations.

## Key Implementation Details

The system uses Hammerspoon because AppleScript's `AXRaise` and URL schemes (`cursor://`, `vscode://`) cannot switch between macOS Spaces. Hammerspoon's `hs.window:focus()` properly navigates to the window's Space and focuses it.

Flow:
1. Claude Code `Stop` hook fires when Claude finishes a task
2. `notify.sh` is executed with workspace name from `CLAUDE_PROJECT_DIR`
3. Script calls `hs -c "claudeNotify('workspace', 'message')"`
4. Hammerspoon shows notification with click callback
5. On click, `hs.window.filter` finds the window matching the workspace name
6. `hs.window:focus()` switches to the correct Space and focuses the window

Claude Code hooks only work in IDE-integrated terminals (via SSE connection). For standalone terminals like iTerm2, users must configure iTerm's Triggers feature as a workaround.

## Testing

Test the notification manually:
```bash
./notify.sh "Test message"
```

Test Hammerspoon directly:
```bash
hs -c "claudeNotify('test-workspace', 'Test message')"
```

Test cross-Space focusing:
1. Open Cursor with a project
2. Switch to a different Space
3. Run the notification test
4. Click the notification
5. Verify it switches back to the correct Space and window

Test installation/uninstallation by checking:
- `~/.claude/notify.sh` exists and is executable
- `~/.claude/settings.json` contains the `Stop` hook
- `~/.hammerspoon/claude-notify.lua` exists
- `~/.hammerspoon/init.lua` contains `require("claude-notify")`
- `hs -c "print('ok')"` works
