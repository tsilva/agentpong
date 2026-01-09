# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Code Notify is a macOS notification system that alerts users when Claude Code is ready for input. It hooks into Claude Code's event system and uses `terminal-notifier` to send desktop notifications with click-to-focus functionality.

## Architecture

Three bash scripts form the complete system:

- **notify.sh** - Core notification script that detects the terminal environment (Cursor, VS Code, iTerm2) and sends appropriate notifications. Uses URL schemes (`cursor://`, `vscode://`) to focus the correct workspace window when clicked.
- **install.sh** - Installs dependencies (`terminal-notifier`, `jq`), copies `notify.sh` to `~/.claude/`, and configures the `Stop` hook in `~/.claude/settings.json`.
- **uninstall.sh** - Removes the notification script and cleans up the hook configuration.

## Key Implementation Details

The notification script walks up the process tree (up to 5 levels) to detect whether it's running in Cursor or VS Code, since both set `TERM_PROGRAM=vscode` and Claude runs several process levels deep. It uses URL schemes (`cursor://file/path` or `vscode://file/path`) with the `-open` flag to focus the specific workspace window when clicked.

Claude Code hooks only work in IDE-integrated terminals (via SSE connection). For standalone terminals like iTerm2, users must configure iTerm's Triggers feature as a workaround.

## Testing

Test the notification manually:
```bash
./notify.sh "Test message"
```

Test installation/uninstallation in a clean environment by checking:
- `~/.claude/notify.sh` exists and is executable
- `~/.claude/settings.json` contains the `Stop` hook
