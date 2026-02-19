<div align="center">
  <img src="logo.png" alt="agentpong" width="512"/>

  # agentpong

  [![GitHub stars](https://img.shields.io/github/stars/tsilva/agentpong?style=flat&logo=github)](https://github.com/tsilva/agentpong)
  [![macOS](https://img.shields.io/badge/macOS-Sequoia%2015.x-blue?logo=apple)](https://www.apple.com/macos/sequoia/)
  [![License](https://img.shields.io/github/license/tsilva/agentpong)](LICENSE)
  [![AeroSpace](https://img.shields.io/badge/AeroSpace-Tiling%20WM-8B5CF6?logo=apple)](https://github.com/nikitabobko/AeroSpace)

  **🏓 Claude pings, you pong back — desktop notifications that focus the right window, even across workspaces 🔔**

  [Installation](#-installation) · [Usage](#-usage) · [How It Works](#-how-it-works) · [Troubleshooting](#-troubleshooting)
</div>

---

## Overview

**The Pain:** You're running Claude Code in the background while working on something else. You keep switching tabs to check if it's done. Or worse — you miss when it needs permission and it sits idle for minutes.

**The Solution:** agentpong sends macOS desktop notifications the instant Claude finishes a task or needs permission. One click jumps you directly to the right IDE window — even if it's buried in another workspace.

**The Result:** Zero tab-switching. Zero missed prompts. Stay in flow while Claude works.

<div align="center">

| ⚡ Setup | 🎯 Focus | 🖥️ Workspaces |
|---------|----------|---------------|
| 30 seconds | 1-click | Cross-workspace |

</div>

## ✨ Features

- **🔔 Smart notifications** — Alerts when Claude finishes tasks ("Ready for input") or needs permission ("Permission required")
- **🎯 Cross-workspace window focus** — Click notification to jump directly to the right Cursor/VS Code window via AeroSpace
- **🍎 Works on Sequoia** — Uses AeroSpace instead of broken AppleScript/Hammerspoon APIs
- **⚙️ Zero config** — Install script handles everything automatically

## 📋 Requirements

- **macOS** (Sequoia 15.x supported)
- **Homebrew** for installing dependencies
- **Cursor** or **VS Code** with Claude Code extension

### Optional

- **[AeroSpace](https://github.com/nikitabobko/AeroSpace)** — Enables cross-workspace window focus when clicking notifications

## 🚀 Installation

```bash
git clone https://github.com/tsilva/agentpong.git
cd agentpong
./install.sh
```

The installer will:
1. Install `terminal-notifier` via Homebrew (if needed)
2. Copy notification and focus scripts to `~/.claude/`
3. Configure Claude Code hooks in `~/.claude/settings.json`
4. Detect AeroSpace and enable window focus if available

### Post-install (with AeroSpace)

1. Ensure AeroSpace is running (should start automatically)
2. Grant Accessibility permissions when prompted
3. Restart your terminal/IDE

Without AeroSpace, notifications still work — clicking them will dismiss the notification but won't switch to the IDE window.

## 💡 Usage

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

## 🔧 How It Works

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Claude Code    │────▶│    notify.sh     │────▶│ terminal-notifier│
│  Stop Hook      │     │                  │     │                 │
└─────────────────┘     └──────────────────┘     └────────┬────────┘
                                                          │
                                                          ▼ click
                        ┌──────────────────┐     ┌─────────────────┐
                        │   AeroSpace      │◀────│ focus-window.sh │
                        │  (focus window)  │     │    (bundled)    │
                        └──────────────────┘     └─────────────────┘
```

1. Claude Code's `Stop` or `PermissionRequest` hook triggers `notify.sh`
2. `notify.sh` sends a notification via `terminal-notifier`
3. Clicking the notification executes `~/.claude/focus-window.sh` (if installed)
4. The focus script finds and focuses the correct IDE window via AeroSpace

### Why AeroSpace?

macOS Sequoia 15.x broke traditional window management APIs:

| Approach | Problem |
|----------|---------|
| Hammerspoon `hs.spaces.gotoSpace()` | No longer works on Sequoia |
| AppleScript `AXRaise` | Can't switch between Spaces |
| URL schemes (`cursor://`, `vscode://`) | Don't switch workspaces |
| **AeroSpace** | ✅ Works reliably without disabling SIP |

AeroSpace uses its own virtual workspace abstraction that bypasses these limitations.

## 🐳 claude-sandbox Integration

If you run Claude Code inside [claude-sandbox](https://github.com/tsilva/claude-sandbox), notifications can still reach your macOS desktop via TCP.

During installation, select "yes" when asked about sandbox support. This installs:
- A launchd service that listens on `localhost:19223`
- A container-compatible notify script that connects via `host.docker.internal`
- Hooks configured in `~/.claude-sandbox/claude-config/settings.json`

**Requirements:**
- claude-sandbox must have `netcat-openbsd` in its Dockerfile (included in recent versions)

**How it works:**
```
Container                              Host (macOS)
────────────────────────────────────────────────────────────
Claude Code hook fires
       │
       ▼
notify.sh connects via ─────────────►  launchd TCP listener
host.docker.internal:19223                    │
                                              ▼
                                       terminal-notifier
                                       + focus-window.sh
```

## 🗑️ Uninstallation

```bash
./uninstall.sh
```

This removes the notification scripts, hooks, and sandbox support (if installed). terminal-notifier is kept (you may have other uses for it).

To fully remove dependencies:
```bash
brew uninstall terminal-notifier
```

## 🔍 Troubleshooting

### Notifications don't appear

1. Check that `terminal-notifier` is installed: `which terminal-notifier`
2. Verify the hook is configured: `cat ~/.claude/settings.json | grep Stop`
3. Test manually: `~/.claude/notify.sh "Test"`

### Clicking notification doesn't focus the window

1. Check focus-window.sh is installed: `ls -la ~/.claude/focus-window.sh`
2. Check AeroSpace is installed: `which aerospace` or `ls /opt/homebrew/bin/aerospace`
3. Check AeroSpace is running: `pgrep -x AeroSpace`
4. Check Accessibility permissions: **System Settings → Privacy & Security → Accessibility**
5. Test window listing: `aerospace list-windows --all | grep Cursor`
6. Test focus script directly: `~/.claude/focus-window.sh "your-project-name"`

### Notifications work but hooks don't fire

Claude Code hooks only work in IDE-integrated terminals (Cursor/VS Code). For standalone terminals like iTerm2, use the Triggers workaround described above.

## 🤝 Contributing

Contributions welcome! Feel free to [open an issue](https://github.com/tsilva/agentpong/issues) or submit a pull request.

## 📄 License

[MIT](LICENSE)

---

<div align="center">

Found this useful? [⭐ Star the repo](https://github.com/tsilva/agentpong) to help others discover it!

</div>
