<div align="center">
  <img src="logo.png" alt="claude-code-notify" width="280"/>

  [![GitHub stars](https://img.shields.io/github/stars/tsilva/claude-code-notify?style=flat&logo=github)](https://github.com/tsilva/claude-code-notify)
  [![macOS](https://img.shields.io/badge/macOS-Sequoia%2015.x-blue?logo=apple)](https://www.apple.com/macos/sequoia/)
  [![License](https://img.shields.io/github/license/tsilva/claude-code-notify)](LICENSE)
  [![AeroSpace](https://img.shields.io/badge/AeroSpace-Tiling%20WM-8B5CF6?logo=apple)](https://github.com/nikitabobko/AeroSpace)

  **Never miss when Claude Code needs your attention — get desktop notifications that focus the right window, even across workspaces**

  [Installation](#installation) · [Usage](#usage) · [How It Works](#how-it-works) · [Troubleshooting](#troubleshooting)
</div>

## Overview

claude-code-notify sends macOS desktop notifications when Claude Code finishes a task or requests permission. Click the notification to instantly switch to the correct IDE window — even if it's on a different workspace.

Built for developers who run Claude Code in the background while multitasking. Stop constantly checking if Claude is done.

## Features

- **Smart notifications** — Alerts when Claude finishes tasks ("Ready for input") or needs permission ("Permission required")
- **Cross-workspace window focus** — Click notification to jump directly to the right Cursor/VS Code window via AeroSpace
- **Works on Sequoia** — Uses AeroSpace instead of broken AppleScript/Hammerspoon APIs
- **Zero config** — Install script handles everything automatically

## Requirements

- **macOS** (Sequoia 15.x supported)
- **Homebrew** for installing dependencies
- **Cursor** or **VS Code** with Claude Code extension
- **AeroSpace** (optional but recommended for window focusing)

## Installation

```bash
git clone https://github.com/tsilva/claude-code-notify.git
cd claude-code-notify
./install.sh
```

The installer will:
1. Install `terminal-notifier` and optionally `AeroSpace` via Homebrew
2. Copy notification scripts to `~/.claude/`
3. Configure Claude Code hooks in `~/.claude/settings.json`

### Post-install

If you installed AeroSpace:
1. Start AeroSpace (launches automatically after install)
2. Grant Accessibility permissions when prompted
3. Restart your terminal/IDE

## Usage

### Cursor / VS Code

Notifications work automatically after installation. Start a new Claude Code session and you'll receive notifications when:
- Claude finishes a task and is ready for input
- Claude needs permission to proceed

Click the notification to focus the IDE window.

### iTerm2

Claude Code hooks don't fire in standalone terminals. Set up iTerm Triggers instead:

1. Open **iTerm → Settings → Profiles → Advanced → Triggers → Edit**
2. Add a new trigger:
   - **Regex:** `^[[:space:]]*>`
   - **Action:** Run Command...
   - **Parameters:** `~/.claude/notify.sh "Ready for input"`
   - **Instant:** ✓ (checked)

## How It Works

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Claude Code    │────▶│    notify.sh     │────▶│ terminal-notifier│
│  Stop Hook      │     │                  │     │                 │
└─────────────────┘     └──────────────────┘     └────────┬────────┘
                                                          │
                                                          ▼ click
                        ┌──────────────────┐     ┌─────────────────┐
                        │   AeroSpace      │◀────│ focus-window.sh │
                        │  (focus window)  │     │                 │
                        └──────────────────┘     └─────────────────┘
```

1. Claude Code's `Stop` or `PermissionRequest` hook triggers `notify.sh`
2. `notify.sh` sends a notification via `terminal-notifier`
3. Clicking the notification executes `focus-window.sh`
4. `focus-window.sh` uses AeroSpace to find and focus the correct IDE window

### Why AeroSpace?

macOS Sequoia 15.x broke traditional window management APIs:
- Hammerspoon's `hs.spaces.gotoSpace()` no longer works
- AppleScript's `AXRaise` can't switch between Spaces
- URL schemes (`cursor://`, `vscode://`) don't switch workspaces

AeroSpace uses its own virtual workspace abstraction that works reliably without disabling SIP.

## Uninstallation

```bash
./uninstall.sh
```

This removes the notification scripts and hooks. AeroSpace and terminal-notifier are kept (you may have other uses for them).

To fully remove dependencies:
```bash
brew uninstall --cask nikitabobko/tap/aerospace
brew uninstall terminal-notifier
```

## Troubleshooting

### Notifications don't appear

1. Check that `terminal-notifier` is installed: `which terminal-notifier`
2. Verify the hook is configured: `cat ~/.claude/settings.json | grep Stop`
3. Test manually: `~/.claude/notify.sh "Test"`

### Window doesn't focus on click

1. Verify AeroSpace is running: `pgrep -x AeroSpace`
2. Check Accessibility permissions: **System Settings → Privacy & Security → Accessibility**
3. Test window listing: `aerospace list-windows --all | grep Cursor`

### Notifications work but hooks don't fire

Claude Code hooks only work in IDE-integrated terminals (Cursor/VS Code). For standalone terminals like iTerm2, use the Triggers workaround described above.

## Contributing

Contributions welcome! Feel free to open issues or submit pull requests.

## License

[MIT](LICENSE)
