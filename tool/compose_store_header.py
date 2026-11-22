#!/usr/bin/env python3
"""Builds the App Store creative assets (product page header art).

    python3 tool/compose_store_header.py [--theme paper|ink] [--preview DIR]

Writes, with no alpha channel as App Store Connect requires:

- branding/app_store_header_<theme>.png      3840x1646 (21:9), product page header
- branding/app_store_universal_<theme>.png   5244x2950 (16:9), header and search

The icon's three fanned bills sit large inside Apple's "art safe area", and
smaller bills drift across the rest of the canvas as background. No text, so
there is nothing to localize. --preview also writes copies with the safe
area outlined, to check against the preview in App Store Connect.
"""

from __future__ import annotations

import argparse
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

import generate_icons as icons

ROOT = Path(__file__).resolve().parent.parent

# (name, width, height, safe area x, y, w, h) from Apple's creative assets spec.
ASSETS = [
    ("app_store_header", 3840, 1646, (1097, 493, 1646, 661)),
    ("app_store_universal", 5244, 2950, (1921, 660, 1402, 962)),
]

THEMES = {
    "paper": {
        "bg": (250, 249, 246),
        "bills": [(226, 241, 232), (231, 235, 255), (251, 240, 220)],  # soft lived/invested/earned
        "shadow": (21, 23, 26, 60),
    },
    "ink": {
        "bg": (21, 23, 26),
        "bills": [(22, 48, 31), (29, 35, 64), (46, 36, 18)],
        "shadow": (0, 0, 0, 140),
    },
}


def focal_art() -> Image.Image:
    """The icon's bills, cropped to their visible bounds, transparent."""
    art = icons._art("color")
    return art.crop(art.getbbox())


def small_bill(width: int, color, angle: float) -> Image.Image:
    """One background bill: a soft rounded rectangle with an inner border."""
    s = 2  # draw at 2x for smooth edges after rotation
    w, h = width * s, round(width * 0.6) * s
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=h * 0.17, fill=color + (255,))
    inset = h * 0.12
    lighter = tuple(min(255, round(c + (255 - c) * 0.35)) if sum(color) > 380 else round(c * 1.35) for c in color)
    d.rounded_rectangle(
        [inset, inset, w - inset, h - inset], radius=h * 0.1, outline=lighter + (255,), width=max(2, round(h * 0.035))
    )
    img = img.resize((w // s, h // s), Image.LANCZOS)
    return img.rotate(angle, resample=Image.BICUBIC, expand=True)


def scatter(width: int, height: int, safe, rng: random.Random):
    """Places background bills around the focal art, avoiding each other
    and leaving a clear oval around the safe area."""
    sx, sy, sw, sh = safe
    cx, cy = sx + sw / 2, sy + sh / 2
    clear_rx, clear_ry = sw * 0.72, sh * 0.82
    unit = min(width, height)
    placed = []
    for _ in range(4000):
        if len(placed) >= 46:
            break
        w = rng.uniform(0.11, 0.2) * unit
        x, y = rng.uniform(-0.05, 1.05) * width, rng.uniform(-0.08, 1.08) * height
        if ((x - cx) / clear_rx) ** 2 + ((y - cy) / clear_ry) ** 2 < 1:
            continue
        if any(math.hypot(x - px, y - py) < (w + pw) * 0.62 for px, py, pw, _ in placed):
            continue
        placed.append((x, y, w, rng.uniform(-35, 35)))
    return placed


def build(width: int, height: int, safe, theme: dict, seed: int) -> Image.Image:
    rng = random.Random(seed)
    img = Image.new("RGBA", (width, height), theme["bg"] + (255,))
    for i, (x, y, w, angle) in enumerate(scatter(width, height, safe, rng)):
        bill = small_bill(round(w), theme["bills"][i % 3], angle)
        img.alpha_composite(bill, (round(x - bill.width / 2), round(y - bill.height / 2)))

    # Focal bills: as large as fits in the safe area with a little air.
    sx, sy, sw, sh = safe
    art = focal_art()
    scale = min(sw * 0.9 / art.width, sh * 0.92 / art.height)
    art = art.resize((round(art.width * scale), round(art.height * scale)), Image.LANCZOS)
    ax, ay = round(sx + (sw - art.width) / 2), round(sy + (sh - art.height) / 2)
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    shadow.paste(theme["shadow"], (ax, ay + round(art.height * 0.06)), art.getchannel("A"))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(art.height * 0.06)))
    img.alpha_composite(art, (ax, ay))
    return img.convert("RGB")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--theme", choices=THEMES, default="paper")
    parser.add_argument("--preview", type=Path, help="also write copies with the safe area outlined here")
    args = parser.parse_args()
    for name, w, h, safe in ASSETS:
        out = build(w, h, safe, THEMES[args.theme], seed=3)
        path = ROOT / "branding" / f"{name}_{args.theme}.png"
        out.save(path, optimize=True)
        print(f"{path.relative_to(ROOT)}  {out.width}x{out.height} {out.mode}")
        if args.preview:
            args.preview.mkdir(parents=True, exist_ok=True)
            p = out.copy()
            sx, sy, sw, sh = safe
            ImageDraw.Draw(p).rectangle([sx, sy, sx + sw, sy + sh], outline=(230, 40, 40), width=6)
            p.thumbnail((1600, 1600))
            p.save(args.preview / f"{name}_{args.theme}.png")


if __name__ == "__main__":
    main()
