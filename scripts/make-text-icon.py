#!/usr/bin/env python3
"""Generate the 'HR' text-based tray icon for hermes-router-tray.

Renders bold white 'HR' letters centered on a circular dark-slate-blue
background, then outputs all required sizes to the icon directory. The
status-dot overlay is added by ``make-status-icons.py``.

Honors ``HERMES_ROUTER_ICON_DIR`` for the output directory and
``HERMES_ROUTER_FONT_PATH`` to override the font (default: DejaVuSans-Bold).
"""
from __future__ import annotations

import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT_DIR = Path(
    os.environ.get(
        "HERMES_ROUTER_ICON_DIR",
        str(Path("~/.local/share/icons/hicolor/256x256/apps").expanduser()),
    )
)
OUT_DIR.mkdir(parents=True, exist_ok=True)

FONT_PATH = os.environ.get(
    "HERMES_ROUTER_FONT_PATH",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
)

SIZES = [32, 48, 64, 96, 128, 256]
BG_COLOR = (52, 73, 94, 255)  # dark slate blue
TEXT_COLOR = (255, 255, 255, 255)


def render(size: int) -> Image.Image:
    """Render the ``size``-pixel 'HR' badge."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    bg = Image.new("RGBA", (size, size), BG_COLOR)
    img.paste(bg, (0, 0), mask)

    draw = ImageDraw.Draw(img)
    font_size = max(12, int(size * 0.55))
    try:
        font = ImageFont.truetype(FONT_PATH, font_size)
    except OSError:
        font = ImageFont.load_default()

    text = "HR"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (size - tw) / 2 - bbox[0]
    y = (size - th) / 2 - bbox[1]
    draw.text((x, y), text, fill=TEXT_COLOR, font=font)
    return img


def main() -> int:
    for size in SIZES:
        out = OUT_DIR / f"hermes-router-circle-{size}.png"
        render(size).save(out, "PNG")
        print(f"wrote {out}")
    canon = OUT_DIR / "hermes-router-circle.png"
    render(256).save(canon, "PNG")
    print(f"wrote {canon}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
