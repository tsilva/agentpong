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
- `src/notify.sh` -- Sends desktop notifications via terminal-notifier
- `src/focus-window.sh` -- Focuses correct IDE window when notification is clicked
- `src/pong.sh` -- Cycles through pending notifications (bound to alt+n)
- `plugins/opencode/agentpong.ts` -- OpenCode plugin for session.idle/permission.asked events

### Installation System
- `install.sh` (v3.0.0) -- Full installer with dry-run, rollback, wizard, health-check
- `uninstall.sh` (v3.0.0) -- Clean uninstaller with prompts for user data

## Key Decisions
- AeroSpace is a hard requirement (no AppleScript fallback)
- Alfred is optional (detected, not required)
- `~/.aerospace.toml` prompts before overwrite (user may have customized)
- `AGENTPONG_REPOS_DIR` env var overrides default repo scan path
