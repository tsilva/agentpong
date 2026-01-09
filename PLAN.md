# Claude Code Notify: AeroSpace Integration Plan

## Problem Statement

macOS Sequoia 15.x broke Hammerspoon's `hs.spaces.gotoSpace()` API. The current implementation can show notifications but cannot switch to the correct Space when clicked.

**Research confirmed:**
- Hammerspoon issue #3698: `hs.spaces.gotoSpace()` returns true but does nothing on Sequoia
- yabai has similar issues, now requires SIP disabled on Sequoia
- AppleScript keystroke commands also have issues on Sequoia

## Solution: AeroSpace Virtual Workspaces

Replace native macOS Spaces with **AeroSpace** (https://github.com/nikitabobko/AeroSpace), which uses its own workspace abstraction that works on Sequoia without disabling SIP.

**Why AeroSpace:**
- Uses custom workspace emulation, not native macOS Spaces
- CLI-first design with commands like `aerospace workspace <name>`
- Works on macOS 15 (Sequoia) without SIP modification
- Can focus windows across workspaces programmatically

## New Architecture

```
Claude Code Stop hook fires
        ↓
notify.sh (detects AeroSpace is available)
        ↓
terminal-notifier with -execute flag
        ↓ (user clicks notification)
focus-window.sh executes
        ↓
aerospace list-windows → find Cursor window with project in title
        ↓
aerospace workspace <name> → switch to workspace
        ↓
aerospace focus --window-id <id> → focus window
```

## Files to Modify

### 1. `notify.sh` - Detection and Routing

**Changes:**
- Add AeroSpace detection as Priority 1 (before Hammerspoon)
- When AeroSpace available: use `terminal-notifier -execute` to call `focus-window.sh` on click
- Keep Hammerspoon as Priority 2 fallback
- Keep terminal-notifier-only as Priority 3

**New logic:**
```bash
# Priority 1: AeroSpace (works on Sequoia)
if command -v aerospace &> /dev/null; then
    terminal-notifier \
        -title "Claude Code [$WORKSPACE]" \
        -message "$MESSAGE" \
        -sound default \
        -execute "$SCRIPT_DIR/focus-window.sh '$WORKSPACE'"
    exit 0
fi

# Priority 2: Hammerspoon (fallback, broken on Sequoia)
# ... existing code ...

# Priority 3: terminal-notifier only
# ... existing code ...
```

### 2. `focus-window.sh` - NEW FILE

**Purpose:** AeroSpace window focusing logic (executed on notification click)

```bash
#!/bin/bash
# Focus the Cursor/VS Code window containing the specified workspace name

WORKSPACE="$1"

# Find window ID for Cursor/Code with workspace in title
WINDOW_INFO=$(aerospace list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' | \
    grep -E '(Cursor|Code)' | \
    grep -i "$WORKSPACE" | \
    head -1)

if [ -z "$WINDOW_INFO" ]; then
    # Fallback: first Cursor window
    WINDOW_INFO=$(aerospace list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' | \
        grep -E '(Cursor|Code)' | \
        head -1)
fi

if [ -n "$WINDOW_INFO" ]; then
    WINDOW_ID=$(echo "$WINDOW_INFO" | cut -d'|' -f1)
    WINDOW_WORKSPACE=$(echo "$WINDOW_INFO" | cut -d'|' -f4)

    # Switch workspace and focus window
    [ -n "$WINDOW_WORKSPACE" ] && aerospace workspace "$WINDOW_WORKSPACE"
    aerospace focus --window-id "$WINDOW_ID"
else
    # Last resort: just activate Cursor
    osascript -e 'tell application "Cursor" to activate' 2>/dev/null
fi
```

### 3. `install.sh` - AeroSpace Installation

**Add before Hammerspoon section:**
1. Check if AeroSpace installed
2. Prompt to install via `brew install --cask nikitabobko/tap/aerospace`
3. Install `terminal-notifier` if needed (`brew install terminal-notifier`)
4. Copy `focus-window.sh` to `~/.claude/`
5. Make Hammerspoon installation optional (skip if AeroSpace chosen)

### 4. `uninstall.sh` - Cleanup

**Add:**
- Remove `~/.claude/focus-window.sh`
- Do NOT uninstall AeroSpace itself (user may use it elsewhere)

### 5. `claude-notify.lua` - Minor Update

**Add comment at top:**
```lua
-- NOTE: On macOS Sequoia 15.x, hs.spaces.gotoSpace() may not work.
-- Consider using AeroSpace instead: brew install --cask nikitabobko/tap/aerospace
```

## Detection Priority Order

```
1. AeroSpace (command -v aerospace) → terminal-notifier + focus-window.sh
2. Hammerspoon (command -v hs) → hs -c "claudeNotify(...)"
3. terminal-notifier only → notification without window focus
4. Error → prompt to install
```

## Key Dependencies

| Tool | Purpose | Installation |
|------|---------|--------------|
| AeroSpace | Virtual workspaces, window focusing | `brew install --cask nikitabobko/tap/aerospace` |
| terminal-notifier | Notifications with -execute callback | `brew install terminal-notifier` |

## Verification Steps

### Test 1: Basic Notification
```bash
./notify.sh "Test message"
```
Expected: Notification appears with project name in title

### Test 2: Window Finding
```bash
aerospace list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' | grep Cursor
```
Expected: Lists all Cursor windows with their IDs and workspaces

### Test 3: Cross-Workspace Focus
1. Open Cursor with project "project-a"
2. Switch to different AeroSpace workspace
3. Run notification from project-a directory
4. Click notification
5. Verify: Switches to correct workspace AND focuses correct window

### Test 4: Fallback (without AeroSpace)
```bash
# Temporarily hide aerospace from PATH
(PATH="${PATH//:*aerospace*/}" && ./notify.sh "Test")
```
Expected: Falls back to Hammerspoon

## Migration Notes for Users

1. **First time setup:** Run `install.sh`, choose to install AeroSpace when prompted
2. **AeroSpace learning:** Basic usage is simple - workspaces are just named containers
3. **Optional optimization:** Configure `~/.aerospace.toml` to auto-assign Cursor windows to named workspaces
4. **Keyboard shortcuts:** Set up AeroSpace keybindings for workspace switching (replaces Ctrl+Number)

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| AeroSpace performance issues (reported 5s+ delays under high CPU) | Document as known limitation; Hammerspoon fallback available |
| User unfamiliar with AeroSpace | Provide clear setup instructions; keep system optional |
| Window title doesn't contain project name | Fallback to first Cursor window; user can rename windows |
| terminal-notifier -execute requires Homebrew version | Verify installation source in install.sh |

## Research Sources

- [Hammerspoon Sequoia Issue #3698](https://github.com/Hammerspoon/hammerspoon/issues/3698)
- [AeroSpace GitHub](https://github.com/nikitabobko/AeroSpace)
- [AeroSpace Commands](https://nikitabobko.github.io/AeroSpace/commands)
- [yabai Sequoia Issues](https://github.com/koekeishiya/yabai/issues/2487)
- [AltTab Space switching discussion](https://github.com/lwouis/alt-tab-macos/issues/447)
