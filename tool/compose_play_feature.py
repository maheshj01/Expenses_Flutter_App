#!/usr/bin/env python3
"""Builds the "Fanned screens" Google Play feature graphic at 1024x500.

    python3 tool/compose_play_feature.py

Same layout as "Feature graphic 2 · Fanned screens" on the brand canvas: the
icon, name, headline and copy on the left, three framed app screens fanned
like the bills in the icon on the right. Uses the iPhone 17 Pro Max captures
from `make capture-screens`. Writes branding/play_feature_graphic_fanned.png
with no alpha channel, as Play Console requires.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

from compose_store_hero import ICON, SS, draw_tracked, font, wrap

ROOT = Path(__file__).resolve().parent.parent
W, H = 1024, 500
SCREENS = ROOT / "screenshots/framed/iphone 17 pro max"
PAPER = (250, 249, 246)
INK = (21, 23, 26)
MUTED = (74, 78, 84)

# (file, left, top, rotation in degrees clockwise), back to front.
FAN = [
    ("11_history.png", 556, 118, -12),
    ("24_split_entry.png", 784, 118, 12),
    ("16_people.png", 670, 70, 0),
]
PHONE_W = 200


def main() -> None:
    img = Image.new("RGBA", (W * SS, H * SS), PAPER + (255,))
    d = ImageDraw.Draw(img)

    # Left column, measured first so it can be centered vertically.
    left, col_w = 72, 466
    label = font(28, 800)
    label_track = -0.015 * 28
    head = font(50, 800)
    head_track = -0.018 * 50
    head_lines = wrap("Track spending in one line.", head, head_track, col_w)
    body = font(19, 500)
    # Broken by hand so no single word is left on its own line.
    body_lines = ["Budgets, every year at a glance,", "and bills split with friends."]
    icon_px, gap = 56, 22
    head_lh, body_lh = round(50 * 1.04), round(19 * 1.45)
    total = icon_px + gap + head_lh * len(head_lines) + gap + body_lh * len(body_lines)
    y = (H - total) / 2

    icon = Image.open(ICON).convert("RGBA").resize((icon_px * SS, icon_px * SS), Image.LANCZOS)
    mask = Image.new("L", icon.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, icon.width - 1, icon.height - 1], radius=round(icon_px * 0.2237) * SS, fill=255
    )
    # The icon's paper background matches the page, so give the tile an edge.
    shade = Image.new("RGBA", img.size, (0, 0, 0, 0))
    shade.paste((21, 23, 26, 40), (left * SS, round(y * SS) + 3 * SS), mask)
    img.alpha_composite(shade.filter(ImageFilter.GaussianBlur(5 * SS)))
    img.paste(icon, (left * SS, round(y * SS)), mask)
    ImageDraw.Draw(img).rounded_rectangle(
        [left * SS, round(y * SS), left * SS + icon.width - 1, round(y * SS) + icon.height - 1],
        radius=round(icon_px * 0.2237) * SS,
        outline=(230, 226, 218, 255),
        width=SS,
    )
    asc, desc = label.getmetrics()
    draw_tracked(
        d,
        (left + icon_px + 14) * SS,
        y * SS + (icon_px * SS - (asc + desc)) / 2,
        "Three Bucks",
        label,
        INK,
        label_track,
    )
    y += icon_px + gap
    for line in head_lines:
        draw_tracked(d, left * SS, y * SS, line, head, INK, head_track)
        y += head_lh
    y += gap
    for line in body_lines:
        d.text((left * SS, y * SS), line, font=body, fill=MUTED)
        y += body_lh

    # Phones, each rotated about its own center like CSS rotate().
    for name, x, top, degrees in FAN:
        phone = Image.open(SCREENS / name).convert("RGBA")
        pw = PHONE_W * SS
        ph = round(pw * phone.height / phone.width)
        phone = phone.resize((pw, ph), Image.LANCZOS)
        rotated = phone.rotate(-degrees, resample=Image.BICUBIC, expand=True)
        cx, cy = (x + PHONE_W / 2) * SS, top * SS + ph / 2
        img.alpha_composite(rotated, (round(cx - rotated.width / 2), round(cy - rotated.height / 2)))

    out = img.convert("RGB").resize((W, H), Image.LANCZOS)
    path = ROOT / "branding/play_feature_graphic_fanned.png"
    out.save(path, optimize=True)
    print(f"{path.relative_to(ROOT)}  {out.width}x{out.height} {out.mode}")


if __name__ == "__main__":
    main()
