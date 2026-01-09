# claude-code-notify

macOS notifications for [Claude Code](https://claude.ai/code). Click to focus the right window, even across workspaces.

## Requirements

- macOS Sequoia (15.x)
- [AeroSpace](https://github.com/nikitabobko/AeroSpace) - required because Sequoia broke native Space switching
- [Homebrew](https://brew.sh)

## Install

```bash
git clone https://github.com/tsilva/claude-code-notify.git
cd claude-code-notify
./install.sh
```

Grant AeroSpace accessibility permissions when prompted.

## Usage

1. **Use AeroSpace workspaces** (not macOS Spaces) - this is required for click-to-focus
2. Move windows between workspaces: `Alt+Shift+1-9`
3. Switch workspaces: `Alt+1-9` or `Alt+Left/Right`
4. Start a new Claude session - you'll get notifications when Claude is ready for input

## iTerm2

Claude hooks only work in Cursor/VS Code. For iTerm2, add a Trigger:

**iTerm > Settings > Profiles > Advanced > Triggers**
- Regex: `^[[:space:]]*>`
- Action: Run Command...
- Parameters: `~/.claude/notify.sh "Ready for input"`
- Instant: checked

## Troubleshooting

**No notifications:** Start a new Claude session after install

**Click doesn't focus window:**
- Make sure you're using AeroSpace workspaces, not macOS Spaces
- Test: `~/.claude/focus-window.sh "your-project-name"`
- Check windows: `aerospace list-windows --all`

## Uninstall

```bash
./uninstall.sh
```
