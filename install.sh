#!/usr/bin/env bash
# Install the Hermes Router tray indicator.
#
# Usage:
#   ./install.sh                       # install to ~/.local (default)
#   PREFIX=/usr/local ./install.sh     # install to /usr/local
#   HERMES_ROUTER_HOST=100.x.x.x ./install.sh   # override detected host
#
# Re-running is safe; existing files are overwritten in place.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
BIN_DIR="$PREFIX/bin"
SHARE_DIR="$PREFIX/share"
APPS_DIR="$SHARE_DIR/applications"
AUTOSTART_DIR="$SHARE_DIR/autostart"
ICON_DIR="$SHARE_DIR/icons/hicolor/256x256/apps"
SVG_DIR="$SHARE_DIR/icons/hicolor/scalable/apps"

# Resolve the hr binary path for HERMES_ROUTER_BIN injection
HR_BIN_PATH="$(command -v hr || true)"

# Pick the Python interpreter that has hermes-tray-lib + the indicator
# package importable. Drives both EXEC_LINE (for the .desktop and
# systemd units) and the wrapper-shim shebang.
# We use `readlink -e` (which returns nothing if the path doesn't resolve
# to an existing file) so we don't get tricked by a broken self-symlink
# left over from a previous failed install.
INDICATOR_PY=""
if [[ -n "$(readlink -e "$REPO_ROOT/.venv/bin/hermes-router-indicator" 2>/dev/null)" ]]; then
    # venv install: use the venv's python. The console script under
    # ~/.local/bin/ is usually a symlink to the venv one, but the
    # actual interpreter must be the venv python for hermes_tray /
    # Pillow to be importable.
    INDICATOR_PY="$REPO_ROOT/.venv/bin/python3"
elif [[ -n "$(readlink -e "$HOME/.local/bin/hermes-router-indicator" 2>/dev/null)" ]]; then
    # pip install --user to a system python: use that system python.
    INDICATOR_PY="/usr/bin/python3"
elif [[ -x "$REPO_ROOT/.venv/bin/python3" ]]; then
    INDICATOR_PY="$REPO_ROOT/.venv/bin/python3"
else
    INDICATOR_PY="/usr/bin/python3"
fi

EXEC_LINE="$INDICATOR_PY $BIN_DIR/hermes-router-indicator"
if [[ -n "$HR_BIN_PATH" && "$HR_BIN_PATH" != "$PREFIX/bin/hr" ]]; then
    EXEC_LINE="/usr/bin/env HERMES_ROUTER_BIN=${HR_BIN_PATH} $EXEC_LINE"
fi

# -----------------------------------------------------------------------------
# Check that hr is installed
# -----------------------------------------------------------------------------
if [[ -z "$HR_BIN_PATH" ]]; then
    cat <<EOF
Warning: 'hr' is not on PATH. The Hermes-router is the free-tier AI
load-balancer; you need to install it before this indicator can manage it.

Install with the upstream one-liner:

    curl -fsSL https://raw.githubusercontent.com/Shaf2665/Hermes-router/main/get.sh | bash

Or see https://github.com/Shaf2665/Hermes-router for details.

The indicator will still install and run, but it won't be able to
start/stop the router until 'hr' is on PATH.
EOF
fi

# -----------------------------------------------------------------------------
# Auto-detect HERMES_ROUTER_HOST
# -----------------------------------------------------------------------------
# The router's own .env (installed at ~/.local/share/hermes-router/.env by
# the upstream one-liner) is the source of truth. If that doesn't exist or
# doesn't have HOST=, fall back to the user's Tailscale IPv4 address. Final
# fallback: localhost.
DETECTED_ROUTER_HOST="$(grep -E '^HOST=' "$HOME/.local/share/hermes-router/.env" 2>/dev/null \
    | head -1 | cut -d= -f2 || true)"
if [[ -z "$DETECTED_ROUTER_HOST" ]]; then
    DETECTED_ROUTER_HOST="$(tailscale ip -4 2>/dev/null | head -1 || true)"
fi
HERMES_ROUTER_HOST="${HERMES_ROUTER_HOST:-${DETECTED_ROUTER_HOST:-localhost}}"
echo "Hermes-router host: $HERMES_ROUTER_HOST"

# -----------------------------------------------------------------------------
# Auto-disable auto-start if the router is already running
# -----------------------------------------------------------------------------
# The router is managed by a unit file if `hr service install` was run, OR
# if the router is already listening on its port (started manually, or as
# a long-running detached process). In either case, the indicator should
# only supervise — not auto-start, which would race for port 8319.
ROUTER_ALREADY_RUNNING=false
if [[ -f "$HOME/.config/systemd/user/hermes-router.service" ]]; then
    ROUTER_ALREADY_RUNNING=true
    echo "Detected hermes-router.service — auto-start disabled to avoid port race."
elif ss -tln 2>/dev/null | grep -q ':8319 '; then
    ROUTER_ALREADY_RUNNING=true
    echo "Detected router already listening on port 8319 — auto-start disabled."
fi

if [[ "$ROUTER_ALREADY_RUNNING" == "true" ]]; then
    AUTO_START="0"
else
    AUTO_START="1"
fi

# -----------------------------------------------------------------------------
# Detect hermes-gateway.service
# -----------------------------------------------------------------------------
if [[ -f "$HOME/.config/systemd/user/hermes-gateway.service" ]]; then
    WANTED_BY="hermes-gateway.service"
    SYSTEMD_WANTS_DIR="$SYSTEMD_USER_DIR/hermes-gateway.service.wants"
    echo "Detected hermes-gateway.service — indicator will start alongside it."
else
    WANTED_BY="default.target"
    SYSTEMD_WANTS_DIR="$SYSTEMD_USER_DIR/default.target.wants"
    echo "No hermes-gateway.service found — indicator will start at every login."
fi

echo
echo "Installing to PREFIX=$PREFIX"
echo "  bin:        $BIN_DIR"
echo "  apps:       $APPS_DIR"
echo "  autostart:  $AUTOSTART_DIR"
echo "  icons:      $ICON_DIR"
echo "  systemd:    $SYSTEMD_USER_DIR/hermes-router-indicator.service"

mkdir -p "$BIN_DIR" "$APPS_DIR" "$AUTOSTART_DIR" "$ICON_DIR" "$SVG_DIR" "$SYSTEMD_WANTS_DIR"

# Locate the indicator console-script. Check three places, in order:
#   1. ~/.local/bin/        (the `pip install --user` location)
#   2. <REPO>/.venv/bin/    (the python -m venv install location)
#   3. None — fall back to a wrapper shim that uses $INDICATOR_PY
#      (chosen above) to run the indicator directly from the repo source.
#      This makes ./install.sh work without a `pip install --user` step
#      on systems where pip is unavailable (Ubuntu 24.04+ ships
#      without pip by default).
#
# We use `readlink -e` (which returns nothing for broken symlinks) so
# we don't get tricked by a stale self-symlink from a previous failed
# install.
INDICATOR_BIN=""
if [[ -n "$(readlink -e "$HOME/.local/bin/hermes-router-indicator" 2>/dev/null)" ]]; then
    INDICATOR_BIN="$HOME/.local/bin/hermes-router-indicator"
elif [[ -n "$(readlink -e "$REPO_ROOT/.venv/bin/hermes-router-indicator" 2>/dev/null)" ]]; then
    INDICATOR_BIN="$REPO_ROOT/.venv/bin/hermes-router-indicator"
fi

if [[ -n "$INDICATOR_BIN" ]]; then
    # Only create the symlink if the source is actually somewhere different
    # from the destination. If both are ~/.local/bin/hermes-...-indicator
    # (the pip --user case with default PREFIX), `ln -sf A A` would
    # create a self-referencing symlink that systemd then fails to open.
    if [[ "$(readlink -f "$INDICATOR_BIN" 2>/dev/null || echo "$INDICATOR_BIN")" \
            != "$(readlink -f "$BIN_DIR/hermes-router-indicator" 2>/dev/null || echo "$BIN_DIR/hermes-router-indicator")" ]]; then
        ln -sf "$INDICATOR_BIN" "$BIN_DIR/hermes-router-indicator"
    fi
else
    # Create a wrapper shim. See the matching comment in the Mnemosyne
    # install.sh for the design rationale.
    cat > "$BIN_DIR/hermes-router-indicator" <<PYEOF
#!/usr/bin/env python3
"""Auto-generated shim - runs the Router indicator from $REPO_ROOT.

Uses the python interpreter that has hermes-tray-lib on the path; this
is the venv's python if a venv was created, else the system python
(which only works if hermes-tray-lib is system-wide installable).
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path("$REPO_ROOT") / "src"))
from hermes_router_tray.__main__ import main
sys.exit(main())
PYEOF
    chmod +x "$BIN_DIR/hermes-router-indicator"
    echo "Created wrapper shim at $BIN_DIR/hermes-router-indicator"
    echo "(no console script found; shim uses $INDICATOR_PY from repo source)"
fi

# Render .desktop templates
sed "s|__EXEC_LINE__|$EXEC_LINE|g" \
    "$REPO_ROOT/share/applications/hermes-router.desktop.in" \
    > "$APPS_DIR/hermes-router.desktop"

sed "s|__EXEC_LINE__|$EXEC_LINE|g" \
    "$REPO_ROOT/share/autostart/hermes-router-autostart.desktop.in" \
    > "$AUTOSTART_DIR/hermes-router-autostart.desktop"

# Render and install systemd service
sed \
    -e "s|__EXEC_LINE__|$EXEC_LINE|g" \
    -e "s|__HERMES_ROUTER_HOST__|$HERMES_ROUTER_HOST|g" \
    -e "s|__WANTED_BY__|$WANTED_BY|g" \
    "$REPO_ROOT/share/systemd/hermes-router-indicator.service.in" \
    > "$SYSTEMD_USER_DIR/hermes-router-indicator.service"

# Inject AUTO_START override (if needed) as a second Environment= line
if [[ "$AUTO_START" == "0" ]]; then
    sed -i "s|^Environment=\"HERMES_ROUTER_HOST=.*$|&\nEnvironment=\"HERMES_ROUTER_AUTO_START=0\"|" \
        "$SYSTEMD_USER_DIR/hermes-router-indicator.service"
fi

# Symlink into the WantedBy target
ln -sf "$SYSTEMD_USER_DIR/hermes-router-indicator.service" \
    "$SYSTEMD_WANTS_DIR/hermes-router-indicator.service"

# Copy icons (skip if not yet generated — user regenerates later)
cp -n "$ICON_DIR"/hermes-router-*.png "$ICON_DIR/" 2>/dev/null || true

# Refresh caches (best-effort)
command -v update-desktop-database >/dev/null && \
    update-desktop-database "$APPS_DIR" 2>/dev/null || true
command -v gtk-update-icon-cache >/dev/null && \
    gtk-update-icon-cache -f -t "$SHARE_DIR/icons/hicolor" 2>/dev/null || true

echo
echo "Installed."
echo
echo "Next steps:"
if [[ -d "$HOME/.config/systemd/user" ]]; then
    echo "  1. Reload systemd:    systemctl --user daemon-reload"
    echo "  2. Enable & start:    systemctl --user enable --now hermes-router-indicator.service"
    echo
    echo "  To check status:      systemctl --user status hermes-router-indicator.service"
    echo "  To view logs:         journalctl --user -u hermes-router-indicator -f"
fi
echo "  - If icons are missing, regenerate them:"
echo "      cd $REPO_ROOT"
echo "      python3 scripts/make-text-icon.py"
echo "      python3 scripts/make-status-icons.py"
