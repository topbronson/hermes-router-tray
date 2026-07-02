"""Tests for the Router-specific LivenessProbe factory."""

from __future__ import annotations

from hermes_tray import PortListeningProbe

from hermes_router_tray.config import make_config
from hermes_router_tray.probe import make_probe


def test_probe_is_port_listening() -> None:
    cfg = make_config()
    probe = make_probe(cfg)
    assert isinstance(probe, PortListeningProbe)
    assert probe.host == cfg.host
    assert probe.port == cfg.port
