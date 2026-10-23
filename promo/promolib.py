"""Drawing / animation toolkit for the DSH Fish Buddy promo video.

Frames are rendered with Pillow on a supersampled canvas (2x) and then
box-downscaled, which keeps text, rounded corners and thin borders crisp
at 1080p.
"""

from __future__ import annotations

import math
import os
import random
from functools import lru_cache

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

# --------------------------------------------------------------------------
# Paths / palette
# --------------------------------------------------------------------------

W, H = 1920, 1080

PROMO_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(PROMO_DIR)
WHALE_DIR = os.path.join(ROOT, "assets", "whale")
SHOT_DIR = os.path.join(ROOT, "assets", "screenshots")

FONT_FILES = {
    "r": "C:/Windows/Fonts/msyh.ttc",
    "b": "C:/Windows/Fonts/msyhbd.ttc",
    "l": "C:/Windows/Fonts/msyhl.ttc",
    "en": "C:/Windows/Fonts/segoeui.ttf",
    "enb": "C:/Windows/Fonts/segoeuib.ttf",
    "ensb": "C:/Windows/Fonts/seguisb.ttf",
    "mono": "C:/Windows/Fonts/consola.ttf",
    "monob": "C:/Windows/Fonts/consolab.ttf",
}

C = {
    "bg0": (5, 7, 15),
    "bg1": (9, 15, 34),
    "bg2": (5, 9, 22),
    "ink": (242, 246, 255),
    "ink2": (199, 211, 242),
    "ink3": (159, 176, 216),
    "muted": (124, 140, 180),
    "blue": (124, 147, 255),
    "blue2": (169, 186, 255),
    "blue3": (74, 106, 240),
    "green": (61, 220, 151),
    "green2": (140, 240, 198),
    "gold": (255, 216, 107),
    "red": (255, 107, 122),
    "white": (255, 255, 255),
}

# --------------------------------------------------------------------------
# Easing / math
# --------------------------------------------------------------------------


def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else hi if v > hi else v


def lerp(a, b, t):
    return a + (b - a) * t


def inv_lerp(a, b, v):
    if b == a:
        return 0.0
    return clamp((v - a) / (b - a))


def smoothstep(t):
    t = clamp(t)
    return t * t * (3 - 2 * t)


def ease_out_cubic(t):
    t = clamp(t)
    return 1 - (1 - t) ** 3


def ease_in_cubic(t):
    t = clamp(t)
    return t ** 3


def ease_out_expo(t):
    t = clamp(t)
    return 1.0 if t >= 1 else 1 - 2 ** (-10 * t)


def ease_in_out(t):
    t = clamp(t)
    return 4 * t ** 3 if t < 0.5 else 1 - (-2 * t + 2) ** 3 / 2


def ease_out_back(t, s=1.70158):
    t = clamp(t) - 1
    return 1 + (s + 1) * t ** 3 + s * t ** 2


def spring(t, freq=13.0, damp=6.5):
    """Overshooting 0->1 spring."""
    t = clamp(t)
    if t <= 0:
        return 0.0
    return 1 - math.exp(-damp * t) * math.cos(freq * t)


def scene_envelope(t, start, end, fin=0.65, fout=0.55, drift=26.0):
    """Alpha + upward drift for scene content."""
    a_in = smoothstep(inv_lerp(start, start + fin, t))
    a_out = 1.0 - smoothstep(inv_lerp(end - fout, end, t))
    alpha = min(a_in, a_out)
    # content rises slightly while fading in
    dy = (1 - ease_out_cubic(inv_lerp(start, start + fin + 0.5, t))) * drift
    return alpha, dy


def hexc(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


def mix(c1, c2, t, a=None):
    t = clamp(t)
    if len(c1) == 3:
        c1 = (*c1, 255)
    if len(c2) == 3:
        c2 = (*c2, 255)
    out = tuple(int(round(lerp(c1[i], c2[i], t))) for i in range(4))
    if a is not None:
        out = (*out[:3], a)
    return out


def seeded(n, salt=0):
    return random.Random(9361 * (n + 1) + 37 * salt)


# --------------------------------------------------------------------------
# Fonts
# --------------------------------------------------------------------------


@lru_cache(maxsize=512)
def get_font(kind: str, px: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT_FILES[kind], max(1, int(round(px))))


# --------------------------------------------------------------------------
# Canvas
# --------------------------------------------------------------------------


class Canvas:
    """Supersampled RGBA canvas addressed in logical (1920x1080) pixels."""

    def __init__(self, w: int, h: int, ss: int = 2):
        self.W, self.H, self.ss = w, h, ss
        self.img = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)
        self._fit_cache = {}

    # -- primitives ------------------------------------------------------
    def rect(self, x, y, w, h, fill=None, outline=None, width=1):
        s = self.ss
        w, h = max(w, 1.0 / s), max(h, 1.0 / s)
        self.d.rectangle(
            [x * s, y * s, (x + w) * s - 1, (y + h) * s - 1],
            fill=fill,
            outline=outline,
            width=max(1, int(round(width * s))),
        )

    def rrect(self, x, y, w, h, r, fill=None, outline=None, width=1):
        s = self.ss
        w, h = max(w, 1.0 / s), max(h, 1.0 / s)
        r = min(r, w / 2, h / 2)
        self.d.rounded_rectangle(
            [x * s, y * s, (x + w) * s - 1, (y + h) * s - 1],
            radius=max(0.0, r * s),
            fill=fill,
            outline=outline,
            width=max(1, int(round(width * s))),
        )

    def circle(self, cx, cy, r, fill=None, outline=None, width=1):
        s = self.ss
        self.d.ellipse(
            [(cx - r) * s, (cy - r) * s, (cx + r) * s, (cy + r) * s],
            fill=fill,
            outline=outline,
            width=max(1, int(round(width * s))),
        )

    def arc(self, cx, cy, r, start_deg, end_deg, fill, width=1):
        ss = self.ss
        self.d.arc(
            [(cx - r) * ss, (cy - r) * ss, (cx + r) * ss, (cy + r) * ss],
            start=start_deg,
            end=end_deg,
            fill=fill,
            width=max(1, int(round(width * ss))),
        )

    def line(self, pts, fill, width=1, joint="curve"):
        s = self.ss
        self.d.line(
            [(p[0] * s, p[1] * s) for p in pts],
            fill=fill,
            width=max(1, int(round(width * s))),
            joint=joint,
        )

    def polygon(self, pts, fill=None, outline=None, width=1):
        s = self.ss
        pts_px = [(p[0] * s, p[1] * s) for p in pts]
        self.d.polygon(pts_px, fill=fill, outline=outline)
        if outline is not None and width > 1:
            self.d.line(pts_px + [pts_px[0]], fill=outline, width=int(round(width * s)))

    # -- text ------------------------------------------------------------
    def text_len(self, s, size, kind="r"):
        f = get_font(kind, size * self.ss)
        return self.d.textlength(s, font=f) / self.ss

    def fit(self, s, size, kind, max_w, ellipsis="…"):
        key = (s, size, kind, round(max_w, 1))
        if key in self._fit_cache:
            return self._fit_cache[key]
        if self.text_len(s, size, kind) <= max_w:
            self._fit_cache[key] = s
            return s
        lo, hi = 0, len(s)
        while lo < hi:
            mid = (lo + hi + 1) // 2
            if self.text_len(s[:mid] + ellipsis, size, kind) <= max_w:
                lo = mid
            else:
                hi = mid - 1
        out = s[:lo] + ellipsis
        self._fit_cache[key] = out
        return out

    def text(
        self,
        xy,
        s,
        size,
        color=C["ink"],
        kind="r",
        anchor="la",
        ls=0.0,
        lh=1.32,
        alpha=1.0,
        shadow=None,
    ):
        if not s or alpha <= 0:
            return
        s_px = self.ss
        if len(color) == 3:
            color = (*color, 255)
        a = int(round(color[3] * clamp(alpha)))
        if a <= 0:
            return
        col = (color[0], color[1], color[2], a)
        f = get_font(kind, size * s_px)
        x, y = xy

        lines = s.split(chr(10))
        step = size * lh
        widths = [self.d.textlength(ln, font=f) / s_px for ln in lines]
        if ls:
            widths = [w + ls * max(0, len(ln) - 1) for w, ln in zip(widths, lines)]
        total_w = max(widths) if widths else 0
        single_h = size * 1.2
        total_h = step * (len(lines) - 1) + single_h if len(lines) > 1 else single_h

        x0, y0 = x, y
        if anchor[0] == "m":
            x0 = x - total_w / 2
        elif anchor[0] == "r":
            x0 = x - total_w
        if anchor[1] == "m":
            y0 = y - total_h / 2
        elif anchor[1] == "b":
            y0 = y - total_h

        def render(draw, ox, oy, fill, sh):
            for i, ln in enumerate(lines):
                lx = ox
                if anchor[0] == "m":
                    lx = ox + (total_w - widths[i]) / 2
                elif anchor[0] == "r":
                    lx = ox + total_w - widths[i]
                ly = oy + i * step
                if sh is not None:
                    sh_col, sh_off, sh_a = sh
                    sfill = (*sh_col[:3], int(sh_a * 255 * clamp(alpha)))
                    if ls:
                        self._draw_spaced(draw, lx + sh_off[0], ly + sh_off[1], ln, f, sfill, ls, s_px)
                    else:
                        draw.text(((lx + sh_off[0]) * s_px, (ly + sh_off[1]) * s_px), ln, font=f, fill=sfill, anchor="la")
                if ls:
                    self._draw_spaced(draw, lx, ly, ln, f, fill, ls, s_px)
                else:
                    draw.text((lx * s_px, ly * s_px), ln, font=f, fill=fill, anchor="la")

        # translucent text is composited through a small tile so it blends
        # over cards / bubbles instead of punching holes in them
        if a < 250:
            pad_x = max(4.0, size * 0.45)
            pad_y = max(4.0, size * 0.45)
            tw = int(math.ceil(total_w + pad_x * 2))
            th = int(math.ceil(total_h + step * (len(lines) - 1) * 0 + pad_y * 2))
            if tw <= 0 or th <= 0:
                return
            tile = Image.new("RGBA", (tw * s_px, th * s_px), (0, 0, 0, 0))
            td = ImageDraw.Draw(tile)
            render(td, pad_x, pad_y, col, shadow)
            self.img.alpha_composite(tile, (int(round((x0 - pad_x) * s_px)), int(round((y0 - pad_y) * s_px))))
        else:
            render(self.d, x0, y0, col, shadow)

    def _draw_spaced(self, draw, x, y, s, f, col, ls, s_px):
        cx = x
        for ch in s:
            draw.text((cx * s_px, y * s_px), ch, font=f, fill=col, anchor="la")
            cx += (draw.textlength(ch, font=f) / s_px) + ls

    # -- mixed CJK / monospace text --------------------------------------
    def mix_len(self, s, size, cjk="r", latin="mono"):
        total = 0.0
        for run, kind in _split_runs(s, cjk, latin):
            total += self.text_len(run, size, kind)
        return total

    def mix_text(self, xy, s, size, color, cjk="r", latin="mono", alpha=1.0, anchor="la"):
        if not s or alpha <= 0:
            return
        if len(color) == 3:
            color = (*color, 255)
        col = (color[0], color[1], color[2], int(round(color[3] * clamp(alpha))))
        total = self.mix_len(s, size, cjk, latin)
        x, y = xy
        if anchor[0] == "m":
            x -= total / 2
        elif anchor[0] == "r":
            x -= total
        if anchor[1] == "m":
            y -= size * 0.62
        elif anchor[1] == "b":
            y -= size * 1.22
        s_px = self.ss
        cx = x
        for run, kind in _split_runs(s, cjk, latin):
            f = get_font(kind, size * s_px)
            self.d.text((cx * s_px, y * s_px), run, font=f, fill=col, anchor="la")
            cx += self.d.textlength(run, font=f) / s_px

    # -- images ----------------------------------------------------------
    def paste(self, im: Image.Image, x, y, scale=1.0, alpha=1.0):
        if alpha <= 0:
            return
        s = self.ss
        if scale != 1.0:
            im = im.resize(
                (max(1, int(im.width * scale)), max(1, int(im.height * scale))),
                Image.LANCZOS,
            )
        if alpha < 1.0:
            im = _with_alpha(im, alpha)
        self.img.alpha_composite(im, (int(round(x * s)), int(round(y * s))))


def _with_alpha(im: Image.Image, factor: float) -> Image.Image:
    if factor >= 1.0:
        return im
    im = im.copy()
    a = im.getchannel("A").point(lambda v: int(v * factor))
    im.putalpha(a)
    return im


# --------------------------------------------------------------------------
# Cached art: gradients, glows, shadows, glass
# --------------------------------------------------------------------------


@lru_cache(maxsize=128)
def vertical_gradient(w, h, stops):
    """stops: tuple((pos, (r,g,b,a)), ...)"""
    ramp = np.linspace(0.0, 1.0, h, dtype=np.float32)
    arr = np.zeros((h, 4), dtype=np.float32)
    positions = [p for p, _ in stops]
    colors = np.array([c for _, c in stops], dtype=np.float32)
    for ch in range(4):
        arr[:, ch] = np.interp(ramp, positions, colors[:, ch])
    rgba = np.repeat(arr[:, None, :], w, axis=1).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


@lru_cache(maxsize=64)
def radial_mask(radius_px: int, power: float = 2.2) -> Image.Image:
    r = int(radius_px)
    size = max(2, r * 2)
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    d = np.sqrt((xx - (size - 1) / 2) ** 2 + (yy - (size - 1) / 2) ** 2) / max(1.0, r)
    a = np.clip(1.0 - d, 0, 1) ** power
    return Image.fromarray((a * 255).astype(np.uint8), "L")


def glow_layer(radius_px: int, color=(124, 147, 255), alpha=60, power=2.2) -> Image.Image:
    """Soft radial glow, cheap to create per frame (mask is cached)."""
    mask = radial_mask(int(radius_px), power)
    a = max(0, min(255, int(alpha)))
    if a != 255:
        mask = mask.point(lambda v: v * a // 255)
    layer = Image.new("RGBA", mask.size, (int(color[0]), int(color[1]), int(color[2]), 255))
    layer.putalpha(mask)
    return layer


@lru_cache(maxsize=64)
def radial_sprite(radius_px: int, color=(124, 147, 255, 255), power=2.2):
    r = int(radius_px)
    size = max(2, r * 2)
    mask = radial_mask(r, power).point(lambda v: v * color[3] // 255)
    layer = Image.new("RGBA", mask.size, (color[0], color[1], color[2], 255))
    layer.putalpha(mask)
    return layer


@lru_cache(maxsize=64)
def soft_shadow(w, h, r, blur, color=(0, 0, 0), alpha=150, pad=40):
    img = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(
        [pad, pad, pad + w - 1, pad + h - 1],
        radius=min(r, w / 2, h / 2),
        fill=(*color, alpha),
    )
    img = img.filter(ImageFilter.GaussianBlur(blur))
    return img


@lru_cache(maxsize=16)
def shadow_white(w, h, r, blur, pad=40):
    """Cached black shadow at full opacity; fade with _with_alpha at draw time."""
    img = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([pad, pad, pad + w - 1, pad + h - 1], radius=min(r, w / 2, h / 2), fill=(0, 0, 0, 255))
    return img.filter(ImageFilter.GaussianBlur(blur))


@lru_cache(maxsize=16)
def grain_tiles(n=8, w=1920, h=1080, seed=7):
    rng = np.random.default_rng(seed)
    tiles = []
    for _ in range(n):
        noise = rng.normal(0, 1, (h, w, 1)).astype(np.float32)
        tiles.append(noise)
    return tiles


@lru_cache(maxsize=32)
def vignette_layer(w, h, strength=0.55):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    cx, cy = w / 2, h / 2
    dx = (xx - cx) / (w * 0.62)
    dy = (yy - cy) / (h * 0.62)
    d = np.sqrt(dx * dx + dy * dy)
    a = np.clip((d - 0.45) / 0.8, 0, 1) ** 1.8 * strength
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[..., 3] = (a * 255).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def bubble_body(w_px, h_px, r_px, style="default", ok=False):
    """Cached gradient body of the widget bubble (pixel size, already @ss)."""
    return _bubble_body(int(w_px), int(h_px), int(r_px), style, bool(ok))


@lru_cache(maxsize=96)
def _bubble_body(w_px, h_px, r_px, style, ok):
    if style == "white":
        stops = ((0, (250, 252, 255, 255)), (1, (238, 243, 251, 255)))
        border = (255, 255, 255, 210)
    elif style == "glass":
        stops = ((0, (255, 255, 255, 34)), (0.45, (255, 255, 255, 16)), (1, (255, 255, 255, 26)))
        border = (255, 255, 255, 120)
    else:
        stops = (
            (0, (22, 33, 61, 250)),
            (0.6, (14, 23, 48, 242)),
            (1, (12, 20, 43, 242)),
        )
        border = (255, 255, 255, 48)

    body = vertical_gradient(w_px, h_px, stops).copy()

    # top gloss
    gloss = Image.new("RGBA", (w_px, h_px), (0, 0, 0, 0))
    gd = ImageDraw.Draw(gloss)
    gd.rounded_rectangle(
        [0, 0, w_px - 1, h_px - 1],
        radius=r_px,
        fill=None,
        outline=(255, 255, 255, 0),
    )
    grad = vertical_gradient(
        w_px,
        h_px,
        (
            (0.0, (255, 255, 255, 20 if style == "default" else 34)),
            (0.35, (255, 255, 255, 0)),
            (1.0, (255, 255, 255, 0)),
        ),
    )
    mask = Image.new("L", (w_px, h_px), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w_px - 1, h_px - 1], radius=r_px, fill=255)
    body = Image.composite(grad, body, mask)

    # border
    bd = ImageDraw.Draw(body)
    bw = max(1, int(round(w_px / 348 * 1.2)))
    bd.rounded_rectangle(
        [bw / 2, bw / 2, w_px - 1 - bw / 2, h_px - 1 - bw / 2],
        radius=r_px,
        outline=border,
        width=bw,
    )

    # completion tint ring
    if ok:
        ring = Image.new("RGBA", (w_px, h_px), (0, 0, 0, 0))
        rd = ImageDraw.Draw(ring)
        rd.rounded_rectangle(
            [bw / 2, bw / 2, w_px - 1 - bw / 2, h_px - 1 - bw / 2],
            radius=r_px,
            outline=(72, 228, 160, 190),
            width=max(1, bw),
        )
        body = Image.alpha_composite(body, ring)
    return body


def panel_art(w_px, h_px, r_px, tint=(255, 255, 255, 9), border=(255, 255, 255, 26), top_glow=None):
    return _panel_art(int(w_px), int(h_px), int(r_px), tint, border, top_glow)


@lru_cache(maxsize=64)
def _panel_art(w_px, h_px, r_px, tint, border, top_glow):
    img = Image.new("RGBA", (w_px, h_px), (0, 0, 0, 0))
    mask = Image.new("L", (w_px, h_px), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w_px - 1, h_px - 1], radius=r_px, fill=255)
    base = vertical_gradient(
        w_px,
        h_px,
        (
            (0.0, (255, 255, 255, tint[3] + 10)),
            (0.5, (255, 255, 255, tint[3])),
            (1.0, (13, 21, 44, tint[3] + 14)),
        ),
    )
    img = Image.composite(base, img, mask)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(
        [1, 1, w_px - 2, h_px - 2],
        radius=r_px,
        outline=border,
        width=max(1, int(round(w_px / 540 * 1.4))),
    )
    if top_glow:
        g = radial_sprite(int(min(w_px, h_px) * 0.55), top_glow)
        img.alpha_composite(g, (int(w_px / 2 - g.width / 2), int(-g.height * 0.62)))
    return img


@lru_cache(maxsize=8)
def wallpaper_art(w_px, h_px, r_px):
    """Small bright desktop-wallpaper strip used to show bubble materials."""
    img = vertical_gradient(
        w_px,
        h_px,
        ((0.0, (33, 45, 88, 255)), (0.5, (56, 72, 124, 255)), (1.0, (86, 106, 158, 255))),
    )
    ov = Image.new("RGBA", (w_px, h_px), (0, 0, 0, 0))
    blobs = [
        (0.20, 0.32, 0.55, (170, 200, 255, 46)),
        (0.72, 0.22, 0.42, (214, 190, 255, 34)),
        (0.62, 0.85, 0.50, (120, 240, 220, 20)),
    ]
    for bx, by, br, col in blobs:
        rad = int(w_px * br * 0.5)
        g = radial_sprite(max(8, rad), col, 2.2)
        ov.alpha_composite(g, (int(w_px * bx - g.width / 2), int(h_px * by - g.height / 2)))
    img.alpha_composite(ov)
    mask = Image.new("L", (w_px, h_px), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w_px - 1, h_px - 1], radius=r_px, fill=255)
    out = Image.new("RGBA", (w_px, h_px), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    ImageDraw.Draw(out).rounded_rectangle(
        [1, 1, w_px - 2, h_px - 2], radius=r_px, outline=(255, 255, 255, 54), width=2
    )
    return out


# --------------------------------------------------------------------------
# Mascot / frame animation
# --------------------------------------------------------------------------

FRAMES = {
    "idle": (["idle_0", "idle_1", "idle_2"], 0.40),
    "working": (["working_0", "working_1", "working_2"], 0.26),
    "think": (["think_0"], 0.5),
    "sleep": (["sleep_0", "sleep_1"], 0.70),
    "celebrate": (["celebrate_0", "celebrate_1", "celebrate_2"], 0.20),
    "error": (["error_0", "error_1"], 0.42),
}


@lru_cache(maxsize=64)
def mascot_sprite(name: str) -> Image.Image:
    return Image.open(os.path.join(WHALE_DIR, name + ".png")).convert("RGBA")


def mascot_frame(state: str, t: float) -> str:
    names, period = FRAMES.get(state, FRAMES["idle"])
    return names[int(max(0.0, t) / period) % len(names)]


@lru_cache(maxsize=128)
def mascot_scaled(name: str, h_px: int) -> Image.Image:
    im = mascot_sprite(name)
    w_px = max(1, int(round(h_px * im.width / im.height)))
    return im.resize((w_px, h_px), Image.LANCZOS)


def draw_mascot(
    cv: Canvas,
    state: str,
    t: float,
    cx: float,
    bottom: float,
    height: float,
    alpha: float = 1.0,
    breathe: float = 0.010,
    glow: bool = True,
    glow_color=(124, 147, 255, 150),
    bob: float = 1.8,
    fade_bottom: float = 0.045,
):
    if alpha <= 0:
        return
    # quantise breathing to 5 levels so sprite resizes stay cacheable
    level = round(math.sin(t * math.tau / 3.3) * 2) / 2.0
    breath = 1.0 + breathe * level
    dy = bob * math.sin(t * math.tau / 3.3 + 0.7)
    h_px = int(round(height * cv.ss * breath))
    name = mascot_frame(state, t)
    sprite = mascot_scaled(name, h_px)
    if fade_bottom > 0:
        fm = bottom_fade_mask(sprite.width, sprite.height, max(2, int(sprite.height * fade_bottom)))
        from PIL import ImageChops as _ic

        sprite = sprite.copy()
        sprite.putalpha(_ic.multiply(sprite.getchannel("A"), fm))

    x = (cx * cv.ss) - sprite.width / 2
    y = (bottom + dy) * cv.ss - sprite.height

    if glow:
        gr = int(height * cv.ss * 0.95)
        g = glow_layer(gr, glow_color[:3], max(0, int(glow_color[3] * alpha)))
        cv.img.alpha_composite(g, (int(cx * cv.ss - g.width / 2), int((bottom - height * 0.52) * cv.ss - g.height / 2)))
    if alpha < 1:
        sprite = _with_alpha(sprite, alpha)
    cv.img.alpha_composite(sprite, (int(x), int(y)))


def _split_runs(s, cjk="r", latin="mono"):
    runs = []
    cur = ""
    cur_kind = None
    for ch in s:
        cjk_char = ord(ch) > 0x2500
        kind = cjk if cjk_char else latin
        if kind != cur_kind:
            if cur:
                runs.append((cur, cur_kind))
            cur, cur_kind = ch, kind
        else:
            cur += ch
    if cur:
        runs.append((cur, cur_kind))
    return runs


@lru_cache(maxsize=64)
def bottom_fade_mask(w_px, h_px, fade_px):
    arr = np.ones((h_px, 1), dtype=np.float32)
    n = min(fade_px, h_px)
    ramp = np.linspace(1.0, 0.0, n, dtype=np.float32) ** 1.15
    arr[h_px - n :, 0] = ramp
    full = np.repeat(arr, w_px, axis=1)
    return Image.fromarray((full * 255).astype(np.uint8), "L")


@lru_cache(maxsize=8)
def hero_sprite(h_px: int) -> Image.Image:
    im = Image.open(os.path.join(ROOT, "assets", "whale.png")).convert("RGBA")
    w_px = max(1, int(round(h_px * im.width / im.height)))
    return im.resize((w_px, h_px), Image.LANCZOS)


def draw_hero(cv: Canvas, t, cx, bottom, height, alpha=1.0, glow=True,
              glow_color=(124, 147, 255, 120), bob=3.0):
    if alpha <= 0:
        return
    level = round(math.sin(t * math.tau / 4.2 + 0.6) * 2) / 2.0
    h_px = int(round(height * cv.ss * (1 + 0.006 * level)))
    spr = hero_sprite(h_px)
    dy = bob * math.sin(t * math.tau / 4.2 + 0.4)
    dx = 1.6 * math.sin(t * 0.62 + 0.5)
    if glow:
        gr = int(height * cv.ss * 1.05)
        g = glow_layer(gr, glow_color[:3], max(0, int(glow_color[3] * alpha)), 2.2)
        cv.img.alpha_composite(g, (int(cx * cv.ss - g.width / 2),
                                   int((bottom - height * 0.5) * cv.ss - g.height / 2)))
    if alpha < 1:
        spr = _with_alpha(spr, alpha)
    cv.img.alpha_composite(spr, (int((cx + dx) * cv.ss - spr.width / 2),
                                 int((bottom + dy) * cv.ss - spr.height)))


@lru_cache(maxsize=8)
def fish_icon(size: int) -> Image.Image:
    im = Image.open(os.path.join(ROOT, "assets", "fish-64.png")).convert("RGBA")
    return im.resize((max(1, int(size)), max(1, int(size))), Image.LANCZOS)


@lru_cache(maxsize=32)
def ellipse_shadow(w_px, h_px, alpha=110):
    spr = radial_sprite(max(8, int(w_px / 2)), (0, 0, 0, alpha), 2.6)
    return spr.resize((max(2, int(w_px)), max(2, int(h_px))), Image.LANCZOS)


def ground_shadow(cv: Canvas, cx, cy, w, alpha=0.42):
    spr = ellipse_shadow(int(w * 1.15 * cv.ss), int(w * 0.17 * cv.ss), 255)
    spr = _with_alpha(spr, alpha)
    cv.img.alpha_composite(spr, (int(cx * cv.ss - spr.width / 2), int(cy * cv.ss - spr.height / 2)))


# --------------------------------------------------------------------------
# Bubble widget mock
# --------------------------------------------------------------------------


def draw_bubble(
    cv: Canvas,
    x: float,
    y: float,
    w: float,
    scale: float,
    title: str,
    count: str = "",
    progress: float = 0.0,
    task: str = "",
    meta: str = "",
    style: str = "default",
    ok: bool = False,
    alpha: float = 1.0,
    dot_phase: float = 0.0,
    tail: bool = True,
    reveal: float = 1.0,
):
    """Draw the desktop widget bubble. `scale` maps the 348px app bubble."""
    if alpha <= 0 or w <= 0:
        return
    pad_x = 16 * scale
    pad_y = 12 * scale
    title_sz = 13.5 * scale
    count_sz = 11.5 * scale
    task_sz = 12.5 * scale
    meta_sz = 10.5 * scale
    bar_h = 6 * scale
    gap1 = 10 * scale
    gap2 = 9 * scale
    gap3 = 5 * scale

    title_h = title_sz * 1.35
    task_h = task_sz * 1.4
    meta_h = meta_sz * 1.4
    h = pad_y * 2 + title_h + gap1 + bar_h + gap2 + task_h + (gap3 + meta_h if meta else 0)

    r = 20 * scale
    ss = cv.ss

    # shadow
    pad = int(24 * scale * ss)
    sh = shadow_white(int(w * ss), int(h * ss), int(r * ss), int(20 * scale * ss), pad=pad)
    sh = _with_alpha(sh, 0.20 * alpha)
    cv.img.alpha_composite(sh, (int(x * ss) - pad, int((y + 9 * scale) * ss) - pad))

    body = bubble_body(w * ss, h * ss, r * ss, style, ok)
    if alpha < 1:
        body = _with_alpha(body, alpha)
    cv.img.alpha_composite(body, (int(x * ss), int(y * ss)))

    if tail:
        tw = 18 * scale
        th = 11 * scale
        tx = x + w / 2
        ty = y + h - 1
        if style == "white":
            tail_col = (243, 247, 253, int(255 * alpha))
        elif style == "glass":
            tail_col = (255, 255, 255, int(40 * alpha))
        else:
            tail_col = (12, 20, 43, int(242 * alpha))
        cv.polygon([(tx - tw / 2, ty), (tx + tw / 2, ty), (tx, ty + th)], fill=tail_col)

    # colors
    if style == "white":
        c_title = (22, 33, 61, 255)
        c_count = (104, 120, 158, 255)
        c_task = (52, 68, 108, 255)
        c_meta = (116, 132, 170, 255)
        track = (220, 228, 242, 255)
        c_dot = C["green"] if ok else C["blue3"]
        shadow = None
    elif style == "glass":
        c_title = (255, 255, 255, 255)
        c_count = (235, 242, 255, 220)
        c_task = (255, 255, 255, 245)
        c_meta = (226, 236, 255, 200)
        track = (255, 255, 255, 60)
        c_dot = C["green2"] if ok else C["blue2"]
        shadow = ((0, 0, 0), (0, 1.2 * scale), 0.65)
    else:
        c_title = (242, 246, 255, 255)
        c_count = (143, 163, 217, 255)
        c_task = (215, 224, 255, 255)
        c_meta = (127, 144, 196, 255)
        track = (34, 48, 92, 255)
        c_dot = C["green"] if ok else C["blue"]
        shadow = None

    def fade(col):
        return (col[0], col[1], col[2], int(col[3] * alpha)) if len(col) == 4 else (*col, int(255 * alpha))

    # title row
    row_y = y + pad_y
    dot_r = 4 * scale
    cv.circle(x + pad_x + dot_r + 1, row_y + title_h * 0.46, dot_r, fill=fade(c_dot))
    if ok:
        pulse = 0.5 + 0.5 * math.sin(dot_phase * 2.4)
        cv.circle(
            x + pad_x + dot_r + 1,
            row_y + title_h * 0.46,
            dot_r + 3.5 * scale + 2 * scale * pulse,
            outline=fade((61, 220, 151, int(70 - 30 * pulse))),
            width=1.4 * scale,
        )
    else:
        pulse = 0.5 + 0.5 * math.sin(dot_phase * 3.0)
        cv.circle(
            x + pad_x + dot_r + 1,
            row_y + title_h * 0.46,
            dot_r + 3.0 * scale * pulse + 1.5 * scale,
            outline=fade((*C["blue"][:3], int(75 - 40 * pulse))),
            width=1.2 * scale,
        )

    text_x = x + pad_x + 14 * scale
    count_w = cv.text_len(count, count_sz, "r") if count else 0
    avail = w - pad_x * 2 - 14 * scale - count_w - 10 * scale
    cv.text(
        (text_x, row_y + title_h * 0.08),
        cv.fit(title, title_sz, "b", avail),
        title_sz,
        fade(c_title),
        "b",
        alpha=alpha,
        shadow=shadow if style == "glass" else None,
    )
    if count:
        cv.text(
            (x + w - pad_x, row_y + title_h * 0.12),
            count,
            count_sz,
            fade(c_count),
            "r",
            anchor="ra",
            alpha=alpha,
        )

    # progress bar
    bar_y = row_y + title_h + gap1
    bar_w = w - pad_x * 2
    cv.rrect(x + pad_x, bar_y, bar_w, bar_h, bar_h / 2, fill=fade(track))
    fill_w = bar_w * clamp(progress)
    if fill_w > bar_h:
        fill_w = max(fill_w, bar_h)
        grad = vertical_gradient(
            int(bar_w * ss),
            int(bar_h * ss),
            ((0, (*((61, 220, 151) if ok else (124, 147, 255)), 255)),
             (1, (*((140, 240, 198) if ok else (169, 186, 255)), 255))),
        )
        mask = Image.new("L", (int(bar_w * ss), int(bar_h * ss)), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [0, 0, int(fill_w * ss) - 1, int(bar_h * ss) - 1], radius=int(bar_h * ss / 2), fill=255
        )
        crop = grad.crop((0, 0, max(1, int(fill_w * ss)), int(bar_h * ss)))
        crop.putalpha(mask.crop((0, 0, crop.width, crop.height)))
        if alpha < 1:
            crop = _with_alpha(crop, alpha)
        cv.img.alpha_composite(crop, (int((x + pad_x) * ss), int(bar_y * ss)))
        # leading highlight
        if not ok and progress < 0.99:
            hx = x + pad_x + fill_w
            cv.circle(hx, bar_y + bar_h / 2, bar_h * 0.85, fill=fade((190, 205, 255, 120)))

    # task
    ty = bar_y + bar_h + gap2
    if task:
        cv.text(
            (x + pad_x, ty + task_h * 0.06),
            cv.fit(task, task_sz, "r", w - pad_x * 2),
            task_sz,
            fade(c_task),
            "r",
            alpha=alpha,
            shadow=shadow if style == "glass" else None,
        )
    if meta:
        my = ty + task_h + gap3
        cv.text(
            (x + pad_x, my + meta_h * 0.04),
            cv.fit(meta, meta_sz, "r", w - pad_x * 2),
            meta_sz,
            fade(c_meta),
            "r",
            alpha=alpha,
        )
    return h


# --------------------------------------------------------------------------
# Small UI bits
# --------------------------------------------------------------------------


def draw_pill(cv: Canvas, cx, cy, label, size=22, pad_x=24, pad_y=13, alpha=1.0,
              color=(199, 211, 242, 255), border=(255, 255, 255, 44), fill=(255, 255, 255, 8),
              kind="r"):
    if alpha <= 0:
        return
    tw = cv.text_len(label, size, kind)
    w = tw + pad_x * 2
    h = size + pad_y * 2
    cv.rrect(cx - w / 2, cy - h / 2, w, h, h / 2, fill=_a(fill, alpha), outline=_a(border, alpha), width=1.2)
    cv.text((cx, cy + size * 0.02), label, size, _a(color, alpha), kind, anchor="mm", alpha=alpha)


def draw_kicker(cv: Canvas, xy, text, alpha=1.0, color=C["ink3"], size=18, anchor="la", accent=None):
    if alpha <= 0:
        return
    x, y = xy
    cv.text((x, y), text, size, _a(color, alpha), "ensb", anchor=anchor, ls=3.4, alpha=alpha)
    if accent:
        tw = cv.text_len(text, size, "ensb") + 3.4 * (len(text) - 1)
        if anchor[0] == "m":
            start = x - tw / 2
        elif anchor[0] == "r":
            start = x - tw
        else:
            start = x
        cv.rect(start, y + size + 9, 46, 3, fill=_a(accent, alpha))


def draw_check_badge(cv: Canvas, cx, cy, r, alpha=1.0, scale=1.0):
    if alpha <= 0:
        return
    r = r * scale
    cv.circle(cx, cy, r, fill=_a((61, 220, 151, 255), alpha))
    cv.circle(cx, cy, r, outline=_a((255, 255, 255, 235), alpha), width=max(1.2, r * 0.12))
    pts = [
        (cx - r * 0.42, cy + r * 0.02),
        (cx - r * 0.1, cy + r * 0.34),
        (cx + r * 0.46, cy - r * 0.32),
    ]
    cv.line(pts, fill=_a((255, 255, 255, 255), alpha), width=max(1.5, r * 0.2))


def _a(color, alpha):
    if len(color) == 3:
        color = (*color, 255)
    return (color[0], color[1], color[2], int(color[3] * clamp(alpha)))


def draw_sparkle(cv: Canvas, cx, cy, r, color=(255, 216, 107), alpha=1.0, rot=0.0):
    if alpha <= 0 or r <= 0:
        return
    pts = []
    for i in range(8):
        ang = rot + i * math.pi / 4
        rad = r if i % 2 == 0 else r * 0.32
        pts.append((cx + math.cos(ang) * rad, cy + math.sin(ang) * rad))
    cv.polygon(pts, fill=_a((*color[:3], 255), alpha))


# --------------------------------------------------------------------------
# Wooden/dark "desktop" helpers
# --------------------------------------------------------------------------


def draw_logo_mark(cv: Canvas, cx, cy, r, alpha=1.0):
    """Small whale-tail inspired mark used as a repeated brand accent."""
    if alpha <= 0:
        return
    cv.circle(cx, cy, r, fill=_a((124, 147, 255, 255), alpha))
    # tail silhouette
    cv.polygon(
        [
            (cx - r * 0.62, cy + r * 0.05),
            (cx + r * 0.05, cy + r * 0.05),
            (cx + r * 0.52, cy - r * 0.44),
            (cx + r * 0.2, cy + r * 0.42),
        ],
        fill=_a((255, 255, 255, 255), alpha),
    )
