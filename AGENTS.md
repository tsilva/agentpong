# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## Project Overview

agentpong is an opinionated macOS workspace for supervising multiple AI coding agents in parallel, powered by AeroSpace. It organizes Cursor windows into numbered workspaces, sends desktop notifications when agents finish or need permission, and focuses the correct window when you respond -- even across workspaces.

## Architecture

The system has two main subsystems:

### 1. Workspace Management
- `config/aerospace.toml` -- AeroSpace tiling window manager configuration
- `src/sort-workspaces.sh` -- Organizes Cursor windows into numbered workspaces (alt+s)
- `src/open-project.sh` -- Alfred workflow action: focus window by ID or open new project
- `src/list-all-repos.sh` -- Alfred script filter: lists all repos with open/closed status
- `src/toggle-animations.sh` -- Disables/enables macOS animations for snappier workspace switching
- `src/alfred-search.sh` -- Opens Alfred with a keyword pre-filled

### 2. Agent Notifications (original agentpong)
- `src/notify.sh` -- Sends desktop notifications via terminal-notifier (detects Claude Code, Codex CLI, OpenCode, Kimi Code via env vars)
- `src/focus-window.sh` -- Focuses correct IDE window when notification is clicked
- `src/pong.sh` -- Cycles through pending notifications (bound to alt+n)
- `plugins/opencode/agentpong.ts` -- OpenCode plugin for session.idle/permission.asked events
- `plugins/codex/agentpong.py` -- Codex CLI notify handler (agent-turn-complete)
- `plugins/kimi/agentpong.sh` -- Kimi Code hook handler (Stop/PermissionRequest via `[[hooks]]` in ~/.kimi-code/config.toml)

### Installation System
- `install.sh` (v3.1.0) -- Full installer with dry-run, rollback, wizard, health-check, and an interactive multi-select component picker (gum-powered when available, text fallback otherwise)
- `uninstall.sh` (v3.1.0) -- Selective uninstaller: per-component picker, plus cleanup of agentpong blocks in Codex/Kimi config.toml

## Key Decisions
- AeroSpace is a hard requirement (no AppleScript fallback)
- Alfred is optional (detected, not required)
- `~/.aerospace.toml` prompts before overwrite (user may have customized)
- `AGENTPONG_REPOS_DIR` env var overrides default repo scan path
- Agent config edits (Codex `notify`, Kimi `[[hooks]]`) use `# >>> agentpong >>>` / `# <<< agentpong <<<` marker blocks so uninstall can remove them cleanly
- `gum` is optional: `src/style.sh` routes prompts through it when installed, plain-text fallback otherwise
