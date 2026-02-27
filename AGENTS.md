# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

agentpong is a macOS notification system that alerts users when Claude Code or OpenCode is ready for input. Claude pings, you pong back. It uses AeroSpace and terminal-notifier to send desktop notifications and focus the correct IDE window when clicked - even across multiple workspaces.

## Supported Tools

- **Claude Code** - Full support with `Stop` and `PermissionRequest` hooks
- **OpenCode** - Full support via TypeScript plugin (`session.idle` and `permission.asked` events)
- **claude-sandbox** - Full support via TCP listener (port 19223)

## Directory Structure

```
agentpong/
├── install.sh              # Main installation script
├── uninstall.sh            # Uninstallation script
├── src/                    # Core shell scripts
│   ├── notify.sh          # Main notification script
│   ├── focus-window.sh    # AeroSpace window focusing
│   ├── style.sh           # Terminal styling library
│   ├── notify-handler.sh  # TCP listener for sandbox
│   └── notify-sandbox.sh  # Container notification script
├── plugins/               # IDE/editor plugins
│   └── opencode/
│       └── agentpong.ts   # OpenCode TypeScript plugin
├── config/                # Configuration templates
│   └── com.agentpong.sandbox.plist.template
├── assets/                # Images and media
│   └── logo.png
└── logs/                  # Runtime logs
```

## Core Components

- **src/notify.sh** - Shell script called by Claude Code hooks and the OpenCode plugin. Uses terminal-notifier to send notifications. Conditionally includes `-execute` with focus-window.sh if available.
- **src/focus-window.sh** - AeroSpace window focusing script bundled with agentpong. Locates the aerospace binary, finds the correct IDE window, and focuses it. Falls back to AppleScript if AeroSpace is unavailable.
- **plugins/opencode/agentpong.ts** - OpenCode plugin installed to `~/.config/opencode/plugins/agentpong.ts`. Hooks into `session.idle` (equivalent to Stop) and `permission.asked` (equivalent to PermissionRequest) events, calling `~/.opencode/notify.sh` with `OPENCODE_PROJECT_DIR` and `OPENCODE` env vars set.
- **install.sh** - Installs terminal-notifier (if needed), copies scripts to `~/.claude/`, detects AeroSpace (optional), configures the `Stop` and `PermissionRequest` hooks for Claude Code, and installs the OpenCode plugin to `~/.config/opencode/plugins/`.
- **uninstall.sh** - Removes the notification scripts and cleans up configurations. Removes the OpenCode plugin and cleans up any legacy broken hooks from settings.json files.

## Key Implementation Details

The system uses AeroSpace because:
- macOS Sequoia 15.x broke Hammerspoon's `hs.spaces.gotoSpace()` API
- AppleScript's `AXRaise` and URL schemes (`cursor://`, `vscode://`) cannot switch between macOS Spaces
- AeroSpace uses its own virtual workspace abstraction that works reliably on Sequoia without requiring SIP to be disabled

Flow:
1. Claude Code `Stop` hook fires when the AI finishes a task, or `PermissionRequest` hook fires when permission is needed. For OpenCode, the `session.idle` or `permission.asked` plugin event fires instead.
2. `notify.sh` is executed with workspace name from `CLAUDE_PROJECT_DIR` (Claude Code) or `OPENCODE_PROJECT_DIR` (OpenCode, set by the plugin)
3. Script calls terminal-notifier — if `focus-window.sh` exists and is executable, `-execute` is included to trigger it on click; otherwise the notification just dismisses on click
4. Notification appears with workspace name in title (prefixed with "Claude Code" or "OpenCode" based on which tool triggered it)
5. On click (with focus-window.sh), focus-window.sh executes:
   - Locates aerospace binary at `/opt/homebrew/bin/aerospace` or `/usr/local/bin/aerospace`
   - `aerospace list-windows` finds the Cursor/Code window matching the workspace
   - `aerospace workspace <name>` switches to the correct workspace
   - `aerospace focus --window-id <id>` focuses the window
   - Falls back to AppleScript `tell application "Cursor" to activate` if AeroSpace is unavailable

Note: Claude Code and OpenCode hooks only work in IDE-integrated terminals (via SSE connection). For standalone terminals like iTerm2, users must configure iTerm's Triggers feature as a workaround.

## Testing

Test the notification manually:
```bash
./src/notify.sh "Test message"
```

Test AeroSpace window finding:
```bash
aerospace list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' | grep Cursor
```

Test focus script directly:
```bash
./src/focus-window.sh "project-name"
```

Test cross-workspace focusing:
1. Open Cursor with a project
2. Switch to a different AeroSpace workspace
3. Run the notification test
4. Click the notification
5. Verify it switches back to the correct workspace and window

Test graceful degradation (without AeroSpace):
1. Temporarily rename/remove aerospace binary
2. Run `./src/notify.sh "Test"` — notification should appear, no crash
3. Click the notification — should dismiss without focusing a window
4. Restore aerospace binary

Test installation/uninstallation by checking:
- `~/.claude/notify.sh` exists and is executable
- `~/.claude/focus-window.sh` exists and is executable
- `~/.claude/settings.json` contains the `Stop` and `PermissionRequest` hooks
- `aerospace list-windows` works (if AeroSpace installed)

## Development Guidelines

- Keep `README.md` up to date with any significant project changes
