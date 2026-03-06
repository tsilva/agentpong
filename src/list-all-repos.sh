#!/bin/bash
# List all repos from repos directory for Alfred Script Filter
# Shows open Cursor windows first (by workspace), then unopened repos alphabetically

# Auto-detect aerospace binary
AEROSPACE=$(command -v aerospace || echo "/opt/homebrew/bin/aerospace")
if [ ! -x "$AEROSPACE" ]; then
    AEROSPACE="/usr/local/bin/aerospace"
fi

REPOS_DIR="${AGENTPONG_REPOS_DIR:-$HOME/repos}"

# Build associative-style lookup of open Cursor windows using parallel arrays
# (bash 3.x compatible - no associative arrays)
open_projects=()
open_window_ids=()
open_workspaces=()

while IFS='|' read -r window_id app_name title workspace; do
    [ -z "$window_id" ] && continue
    # Extract project name from Cursor title
    if [[ "$title" == *" — "* ]]; then
        project="${title##* — }"
    else
        project="$title"
    fi
    project="${project% (Workspace)}"
    project="${project## }"
    project="${project%% }"

    open_projects+=("$project")
    open_window_ids+=("$window_id")
    open_workspaces+=("$workspace")
done < <("$AEROSPACE" list-windows --all --format '%{window-id}|%{app-name}|%{window-title}|%{workspace}' 2>/dev/null | grep '|Cursor|' | sort -t'|' -k4 -n)

# Collect all items as lines for sorting: "sort_key|json_line"
items=""

# Scan all repo directories (search all subdirectories of REPOS_DIR)
for search_dir in "$REPOS_DIR"/*/ "$REPOS_DIR"/.[!.]*/; do
    # If the directory itself is a git repo, use it
    if [ -d "$search_dir/.git" ]; then
        repo_dirs="$search_dir"
    else
        # Otherwise search one level deeper (for user/org subdirectories)
        repo_dirs=$(find "$search_dir" -maxdepth 1 -type d 2>/dev/null)
    fi

    for repo_dir in $repo_dirs; do
        [ -d "$repo_dir/.git" ] || continue
        [ -f "$repo_dir/.archived.md" ] && continue
        repo_name="$(basename "$repo_dir")"
        repo_escaped="${repo_name//\"/\\\"}"

        # Check for repo logo
        if [ -f "${repo_dir}logo.png" ]; then
            icon_json=",\"icon\":{\"path\":\"${repo_dir}logo.png\"}"
        elif [ -f "${repo_dir}/logo.png" ]; then
            icon_json=",\"icon\":{\"path\":\"${repo_dir}/logo.png\"}"
        else
            icon_json=""
        fi

        # Check if this repo has an open Cursor window
        found=0
        for i in "${!open_projects[@]}"; do
            if [ "${open_projects[$i]}" = "$repo_name" ]; then
                wid="${open_window_ids[$i]}"
                ws="${open_workspaces[$i]}"
                items="${items}0|${ws}|{\"title\":\"${repo_escaped}\",\"subtitle\":\"Workspace ${ws}\",\"arg\":\"open|${wid}\",\"match\":\"${repo_escaped}\"${icon_json}}
"
                found=1
                break
            fi
        done

        if [ "$found" -eq 0 ]; then
            path_escaped="${repo_dir//\"/\\\"}"
            # Remove trailing slash
            path_escaped="${path_escaped%/}"
            items="${items}1|${repo_name}|{\"title\":\"${repo_escaped}\",\"subtitle\":\"Not open\",\"arg\":\"new|${path_escaped}\",\"match\":\"${repo_escaped}\"${icon_json}}
"
        fi
    done
done

# Sort: open (0) first by workspace number, then unopened (1) alphabetically
printf '%s' "$items" | sort -t'|' -k1,1n -k2,2 | cut -d'|' -f3- | \
    paste -sd',' - | \
    awk '{print "{\"items\":["$0"]}"}'
