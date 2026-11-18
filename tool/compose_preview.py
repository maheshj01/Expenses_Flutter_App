"""Turns the recorded app footage into the App Store preview.

Reads build/preview/preview_raw.mp4 and build/preview/markers.tsv (from
tool/record_preview.sh) and writes build/preview/epoch_app_preview.mp4:
886x1920 portrait, 30 fps, H.264 High@4.0 ~11 Mbps, silent stereo AAC, 15-30 s
(Apple's app preview specification).

Everything in the frame is the real app. The motion graphics only frame it:
a dot that opens into the screen, captions in the app's type and colours, a
dot wherever a finger taps, and a closing dot that beats under the wordmark.

Usage: python3 tool/compose_preview.py [build/preview]
"""
import math
import os
import shutil
import subprocess
import sys
from multiprocessing import Pool

from PIL import Image, ImageDraw, ImageFilter, ImageFont

DIR = sys.argv[1] if len(sys.argv) > 1 else "build/preview"
FONTS = os.path.join(os.path.dirname(__file__), "..", "assets", "fonts")
W, H, FPS, SS = 886, 1920, 30, 2

CREAM = (255, 242, 224)
VERM = (239, 91, 37)
INK = (43, 32, 24)
MUTED = (155, 139, 122)

# The phone screen card: the recording, scaled, with the iPhone's rounded corners.
SRC_W, SRC_H = 1206, 2622
CARD_W = 640
CARD_H = CARD_W * SRC_H / SRC_W
CARD_X = (W - CARD_W) / 2
CARD_Y = H - CARD_H - 64
CARD_R = 88

CAPTIONS = {
    "year": "Every day is a dot.",
    "timeline": "Give your plans a date.",
    "countdown": "Watch them come closer.",
    "inyear": "See it in your year.",
    "life": "Make the years count.",
}

INTRO = 1.4   # a dot opens into the app
OUTRO = 2.6   # the app closes into a dot, which beats under the wordmark


# ------------------------------------------------------------------ helpers

def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))


def seg(t, a, b):
    return clamp((t - a) / (b - a))


def lerp(a, b, u):
    return a + (b - a) * u


def out_cubic(u):
    return 1 - (1 - u) ** 3


def in_cubic(u):
    return u ** 3


def io_cubic(u):
    return 4 * u ** 3 if u < 0.5 else 1 - (-2 * u + 2) ** 3 / 2


def out_back(u, s=1.7):
    u -= 1
    return 1 + (s + 1) * u ** 3 + s * u ** 2


def beat(t, start, length, strength):
    u = seg(t, start, start + length)
    if u in (0, 1):
        return 0
    return strength * math.sin(math.pi * u) ** 2 * (1 - 0.35 * u)


def lub_dub(t, start):
    return beat(t, start, 0.34, 0.16) + beat(t, start + 0.28, 0.28, 0.09)


_fonts = {}


def font(weight, size):
    k = (weight, int(size * SS))
    if k not in _fonts:
        _fonts[k] = ImageFont.truetype(os.path.join(FONTS, f"Poppins-{weight}.ttf"), k[1])
    return _fonts[k]


def s(v):
    return int(round(v * SS))


def rgba(c, a):
    return tuple(c) + (int(round(255 * clamp(a))),)


def blend(img, x0, y0, x1, y1, fn):
    X0, Y0, X1, Y1 = int(x0 * SS) - 2, int(y0 * SS) - 2, int(x1 * SS) + 3, int(y1 * SS) + 3
    lay = Image.new("RGBA", (X1 - X0, Y1 - Y0), (0, 0, 0, 0))
    fn(ImageDraw.Draw(lay), X0, Y0)
    img.alpha_composite(lay, dest=(X0, Y0))


def circle(img, x, y, r, c, a=1.0):
    if r > 0.1 and a > 0.003:
        blend(img, x - r, y - r, x + r, y + r,
              lambda d, ox, oy: d.ellipse((s(x - r) - ox, s(y - r) - oy, s(x + r) - ox, s(y + r) - oy), fill=rgba(c, a)))


def ring(img, x, y, r, w, c, a=1.0):
    if r > 0.1 and a > 0.003:
        blend(img, x - r, y - r, x + r, y + r,
              lambda d, ox, oy: d.ellipse((s(x - r) - ox, s(y - r) - oy, s(x + r) - ox, s(y + r) - oy),
                                          outline=rgba(c, a), width=max(1, s(min(w, r)))))


def words(img, line, x, y, size, t, t0, color=INK, a=1.0, rise=26, stagger=0.06, dur=0.4):
    f = font("SemiBold", size)
    parts = line.split(" ")
    sp = f.getlength(" ") / SS
    ws = [f.getlength(p) / SS for p in parts]
    cur = x - (sum(ws) + sp * (len(parts) - 1)) / 2
    for i, (p, w) in enumerate(zip(parts, ws)):
        u = out_cubic(seg(t, t0 + i * stagger, t0 + i * stagger + dur))
        if u > 0:
            yy = y + (1 - u) * rise
            bx0, by0, bx1, by1 = f.getbbox(p, anchor="ls")
            blend(img, cur + bx0 / SS, yy + by0 / SS, cur + bx1 / SS, yy + by1 / SS,
                  lambda d, ox, oy, p=p, cur=cur, yy=yy, u=u: d.text((s(cur) - ox, s(yy) - oy), p, font=f,
                                                                    fill=rgba(color, a * u), anchor="ls"))
        cur += w + sp


def text(img, string, x, y, size, weight, color, a=1.0):
    if a <= 0.003:
        return
    f = font(weight, size)
    bx0, by0, bx1, by1 = f.getbbox(string, anchor="mm")
    blend(img, x + bx0 / SS, y + by0 / SS, x + bx1 / SS, y + by1 / SS,
          lambda d, ox, oy: d.text((s(x) - ox, s(y) - oy), string, font=f, fill=rgba(color, a), anchor="mm"))


# ------------------------------------------------------------------ edit list

def read_markers():
    scenes, taps, stop = [], [], None
    with open(os.path.join(DIR, "markers.tsv")) as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if parts[0] == "scene":
                scenes.append((parts[2], float(parts[1])))
            elif parts[0] == "tap":
                x, y = parts[2].split()
                taps.append((float(parts[1]), float(x), float(y)))
            elif parts[0] == "stop":
                stop = float(parts[1])
    return scenes, taps, stop


SCENES, TAPS, STOP = read_markers()
SCENE_AT = dict(SCENES)

# Segments of the recording, in order, each with a playback speed. Long
# interactions (typing, the pickers) play a little faster so the story fits.
SEGMENTS = [
    (SCENE_AT["year"] - 0.1, SCENE_AT["timeline"], 1.0),
    (SCENE_AT["timeline"], SCENE_AT["countdown"], 1.35),
    (SCENE_AT["countdown"], SCENE_AT["inyear"], 1.15),
    (SCENE_AT["inyear"], SCENE_AT["life"], 1.15),
    (SCENE_AT["life"], SCENE_AT["end"] + 0.9, 1.1),
]
BODY = sum((b - a) / sp for a, b, sp in SEGMENTS)
TOTAL = INTRO + BODY + OUTRO


def src_time(t):
    """Output time -> recording time (None in the intro and outro)."""
    u = t - INTRO
    if u < 0:
        return SEGMENTS[0][0]
    for a, b, sp in SEGMENTS:
        d = (b - a) / sp
        if u < d:
            return a + u * sp
        u -= d
    return SEGMENTS[-1][1]


def out_time(src):
    """Recording time -> output time, for markers."""
    o = INTRO
    for a, b, sp in SEGMENTS:
        if a <= src <= b:
            return o + (src - a) / sp
        o += (b - a) / sp
    return None


CAPTION_TIMES = []
for name, at in SCENES:
    if name in CAPTIONS:
        CAPTION_TIMES.append((out_time(at) if name != "year" else INTRO - 0.35, CAPTIONS[name]))
TAP_TIMES = [(out_time(t), x, y) for t, x, y in TAPS if out_time(t) is not None]


# ------------------------------------------------------------------ frames

def card_mask(w, h, r):
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w - 1, h - 1), radius=r, fill=255)
    return m


SHADOW = None


def shadow():
    global SHADOW
    if SHADOW is None:
        pad = 120
        sh = Image.new("RGBA", (s(CARD_W) + 2 * s(pad), s(CARD_H) + 2 * s(pad)), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle((s(pad), s(pad) + s(24), s(pad) + s(CARD_W), s(pad) + s(CARD_H) + s(24)),
                                             radius=s(CARD_R), fill=(122, 90, 58, 70))
        SHADOW = sh.filter(ImageFilter.GaussianBlur(s(34)))
    return SHADOW


def src_frame(t):
    n = int(round(src_time(t) * FPS))
    path = os.path.join(DIR, "src", f"f{max(1, n + 1):05d}.jpg")
    while not os.path.exists(path) and n > 0:
        n -= 1
        path = os.path.join(DIR, "src", f"f{n + 1:05d}.jpg")
    return Image.open(path).convert("RGB")


def draw_card(img, t, scale=1.0, cx=None, cy=None, radius=None, alpha=1.0, frame=None):
    w, h = CARD_W * scale, CARD_H * scale
    cx = CARD_X + CARD_W / 2 if cx is None else cx
    cy = CARD_Y + CARD_H / 2 if cy is None else cy
    r = CARD_R * scale if radius is None else radius
    W2, H2 = max(2, s(w)), max(2, s(h))
    shot = (frame or src_frame(t)).resize((W2, H2), Image.LANCZOS).convert("RGBA")
    m = card_mask(W2, H2, s(min(r, w / 2, h / 2)))
    if alpha < 1:
        m = m.point(lambda v: int(v * alpha))
    shot.putalpha(m)
    if scale > 0.6:
        sh = shadow()
        if scale != 1.0:
            sh = sh.resize((max(2, int(sh.width * scale)), max(2, int(sh.height * scale))))
        if alpha < 1:
            sh = sh.copy()
            sh.putalpha(sh.getchannel("A").point(lambda v: int(v * alpha)))
        img.alpha_composite(sh, dest=(s(cx) - sh.width // 2, s(cy) - sh.height // 2))
    img.alpha_composite(shot, dest=(s(cx - w / 2), s(cy - h / 2)))


def taps(img, t):
    """A dot where the finger lands: it fills, then a ring lets go of it."""
    k = CARD_W / SRC_W
    for at, x, y in TAP_TIMES:
        u = t - at
        if not -0.02 < u < 0.6:
            continue
        px, py = CARD_X + x * k, CARD_Y + y * k
        grow = out_back(seg(u, 0.0, 0.14), 2.2)
        fade = 1 - seg(u, 0.22, 0.42)
        circle(img, px, py, 17 * grow, VERM, 0.85 * fade)
        circle(img, px, py, 6 * grow, (255, 255, 255), 0.9 * fade)
        rp = seg(u, 0.08, 0.6)
        if rp > 0:
            ring(img, px, py, 17 + 46 * out_cubic(rp), 3, VERM, 0.6 * (1 - rp))


def captions(img, t):
    """The scene's few words, and a small dot above them that beats on each change."""
    current = None
    for i, (at, line) in enumerate(CAPTION_TIMES):
        nxt = CAPTION_TIMES[i + 1][0] if i + 1 < len(CAPTION_TIMES) else TOTAL - OUTRO
        if at <= t < nxt:
            current = (at, nxt, line)
    if current is None:
        return
    at, nxt, line = current
    out = in_cubic(seg(t, nxt - 0.18, nxt))
    size = 60
    while font("SemiBold", size).getlength(line) / SS > W - 120:
        size -= 2
    words(img, line, W / 2, 300 - 22 * out, size, t, at + 0.05, a=1 - out)
    # The dot: always there, beating as each new line arrives.
    d = 1 + lub_dub(t, at)
    circle(img, W / 2, 168, 13 * d, VERM)


def intro(img, t):
    """A dot drops, beats, and opens into the app."""
    land = 0.35
    cx, cy = W / 2, CARD_Y + CARD_H / 2
    if t < land:
        y = lerp(-40, cy, in_cubic(seg(t, 0, land)))
        circle(img, cx, y, 16, VERM)
        return
    open_u = io_cubic(seg(t, 0.62, INTRO))
    if open_u == 0:
        k = t - land
        wob = 0.3 * math.exp(-11 * k) * math.cos(30 * k)
        r = 16 * (1 + lub_dub(t, land + 0.02))
        blend(img, cx - r * 1.4, cy - r * 1.4, cx + r * 1.4, cy + r * 1.4,
              lambda d, ox, oy: d.ellipse((s(cx - r * (1 + wob)) - ox, s(cy - r * (1 - wob)) - oy,
                                           s(cx + r * (1 + wob)) - ox, s(cy + r * (1 - wob)) - oy), fill=rgba(VERM, 1)))
        return
    # The dot becomes the screen: a circle growing into the rounded card.
    scale = lerp(32 / CARD_W, 1.0, open_u)
    rad = lerp(16, CARD_R, open_u)
    draw_card(img, INTRO, scale=scale, radius=rad if scale * CARD_W > 2 * rad else scale * CARD_W / 2)
    circle(img, cx, cy, 16 * (1 - seg(open_u, 0, 0.35)) * max(1, scale * CARD_W / 32), VERM,
           1 - seg(open_u, 0, 0.35))


def outro(img, t):
    """The app closes into a dot, which beats under the wordmark."""
    u = t - (TOTAL - OUTRO)
    shrink = io_cubic(seg(u, 0.0, 0.7))
    last = src_frame(TOTAL - OUTRO - 0.01)
    cx = W / 2
    cy = lerp(CARD_Y + CARD_H / 2, 820, shrink)
    if shrink < 1:
        scale = lerp(1.0, 34 / CARD_W, shrink)
        rad = lerp(CARD_R, 17, shrink)
        draw_card(img, 0, scale=scale, cy=cy, radius=rad, frame=last)
        circle(img, cx, cy, 17 * max(1, scale * CARD_W / 34) * seg(shrink, 0.6, 1.0), VERM, seg(shrink, 0.6, 1.0))
    else:
        circle(img, cx, 820, 17 * (1 + lub_dub(t, TOTAL - OUTRO + 0.8)), VERM)
    words(img, "Epoch", cx, 990, 92, t, TOTAL - OUTRO + 0.85, rise=24)
    f = seg(t, TOTAL - OUTRO + 1.1, TOTAL - OUTRO + 1.45)
    text(img, "Make every day count.", cx, 1060, 38, "Regular", MUTED, out_cubic(f))


def render(i):
    t = i / FPS
    img = Image.new("RGBA", (s(W), s(H)), CREAM + (255,))
    if t < INTRO:
        intro(img, t)
        captions(img, t)
    elif t < TOTAL - OUTRO:
        draw_card(img, t)
        taps(img, t)
        captions(img, t)
    else:
        outro(img, t)
    img.convert("RGB").resize((W, H), Image.LANCZOS).save(os.path.join(DIR, "out", f"o{i:05d}.png"),
                                                           compress_level=1)
    return i


if __name__ == "__main__":
    print(f"intro {INTRO}s + body {BODY:.2f}s + outro {OUTRO}s = {TOTAL:.2f}s")
    if not 15 <= TOTAL <= 30:
        sys.exit(f"length {TOTAL:.2f}s is outside Apple's 15-30 s; adjust SEGMENTS speeds")
    src = os.path.join(DIR, "src")
    if not os.path.isdir(src):
        os.makedirs(src)
        subprocess.run(["ffmpeg", "-loglevel", "error", "-i", os.path.join(DIR, "preview_raw.mp4"), "-vf",
                        f"fps={FPS}", "-q:v", "2", os.path.join(src, "f%05d.jpg")], check=True)
    out = os.path.join(DIR, "out")
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(out)
    n = int(round(TOTAL * FPS))
    which = range(n) if len(sys.argv) < 3 else [int(float(x) * FPS) for x in sys.argv[2:]]
    with Pool(10) as pool:
        list(pool.imap_unordered(render, which, chunksize=4))
    if len(sys.argv) >= 3:
        sys.exit(0)
    subprocess.run([
        "ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", os.path.join(out, "o%05d.png"),
        "-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=48000",
        "-shortest", "-c:v", "libx264", "-profile:v", "high", "-level", "4.0", "-pix_fmt", "yuv420p",
        "-b:v", "11M", "-maxrate", "12M", "-bufsize", "24M", "-r", str(FPS),
        "-c:a", "aac", "-b:a", "256k", "-ar", "48000", "-ac", "2", "-movflags", "+faststart",
        os.path.join(DIR, "epoch_app_preview.mp4"),
    ], check=True)
    print("wrote", os.path.join(DIR, "epoch_app_preview.mp4"))
