# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

claudepong is a macOS notification system that alerts users when Claude Code is ready for input. Claude pings, you pong back. It uses AeroSpace and terminal-notifier to send desktop notifications and focus the correct IDE window when clicked - even across multiple workspaces.

## Architecture

Four files form the complete system:

- **notify.sh** - Shell script called by Claude Code hooks. Uses terminal-notifier with `-execute` to trigger focus-window.sh on click when AeroSpace is available.
- **focus-window.sh** - AeroSpace window focusing script executed when notification is clicked. Uses `aerospace list-windows` to find the correct window and `aerospace focus` to switch workspace and focus.
- **install.sh** - Installs AeroSpace and terminal-notifier (if needed), copies scripts to `~/.claude/`, and configures the `Stop` and `PermissionRequest` hooks.
- **uninstall.sh** - Removes the notification scripts and cleans up configurations.

## Key Implementation Details

The system uses AeroSpace because:
- macOS Sequoia 15.x broke Hammerspoon's `hs.spaces.gotoSpace()` API
- AppleScript's `AXRaise` and URL schemes (`cursor://`, `vscode://`) cannot switch between macOS Spaces
- AeroSpace uses its own virtual workspace abstraction that works reliably on Sequoia without requiring SIP to be disabled

Flow:
1. Claude Code `Stop` hook fires when Claude finishes a task, or `PermissionRequest` hook fires when Claude needs permission
2. `notify.sh` is executed with workspace name from `CLAUDE_PROJECT_DIR`
3. Script calls terminal-notifier with `-execute` pointing to focus-window.sh
4. Notification appears with workspace name in title
5. On click, focus-window.sh executes:
   - `aerospace list-windows` finds the Cursor/Code window matching the workspace
   - `aerospace workspace <name>` switches to the correct workspace
   - `aerospace focus --window-id <id>` focuses the window

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

Test installation/uninstallation by checking:
- `~/.claude/notify.sh` exists and is executable
- `~/.claude/focus-window.sh` exists and is executable
- `~/.claude/settings.json` contains the `Stop` and `PermissionRequest` hooks
- `aerospace list-windows` works
