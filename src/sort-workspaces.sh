#!/bin/bash
# Organize Cursor windows into workspaces by project priority
# Triggered by alt+c keybinding in aerospace.toml

# Auto-detect aerospace binary
AEROSPACE=$(command -v aerospace || echo "/opt/homebrew/bin/aerospace")
if [ ! -x "$AEROSPACE" ]; then
    AEROSPACE="/usr/local/bin/aerospace"
fi

# Unminimize all Cursor windows before organizing
# Note: run toggle-animations.sh off to disable minimize/unminimize animations
osascript -e '
tell application "System Events"
    tell process "Cursor"
        set minimizedWindows to (windows whose value of attribute "AXMinimized" is true)
        repeat with w in minimizedWindows
            set value of attribute "AXMinimized" of w to false
        end repeat
    end tell
end tell
' 2>/dev/null

# Poll until all windows are unminimized (up to 3 seconds)
i=0
while [ $i -lt 30 ]; do
    MINIMIZED_COUNT=$(osascript -e 'tell application "System Events" to tell process "Cursor" to count of (windows whose value of attribute "AXMinimized" is true)' 2>/dev/null)
    [ "${MINIMIZED_COUNT:-0}" = "0" ] && break
    sleep 0.1
    i=$((i + 1))
done

# Get expected window count from System Events (the source of truth)
EXPECTED_COUNT=$(osascript -e 'tell application "System Events" to count of windows of process "Cursor"' 2>/dev/null)
EXPECTED_COUNT=${EXPECTED_COUNT:-0}

# Poll until aerospace sees all windows (up to 3 seconds)
# This is critical - aerospace's window tree lags behind macOS accessibility API
i=0
while [ $i -lt 30 ]; do
    AEROSPACE_COUNT=$("$AEROSPACE" list-windows --all | grep -c "| Cursor" || echo "0")
    [ "$AEROSPACE_COUNT" -ge "$EXPECTED_COUNT" ] && break
    sleep 0.1
    i=$((i + 1))
done

# Read project priority order from config file
CONFIG_FILE="$HOME/.config/aerospace/cursor-projects.txt"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Config file not found: $CONFIG_FILE"
  exit 1
fi

# Read projects into array (compatible with bash 3)
PROJECTS=()
while IFS= read -r line || [ -n "$line" ]; do
  [ -n "$line" ] && PROJECTS+=("$line")
done < "$CONFIG_FILE"

# Get all Cursor windows
WINDOWS=$("$AEROSPACE" list-windows --all | grep "| Cursor")

# Track which window IDs we've processed
PROCESSED_IDS=()

# Assign workspaces starting at 2
WS=2

# First pass: move known projects in priority order
for project in "${PROJECTS[@]}"; do
  WINDOW_ID=$(echo "$WINDOWS" | grep "$project" | awk '{print $1}')
  if [ -n "$WINDOW_ID" ]; then
    "$AEROSPACE" move-node-to-workspace "$WS" --window-id "$WINDOW_ID"
    PROCESSED_IDS+=("$WINDOW_ID")
    ((WS++))
  fi
done

# Second pass: move any remaining Cursor windows to subsequent workspaces
ALL_IDS=$(echo "$WINDOWS" | awk '{print $1}')
for WINDOW_ID in $ALL_IDS; do
  [ -z "$WINDOW_ID" ] && continue

  # Check if this ID was already processed
  FOUND=0
  for PROCESSED in "${PROCESSED_IDS[@]}"; do
    if [ "$WINDOW_ID" = "$PROCESSED" ]; then
      FOUND=1
      break
    fi
  done

  if [ "$FOUND" -eq 0 ]; then
    "$AEROSPACE" move-node-to-workspace "$WS" --window-id "$WINDOW_ID"
    ((WS++))
  fi
done
