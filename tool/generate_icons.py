#!/usr/bin/env python3
"""Draws the Three Bucks icon (three fanned bills with a $) and writes every
app and store icon from that one drawing.

    python3 tool/generate_icons.py

Needs Pillow and macOS (the $ uses the system font, SF Pro). Writes:

- branding/           masters and store icons (App Store 1024, Play 512)
- ios/                AppIcon.appiconset, every size Xcode asks for
- android/            legacy launcher icons, adaptive foreground + monochrome
- macos/              AppIcon.appiconset in the macOS rounded-square style

The drawing matches logo E on the brand canvas: a 100x100 grid, bills
50x30 with 5 corner radius, rotated about (50, 58).
"""

from __future__ import annotations

import json
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SS = 4  # draw this many times larger, then downsample, for smooth edges

PAPER = (250, 249, 246, 255)
GREEN = (29, 122, 82, 255)
BLUE = (64, 87, 214, 255)
AMBER = (183, 121, 31, 255)
WHITE = (255, 255, 255, 255)
CLEAR = (0, 0, 0, 0)

# Back to front: (color, rotation in degrees, clockwise like SVG).
BILLS = [(AMBER, -18), (BLUE, -6), (GREEN, 7)]
PIVOT = (50, 58)
FONT = "/System/Library/Fonts/SFNS.ttf"


def _font(px: float) -> ImageFont.FreeTypeFont:
    font = ImageFont.truetype(FONT, max(1, round(px)))
    # Axes: Width, Optical size, GRAD, Weight.
    font.set_variation_by_axes([100, 96, 400, 800])
    return font


class Grid:
    """Maps the 100x100 design grid onto a canvas of `size` pixels."""

    def __init__(self, size: int):
        self.px = size * SS
        self.k = self.px / 100
        self.offset = 0

    def p(self, x: float, y: float) -> tuple[float, float]:
        return (self.offset + x * self.k, self.offset + y * self.k)

    def box(self, x0, y0, x1, y1):
        return [self.p(x0, y0), self.p(x1, y1)]

    def layer(self) -> Image.Image:
        return Image.new("RGBA", (self.px, self.px), CLEAR)

    def rotate(self, img: Image.Image, degrees: float) -> Image.Image:
        return img.rotate(-degrees, resample=Image.BICUBIC, center=self.p(*PIVOT))


def _bill(g: Grid, color, grow: float = 0) -> Image.Image:
    img = g.layer()
    ImageDraw.Draw(img).rounded_rectangle(
        g.box(25 - grow, 37 - grow, 75 + grow, 67 + grow), radius=(5 + grow) * g.k, fill=color
    )
    return img


ART = 1024  # the drawing is made once at this size (times SS), then fitted


def _color_art() -> Image.Image:
    g = Grid(ART)
    canvas = g.layer()
    for i, (color, degrees) in enumerate(BILLS):
        bill = _bill(g, color)
        if i == len(BILLS) - 1:
            # Front bill: a faint inner border and the $.
            border = g.layer()
            ImageDraw.Draw(border).rounded_rectangle(
                g.box(28.5, 40.5, 71.5, 63.5),
                radius=3 * g.k,
                outline=(250, 249, 246, 90),
                width=max(1, round(1.2 * g.k)),
            )
            bill.alpha_composite(border)
            ImageDraw.Draw(bill).text(g.p(50, 53), "$", font=_font(22 * g.k), fill=PAPER, anchor="mm")
        canvas.alpha_composite(g.rotate(bill, degrees))
    return canvas


def _mono_art() -> Image.Image:
    g = Grid(ART)
    canvas = g.layer()
    stroke = max(1, round(3 * g.k))
    for color, degrees in BILLS[:-1]:
        outline = g.layer()
        ImageDraw.Draw(outline).rounded_rectangle(
            g.box(25, 37, 75, 67), radius=5 * g.k, outline=WHITE, width=stroke
        )
        canvas.alpha_composite(g.rotate(outline, degrees))
    color, degrees = BILLS[-1]
    # Clear a gap around the front bill so it doesn't touch the outlines.
    halo = g.rotate(_bill(g, WHITE, grow=2.5), degrees).getchannel("A")
    canvas = Image.composite(g.layer(), canvas, halo)
    front = _bill(g, WHITE)
    ImageDraw.Draw(front).text(g.p(50, 53), "$", font=_font(22 * g.k), fill=CLEAR, anchor="mm")
    canvas.alpha_composite(g.rotate(front, degrees))
    return canvas


_cache: dict[str, Image.Image] = {}


def _art(kind: str) -> Image.Image:
    if kind not in _cache:
        _cache[kind] = _color_art() if kind == "color" else _mono_art()
    return _cache[kind]


def _fit(kind: str, size: int, width: float, background) -> Image.Image:
    """Centers the drawing by its visible bounds, `width` of the canvas wide.
    Both versions use the color drawing's bounds, so they line up."""
    art = _art(kind)
    box = _art("color").getbbox()
    content = art.crop(box)
    w = round(size * SS * width)
    h = round(content.height * w / content.width)
    content = content.resize((w, h), Image.LANCZOS)
    big = size * SS
    canvas = Image.new("RGBA", (big, big), background or CLEAR)
    canvas.alpha_composite(content, ((big - w) // 2, (big - h) // 2))
    return canvas.resize((size, size), Image.LANCZOS)


# How wide the bills are, as a share of the canvas.
FULL = 0.70  # iOS, Play, macOS: the whole icon is visible
ADAPTIVE = 0.46  # Android adaptive layers: 108dp, keep inside the 66dp safe zone


def bills(size: int, width: float = FULL, background=PAPER) -> Image.Image:
    """The full-color icon, on `background` (None for transparent)."""
    return _fit("color", size, width, background)


def monochrome(size: int, width: float = ADAPTIVE) -> Image.Image:
    """One-color version for Android 13+ themed icons: the back bills as
    outlines, the front bill solid with the $ cut out."""
    return _fit("mono", size, width, None)


def rounded(img: Image.Image, radius: float, inset: float = 0, shadow: bool = False) -> Image.Image:
    """Cuts `img` to a rounded square, optionally inset with a soft shadow
    (macOS style). `radius` and `inset` are fractions of the size."""
    size = img.width
    big = size * SS
    body = round(big * (1 - 2 * inset))
    mask = Image.new("L", (body, body), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, body - 1, body - 1], radius=radius * big, fill=255)
    out = Image.new("RGBA", (big, big), CLEAR)
    pos = round(big * inset)
    if shadow:
        from PIL import ImageFilter

        shade = Image.new("RGBA", (big, big), CLEAR)
        shade.paste((0, 0, 0, 70), (pos, pos + round(big * 0.012)), mask)
        out.alpha_composite(shade.filter(ImageFilter.GaussianBlur(big * 0.012)))
    art = img.resize((body, body), Image.LANCZOS)
    out.paste(art, (pos, pos), mask)
    return out.resize((size, size), Image.LANCZOS)


def opaque(img: Image.Image) -> Image.Image:
    """App Store and iOS icons must not have an alpha channel."""
    return img.convert("RGB")


def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)
    print(f"  {path.relative_to(ROOT)}  {img.width}x{img.height}")


def main() -> None:
    master = bills(1024)

    print("branding/")
    brand = ROOT / "branding"
    save(master, brand / "icon_1024.png")
    save(opaque(master), brand / "app_store_icon_1024.png")
    save(opaque(bills(512)), brand / "play_store_icon_512.png")
    save(bills(432, ADAPTIVE, background=None), brand / "android_foreground_432.png")
    save(monochrome(432), brand / "android_monochrome_432.png")

    print("ios/")
    ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((ios / "Contents.json").read_text())
    done = set()
    for image in contents["images"]:
        name = image["filename"]
        if name in done:
            continue
        done.add(name)
        points = float(image["size"].split("x")[0])
        px = round(points * int(image["scale"].rstrip("x")))
        save(opaque(bills(px) if px != 1024 else master), ios / name)

    print("android/")
    res = ROOT / "android/app/src/main/res"
    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    for name, factor in densities.items():
        # Legacy (pre-Android 8) launchers: a rounded square with a little air.
        save(rounded(bills(round(48 * factor)), radius=0.2, inset=0.04), res / f"mipmap-{name}/ic_launcher.png")
        # Adaptive layers are 108dp; launchers show the middle 72dp.
        layer = round(108 * factor)
        save(bills(layer, ADAPTIVE, background=None), res / f"mipmap-{name}/ic_launcher_foreground.png")
        save(monochrome(layer), res / f"mipmap-{name}/ic_launcher_monochrome.png")
    adaptive = res / "mipmap-anydpi-v26/ic_launcher.xml"
    adaptive.parent.mkdir(parents=True, exist_ok=True)
    adaptive.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>\n'
        "</adaptive-icon>\n"
    )
    print(f"  {adaptive.relative_to(ROOT)}")
    colors = res / "values/ic_launcher_background.xml"
    colors.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<resources>\n"
        '    <color name="ic_launcher_background">#FAF9F6</color>\n'
        "</resources>\n"
    )
    print(f"  {colors.relative_to(ROOT)}")

    print("macos/")
    mac = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    for px in (16, 32, 64, 128, 256, 512, 1024):
        # macOS icons sit on an 824/1024 rounded square with a soft shadow.
        save(rounded(bills(px), radius=0.185 * 824 / 1024, inset=100 / 1024, shadow=px >= 64), mac / f"app_icon_{px}.png")


if __name__ == "__main__":
    os.chdir(ROOT)
    main()
