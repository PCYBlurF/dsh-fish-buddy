"""Render the DSH Fish Buddy promo video (1920x1080 @ 60fps).

Usage:
    python build.py --stills 1.0,5.0,12.0        # PNG stills for review
    python build.py --preview                    # fast low-res motion preview
    python build.py --render                     # final video (no audio mux)
    python build.py --all                        # soundtrack + final mux
"""

from __future__ import annotations

import argparse
import math
import os
import shutil
import subprocess
import sys
import time

import numpy as np
from PIL import Image

from background import Background, apply_vignette_and_grain, mood_at
from promolib import (
    C,
    H,
    W,
    Canvas,
    clamp,
    fish_icon,
    inv_lerp,
    smoothstep,
    _with_alpha,
)
from scenes import LIGHT_KEYS, SCENE_FNS
from timeline import BEAT, DURATION, FPS, SCENES, TOTAL_FRAMES

PROMO_DIR = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(PROMO_DIR, "out")
PREVIEW_DIR = os.path.join(PROMO_DIR, "preview")
os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(PREVIEW_DIR, exist_ok=True)

def find_ffmpeg():
    env = os.environ.get("FFMPEG")
    if env and os.path.exists(env):
        return env
    try:
        import imageio_ffmpeg

        exe = imageio_ffmpeg.get_ffmpeg_exe()
        if exe and os.path.exists(exe):
            return exe
    except Exception:
        pass
    for cand in ("ffmpeg", "ffmpeg.exe"):
        found = shutil.which(cand)
        if found:
            return found
    return "ffmpeg"


FFMPEG = find_ffmpeg()

ENV = {
    "intro": (0.02, 0.65, 26),
    "progress": (0.55, 0.45, 20),
    "states": (0.55, 0.45, 20),
    "celebrate": (0.45, 0.45, 18),
    "details": (0.50, 0.45, 20),
    "install": (0.45, 0.45, 20),
    "outro": (0.60, 0.02, 16),
}

FOOTER = None


def scene_at(t):
    for name, start, end in SCENES:
        if t < end or name == SCENES[-1][0]:
            return name, start, end
    return SCENES[-1]


def alpha_mul(img: Image.Image, factor: float) -> Image.Image:
    a = np.asarray(img.getchannel("A")).astype(np.uint16)
    a = (a * int(round(factor * 255))) >> 8
    img.putalpha(Image.fromarray(a.astype(np.uint8), "L"))
    return img


def translate(img: Image.Image, dx: float, dy: float) -> Image.Image:
    if abs(dx) < 0.4 and abs(dy) < 0.4:
        return img
    return img.transform(
        img.size,
        Image.AFFINE,
        (1, 0, -dx, 0, 1, -dy),
        resample=Image.BILINEAR,
    )


def build_footer() -> Image.Image:
    global FOOTER
    if FOOTER is not None:
        return FOOTER
    cv = Canvas(W, 48, 2)
    cv.img.alpha_composite(fish_icon(26 * 2), (56 * 2, 10 * 2))
    cv.text((92, 10), "DSH 桌面挂件", 17, (185, 199, 232, 255), "b")
    cv.text((236, 13), "v0.1.21", 13, (128, 144, 184, 255), "r")
    cv.text((W - 64, 13), "github.com/PCYBlurF/dsh-fish-buddy", 15, (128, 144, 184, 255), "mono", anchor="ra")
    FOOTER = cv.img.reduce(2)
    return FOOTER


def pulse_at(t):
    p = 0.0
    for name, start, end in SCENES[1:]:
        dt = t - start
        if 0 <= dt < 1.4:
            p += 0.55 * math.exp(-dt * 3.0)
    return p


class Renderer:
    def __init__(self, ss=2):
        self.ss = ss
        self.bg = Background()

    def render(self, t: float, ss: int | None = None, grain=True):
        ss = self.ss if ss is None else ss
        mood, center, inten = mood_at(t, LIGHT_KEYS)
        bg = self.bg.render(t, mood, center, inten, pulse_at(t))

        name, start, end = scene_at(t)
        fin, fout, drift = ENV[name]
        content = Canvas(W, H, ss)
        SCENE_FNS[name](content, t, t - start)

        alpha = min(
            smoothstep(inv_lerp(start, start + fin, t)),
            1.0 - smoothstep(inv_lerp(end - fout, end, t)),
        )
        dy = (1 - smoothstep(inv_lerp(start, start + fin + 0.4, t))) * drift
        img = content.img
        if abs(dy) > 0.4:
            img = translate(img, 0, dy * ss)
        if alpha < 0.998:
            img = alpha_mul(img, alpha)
        if ss > 1:
            img = img.reduce(ss)
        bg.alpha_composite(img)

        # persistent footer
        vis = smoothstep(inv_lerp(4.3, 4.9, t)) * (1 - smoothstep(inv_lerp(33.7, 34.4, t)))
        if vis > 0.01:
            bg.alpha_composite(_with_alpha(build_footer(), 0.9 * vis), (0, 1032))

        if grain:
            out = apply_vignette_and_grain(bg, t)
        else:
            out = bg.convert("RGB")

        # completion flash (global, so it lights the whole frame)
        if BEAT["completed"] <= t <= BEAT["completed"] + 0.95:
            fl = 0.16 * math.exp(-(t - BEAT["completed"]) * 9.0)
            if fl > 0.002:
                white = Image.new("RGB", out.size, (235, 245, 255))
                out = Image.blend(out, white, fl)

        fade = smoothstep(inv_lerp(0.0, 0.5, t)) * (1.0 - smoothstep(inv_lerp(38.6, 40.0, t)))
        if fade < 0.999:
            black = Image.new("RGB", out.size, (0, 0, 0))
            out = Image.blend(black, out, fade)
        return out


# --------------------------------------------------------------------------
# encoding
# --------------------------------------------------------------------------


def encode_video(renderer: Renderer, out_path: str, preview=False):
    if preview:
        out_w, out_h, fps = 960, 540, 30
        step = 2
        n = int(TOTAL_FRAMES / step)
        cmd = [
            FFMPEG, "-y", "-hide_banner", "-loglevel", "error",
            "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{out_w}x{out_h}", "-r", str(fps), "-i", "-",
            "-an", "-c:v", "libx264", "-preset", "veryfast", "-crf", "25",
            "-pix_fmt", "yuv420p", "-movflags", "+faststart", out_path,
        ]
    else:
        out_w, out_h, fps = W, H, FPS
        step = 1
        n = TOTAL_FRAMES
        cmd = [
            FFMPEG, "-y", "-hide_banner", "-loglevel", "error",
            "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{out_w}x{out_h}", "-r", str(fps), "-i", "-",
            "-an", "-c:v", "libx264", "-preset", "medium", "-crf", "18",
            "-profile:v", "high", "-level", "4.2", "-pix_fmt", "yuv420p",
            "-x264-params", "aq-mode=3:aq-strength=1.0",
            "-color_primaries", "bt709", "-color_trc", "bt709", "-colorspace", "bt709",
            "-g", "120", "-movflags", "+faststart", out_path,
        ]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    t0 = time.time()
    for i in range(n):
        f = i * step
        t = f / FPS
        frame = renderer.render(t, ss=1 if preview else None)
        if preview:
            frame = frame.resize((out_w, out_h), Image.LANCZOS)
        proc.stdin.write(frame.tobytes())
        if i % 60 == 0:
            el = time.time() - t0
            fps_now = (i + 1) / max(1e-6, el)
            eta = (n - i) / max(1e-6, fps_now)
            print(f"  frame {i}/{n}  t={t:5.2f}s  {fps_now:5.2f} fps  eta {eta/60:4.1f} min", flush=True)
    proc.stdin.close()
    rc = proc.wait()
    if rc != 0:
        raise SystemExit(f"ffmpeg failed with code {rc}")
    print(f"video written: {out_path}  ({time.time()-t0:.1f}s)")


def render_stills(renderer: Renderer, times, ss=2):
    for t in times:
        t0 = time.time()
        frame = renderer.render(t, ss=ss)
        name = f"still_{t:05.2f}.png".replace(".", "_", 1)
        path = os.path.join(PREVIEW_DIR, name)
        frame.save(path)
        print(f"still t={t:5.2f} -> {path} ({time.time()-t0:.2f}s)")


def mux_audio(video_in, audio_in, out_path):
    cmd = [
        FFMPEG, "-y", "-hide_banner", "-loglevel", "error",
        "-i", video_in, "-i", audio_in,
        "-c:v", "copy", "-c:a", "aac", "-b:a", "256k", "-ar", "48000",
        "-af", "loudnorm=I=-14:TP=-1.5:LRA=11",
        "-shortest", "-movflags", "+faststart", out_path,
    ]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit(r.stderr)
    print("muxed:", out_path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--stills", type=str, default="")
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--render", action="store_true")
    ap.add_argument("--audio", action="store_true")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--ss", type=int, default=2)
    args = ap.parse_args()

    renderer = Renderer(ss=args.ss)

    if args.stills:
        times = [float(x) for x in args.stills.split(",") if x.strip()]
        render_stills(renderer, times, ss=args.ss)
        return

    if args.preview:
        encode_video(renderer, os.path.join(PREVIEW_DIR, "preview.mp4"), preview=True)
        return

    if args.audio or args.all:
        from audio import build_soundtrack

        wav = os.path.join(OUT_DIR, "soundtrack.wav")
        build_soundtrack(wav)
        print("soundtrack:", wav)

    if args.render or args.all:
        video = os.path.join(OUT_DIR, "video_noaudio.mp4")
        encode_video(renderer, video, preview=False)
        if args.audio or args.all:
            final = os.path.join(PROMO_DIR, "dsh-desktop-widget-promo-1080p60.mp4")
            mux_audio(video, os.path.join(OUT_DIR, "soundtrack.wav"), final)
            with open(os.path.join(OUT_DIR, "render_info.txt"), "w", encoding="utf-8") as f:
                f.write("DSH Fish Buddy promo\n1920x1080 60fps\nduration 60s\n")


if __name__ == "__main__":
    main()
