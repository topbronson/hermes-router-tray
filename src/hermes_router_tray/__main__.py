"""hermes-router-tray — top-level entry point.

Run with::

    python -m hermes_router_tray
"""

from __future__ import annotations

import sys

from hermes_tray import main as lib_main

from hermes_router_tray.config import make_config
from hermes_router_tray.probe import make_probe


def main() -> int:
    """Entry point for the ``hermes-router-indicator`` console script."""
    cfg = make_config()
    return lib_main(cfg, make_probe(cfg))


if __name__ == "__main__":
    sys.exit(main())
