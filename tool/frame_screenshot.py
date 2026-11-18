#!/usr/bin/env python3
"""Wraps raw device screenshots in a phone frame.

`adb screencap` returns the bare framebuffer, so the pictures that
tool/capture_screens.sh saves have no bezel, no rounded corners and no
shadow. This puts one around them in one of two ways:

* `--skin <name|path>` composites the shot into a real Android Emulator skin
  (the bezel the emulator window draws): `back.webp` behind the screen, the
  display offset from the skin's `layout` file, and the `mask.webp` overlay
  that shapes the corners and camera cutout. Names are looked up in the SDK's
  `skins/` folder (pixel_7, pixel_10_pro, ...). Foldable skins keep one
  sub-skin per posture; the one whose display matches the shot is used.
* `--skin ios` composites the shot into the bezel Xcode's Simulator draws
  around that device: the device type whose screen matches the shot's pixel
  size is looked up under /Library/Developer/CoreSimulator, its screen mask
  (corner radius) and DeviceKit chrome PDFs are rasterised at the device's
  scale with a small CoreGraphics helper (compiled on first use, needs Xcode),
  and the side buttons go where the Simulator puts them. The Dynamic Island
  is painted in when the capture lacks one (a physical iPhone's screenshot
  does; the Simulator already draws it); `--no-island` leaves it out.
* Without `--skin` (or with `--skin generic`) a neutral, device-agnostic
  frame is drawn instead: rounded screen corners, a dark bezel, side buttons,
  a punch hole in the status bar area and a soft drop shadow, all scaled from
  the screenshot's own size.

    python3 tool/frame_screenshot.py shot.png framed.png --skin pixel_7
    python3 tool/frame_screenshot.py screenshots/*.png --out-dir screenshots/framed

Needs Pillow (`python3 -m pip install pillow`).
"""
import argparse
import glob
import json
import os
import plistlib
import re
import subprocess
import sys
import tempfile

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError:  # pragma: no cover - reported to the caller
    sys.exit("frame_screenshot.py needs Pillow: python3 -m pip install pillow")

# Masks are drawn at this multiple and downsampled, which anti-aliases the
# curved edges that ImageDraw would otherwise leave jagged.
SUPERSAMPLE = 4


def _rounded_mask(size, radius):
    """Anti-aliased L-mode mask of a rounded rectangle filling `size`."""
    w, h = size
    s = SUPERSAMPLE
    big = Image.new("L", (w * s, h * s), 0)
    ImageDraw.Draw(big).rounded_rectangle(
        (0, 0, w * s - 1, h * s - 1), radius=radius * s, fill=255
    )
    return big.resize((w, h), Image.LANCZOS)


def _hex_rgb(value):
    value = value.lstrip("#")
    if len(value) != 6:
        raise argparse.ArgumentTypeError(f"expected #rrggbb, got {value!r}")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


def frame(shot, bezel_color=(20, 20, 20), shadow=True, buttons=True, hole=True):
    """Return a new RGBA image of `shot` inside a phone frame."""
    shot = shot.convert("RGB")
    w, h = shot.size

    # Everything scales with the screenshot width so a 1080px and a 1440px
    # capture of the same device end up looking identical when resized.
    bezel = round(w * 0.035)
    screen_radius = round(w * 0.09)
    frame_radius = screen_radius + bezel
    button_depth = round(w * 0.011) if buttons else 0
    pad = round(w * 0.08) if shadow else round(w * 0.02)

    frame_w, frame_h = w + 2 * bezel, h + 2 * bezel
    canvas_w = frame_w + 2 * pad + button_depth
    canvas_h = frame_h + 2 * pad
    fx, fy = pad, pad  # frame's top-left on the canvas
    canvas = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))

    if shadow:
        blur = w * 0.03
        offset_y = round(w * 0.02)
        layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        layer.paste(
            (0, 0, 0, 120),
            (fx, fy + offset_y, fx + frame_w, fy + offset_y + frame_h),
            _rounded_mask((frame_w, frame_h), frame_radius),
        )
        canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))

    body = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(body)

    if buttons:
        # Power and volume rocker on the right edge, Pixel style. Drawn first
        # so the body covers their inner half and they read as attached.
        button_color = tuple(min(255, c + 22) for c in bezel_color)
        x0 = fx + frame_w - 1
        x1 = x0 + button_depth
        for top, bottom in ((0.20, 0.27), (0.31, 0.44)):
            draw.rounded_rectangle(
                (x0, fy + round(frame_h * top), x1, fy + round(frame_h * bottom)),
                radius=max(2, button_depth // 3),
                fill=button_color + (255,),
            )

    body.paste(
        bezel_color + (255,),
        (fx, fy, fx + frame_w, fy + frame_h),
        _rounded_mask((frame_w, frame_h), frame_radius),
    )
    # Thin lighter rim so the frame edge reads against dark backgrounds.
    rim = tuple(min(255, c + 40) for c in bezel_color)
    draw.rounded_rectangle(
        (fx, fy, fx + frame_w - 1, fy + frame_h - 1),
        radius=frame_radius,
        outline=rim + (255,),
        width=max(1, round(w * 0.0015)),
    )
    canvas.alpha_composite(body)

    screen = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    screen.paste(shot, (fx + bezel, fy + bezel), _rounded_mask((w, h), screen_radius))
    canvas.alpha_composite(screen)

    if hole:
        # Centered punch-hole camera inside the status bar, where Android
        # keeps content clear of the real cutout.
        r = round(w * 0.012)
        cx = fx + bezel + w // 2
        cy = fy + bezel + round(h * 0.028)
        s = SUPERSAMPLE
        dot = Image.new("L", (4 * r * s, 4 * r * s), 0)
        ImageDraw.Draw(dot).ellipse((r * s, r * s, 3 * r * s, 3 * r * s), fill=255)
        dot = dot.resize((4 * r, 4 * r), Image.LANCZOS)
        canvas.paste((10, 10, 10, 255), (cx - 2 * r, cy - 2 * r), dot)

    return canvas


# --- Emulator skins ---------------------------------------------------------


def sdk_skin_dirs():
    """Candidate `skins/` folders, from $ANDROID_HOME and the usual defaults."""
    roots = [os.environ.get("ANDROID_HOME"), os.environ.get("ANDROID_SDK_ROOT")]
    home = os.path.expanduser("~")
    roots += [
        os.path.join(home, "Library", "Android", "sdk"),  # macOS
        os.path.join(home, "Android", "Sdk"),  # Linux
        os.path.join(home, "AppData", "Local", "Android", "Sdk"),  # Windows
    ]
    return [os.path.join(r, "skins") for r in roots if r]


def list_skins():
    """Skin names the SDK ships, one per line: `pixel_7`, and for foldables
    `pixel_fold/closed` style sub-skins. Empty when no SDK skins folder exists."""
    names = []
    for root in sdk_skin_dirs():
        if not os.path.isdir(root):
            continue
        for name in sorted(os.listdir(root)):
            skin = os.path.join(root, name)
            if not os.path.isdir(skin):
                continue
            if os.path.isfile(os.path.join(skin, "layout")):
                names.append(name)
            else:
                names += [
                    f"{name}/{sub}"
                    for sub in sorted(os.listdir(skin))
                    if os.path.isfile(os.path.join(skin, sub, "layout"))
                ]
    return names


def parse_layout(text):
    """Parse the emulator's brace-delimited `layout` format into nested dicts.

    Blocks (`name { ... }`) become dicts and `key value` lines become strings;
    numeric values are converted to int.
    """
    tokens = re.findall(r"\{|\}|[^\s{}]+", text)
    root, stack, i = {}, [], 0
    cur = root
    while i < len(tokens):
        tok = tokens[i]
        if tok == "}":
            cur = stack.pop()
            i += 1
        elif i + 1 < len(tokens) and tokens[i + 1] == "{":
            child = {}
            cur[tok] = child
            stack.append(cur)
            cur = child
            i += 2
        else:
            value = tokens[i + 1] if i + 1 < len(tokens) else ""
            cur[tok] = int(value) if re.fullmatch(r"-?\d+", value) else value
            i += 2
    return root


class Skin:
    """One emulator skin layout (portrait orientation) and its images."""

    def __init__(self, directory):
        self.directory = directory
        tree = parse_layout(open(os.path.join(directory, "layout")).read())
        parts = tree["parts"]
        display = parts["device"]["display"]
        self.display_size = (display["width"], display["height"])
        self.corner_radius = display.get("corner_radius", 0)

        layouts = tree["layouts"]
        # Unfolded foldable skins have no "portrait" layout; take the first.
        layout = layouts.get("portrait") or next(iter(layouts.values()))
        self.size = (layout["width"], layout["height"])
        offsets = {}
        for key, part in layout.items():
            if isinstance(part, dict) and "name" in part:
                offsets[part["name"]] = (part.get("x", 0), part.get("y", 0))
        dev_x, dev_y = offsets.get("device", (0, 0))
        self.display_pos = (dev_x + display.get("x", 0), dev_y + display.get("y", 0))

        # The background part is whichever non-device part carries an image;
        # skins call it "portrait" but that name is not guaranteed.
        self.background = None
        self.overlays = []  # (image path, position, stretch-to-display?)
        for name, part in parts.items():
            if name == "device" or not isinstance(part, dict):
                continue
            pos = offsets.get(name, (0, 0))
            if "background" in part and "image" in part["background"]:
                self.background = (os.path.join(directory, part["background"]["image"]), pos)
            fg = part.get("foreground", {})
            if "mask" in fg:
                # Mask is display-sized and sits over the screen.
                self.overlays.append((os.path.join(directory, fg["mask"]), None))
            onion = part.get("onion", {})
            if "image" in onion:
                # Onion images are drawn over the whole layout.
                self.overlays.append((os.path.join(directory, onion["image"]), pos))
            if self.background:
                break
        if self.background is None:
            raise ValueError(f"{directory}: layout has no background image")


def resolve_skin(spec, shot_size):
    """Return the Skin for `spec` (a directory or an SDK skin name).

    Foldable skins are a folder of sub-skins (`closed/`, `default/`, ...);
    the one whose display aspect ratio is closest to `shot_size` wins, so a
    folded capture lands in the cover-screen bezel and an unfolded one in the
    inner-screen bezel.
    """
    candidates = [spec] if os.path.isdir(spec) else [os.path.join(d, spec) for d in sdk_skin_dirs()]
    directory = next((c for c in candidates if os.path.isdir(c)), None)
    if directory is None:
        searched = ", ".join(sdk_skin_dirs())
        raise FileNotFoundError(f"skin {spec!r} not found (searched {searched})")
    if os.path.isfile(os.path.join(directory, "layout")):
        return Skin(directory)
    subs = sorted(
        os.path.join(directory, d)
        for d in os.listdir(directory)
        if os.path.isfile(os.path.join(directory, d, "layout"))
    )
    if not subs:
        raise FileNotFoundError(f"{directory} has no layout file")
    skins = [Skin(d) for d in subs]
    if shot_size[0] and shot_size[1]:
        aspect = shot_size[0] / shot_size[1]
        return min(skins, key=lambda k: abs(k.display_size[0] / k.display_size[1] - aspect))
    return skins[0]


def frame_with_skin(shot, skin):
    """Return `shot` composited into the emulator `skin`, as RGBA."""
    shot = shot.convert("RGBA")
    if shot.size != skin.display_size:
        shot = shot.resize(skin.display_size, Image.LANCZOS)

    bg_path, bg_pos = skin.background
    background = Image.open(bg_path).convert("RGBA")
    # Some skins ship a background a pixel or two larger than the layout says.
    size = (
        max(skin.size[0], bg_pos[0] + background.width),
        max(skin.size[1], bg_pos[1] + background.height),
    )
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(background, bg_pos)

    screen = Image.new("RGBA", size, (0, 0, 0, 0))
    mask = _rounded_mask(shot.size, skin.corner_radius) if skin.corner_radius else None
    screen.paste(shot, skin.display_pos, mask)
    canvas.alpha_composite(screen)

    for path, pos in skin.overlays:
        overlay = Image.open(path).convert("RGBA")
        if pos is None:  # display mask
            if overlay.size != skin.display_size:
                overlay = overlay.resize(skin.display_size, Image.LANCZOS)
            pos = skin.display_pos
        layer = Image.new("RGBA", size, (0, 0, 0, 0))
        layer.paste(overlay, pos)
        canvas.alpha_composite(layer)
    return canvas


# --- iOS Simulator chrome ----------------------------------------------------

DEVICEKIT_DIR = "/Library/Developer/DeviceKit"
SIM_DEVICE_TYPES_DIR = "/Library/Developer/CoreSimulator/Profiles/DeviceTypes"

# The chrome ships as vector PDFs; Pillow cannot rasterise those, so a tiny
# CoreGraphics program does it at the device's pixel scale, alpha included.
_PDF2PNG_SWIFT = """
import CoreGraphics
import ImageIO
import Foundation
import UniformTypeIdentifiers
let a = CommandLine.arguments
guard a.count == 4, let scale = Double(a[3]),
      let doc = CGPDFDocument(URL(fileURLWithPath: a[1]) as CFURL), let page = doc.page(at: 1) else {
    FileHandle.standardError.write("usage: pdf2png in.pdf out.png scale\\n".data(using: .utf8)!); exit(2)
}
let box = page.getBoxRect(.mediaBox)
let w = Int((box.width * scale).rounded()), h = Int((box.height * scale).rounded())
let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
ctx.translateBy(x: -box.minX, y: -box.minY)
ctx.drawPDFPage(page)
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: a[2]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
exit(CGImageDestinationFinalize(dest) ? 0 : 1)
"""


def _pdf2png():
    """Path to the compiled PDF rasteriser, building it on first use."""
    cache = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".cache")
    exe, src = os.path.join(cache, "pdf2png"), os.path.join(cache, "pdf2png.swift")
    if not os.path.isfile(exe) or open(src).read() != _PDF2PNG_SWIFT:
        os.makedirs(cache, exist_ok=True)
        with open(src, "w") as f:
            f.write(_PDF2PNG_SWIFT)
        subprocess.run(["swiftc", "-O", "-o", exe, src], check=True)
    return exe


def _render_pdf(path, scale):
    """Rasterise page 1 of `path` at `scale` pixels per point, as RGBA."""
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, "page.png")
        subprocess.run([_pdf2png(), path, out, str(scale)], check=True)
        return Image.open(out).convert("RGBA")


def _nine_slice(img, size, cap):
    """Stretch `img` to `size`, keeping its `cap`-pixel corners unscaled."""
    if img.size == size:
        return img
    w, h = img.size
    W, H = size
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    xs = [(0, cap, 0, cap), (cap, w - cap, cap, W - cap), (w - cap, w, W - cap, W)]
    ys = [(0, cap, 0, cap), (cap, h - cap, cap, H - cap), (h - cap, h, H - cap, H)]
    for x0, x1, X0, X1 in xs:
        for y0, y1, Y0, Y1 in ys:
            piece = img.crop((x0, y0, x1, y1))
            if piece.size != (X1 - X0, Y1 - Y0):
                piece = piece.resize((X1 - X0, Y1 - Y0), Image.LANCZOS)
            out.paste(piece, (X0, Y0))
    return out


class IOSChrome:
    """The Simulator's device bezel for the device whose screen matches `shot_size`."""

    @staticmethod
    def _screen_info(resources_dir, profile):
        """(width, height, scale) for a device type. Older Xcode kept these on
        profile.plist as mainScreen{Width,Height,Scale}; Xcode 26+ moved them to
        capabilities.plist under ScreenDimensionsCapability (e.g. iPhone 17 Pro)."""
        w = profile.get("mainScreenWidth")
        h = profile.get("mainScreenHeight")
        s = profile.get("mainScreenScale")
        if None in (w, h, s):
            cap_path = os.path.join(resources_dir, "capabilities.plist")
            if os.path.exists(cap_path):
                with open(cap_path, "rb") as f:
                    dims = plistlib.load(f).get("capabilities", {}).get("ScreenDimensionsCapability", {})
                w = w if w is not None else dims.get("main-screen-width")
                h = h if h is not None else dims.get("main-screen-height")
                s = s if s is not None else dims.get("main-screen-scale")
        return w, h, s

    def __init__(self, shot_size):
        for plist in glob.glob(os.path.join(SIM_DEVICE_TYPES_DIR, "*.simdevicetype", "Contents", "Resources", "profile.plist")):
            with open(plist, "rb") as f:
                profile = plistlib.load(f)
            w, h, scale = self._screen_info(os.path.dirname(plist), profile)
            if (w, h) == shot_size:
                break
        else:
            raise FileNotFoundError(f"no simulator device type has a {shot_size[0]}x{shot_size[1]} screen")
        self.name = os.path.basename(os.path.dirname(os.path.dirname(os.path.dirname(plist)))).removesuffix(".simdevicetype")
        self.scale = int(scale)
        self.mask_pdf = os.path.join(DEVICEKIT_DIR, "FramebufferMasks", profile["framebufferMask"] + ".pdf")
        for spec in glob.glob(os.path.join(DEVICEKIT_DIR, "Chrome", "*.devicechrome", "Contents", "Resources", "chrome.json")):
            with open(spec) as f:
                chrome = json.load(f)
            if chrome["identifier"] == profile["chromeIdentifier"]:
                break
        else:
            raise FileNotFoundError(f"no DeviceKit chrome {profile['chromeIdentifier']!r}")
        self.chrome_dir = os.path.dirname(spec)
        self.chrome = chrome

    def _image(self, name):
        return _render_pdf(os.path.join(self.chrome_dir, name + ".pdf"), self.scale)

    def frame(self, shot, island=True):
        shot = shot.convert("RGBA")
        s = self.scale
        images = self.chrome["images"]
        # The composite is the whole bezel drawn for one screen size; other
        # screens sharing the chrome get it 9-slice stretched around them.
        composite = self._image(images["composite"])
        border = (composite.width - shot.width) // 2
        if border <= 0 or composite.height - shot.height != 2 * border:
            border = images["sizing"]["leftWidth"] * s
        body_size = (shot.width + 2 * border, shot.height + 2 * border)
        composite = _nine_slice(composite, body_size, cap=composite.width // 3)
        pad = images["padding"]["width"] * s
        canvas = Image.new("RGBA", (body_size[0] + 2 * pad, body_size[1]), (0, 0, 0, 0))

        # Side buttons sit beneath the bezel, at the Simulator's own offsets.
        for button in self.chrome.get("inputs", []):
            if button.get("type") != "button" or button.get("onTop"):
                continue
            img = self._image(button["image"])
            x, y = button["offsets"]["normal"]["x"] * s, button["offsets"]["normal"]["y"] * s
            if button.get("anchor") == "right":
                x = canvas.width + x - img.width
            canvas.alpha_composite(img, (x, y))
        canvas.alpha_composite(composite, (pad, 0))

        mask = _render_pdf(self.mask_pdf, 1)
        if mask.size != shot.size:
            mask = mask.resize(shot.size, Image.LANCZOS)
        screen = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        screen.paste(shot, (pad + border, border), mask.split()[3])
        if island:
            self._draw_island(screen, shot, offset=(pad + border, border))
        canvas.alpha_composite(screen)
        return canvas

    # Island-bearing iPhones by logical width in points: 14 Pro to 17 Pro and
    # their Plus/Max sizes. The cutout is 126 x 37.33 pt, centred, 11 pt down.
    _ISLAND_WIDTHS_PT = {393, 402, 430, 440}
    _ISLAND_PT = (126.0, 37.33, 11.0)

    def island_rect(self, shot_size):
        """Pixel box of the Dynamic Island on this screen, or None without one."""
        if shot_size[0] / self.scale not in self._ISLAND_WIDTHS_PT:
            return None
        w, h, top = (v * self.scale for v in self._ISLAND_PT)
        x = (shot_size[0] - w) / 2
        return (round(x), round(top), round(x + w), round(top + h))

    def _draw_island(self, screen, shot, offset):
        """Paint the island cutout unless the capture already shows it (the
        Simulator draws one; a physical iPhone's screenshot does not)."""
        box = self.island_rect(shot.size)
        if box is None:
            return
        region = shot.convert("L").crop(box)
        if sum(region.getdata()) / (region.width * region.height) < 40:
            return  # already black: a Simulator capture
        w, h = box[2] - box[0], box[3] - box[1]
        s = SUPERSAMPLE
        pill = Image.new("L", (w * s, h * s), 0)
        ImageDraw.Draw(pill).rounded_rectangle((0, 0, w * s - 1, h * s - 1), radius=h * s // 2, fill=255)
        screen.paste((0, 0, 0, 255), (offset[0] + box[0], offset[1] + box[1]), pill.resize((w, h), Image.LANCZOS))


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("inputs", nargs="*", help="raw screenshot PNG(s)")
    p.add_argument("--list-skins", action="store_true", help="print the SDK's emulator skins and exit")
    p.add_argument("output", nargs="?", help="output file (single input only)")
    p.add_argument("--out-dir", help="write <out-dir>/<input basename> for each input")
    p.add_argument(
        "--skin",
        help="emulator skin name (e.g. pixel_7) or skin directory; 'ios' uses the "
        "Xcode Simulator's bezel for the matching device; 'generic' or omitted "
        "draws the built-in frame",
    )
    g = p.add_argument_group("generic frame options (ignored with --skin)")
    g.add_argument("--color", type=_hex_rgb, default="#141414", help="bezel colour, #rrggbb")
    g.add_argument("--no-shadow", action="store_true")
    g.add_argument("--no-buttons", action="store_true")
    g.add_argument("--no-hole", action="store_true", help="skip the camera punch hole")
    p.add_argument("--no-island", action="store_true", help="--skin ios: do not paint the Dynamic Island")
    args = p.parse_args(argv)

    if args.list_skins:
        names = list_skins()
        print("\n".join(names) if names else "No emulator skins found (is $ANDROID_HOME set?)")
        if os.path.isdir(DEVICEKIT_DIR):
            print("ios  (Xcode Simulator bezel, matched to the screenshot's device)")
        return 0
    if not args.inputs:
        p.error("inputs are required unless --list-skins is given")

    inputs = list(args.inputs)
    # argparse can't tell "in out" from "in1 in2"; without --out-dir the last
    # positional is the output file.
    if args.out_dir is None:
        if args.output is None and len(inputs) >= 2:
            args.output = inputs.pop()
        if args.output is None or len(inputs) != 1:
            p.error("give one input and one output, or several inputs with --out-dir")
        targets = [(inputs[0], args.output)]
    else:
        if args.output is not None:
            inputs.append(args.output)
        os.makedirs(args.out_dir, exist_ok=True)
        targets = [(i, os.path.join(args.out_dir, os.path.basename(i))) for i in inputs]

    color = args.color if isinstance(args.color, tuple) else _hex_rgb(args.color)
    use_skin = args.skin and args.skin != "generic"
    skins = {}  # display size -> Skin, so foldables resolve once per posture
    for src, dst in targets:
        with Image.open(src) as im:
            if args.skin == "ios":
                chrome = skins.get(im.size)
                if chrome is None:
                    try:
                        chrome = skins[im.size] = IOSChrome(im.size)
                    except (FileNotFoundError, KeyError, subprocess.CalledProcessError) as e:
                        sys.exit(f"frame_screenshot.py: {e}")
                out = chrome.frame(im, island=not args.no_island)
            elif use_skin:
                skin = skins.get(im.size)
                if skin is None:
                    try:
                        skin = skins[im.size] = resolve_skin(args.skin, im.size)
                    except (FileNotFoundError, ValueError, KeyError) as e:
                        sys.exit(f"frame_screenshot.py: {e}")
                out = frame_with_skin(im, skin)
            else:
                out = frame(
                    im,
                    bezel_color=color,
                    shadow=not args.no_shadow,
                    buttons=not args.no_buttons,
                    hole=not args.no_hole,
                )
        out.save(dst, optimize=True)
        print(dst)


if __name__ == "__main__":
    main()
