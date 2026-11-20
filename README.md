<p align="center">
  <img src="https://raw.githubusercontent.com/tsilva/agentpong/main/logo.png" alt="agentpong" width="512"/>
  <br />
  <!-- repo-tagline:start -->
  <strong>🎛️ Supervise AI coding agents across organized workspaces 🏓</strong>
  <!-- repo-tagline:end -->
</p>

agentpong helps you supervise several coding agents on macOS. It organizes
Cursor windows in AeroSpace workspaces and sends notifications when supported
agents finish or need attention.

## Get started

Requires macOS, Homebrew, and AeroSpace. From a checkout:

```bash
./install.sh --dry-run
./install.sh
```

Choose the integrations you want and grant macOS Accessibility access when
prompted. Open your Cursor projects and press **Alt+S** to arrange them.
Click a notification or press **Alt+N** to focus the next agent window.

See the [usage guide](docs/usage.md) for supported hooks, keyboard shortcuts,
health checks, and selective uninstall.

## License

[MIT License](LICENSE).
