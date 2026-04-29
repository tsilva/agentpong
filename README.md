<div align="center">
  <img src="https://raw.githubusercontent.com/tsilva/agentpong/main/logo.png" alt="agentpong" width="512"/>

  # agentpong

  **🎛️ Supervise multiple AI coding agents in parallel — organized workspaces, instant switching, desktop notifications 🏓**
</div>

agentpong is a macOS workspace for supervising several AI coding agents at once. It uses AeroSpace to keep Cursor project windows in numbered workspaces, then sends desktop notifications when Claude Code, Codex CLI, or OpenCode finishes or needs attention.

Click a notification, or press `alt+n`, to jump back to the correct project window across workspaces.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/tsilva/agentpong/main/install.sh | bash
```

After installation, grant macOS Accessibility permissions when prompted, open the Cursor windows you want to supervise, then press `alt+s` to sort them into workspaces.

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

Codex CLI needs this notify hook in `~/.codex/config.toml`:

```toml
notify = ["python3", "~/.codex/agentpong.py"]
```

## Notes

- macOS and Homebrew are expected. AeroSpace is required for workspace switching and cross-workspace focus.
- The installer installs or configures `terminal-notifier`, `jq`, AeroSpace config, notification scripts, agent hooks, and optional Alfred or claudebox support.
- Cursor is the supported editor for the full workspace-management flow.
- Alfred is optional. When installed, `alt+p` lists open projects first and unopened repos after them.
- `AGENTPONG_REPOS_DIR` overrides the default Alfred repo scan directory of `~/repos`.
- claudebox support uses a launchd listener on local port `19223` with a shared token.
- AeroSpace itself is not removed by `./uninstall.sh`; remove it separately with Homebrew if needed.

## Architecture

![agentpong architecture diagram](./architecture.png)

## License

[MIT](LICENSE)
