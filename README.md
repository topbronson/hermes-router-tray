# hermes-router-tray

> Tray indicator for the
> [Hermes-router](https://github.com/Shaf2665/Hermes-router) free-tier
> AI load-balancer, auto-starting with the Hermes gateway.

A small Python tray icon for Ubuntu/GNOME that owns the lifecycle of
`hr start`. Right-click the tray icon for Start / Stop / Restart / Open /
Quit. The icon is a generated circular "HR" badge on dark slate blue.

## Features

- **State-aware icon.** Tray dot color reflects live state (🟢 running,
  🟡 starting/restarting, ⚪ stopped, 🔴 error).
- **Lifecycle actions.** Right-click menu: Start, Stop, Restart, Open
  dashboard, Quit.
- **Auto-start at login.** Installs a systemd user service that starts
  alongside the Hermes gateway (`Wants=hermes-gateway.service`).
- **Smart port-race detection.** If the router is already managed by
  its own systemd service (`hr service install`), the indicator disables
  auto-start to avoid the two processes racing for port 8319.
- **Env-driven config.** No source edits to retarget host/port/cwd.
- **Clean separation.** Built on
  [`hermes-tray-lib`](https://github.com/topbronson/hermes-tray-lib) —
  this repo is just a thin wrapper.

## Prerequisites

Install the upstream Hermes-router first (this indicator manages it
but doesn't install it):

```bash
curl -fsSL https://raw.githubusercontent.com/Shaf2665/Hermes-router/main/get.sh | bash
```

For a reboot-surviving router service, also run:

```bash
hr service install
```

If you do this, the indicator's `install.sh` will detect the existing
service and disable its own auto-start, so the two don't race for the
port.

## Install

```bash
sudo apt install -y python3-gi gir1.2-gtk-3.0 gir1.2-appindicator3-0.1

git clone https://github.com/topbronson/hermes-router-tray
cd hermes-router-tray
```

Then **pick one** of these three install paths — they're all equivalent
functionally, just different trade-offs:

| Path | When to use | Command |
|---|---|---|
| **venv (recommended)** | Ubuntu 24.04+ has no `pip` by default; this avoids `sudo` | `python3 -m venv .venv && .venv/bin/pip install -e ".[dev]"` |
| `pip install --user` | You already have `pip` set up | `pip install --user -e ".[dev]"` |
| **no pip at all** | Just want the tray icon, skip the dev deps | none — `install.sh` creates a wrapper shim that runs from the repo source |

Then:

```bash
./install.sh
```

By default, this installs to `~/.local`. Use `PREFIX=/usr/local ./install.sh`
for a system-wide install.

After install, enable the systemd service:

```bash
systemctl --user daemon-reload
systemctl --user enable --now hermes-router-indicator.service
```

Check status with:

```bash
systemctl --user status hermes-router-indicator.service
journalctl --user -u hermes-router-indicator -f   # live logs
```

## Configuration

All configuration is via environment variables. Override at the shell
level or by editing the systemd unit's `Environment=` line.

| Variable | Default | Description |
|---|---|---|
| `HERMES_ROUTER_BIN` | `hr` | Path to the `hr` CLI binary |
| `HERMES_ROUTER_HOST` | `localhost` | Bind host (auto-detected from `~/.local/share/hermes-router/.env` at install time) |
| `HERMES_ROUTER_PORT` | `8319` | Bind port |
| `HERMES_ROUTER_URL` | `http://${HOST}:${PORT}/dashboard` | URL opened by "Open Router" |
| `HERMES_ROUTER_CWD` | `~/.local/share/hermes-router` | Working directory of the router subprocess |
| `HERMES_ROUTER_RESTART_DELAY` | `5` | Seconds to wait between stop and start on restart |
| `HERMES_ROUTER_AUTO_START` | `1` | If `0`, indicator runs without launching the router |
| `HERMES_ROUTER_BROWSER_CMD` | `xdg-open` | Browser launcher for the Open menu item |

## Icons

The repo generates icons from text (no upstream image required):

```bash
# 1. Plain "HR" circular badge (no state indicator)
python3 scripts/make-text-icon.py

# 2. Per-state icons with colored status dot
python3 scripts/make-status-icons.py
```

Both scripts honor `HERMES_ROUTER_ICON_DIR` for the output directory and
`HERMES_ROUTER_FONT_PATH` to override the font (default: DejaVuSans-Bold).

Outputs land in `~/.local/share/icons/hicolor/256x256/apps/` by default.

## License

MIT — see [LICENSE](LICENSE).

## Related

- [hermes-tray-lib](https://github.com/topbronson/hermes-tray-lib) — shared
  indicator infrastructure
- [hermes-dashboard-tray](https://github.com/topbronson/hermes-dashboard-tray) —
  sister tray for the Hermes dashboard
- [hermes-mnemosyne-tray](https://github.com/topbronson/hermes-mnemosyne-tray) —
  sister tray for the Mnemosyne dashboard
- [hermes-agent](https://github.com/nousresearch/hermes-agent)
- [Hermes-router](https://github.com/Shaf2665/Hermes-router) — the
  upstream load-balancer this indicator supervises
