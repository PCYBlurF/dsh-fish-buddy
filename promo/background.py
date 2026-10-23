"""Persistent atmospheric background for the promo (stars, glows, bubbles)."""

from __future__ import annotations

import math

import numpy as np
from functools import lru_cache

from PIL import Image, ImageDraw, ImageFilter

from promolib import (
    C,
    H,
    W,
    clamp,
    lerp,
    mix,
    glow_layer,
    radial_sprite,
    seeded,
    smoothstep,
    vignette_layer,
)


class Background:
    def __init__(self, w=W, h=H):
        self.w, self.h = w, h
        self.base = self._make_base()
        self.rays = self._make_rays()
        rng = seeded(11, 3)
        self.stars = []
        for i in range(150):
            x = rng.uniform(0, w)
            y = rng.uniform(0, h)
            r = rng.choice([0.8, 1.0, 1.2, 1.6, 2.1, 2.8])
            a = rng.randint(45, 165)
            ph = rng.uniform(0, math.tau)
            sp = rng.uniform(0.35, 1.25)
            drift = rng.uniform(0.8, 3.0)
            self.stars.append((x, y, r, a, ph, sp, drift))
        self.bubbles = []
        for i in range(16):
            self.bubbles.append(
                (
                    seeded(100 + i, 5).uniform(0.03, 0.97),
                    seeded(200 + i, 5).uniform(0, 1),
                    seeded(300 + i, 5).uniform(2.0, 7.5),
                    seeded(400 + i, 5).uniform(2.5, 6.0),
                    seeded(500 + i, 5).uniform(0, math.tau),
                    seeded(600 + i, 5).uniform(0.16, 0.5),
                )
            )
        self.bokeh = []
        for i in range(5):
            r = seeded(700 + i, 8)
            radius = int(r.uniform(120, 260))
            self.bokeh.append(
                (
                    r.uniform(0.1, 0.9),
                    r.uniform(0.1, 0.9),
                    radius,
                    glow_layer(radius, (110, 140, 230), 16, 2.4),
                    r.uniform(0, math.tau),
                )
            )

    # ------------------------------------------------------------------
    def _make_base(self):
        w, h = self.w, self.h
        yy = np.linspace(0, 1, h, dtype=np.float32)[:, None]
        # deep navy vertical gradient
        top = np.array([6, 9, 20], np.float32)
        mid = np.array([11, 18, 42], np.float32)
        bot = np.array([5, 8, 20], np.float32)
        col = np.where(yy < 0.55, top + (mid - top) * (yy / 0.55), mid + (bot - mid) * ((yy - 0.55) / 0.45))
        arr = np.repeat(col[:, None, :], w, axis=1)
        # wide ambient glow baked into the base
        xx = np.arange(w, dtype=np.float32)[None, :]
        yy2 = np.arange(h, dtype=np.float32)[:, None]
        d = np.sqrt(((xx - w * 0.60) / (w * 0.62)) ** 2 + ((yy2 - h * 0.55) / (h * 0.62)) ** 2)
        glow = np.clip(1 - d, 0, 1) ** 2.4
        arr += np.array([16, 30, 66], np.float32) * glow[..., None] * 0.85
        arr = np.clip(arr, 0, 255).astype(np.uint8)
        rgba = np.dstack([arr, np.full((h, w), 255, np.uint8)])
        return Image.fromarray(rgba, "RGBA")

    def _make_rays(self):
        layer = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        bands = [
            [(1280, -80), (1560, -80), (760, self.h + 80), (520, self.h + 80)],
            [(1620, -80), (1700, -80), (1050, self.h + 80), (940, self.h + 80)],
            [(300, -80), (470, -80), (60, self.h + 80), (-120, self.h + 80)],
        ]
        for i, poly in enumerate(bands):
            d.polygon(poly, fill=(150, 178, 255, 7 if i != 1 else 10))
        layer = layer.filter(ImageFilter.GaussianBlur(70))
        return layer

    # ------------------------------------------------------------------
    def render(self, t, mood=(124, 147, 255), center=(1150, 560), intensity=1.0, pulse=0.0):
        img = self.base.copy()
        ov = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))

        # key light behind the composition
        breed = 1.0 + 0.045 * math.sin(t * 0.55) + pulse * 0.25
        g = glow_layer(1150, mood[:3], 52 * intensity * breed, 2.0)
        ov.alpha_composite(g, (int(center[0] - g.width / 2), int(center[1] - g.height / 2)))
        g2 = glow_layer(700, mood[:3], 46 * intensity, 2.8)
        ov.alpha_composite(g2, (int(center[0] - g2.width / 2 - 250), int(center[1] - g2.height / 2 + 160)))
        # cool rim light from the top right
        g3 = glow_layer(820, (105, 150, 255), 24, 2.6)
        ov.alpha_composite(g3, (int(self.w * 0.86 - g3.width / 2), int(self.h * 0.12 - g3.height / 2)))

        # slow bokeh
        for (bx, by, radius, spr, ph) in self.bokeh:
            ov.alpha_composite(
                spr,
                (
                    int(bx * self.w - spr.width / 2 + 18 * math.sin(t * 0.12 + ph)),
                    int(by * self.h - spr.height / 2 + 12 * math.cos(t * 0.1 + ph)),
                ),
            )

        # light rays
        rays = self.rays.copy()
        rays.putalpha(rays.getchannel("A").point(lambda v: int(v * (0.55 + 0.18 * math.sin(t * 0.3)))))
        img.alpha_composite(rays)

        # stars
        d = ImageDraw.Draw(ov)
        for (x, y, r, a, ph, sp, drift) in self.stars:
            yy = (y - t * drift) % (self.h + 40) - 20
            tw = 0.55 + 0.45 * math.sin(t * sp + ph)
            alpha = int(a * tw)
            if alpha <= 3:
                continue
            col = (225, 235, 255, alpha)
            d.ellipse([x - r, yy - r, x + r, yy + r], fill=col)
            if r > 2.2 and tw > 0.85:
                gl = glow_layer(20, (190, 210, 255), 90, 2.6)
                ov.alpha_composite(gl, (int(x - gl.width / 2), int(yy - gl.height / 2)))

        # rising air bubbles
        for (nx, phase, speed, r, ph, alpha) in self.bubbles:
            yy = (self.h + 60 - ((t * speed * 10 + phase * self.h) % (self.h + 120)))
            xx = nx * self.w + 16 * math.sin(t * 0.5 + ph) + 8 * math.sin(t * 1.3 + ph * 2)
            a = int(255 * alpha * (0.6 + 0.4 * math.sin(t * 0.8 + ph)))
            d.ellipse([xx - r, yy - r, xx + r, yy + r], outline=(170, 200, 255, a), width=1)
            d.ellipse(
                [xx - r * 0.35, yy - r * 0.45, xx - r * 0.05, yy - r * 0.1],
                fill=(230, 240, 255, min(255, a + 40)),
            )

        img.alpha_composite(ov)
        return img


def mood_at(t, keys):
    """keys: [(time, (r,g,b), (cx,cy), intensity), ...] smooth interpolation."""
    if t <= keys[0][0]:
        return keys[0][1], keys[0][2], keys[0][3]
    for i in range(len(keys) - 1):
        t0, c0, p0, i0 = keys[i]
        t1, c1, p1, i1 = keys[i + 1]
        if t <= t1:
            u = smoothstep((t - t0) / max(1e-6, t1 - t0))
            return (
                mix(c0, c1, u)[:3],
                (lerp(p0[0], p1[0], u), lerp(p0[1], p1[1], u)),
                lerp(i0, i1, u),
            )
    return keys[-1][1], keys[-1][2], keys[-1][3]


@lru_cache(maxsize=1)
def _grain_frames(h, w, n=8, amp=2.6):
    rng = np.random.default_rng(4242)
    return [np.clip(rng.normal(0, amp, (h, w, 1)), -12, 12).astype(np.int16) for _ in range(n)]


def apply_vignette_and_grain(img: Image.Image, t: float, grain_amp: float = 2.6) -> Image.Image:
    img = Image.alpha_composite(img, vignette_layer(img.width, img.height, 0.5))
    arr = np.asarray(img.convert("RGB")).astype(np.int16)
    frames = _grain_frames(img.height, img.width)
    noise = frames[int(t * 60) % len(frames)]
    arr += noise
    np.clip(arr, 0, 255, out=arr)
    return Image.fromarray(arr.astype(np.uint8), "RGB")
