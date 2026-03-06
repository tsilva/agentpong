#!/bin/bash
# Focus a Cursor window by ID
# Called by Alfred workflow after selecting a project

# Auto-detect aerospace binary
AEROSPACE=$(command -v aerospace || echo "/opt/homebrew/bin/aerospace")
if [ ! -x "$AEROSPACE" ]; then
    AEROSPACE="/usr/local/bin/aerospace"
fi

arg="$1"
action="${arg%%|*}"
value="${arg#*|}"

if [ "$action" = "new" ]; then
    repo_path="$value"
    project_name="$(basename "$repo_path")"

    # Open Cursor in the repo (prefer .code-workspace file if available)
    workspace_file="$repo_path/${project_name}.code-workspace"
    if [ -f "$workspace_file" ]; then
        open -a "Cursor" "$workspace_file"
    else
        open -a "Cursor" "$repo_path"
    fi

    # Wait for the window to appear
    sleep 2

    # Run rearrange script
    "$HOME/.config/aerospace/aerospace-fix-cursor.sh"

    # Find the new Cursor window for this project and focus it
    new_wid=$("$AEROSPACE" list-windows --all --format '%{window-id}|%{app-name}|%{window-title}' 2>/dev/null | \
        grep '|Cursor|' | grep "$project_name" | head -1 | cut -d'|' -f1)

    if [ -n "$new_wid" ]; then
        "$AEROSPACE" focus --window-id "$new_wid"
    fi
else
    # Default: focus existing window by ID
    "$AEROSPACE" focus --window-id "$value"
fi
