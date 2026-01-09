# Claude Code Notify

Get macOS notifications when [Claude Code](https://claude.ai/code) is ready for your input. Click the notification to focus the correct IDE window - **even across multiple Spaces**.

## Features

- **Desktop notifications** when Claude finishes a task and is waiting for input
- **Smart window focusing** - clicking the notification brings you to the exact Cursor/VS Code window that triggered it
- **Works across Spaces** - uses Hammerspoon to properly switch to the correct Space and focus the window
- **Workspace name in notification** - instantly know which project needs attention

## Supported Terminals

| Terminal | Notifications | Click to Focus |
|----------|--------------|----------------|
| Cursor   | Automatic    | Exact window (across Spaces) |
| VS Code  | Automatic    | Exact window (across Spaces) |
| iTerm2   | Via Triggers | App only       |

## Requirements

- macOS
- [Claude Code CLI](https://claude.ai/code)
- [Hammerspoon](https://www.hammerspoon.org/) (for window focusing across Spaces)
- [Homebrew](https://brew.sh) (for installing dependencies)

## Installation

```bash
git clone https://github.com/tsilva/claude-code-notify.git
cd claude-code-notify
./install.sh
```

The installer will:
1. Install Hammerspoon (if not present) and configure it
2. Install the `hs` CLI tool for communication
3. Copy the notification script to `~/.claude/`
4. Configure Claude Code hooks automatically

### Post-Installation

After installation, ensure Hammerspoon is running and has Accessibility permissions:
1. Open Hammerspoon from Applications
2. Grant Accessibility permissions when prompted (System Settings > Privacy & Security > Accessibility)
3. The menubar icon confirms it's running

## How It Works

```
Claude Code finishes task → Stop hook fires → notify.sh runs
                                                    ↓
                                         hs -c "claudeNotify(...)"
                                                    ↓
                                         Hammerspoon shows notification
                                                    ↓
                                         User clicks notification
                                                    ↓
                                         hs.window:focus() switches Space
                                         and focuses the correct window
```

### Why Hammerspoon?

Previous approaches using AppleScript's `AXRaise` or URL schemes (`cursor://`, `vscode://`) couldn't switch between macOS Spaces. Hammerspoon's `hs.window:focus()` properly navigates to the window's Space and focuses it.

## iTerm2 Setup

Claude Code hooks only work in IDE terminals (Cursor/VS Code) because they require an SSE connection. For iTerm2, use iTerm's built-in Triggers feature:

1. Open **iTerm > Settings > Profiles > Advanced > Triggers > Edit**
2. Click **+** to add a new trigger
3. Configure:
   - **Regular Expression:** `^[[:space:]]*>`
   - **Action:** Run Command...
   - **Parameters:** `~/.claude/notify.sh "Ready for input"`
   - **Instant:** checked

This triggers a notification whenever Claude's input prompt appears.

## Uninstallation

```bash
./uninstall.sh
```

This removes the notification script, Claude Code hooks, and Hammerspoon module. Hammerspoon itself is not uninstalled (you may have other uses for it).

If you set up iTerm Triggers, remove them manually in iTerm Settings.

## Troubleshooting

### Notifications not appearing (Cursor/VS Code)
- Start a **new** Claude session after installation (hooks are loaded at startup)
- Verify the hook is configured: `cat ~/.claude/settings.json | grep Stop`

### Notifications not appearing (iTerm2)
- Ensure the Trigger is set up correctly
- Test manually: `~/.claude/notify.sh "Test"`

### Clicking notification doesn't focus/switch Space
- Ensure Hammerspoon is running (check for menubar icon)
- Ensure Hammerspoon has Accessibility permissions
- Verify the `hs` CLI works: `hs -c "print('ok')"`
- If `hs` is not found, run in Hammerspoon console: `hs.ipc.cliInstall()`
- Test directly: `hs -c "claudeNotify('test', 'Test message')"`

### Wrong window focuses
- Ensure each workspace has a unique folder/project name
- The window is matched by title containing the workspace name

### Hammerspoon console commands

Open Hammerspoon console (click menubar icon > Console) to debug:

```lua
-- Test notification
claudeNotify("my-project", "Test message")

-- List all windows
for _, w in ipairs(hs.window.allWindows()) do print(w:title()) end

-- Install CLI if missing
hs.ipc.cliInstall()
```

## License

MIT
