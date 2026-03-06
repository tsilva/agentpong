#!/bin/bash
# List all Cursor windows for Alfred Script Filter
# Outputs Alfred-compatible JSON for project switching

# Auto-detect aerospace binary
AEROSPACE=$(command -v aerospace || echo "/opt/homebrew/bin/aerospace")
if [ ! -x "$AEROSPACE" ]; then
    AEROSPACE="/usr/local/bin/aerospace"
fi

"$AEROSPACE" list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' | \
grep '|Cursor|' | \
sort -t'|' -k4 -n | \
while IFS='|' read -r window_id app_name title workspace; do
    # Extract project name (last part after " — " or whole title)
    # Cursor titles: "filename — project-name" or just "project-name"
    if [[ "$title" == *" — "* ]]; then
        project="${title##* — }"
    else
        project="$title"
    fi

    # Clean up project name
    project="${project% (Workspace)}"
    project="${project## }"
    project="${project%% }"

    # Escape quotes for JSON
    title_escaped="${title//\"/\\\"}"
    project_escaped="${project//\"/\\\"}"

    printf '{"title":"%s","subtitle":"Workspace %s","arg":"%s","match":"%s %s"},\n' \
        "$project_escaped" "$workspace" "$window_id" "$project_escaped" "$title_escaped"
done | \
sed '$ s/,$//' | \
awk 'BEGIN{print "{\"items\":["} {print} END{print "]}"}'
