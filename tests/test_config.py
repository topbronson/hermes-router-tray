"""Tests for the Router-specific Config factory."""

from __future__ import annotations

from hermes_router_tray.config import make_config


def test_config_defaults() -> None:
    cfg = make_config()
    assert cfg.name == "router"
    assert cfg.title == "Hermes Router"
    assert cfg.bin == "hr"
    assert cfg.subcommand == ("start",)
    assert cfg.port == 8319


def test_config_icon_fallback() -> None:
    cfg = make_config()
    assert cfg.icon_fallback == "hermes-router-circle-64.png"
    assert str(cfg.icon_fallback_path).endswith("hermes-router-circle-64.png")


def test_config_url_points_at_dashboard() -> None:
    cfg = make_config()
    # /dashboard is the router's web monitoring UI
    assert "/dashboard" in cfg.url
