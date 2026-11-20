#!/usr/bin/env python3
"""Builds the first App Store screenshot (the "hero") at 1320x2868 (6.9").

    python3 tool/compose_store_hero.py [--theme green|paper|ink]

Same layout as the "App Store screenshot 1" board on the brand canvas: the
icon and name, a headline, one line of copy, and the framed Home screen from
`make capture-screens` on an iPhone 17 Pro Max simulator. Needs Pillow and
macOS (text uses SF Pro). Writes branding/app_store_hero_<theme>.png with no
alpha channel, as App Store Connect requires.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
W, H = 1320, 2868
SS = 2  # draw at 2x, then downsample
FONT = "/System/Library/Fonts/SFNS.ttf"
SCREEN = ROOT / "screenshots/framed/iphone 17 pro max/08_home.png"
ICON = ROOT / "branding/icon_1024.png"

THEMES = {
    "green": {"bg": (29, 122, 82), "ink": (250, 249, 246), "soft": (212, 238, 223)},
    "paper": {"bg": (244, 242, 237), "ink": (21, 23, 26), "soft": (74, 78, 84)},
    "ink": {"bg": (21, 23, 26), "ink": (250, 249, 246), "soft": (185, 189, 194)},
}

HEADLINE = "Know where every buck goes."
SUBLINE = "Budget, invest and split bills, all in one line."


def font(px: float, weight: int) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(FONT, round(px * SS))
    f.set_variation_by_axes([100, 96, 400, weight])  # width, optical size, GRAD, weight
    return f


def width(text: str, f: ImageFont.FreeTypeFont, tracking: float) -> float:
    return f.getlength(text) + tracking * SS * max(0, len(text) - 1)


def draw_tracked(d: ImageDraw.ImageDraw, x: float, y: float, text: str, f, fill, tracking: float):
    """Draws text with letter-spacing, keeping the font's kerning."""
    for i, ch in enumerate(text):
        d.text((x + f.getlength(text[:i]) + tracking * SS * i, y), ch, font=f, fill=fill)


def wrap(text: str, f, tracking: float, max_w: float) -> list[str]:
    lines, line = [], ""
    for word in text.split():
        trial = f"{line} {word}".strip()
        if width(trial, f, tracking) <= max_w * SS or not line:
            line = trial
        else:
            lines.append(line)
            line = word
    return lines + [line]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--theme", choices=THEMES, default="green")
    theme = THEMES[parser.parse_args().theme]

    img = Image.new("RGB", (W * SS, H * SS), theme["bg"])
    d = ImageDraw.Draw(img)
    margin = 110
    y = 200

    # Icon and name, centered as one row.
    icon_px = 104
    label = font(52, 800)
    label_track = -0.015 * 52
    label_w = width("Three Bucks", label, label_track)
    row_w = icon_px * SS + 24 * SS + label_w
    x = (W * SS - row_w) / 2
    icon = Image.open(ICON).convert("RGBA").resize((icon_px * SS, icon_px * SS), Image.LANCZOS)
    mask = Image.new("L", icon.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, icon.width - 1, icon.height - 1], radius=round(icon_px * 0.2237) * SS, fill=255
    )
    img.paste(icon, (round(x), y * SS), mask)
    asc, desc = label.getmetrics()
    draw_tracked(
        d,
        x + icon_px * SS + 24 * SS,
        y * SS + (icon_px * SS - (asc + desc)) / 2,
        "Three Bucks",
        label,
        theme["soft"],
        label_track,
    )
    y += icon_px + 44

    # Headline: 128px, tight line height. SF Pro needs less negative tracking
    # than Inter on the canvas, or words run together.
    head = font(128, 800)
    head_track = -0.018 * 128
    for line in wrap(HEADLINE, head, head_track, W - 2 * margin):
        lw = width(line, head, head_track)
        draw_tracked(d, (W * SS - lw) / 2, y * SS, line, head, theme["ink"], head_track)
        y += 128
    y += 44 - 8

    sub = font(50, 500)
    for line in wrap(SUBLINE, sub, 0, W - 2 * margin):
        lw = width(line, sub, 0)
        d.text(((W * SS - lw) / 2, y * SS), line, font=sub, fill=theme["soft"])
        y += 65

    # Framed Home screen, 1100 wide, running off the bottom edge.
    screen = Image.open(SCREEN).convert("RGBA")
    sw = 1100 * SS
    screen = screen.resize((sw, round(sw * screen.height / screen.width)), Image.LANCZOS)
    top = y + 100
    base = img.convert("RGBA")
    base.alpha_composite(screen, (margin * SS, top * SS))

    out = base.convert("RGB").resize((W, H), Image.LANCZOS)
    path = ROOT / "branding" / f"app_store_hero_{parser.parse_args().theme}.png"
    out.save(path, optimize=True)
    print(f"{path.relative_to(ROOT)}  {out.width}x{out.height} {out.mode}")


if __name__ == "__main__":
    main()
