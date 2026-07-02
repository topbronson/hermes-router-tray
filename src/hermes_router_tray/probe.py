"""Liveness probe for the Hermes-router.

The router serves a web dashboard on its bind port. If the port is
accepting connections, the router is considered alive. The probe is
intentionally simple — it does not check the dashboard HTML body
because the router's ``/`` endpoint always serves something, even when
key rotation is in flight.
"""

from __future__ import annotations

from hermes_tray import Config, LivenessProbe, PortListeningProbe

__all__ = ["make_probe"]


def make_probe(config: Config) -> LivenessProbe:
    """Return the liveness probe for the Hermes-router."""
    return PortListeningProbe(host=config.host, port=config.port)
