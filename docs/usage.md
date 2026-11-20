# Using agentpong

## Install options

Interactive installs show a multi-select picker (powered by [gum](https://github.com/charmbracelet/gum) when available) so you can choose which agents to hook into — Claude Code, Codex CLI, OpenCode, Kimi Code — plus optional claude-sandbox and Alfred integrations. Detected agents are pre-selected.

For a local install:

```bash
git clone https://github.com/tsilva/agentpong.git
cd agentpong
./install.sh
```

## Commands

```bash
./install.sh --dry-run       # preview install changes
./install.sh --wizard        # run interactive configuration
./install.sh --health-check  # verify installed scripts and dependencies
./install.sh --force         # reinstall even if files are up to date
./uninstall.sh               # remove agentpong scripts and hooks
```

## Usage

```bash
alt+1..9          # switch to workspace 1-9
alt+shift+1..9    # move current window to workspace 1-9
alt+s             # organize Cursor windows into workspaces 2-9
alt+n             # focus the next pending agent notification
alt+p             # open the Alfred project switcher, when Alfred is installed
alt+f             # toggle fullscreen
alt+left/right    # move to previous or next workspace
```

Codex CLI and Kimi Code hooks are written into their `config.toml` files automatically (marker-delimited blocks, removed again on uninstall). Codex only supports a turn-complete event — there is no permission notification for Codex.

`./uninstall.sh` is selective: it shows the same multi-select picker (everything installed pre-selected) so you can remove just one agent's integration instead of everything.

## Notes

- macOS and Homebrew are expected. AeroSpace is required for workspace switching and cross-workspace focus.
- The installer installs or configures `terminal-notifier`, `jq`, AeroSpace config, notification scripts, agent hooks, and optional Alfred or claudebox support. `gum` is an optional dependency that enables the richer multi-select TUI; a text fallback is built in.
- Cursor is the supported editor for the full workspace-management flow.
- Alfred is optional. When installed, `alt+p` lists open projects first and unopened repos after them.
- `AGENTPONG_REPOS_DIR` overrides the default Alfred repo scan directory of `~/repos`.
- claudebox support uses a launchd listener on local port `19223` with a shared token.
- AeroSpace itself is not removed by `./uninstall.sh`; remove it separately with Homebrew if needed.

## Architecture

![agentpong architecture diagram](../architecture.png)

## Secret scanning

GitHub scans the changed commit range on ordinary pushes and pull requests.
If a push's previous tip is no longer available after rewritten history, the
scanner checks all history reachable from the new tip, requiring a complete
checkout. Missing PR bases, invalid revisions and shallow fallback checkouts
remain failures. Scanner source and matched values are never published.

Run the credential-free workflow regressions with:

```sh
python3 -m unittest discover -s tests -p test_secret_scan_history.py
```
