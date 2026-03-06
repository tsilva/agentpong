# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

agentpong is an opinionated macOS workspace for supervising multiple AI coding agents in parallel, powered by AeroSpace. It organizes Cursor windows into numbered workspaces, sends desktop notifications when agents finish or need permission, and focuses the correct window when you respond -- even across workspaces. The README frames this as "the supervisor pattern": delegate tasks to parallel Claude Code instances, switch away, get notified, jump back.

## Core Capabilities

1. **Workspace Management** -- AeroSpace config with keybindings for workspace switching (alt+1..9), window organization (alt+s), and project switching via Alfred (alt+p)
2. **AI Agent Notifications** -- Desktop notifications via terminal-notifier when Claude Code, OpenCode, or claude-sandbox agents finish tasks or need permission
3. **Window Focusing** -- Click a notification or press alt+n to jump directly to the right Cursor/VS Code window across workspaces

## Ecosystem

Companion projects that enhance the supervisor workflow:
- **[claude-skills](https://github.com/tsilva/claude-skills)** -- Reusable skills for Claude Code
- **[claudebox](https://github.com/tsilva/claudebox)** -- Sandboxed Claude Code execution (no permission prompts)
- **[capture](https://github.com/tsilva/capture)** -- Instant thought capture to Gmail
- **[claudebridge](https://github.com/tsilva/claudebridge)** -- OpenAI-compatible API bridge for Claude Max
- **[gita](https://github.com/nosarthur/gita)** -- Multi-repo git status overview

## Supported Tools

- **Claude Code** -- Full support with `Stop` and `PermissionRequest` hooks
- **OpenCode** -- Full support via TypeScript plugin (`session.idle` and `permission.asked` events)
- **claude-sandbox** -- Full support via TCP listener (port 19223)

## Directory Structure

```
agentpong/
├── install.sh                              # Main installation script (v3.0.0)
├── uninstall.sh                            # Uninstallation script (v3.0.0)
├── src/                                    # Core shell scripts
│   ├── notify.sh                          # Notification script (called by hooks)
│   ├── focus-window.sh                    # Notification click → focus by workspace name
│   ├── pong.sh                            # Notification cycling (alt+n keybinding)
│   ├── style.sh                           # Terminal styling library
│   ├── sort-workspaces.sh                 # Organize Cursor windows (alt+s)
│   ├── open-project.sh                    # Alfred → focus by window ID or open project
│   ├── list-all-repos.sh                  # Alfred Script Filter: list all repos
│   ├── toggle-animations.sh               # Disable/enable macOS animations
│   ├── alfred-search.sh                   # Open Alfred with keyword pre-filled
│   ├── notify-listener.sh                 # TCP listener for sandbox
│   └── notify-container.sh               # Container notification script
├── plugins/                                # IDE/editor plugins
│   └── opencode/
│       └── agentpong.ts                   # OpenCode TypeScript plugin
├── config/                                 # Configuration templates
│   ├── aerospace.toml                     # AeroSpace config (→ ~/.aerospace.toml)
│   └── com.agentpong.sandbox.plist.template
├── alfred/                                 # Alfred workflows
│   └── cursor-project-switcher/
│       └── info.plist                     # Alfred workflow definition
├── logo.png                                # Project logo
└── logs/                                   # Runtime logs
```

## Installation Targets

Scripts are installed to different locations based on their purpose:

| Source | Installed To | Purpose |
|--------|-------------|---------|
| `src/notify.sh` | `~/.claude/notify.sh` | Notification hook target |
| `src/focus-window.sh` | `~/.claude/focus-window.sh` | Notification click handler |
| `src/pong.sh` | `~/.claude/pong.sh` | Notification cycling |
| `src/style.sh` | `~/.claude/style.sh` | Styling library |
| `src/sort-workspaces.sh` | `~/.config/aerospace/sort-workspaces.sh` | Window organization |
| `src/open-project.sh` | `~/.config/aerospace/open-project.sh` | Alfred project handler |
| `src/list-all-repos.sh` | `~/.config/aerospace/list-all-repos.sh` | Alfred script filter |
| `src/toggle-animations.sh` | `~/.config/aerospace/toggle-animations.sh` | Animation toggle |
| `src/alfred-search.sh` | `~/.config/aerospace/alfred-search.sh` | Alfred launcher |
| `config/aerospace.toml` | `~/.aerospace.toml` | AeroSpace config |
| `alfred/cursor-project-switcher/` | Alfred workflows dir | Alfred workflow |

## Key Implementation Details

AeroSpace is a core requirement (no AppleScript fallback):
- AppleScript's `AXRaise` and URL schemes (`cursor://`, `vscode://`) cannot switch between macOS Spaces
- AeroSpace uses its own virtual workspace abstraction that works reliably on macOS 14+ (Sequoia)
- If AeroSpace binary is not found, focus-window.sh exits with an error

**`list-all-repos.sh`** uses `${AGENTPONG_REPOS_DIR:-$HOME/repos}` to locate repositories. Users can override this with the environment variable.

**Alfred** is optional paid software -- detected but never required.

## Testing

Test notification:
```bash
./src/notify.sh "Test message"
```

Test focus script:
```bash
./src/focus-window.sh "project-name"
```

Test window organization:
```bash
./src/sort-workspaces.sh
```

Test installation:
```bash
./install.sh --dry-run
```

## Development Guidelines

- Keep `README.md` up to date with any significant project changes
- AeroSpace is a hard requirement -- do not add AppleScript fallbacks
- Alfred integration must remain optional
- Use `dry_aware_*` wrappers for all file operations in install/uninstall scripts
- Use `needs_update()` SHA256 check for idempotent file copies
- Use `section()`/`step()`/`success()` from style.sh for installer output
- Use `add_rollback()` in install.sh for any new operations that should be reversible on failure
- Run `bash -n <script>` to syntax-check shell scripts after modifications
- CLAUDE.md and AGENTS.md are separate files (not symlinked) -- update both when project scope changes
- The README supervisor pattern narrative is the lead story -- keep it prominent when editing
