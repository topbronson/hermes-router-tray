"""hermes-router-tray: tray indicator for the Hermes-router load-balancer.

This is a thin wrapper around the shared :mod:`hermes_tray` library. It
supplies the router-specific :class:`Config` and a port-listening
:class:`LivenessProbe`, then delegates everything else to the library.
"""

from __future__ import annotations

from pathlib import Path

from hermes_tray import Config

__all__ = ["make_config"]


def make_config() -> Config:
    """Build the :class:`Config` for the Hermes-router indicator.

    The defaults assume ``hr`` is on PATH (installed via the upstream
    one-liner). The host is auto-detected from
    ``~/.local/share/hermes-router/.env`` at install time; the
    ``HERMES_ROUTER_HOST`` env var takes precedence.
    """
    return Config(
        name="router",
        title="Hermes Router",
        bin="hr",
        subcommand=("start",),
        host="localhost",
        port=8319,
        url="http://localhost:8319/dashboard",
        icon_dir=Path("~/.local/share/icons/hicolor/256x256/apps").expanduser(),
        icon_fallback="hermes-router-circle-64.png",
        cwd="~/.local/share/hermes-router",
    )
