# Claude Code Notify

Get macOS notifications when [Claude Code](https://claude.ai/code) is ready for your input. Click the notification to focus the correct IDE window.

## Features

- **Desktop notifications** when Claude finishes a task and is waiting for input
- **Smart window focusing** - clicking the notification brings you to the exact Cursor/VS Code window that triggered it (even with multiple windows open)
- **Workspace name in notification** - instantly know which project needs attention

## Supported Terminals

| Terminal | Notifications | Click to Focus |
|----------|--------------|----------------|
| Cursor   | Automatic    | Exact window   |
| VS Code  | Automatic    | Exact window   |
| iTerm2   | Via Triggers | App only       |

## Requirements

- macOS
- [Claude Code CLI](https://claude.ai/code)
- [Homebrew](https://brew.sh) (for installing dependencies)

## Installation

```bash
git clone https://github.com/tsilva/claude-code-notify.git
cd claude-code-notify
./install.sh
```

The installer will:
1. Install `terminal-notifier` and `jq` if needed
2. Copy the notification script to `~/.claude/`
3. Configure Claude Code hooks automatically

## iTerm2 Setup

Claude Code hooks only work in IDE terminals (Cursor/VS Code) because they require an SSE connection. For iTerm2, use iTerm's built-in Triggers feature:

1. Open **iTerm > Settings > Profiles > Advanced > Triggers > Edit**
2. Click **+** to add a new trigger
3. Configure:
   - **Regular Expression:** `^[[:space:]]*❯`
   - **Action:** Run Command...
   - **Parameters:** `~/.claude/notify.sh "Ready for input"`
   - **Instant:** ✓ (checked)

This triggers a notification whenever Claude's input prompt appears.

## How It Works

### Cursor / VS Code
Claude Code has a hooks system that fires events during operation. This tool uses the `Stop` hook which fires when Claude finishes and is waiting for input. The notification uses the editor's URL scheme (`cursor://file/...` or `vscode://file/...`) to focus the exact workspace window when clicked.

### iTerm2
Claude Code hooks require an IDE integration (SSE connection) that doesn't exist in standalone terminals. The workaround uses iTerm's Triggers feature to detect when Claude's prompt appears and send a notification.

## Uninstallation

```bash
./uninstall.sh
```

If you set up iTerm Triggers, remove them manually in iTerm Settings.

## Troubleshooting

### Notifications not appearing (Cursor/VS Code)
- Start a **new** Claude session after installation (hooks are loaded at startup)
- Verify the hook is configured: `cat ~/.claude/settings.json | grep Stop`

### Notifications not appearing (iTerm2)
- Ensure the Trigger is set up correctly
- Test manually: `~/.claude/notify.sh "Test"`
- Check that `terminal-notifier` is installed: `which terminal-notifier`

### Clicking notification doesn't focus window
- This is expected for iTerm2 (app-level focus only)
- For Cursor/VS Code, the script automatically detects your editor and uses the correct URL scheme

### Wrong window focuses (multiple Cursor windows)
- Ensure each window has a different workspace/folder open
- The URL scheme uses the current working directory to focus the correct window

## License

MIT
