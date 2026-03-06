<div align="center">
  <img src="logo.png" alt="agentpong" width="512"/>

  # agentpong

  [![GitHub stars](https://img.shields.io/github/stars/tsilva/agentpong?style=flat&logo=github)](https://github.com/tsilva/agentpong)
  [![macOS](https://img.shields.io/badge/macOS-Sequoia%2015.x-blue?logo=apple)](https://www.apple.com/macos/sequoia/)
  [![AeroSpace](https://img.shields.io/badge/AeroSpace-required-8B5CF6?logo=apple)](https://github.com/nikitabobko/AeroSpace)
  [![License](https://img.shields.io/github/license/tsilva/agentpong)](LICENSE)

  **🏓 macOS developer workspace management + AI agent notifications, powered by AeroSpace 🔔**

  [Quick Start](#-quick-start) · [Features](#-features) · [Installation](#-installation) · [Usage](#-usage) · [How It Works](#-how-it-works) · [Troubleshooting](#-troubleshooting)
</div>

---

## 🚀 Quick Start

Install with one command:

```bash
curl -fsSL https://raw.githubusercontent.com/tsilva/agentpong/main/install.sh | bash
```

The installer will:
1. Install AeroSpace, terminal-notifier, and jq (if needed)
2. Deploy AeroSpace config with workspace keybindings
3. Install scripts for window organization and notification handling
4. Configure Claude Code hooks (`Stop` + `PermissionRequest`)
5. Optionally install Alfred workflow, OpenCode, and sandbox support

---

## Overview

**The Pain:** You juggle multiple Cursor windows across workspaces while AI agents work in the background. You keep switching tabs to check if they're done -- or worse, you miss a permission prompt and they sit idle for minutes.

**The Solution:** agentpong gives you an opinionated macOS workspace system built on AeroSpace. Your Cursor windows get organized into numbered workspaces by priority. When an AI agent finishes or needs permission, you get a desktop notification. One click (or `alt+n`) jumps you directly to the right window.

**The Result:** Zero tab-switching. Zero missed prompts. Organized workspaces. Stay in flow while your agents work.

<div align="center">

| ⚡ Setup | 🎯 Focus | 🖥️ Workspaces | 🤖 Tools |
|---------|----------|---------------|---------|
| 30 seconds | 1-click or alt+n | Cross-workspace | Claude Code · OpenCode · claude-sandbox |

</div>

## ✨ Features

- **🖥️ Workspace management** -- AeroSpace-powered numbered workspaces with `alt+1..9` switching
- **📋 Window organization** -- Press `alt+s` to sort Cursor windows by project priority
- **🔔 Smart notifications** -- Alerts when AI agents finish tasks or need permission
- **🎯 Cross-workspace focus** -- Click notification or press `alt+n` to jump to the right window
- **🔍 Project switcher** -- Alfred workflow (`alt+p`) to search and switch between projects
- **⚡ Performance tuning** -- Optional macOS animation disabling for snappier workspace switching
- **🤖 Multi-tool support** -- Claude Code, OpenCode, and claude-sandbox containers

## 📋 Requirements

- **macOS** (Sequoia 15.x supported)
- **Homebrew** for installing dependencies
- **Cursor** or **VS Code** with Claude Code or OpenCode

### Installed Automatically

- **[AeroSpace](https://github.com/nikitabobko/AeroSpace)** -- Tiling window manager for workspace management and cross-workspace focus (core requirement)
- **[terminal-notifier](https://github.com/julienXX/terminal-notifier)** -- macOS desktop notifications
- **[jq](https://jqlang.github.io/jq/)** -- JSON processor for settings configuration

### Optional

- **[Alfred](https://www.alfredapp.com/)** -- Project switcher workflow (detected automatically, never required)

## 🚀 Installation

### Quick Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/tsilva/agentpong/main/install.sh | bash
```

**Security-conscious?** Download first to inspect:
```bash
curl -fsSL -o install-agentpong.sh https://raw.githubusercontent.com/tsilva/agentpong/main/install.sh
# Review the script...
bash install-agentpong.sh
```

### Development / Manual Install

```bash
git clone https://github.com/tsilva/agentpong.git
cd agentpong
./install.sh
```

### Installer Flags

```
--dry-run          Preview all changes without applying them
--update           Only update changed files, skip all prompts
--force, -f        Force reinstall even if already up to date
--quiet, -q        Minimal output (for CI/automation)
--verbose, -v      Maximum output with debug logging
--wizard, -w       Interactive TUI configuration mode
--health-check     Run post-install verification only
--uninstall        Remove agentpong completely
```

### Reinstalling / Updating

Run the install command again. The installer is **idempotent** -- it skips unchanged files and only updates what's needed.

Force a complete reinstall:
```bash
curl -fsSL https://raw.githubusercontent.com/tsilva/agentpong/main/install.sh | bash -s -- --force
```

### Post-install

1. AeroSpace should start automatically (configured with `start-at-login = true`)
2. Grant Accessibility permissions when prompted
3. Edit `~/.config/aerospace/cursor-projects.txt` to set your project priority order
4. Press `alt+s` to organize your Cursor windows

## 💡 Usage

### Keybindings

| Shortcut | Action |
|----------|--------|
| `alt+1..9` | Switch to workspace 1-9 |
| `alt+shift+1..9` | Move window to workspace 1-9 |
| `alt+s` | Sort/organize Cursor windows by priority |
| `alt+n` | Focus next pending notification |
| `alt+p` | Open project switcher (Alfred) |
| `alt+f` | Toggle fullscreen |
| `alt+left/right` | Previous/next workspace |

### Project Priority

Edit `~/.config/aerospace/cursor-projects.txt` to control workspace assignment order:

```
my-main-project      # → workspace 2
side-project         # → workspace 3
experiments          # → workspace 4
# Unlisted projects get subsequent workspaces
```

Press `alt+s` to apply the ordering.

### Claude Code (Cursor / VS Code)

Notifications fire automatically after installation. Start a new Claude Code session and you'll receive alerts when:
- The agent finishes a task and is ready for input
- The agent needs permission to proceed

Click the notification to focus the IDE window.

### OpenCode

The OpenCode plugin hooks into `session.idle` and `permission.asked` events -- no extra configuration needed after install. Notifications appear with "OpenCode" prefix.

### Alfred Project Switcher

Press `alt+p` to open the project switcher. It shows:
- **Open projects** first, sorted by workspace number
- **Unopened repos** alphabetically, with option to open in Cursor

Set `AGENTPONG_REPOS_DIR` to customize the repo scan path (default: `~/repos`).

### iTerm2 (Standalone Terminal)

Claude Code hooks don't fire in standalone terminals. Set up iTerm Triggers instead:

1. Open **iTerm > Settings > Profiles > Advanced > Triggers > Edit**
2. Add a new trigger:
   - **Regex:** `^[[:space:]]*>`
   - **Action:** Run Command...
   - **Parameters:** `~/.claude/notify.sh "Ready for input"`
   - **Instant:** checked

## 🔧 How It Works

```
┌─────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  Claude Code    │────▶│    notify.sh     │────▶│ terminal-notifier│
│  Stop Hook      │     │                  │     │                  │
└─────────────────┘     └──────────────────┘     └────────┬─────────┘
                                                          │
┌─────────────────┐     ┌──────────────────┐             │ click
│  OpenCode       │────▶│  agentpong.ts    │             ▼
│  session.idle   │     │  (plugin)        │    ┌─────────────────┐
└─────────────────┘     └──────────────────┘    │ focus-window.sh │
                                                 └────────┬────────┘
                                                          │
                                                          ▼
                                                 ┌─────────────────┐
                                                 │    AeroSpace    │
                                                 │  (focus window) │
                                                 └─────────────────┘
```

### Notification Flow

1. Hook fires (`Stop`/`PermissionRequest` for Claude Code; `session.idle`/`permission.asked` for OpenCode)
2. `notify.sh` sends a notification via `terminal-notifier` with the project workspace name
3. Clicking the notification executes `focus-window.sh`
4. The focus script finds and focuses the correct IDE window via AeroSpace

### Workspace Management Flow

1. `aerospace.toml` defines keybindings and auto-assigns apps to workspaces
2. `alt+s` triggers `sort-workspaces.sh` which:
   - Unminimizes all Cursor windows
   - Reads priority order from `cursor-projects.txt`
   - Moves windows to numbered workspaces (starting at 2)
   - Unmatched windows get subsequent workspaces

### Why AeroSpace?

macOS Sequoia 15.x broke traditional window management APIs:

| Approach | Problem |
|----------|---------|
| Hammerspoon `hs.spaces.gotoSpace()` | No longer works on Sequoia |
| AppleScript `AXRaise` | Can't switch between Spaces |
| URL schemes (`cursor://`, `vscode://`) | Don't switch workspaces |
| **AeroSpace** | Works reliably without disabling SIP |

AeroSpace uses its own virtual workspace abstraction that bypasses these limitations.

## 🐳 claude-sandbox Integration

If you run Claude Code inside [claude-sandbox](https://github.com/tsilva/claude-sandbox), notifications can still reach your macOS desktop via TCP.

During installation, select "yes" when asked about sandbox support. This installs:
- A launchd service that listens on `localhost:19223`
- A container-compatible notify script that connects via `host.docker.internal`
- Hooks configured in `~/.claude-sandbox/claude-config/settings.json`

```
Container                              Host (macOS)
────────────────────────────────────────────────────────────
Agent hook fires
       │
       ▼
notify.sh connects via ─────────────►  launchd TCP listener
host.docker.internal:19223                    │
                                              ▼
                                       terminal-notifier
                                       + focus-window.sh
```

## 🗑️ Uninstallation

One-line uninstall:
```bash
curl -fsSL https://raw.githubusercontent.com/tsilva/agentpong/main/uninstall.sh | bash
```

Or if you have the repo cloned locally:
```bash
./uninstall.sh
```

This removes:
- Notification scripts and hooks
- AeroSpace scripts from `~/.config/aerospace/`
- `~/.aerospace.toml` (with prompt, since you may have customized it)
- Alfred workflow (if installed)
- Re-enables macOS animations
- OpenCode plugin and sandbox support (if installed)

AeroSpace itself is **not** removed. To uninstall it: `brew uninstall aerospace`

To fully remove other dependencies:
```bash
brew uninstall terminal-notifier
```

## 🔍 Troubleshooting

### Notifications don't appear

1. Check that `terminal-notifier` is installed: `which terminal-notifier`
2. Verify the hook is configured: `cat ~/.claude/settings.json | grep Stop`
3. Test manually: `~/.claude/notify.sh "Test"`

### Clicking notification doesn't focus the window

1. Check AeroSpace is installed: `which aerospace` or `ls /opt/homebrew/bin/aerospace`
2. Check AeroSpace is running: `pgrep -x AeroSpace`
3. Check Accessibility permissions: **System Settings > Privacy & Security > Accessibility**
4. Test window listing: `aerospace list-windows --all | grep Cursor`
5. Test focus script: `~/.claude/focus-window.sh "your-project-name"`

### alt+s doesn't organize windows

1. Check `~/.config/aerospace/cursor-projects.txt` exists and has entries
2. Check scripts are installed: `ls ~/.config/aerospace/sort-workspaces.sh`
3. Check AeroSpace config is loaded: `aerospace reload-config`

### Hooks don't fire

Claude Code and OpenCode hooks only work in IDE-integrated terminals (Cursor/VS Code). For standalone terminals like iTerm2, use the Triggers workaround described in [Usage](#-usage).

### Run health check

```bash
./install.sh --health-check
```

## 🤝 Contributing

Contributions welcome! Feel free to [open an issue](https://github.com/tsilva/agentpong/issues) or submit a pull request.

## 📄 License

[MIT](LICENSE)

---

<div align="center">

Found this useful? [⭐ Star the repo](https://github.com/tsilva/agentpong) to help others discover it!

</div>
