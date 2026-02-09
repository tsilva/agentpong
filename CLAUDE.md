# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

claudepong is a macOS notification system that alerts users when Claude Code is ready for input. Claude pings, you pong back. It uses AeroSpace and terminal-notifier to send desktop notifications and focus the correct IDE window when clicked - even across multiple workspaces.

## Architecture

Five files form the complete system:

- **notify.sh** - Shell script called by Claude Code hooks. Uses terminal-notifier to send notifications. Conditionally includes `-execute` with focus-window.sh if available.
- **focus-window.sh** - AeroSpace window focusing script bundled with claudepong. Locates the aerospace binary, finds the correct IDE window, and focuses it. Falls back to AppleScript if AeroSpace is unavailable.
- **install.sh** - Installs terminal-notifier (if needed), copies scripts to `~/.claude/`, detects AeroSpace (optional), and configures the `Stop` and `PermissionRequest` hooks.
- **uninstall.sh** - Removes the notification scripts and cleans up configurations. Leaves focus-window.sh alone if it's a symlink from aerospace-setup.

## Key Implementation Details

The system uses AeroSpace because:
- macOS Sequoia 15.x broke Hammerspoon's `hs.spaces.gotoSpace()` API
- AppleScript's `AXRaise` and URL schemes (`cursor://`, `vscode://`) cannot switch between macOS Spaces
- AeroSpace uses its own virtual workspace abstraction that works reliably on Sequoia without requiring SIP to be disabled

Flow:
1. Claude Code `Stop` hook fires when Claude finishes a task, or `PermissionRequest` hook fires when Claude needs permission
2. `notify.sh` is executed with workspace name from `CLAUDE_PROJECT_DIR`
3. Script calls terminal-notifier — if `~/.claude/focus-window.sh` exists and is executable, `-execute` is included to trigger it on click; otherwise the notification just dismisses on click
4. Notification appears with workspace name in title
5. On click (with focus-window.sh), focus-window.sh executes:
   - Locates aerospace binary at `/opt/homebrew/bin/aerospace` or `/usr/local/bin/aerospace`
   - `aerospace list-windows` finds the Cursor/Code window matching the workspace
   - `aerospace workspace <name>` switches to the correct workspace
   - `aerospace focus --window-id <id>` focuses the window
   - Falls back to AppleScript `tell application "Cursor" to activate` if AeroSpace is unavailable

Claude Code hooks only work in IDE-integrated terminals (via SSE connection). For standalone terminals like iTerm2, users must configure iTerm's Triggers feature as a workaround.

## Testing

Test the notification manually:
```bash
./notify.sh "Test message"
```

Test AeroSpace window finding:
```bash
aerospace list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' | grep Cursor
```

Test focus script directly:
```bash
./focus-window.sh "project-name"
```

Test cross-workspace focusing:
1. Open Cursor with a project
2. Switch to a different AeroSpace workspace
3. Run the notification test
4. Click the notification
5. Verify it switches back to the correct workspace and window

Test graceful degradation (without AeroSpace):
1. Temporarily rename/remove aerospace binary
2. Run `./notify.sh "Test"` — notification should appear, no crash
3. Click the notification — should dismiss without focusing a window
4. Restore aerospace binary

Test installation/uninstallation by checking:
- `~/.claude/notify.sh` exists and is executable
- `~/.claude/focus-window.sh` exists and is executable
- `~/.claude/settings.json` contains the `Stop` and `PermissionRequest` hooks
- `aerospace list-windows` works (if AeroSpace installed)
