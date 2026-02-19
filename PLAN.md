# Plan: Keyboard Shortcut to Cycle Through Notifications

## Context

agentpong sends macOS notifications when Claude Code needs attention. Currently, processing a notification requires clicking it with the mouse. The user wants a keyboard shortcut to cycle through pending notifications, executing each one's focus action (switching AeroSpace workspace + focusing IDE window) without touching the mouse.

**Key constraint:** macOS has no stable API to programmatically "click" Notification Center items. Maintaining a separate queue file would get out of sync with clicked/dismissed notifications.

**Approach:** Stateless — query `terminal-notifier -list ALL` to get pending notifications directly from Notification Center, then process the next one. No queue, no sync issues.

## Files to Modify

- **New: `pong.sh`** — processes the next pending notification via keyboard shortcut
- **`install.sh`** — install `pong.sh` to `~/.claude/`
- **`uninstall.sh`** — clean up `pong.sh`

## Implementation

### Step 1: Verify `terminal-notifier -list` Output Format

Run `terminal-notifier -list ALL` from a normal terminal (not sandboxed) after triggering a test notification. Document the output format so we can parse it correctly. Expected to return group IDs (workspace names) of active notifications.

### Step 2: Create `pong.sh`

```
#!/bin/bash
# Processes the next pending agentpong notification via keyboard shortcut.
# Queries terminal-notifier for active notifications, focuses the next
# workspace, and dismisses the notification — no mouse needed.
```

Logic:
1. Run `terminal-notifier -list ALL` to get active notifications
2. Parse output to extract group IDs (workspace names)
3. If no pending notifications, exit silently (or optional subtle feedback)
4. Pick the first/oldest workspace from the list
5. Run `~/.claude/focus-window.sh '<workspace>'` (reuse existing script)
6. Run `terminal-notifier -remove '<workspace>'` to dismiss the notification

Edge cases:
- Empty list → exit 0 (nothing to process)
- `focus-window.sh` not found → fall back to just removing notification
- `terminal-notifier` not found → exit with error

### Step 3: Update `install.sh`

After the existing `focus-window.sh` installation block, add:
- Copy `pong.sh` to `~/.claude/pong.sh`
- `chmod +x`
- Print keybinding instructions (see Step 5)

### Step 4: Update `uninstall.sh`

Add cleanup for `~/.claude/pong.sh` alongside existing script removal.

### Step 5: Keybinding Documentation

The user binds `~/.claude/pong.sh` to a keyboard shortcut via their preferred tool. Print instructions for AeroSpace (since it's already a dependency):

```toml
# Add to ~/.config/aerospace/aerospace.toml
[mode.main.binding]
alt-p = 'exec-and-forget ~/.claude/pong.sh'
```

Also mention alternatives: skhd, Raycast, macOS Shortcuts app.

## Verification

1. **Trigger test notifications:**
   ```bash
   CLAUDE_PROJECT_DIR=/tmp/project-a ./notify.sh "Ready for input"
   CLAUDE_PROJECT_DIR=/tmp/project-b ./notify.sh "Permission required"
   ```

2. **Verify list works:**
   ```bash
   terminal-notifier -list ALL
   ```
   Should show both notifications with groups `project-a` and `project-b`.

3. **Run pong.sh:**
   ```bash
   ~/.claude/pong.sh
   ```
   Should focus the first workspace and dismiss its notification.

4. **Run pong.sh again:**
   Should process the second notification.

5. **Run pong.sh with empty queue:**
   Should exit silently.

6. **Click a notification manually, then run pong.sh:**
   Should skip the clicked one (already gone from Notification Center) and only process remaining ones.
