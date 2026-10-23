"""Original soundtrack + SFX for the DSH Fish Buddy promo.

100 BPM, A-minor lofi: warm pad, bell arpeggio, soft kick/hats, sub bass.
The widget's own chime.wav lands on the completion beat.
"""

from __future__ import annotations

import math
import os
import wave

import numpy as np

from timeline import BEAT, DURATION, TERM_TYPING

SR = 48000
N = int(DURATION * SR)
T = np.arange(N, dtype=np.float64) / SR
RNG = np.random.default_rng(20261023)
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BEAT_S = 60.0 / 100.0


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


def env_ad(n, attack, decay, curve=1.6):
    a = np.linspace(0, 1, max(1, int(attack * SR))) ** 0.65
    d = np.exp(-np.linspace(0, 5, max(1, n - len(a))) * curve)
    return np.concatenate([a, d])[:n]


def add(buf, sig, start, gain=1.0):
    i = int(start * SR)
    if i >= len(buf) or i < 0:
        return
    j = min(len(buf), i + len(sig))
    buf[i:j] += sig[: j - i] * gain


def place_note(buf, freq, start, dur, gain=1.0, kind="pluck"):
    n = int(dur * SR)
    if n <= 0:
        return
    tt = np.arange(n) / SR
    if kind == "pluck":
        e = np.exp(-tt * 5.2) * (1 - np.exp(-tt * 240))
        w = np.sin(2 * math.pi * freq * tt) + 0.32 * np.sin(4 * math.pi * freq * tt) + 0.12 * np.sin(6 * math.pi * freq * tt)
    elif kind == "bell":
        e = np.exp(-tt * 2.6) * (1 - np.exp(-tt * 180))
        w = (
            np.sin(2 * math.pi * freq * tt)
            + 0.42 * np.sin(2 * math.pi * freq * 2.01 * tt)
            + 0.18 * np.sin(2 * math.pi * freq * 3.02 * tt)
            + 0.08 * np.sin(2 * math.pi * freq * 4.97 * tt)
        )
    else:  # pad
        e = env_ad(n, 1.1, 0, 1.0)
        w = (
            np.sin(2 * math.pi * freq * tt)
            + 0.30 * np.sin(4 * math.pi * freq * tt)
            + 0.10 * np.sin(6 * math.pi * freq * tt)
            + 0.35 * np.sin(2 * math.pi * (freq * 1.0025) * tt)
        )
    add(buf, w * e, start, gain)


# --------------------------------------------------------------------------
# harmony
# --------------------------------------------------------------------------

# Am9 / Fmaj9 / Cmaj9 / G6 (two bars each chord? one bar each)
CHORDS = [
    dict(root=45, notes=[57, 60, 64, 67, 71], pad=[57, 60, 64, 67], pluck=[69, 72, 76, 79, 83]),
    dict(root=41, notes=[53, 57, 60, 64, 67], pad=[53, 57, 60, 64], pluck=[65, 69, 72, 76, 81]),
    dict(root=48, notes=[55, 59, 60, 64, 67], pad=[55, 59, 60, 64], pluck=[67, 72, 76, 79, 84]),
    dict(root=43, notes=[55, 59, 62, 64, 67], pad=[55, 59, 62, 67], pluck=[67, 71, 74, 79, 83]),
]


def chord_at(t):
    bar = int(t // BEAT_S / 4) % len(CHORDS)
    return CHORDS[bar]


# --------------------------------------------------------------------------
# stems
# --------------------------------------------------------------------------


def build_pad():
    buf = np.zeros(N)
    bar = BEAT_S * 4
    t0 = 0.0
    while t0 < DURATION + 2:
        ch = chord_at(t0 + 0.01)
        for i, n in enumerate(ch["pad"]):
            dur = bar + 2.2
            start = t0 - 0.4
            g = 0.078 if i == 0 else 0.058
            place_note(buf, midi(n), max(0.0, start), dur, gain=g, kind="pad")
        # low root an octave down
        place_note(buf, midi(ch["root"]), t0, bar + 1.6, gain=0.052, kind="pad")
        t0 += bar
    # gentle lift in the middle sections
    auto = np.interp(
        T,
        [0, 0.9, 4.0, 10.6, 16.0, 22.0, 28.0, 33.0, 34.8, 37.5, 40.0],
        [0.9, 1.0, 1.0, 1.05, 1.0, 1.0, 1.0, 1.08, 1.12, 1.05, 0.0],
    )
    return buf * auto


def build_bass():
    buf = np.zeros(N)
    beat = 0
    while beat * BEAT_S < DURATION:
        t0 = beat * BEAT_S
        ch = chord_at(t0 + 0.01)
        root = midi(ch["root"] - 12)
        dur = 0.55
        n = int(dur * SR)
        tt = np.arange(n) / SR
        sig = (np.sin(2 * math.pi * root * tt) + 0.32 * np.sin(4 * math.pi * root * tt)) * np.exp(-tt * 3.4) * (1 - np.exp(-tt * 60))
        add(buf, sig, t0, 0.235)
        beat += 1
    auto = np.interp(T, [0, 7, 10, 17, 26, 35, 44, 52, 60], [0.0, 0.0, 0.6, 1.0, 0.95, 1.0, 0.85, 0.35, 0.0])
    return buf * auto


def build_kick():
    buf = np.zeros(N)
    beat = 0
    while beat * BEAT_S < DURATION:
        t0 = beat * BEAT_S
        n = int(0.30 * SR)
        tt = np.arange(n) / SR
        f = 108 * np.exp(-tt * 26) + 44
        ph = 2 * math.pi * np.cumsum(f) / SR
        sig = np.sin(ph) * np.exp(-tt * 15) * (1 - np.exp(-tt * 500))
        click = RNG.normal(0, 0.5, n) * np.exp(-tt * 400)
        add(buf, sig + 0.12 * click, t0, 0.255)
        beat += 1
    auto = np.interp(T, [0, 7, 9, 17, 26, 35, 44, 52, 60], [0.0, 0.0, 0.35, 0.8, 0.7, 0.8, 0.6, 0.0, 0.0])
    return buf * auto


def build_hats():
    buf = np.zeros(N)
    step = BEAT_S / 2
    k = 0
    hp = None
    while k * step < DURATION:
        t0 = k * step
        n = int(0.075 * SR)
        tt = np.arange(n) / SR
        noise = RNG.normal(0, 1, n)
        if hp is None:
            hp = np.concatenate([[0.0], np.diff(noise)])
        sig = np.concatenate([[0.0], np.diff(noise)]) * np.exp(-tt * 90)
        add(buf, sig, t0, 0.05 if k % 2 == 0 else 0.085)
        k += 1
    auto = np.interp(T, [0, 12, 17, 26, 35, 44, 52, 60], [0.0, 0.2, 0.7, 0.6, 0.75, 0.55, 0.15, 0.0])
    return buf * auto


def build_pluck():
    buf = np.zeros(N)
    step = BEAT_S / 2
    pattern = [0, 2, 1, 3, 2, 1, 4, 2]
    k = 0
    while k * step < DURATION:
        t0 = k * step
        ch = chord_at(t0 + 0.01)
        degree = pattern[k % len(pattern)]
        note = ch["pluck"][degree % len(ch["pluck"])]
        if k % 16 in (7, 15):
            note += 12
        # leave a rest at the end of each 2-bar phrase
        if k % 16 not in (6, 14):
            place_note(buf, midi(note), t0, 0.9, gain=0.062, kind="pluck")
        k += 1
    auto = np.interp(T, [0, 6.5, 8, 17, 26, 35, 44, 52, 60], [0.0, 0.0, 0.7, 1.0, 0.8, 1.0, 0.9, 0.45, 0.0])
    return buf * auto


def build_bells():
    buf = np.zeros(N)
    # sparse motif, phrased around section changes
    motif = [
        (1.10, 76, 0.55), (2.00, 79, 0.50), (2.90, 72, 0.50),
        (4.60, 81, 0.50), (5.60, 76, 0.45), (6.80, 79, 0.50), (8.20, 84, 0.40), (9.50, 81, 0.40),
        (11.20, 76, 0.50), (12.20, 79, 0.45), (13.30, 84, 0.40), (14.60, 81, 0.45),
        (17.20, 88, 0.42), (18.30, 84, 0.38), (19.60, 79, 0.40), (20.90, 76, 0.40),
        (22.70, 79, 0.45), (23.80, 84, 0.40), (25.50, 81, 0.40), (26.80, 76, 0.40),
        (28.80, 72, 0.40), (30.00, 76, 0.35), (31.30, 79, 0.35), (32.60, 84, 0.35),
        (33.20, 88, 0.32), (33.45, 91, 0.22),
        (35.30, 72, 0.50), (36.40, 76, 0.45), (37.50, 79, 0.40), (38.60, 84, 0.35),
    ]
    for (st, note, g) in motif:
        if st < DURATION:
            place_note(buf, midi(note), st, 2.4, gain=g * 0.21, kind="bell")
    return buf


def build_riser():
    """Soft noise riser into the completion beat."""
    buf = np.zeros(N)
    for (t_end, dur, amp) in [(BEAT["completed"], 1.4, 0.10), (33.15, 1.0, 0.05)]:
        n = int(dur * SR)
        noise = RNG.normal(0, 1, n)
        # cheap lowpass by moving average
        kernel = np.ones(48) / 48
        noise = np.convolve(noise, kernel, mode="same")
        e = (np.linspace(0, 1, n) ** 2.2) * np.linspace(1.0, 0.2, n)
        add(buf, noise * e, t_end - dur, 1.0)
        # pitch sweep sine
        tt = np.arange(n) / SR
        f = 260 * (1 + np.linspace(0, 1.6, n) ** 2)
        ph = 2 * math.pi * np.cumsum(f) / SR
        add(buf, np.sin(ph) * e * 0.25, t_end - dur, 0.5)
    return buf


def build_whooshes():
    buf = np.zeros(N)
    boundaries = [4.0, 10.6, 16.0, 22.0, 28.0, 34.8]
    for b in boundaries:
        dur = 0.85
        n = int(dur * SR)
        noise = RNG.normal(0, 1, n)
        kernel = np.ones(90) / 90
        noise = np.convolve(noise, kernel, mode="same")
        e = np.sin(np.linspace(0, math.pi, n)) ** 2
        add(buf, noise * e, b - 0.40, 0.055)
    return buf


def build_typing():
    buf = np.zeros(N)
    for (_kind, t0, t1, text) in TERM_TYPING:
        n_chars = max(1, len(text))
        step = (t1 - t0) / n_chars
        k = 0
        while t0 + k * step < t1:
            tt = t0 + k * step + RNG.uniform(0, step * 0.35)
            n = int(0.03 * SR)
            x = np.arange(n) / SR
            click = np.concatenate([[0.0], np.diff(RNG.normal(0, 1, n))]) * np.exp(-x * 220)
            add(buf, click, tt, 0.05 + RNG.uniform(0, 0.035))
            k += 1
    return buf


# --------------------------------------------------------------------------
# the widget chime
# --------------------------------------------------------------------------


def load_chime():
    path = os.path.join(ROOT, "assets", "chime.wav")
    with wave.open(path, "rb") as w:
        ch = w.getnchannels()
        sw = w.getsampwidth()
        sr = w.getframerate()
        n = w.getnframes()
        raw = w.readframes(n)
    if sw == 2:
        data = np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0
    elif sw == 4:
        data = np.frombuffer(raw, dtype="<i4").astype(np.float64) / 2147483648.0
    else:
        data = np.frombuffer(raw, dtype="<u1").astype(np.float64) / 128.0 - 1.0
    if ch > 1:
        data = data.reshape(-1, ch).mean(axis=1)
    if sr != SR:
        x_old = np.linspace(0, 1, len(data))
        x_new = np.linspace(0, 1, int(len(data) * SR / sr))
        data = np.interp(x_new, x_old, data)
    # trim leading silence
    thr = np.max(np.abs(data)) * 0.02
    idx = np.argmax(np.abs(data) > thr)
    return data[max(0, idx - 40):]


# --------------------------------------------------------------------------
# mix
# --------------------------------------------------------------------------


def fft_convolve(sig, ir):
    n = len(sig) + len(ir) - 1
    size = 1 << (n - 1).bit_length()
    s = np.fft.rfft(sig, size)
    i = np.fft.rfft(ir, size)
    return np.fft.irfft(s * i, size)[: len(sig)]


def make_ir(seconds=2.4, seed=1):
    n = int(seconds * SR)
    rng = np.random.default_rng(seed)
    t = np.arange(n) / SR
    sig = rng.normal(0, 1, n) * np.exp(-t * 2.9)
    # soften the highs
    kernel = np.ones(6) / 6
    sig = np.convolve(sig, kernel, mode="same")
    sig[: int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))
    return sig / np.sqrt(np.sum(sig**2))


def build_soundtrack(out_path: str):
    pad = build_pad()
    bass = build_bass()
    kick = build_kick()
    hats = build_hats()
    pluck = build_pluck()
    bells = build_bells()
    riser = build_riser()
    whoosh = build_whooshes()
    typing = build_typing()

    dry = pad + bass + kick + hats + pluck + bells + riser + whoosh + typing

    # reverb send (mono -> stereo)
    send = 0.55 * pad + 0.75 * bells + 0.35 * pluck + 0.2 * riser + 0.15 * whoosh
    ir_l = make_ir(2.6, 11)
    ir_r = make_ir(2.6, 23)
    wet_l = fft_convolve(send, ir_l) * 0.55
    wet_r = fft_convolve(send, ir_r) * 0.55

    left = dry + wet_l
    right = dry * 0.97 + wet_r

    # stereo width from a tiny haas delay on pads/bells
    delay = int(0.011 * SR)
    left[delay:] += 0.10 * (bells + pad)[:-delay]
    right[:-delay] += 0.08 * (bells + pad)[delay:]

    # chime at completion
    chime = load_chime()
    i = int(BEAT["chime"] * SR)
    seg = chime[: min(len(chime), N - i)]
    left[i : i + len(seg)] += seg * 0.55
    right[i : i + len(seg)] += seg * 0.52
    # a soft echo of the chime
    i2 = i + int(0.24 * SR)
    seg2 = chime[: min(len(chime), N - i2)] * 0.18
    left[i2 : i2 + len(seg2)] += seg2
    right[i2 : i2 + len(seg2)] += seg2 * 0.9

    # section automation on the master (leave the chime alone)
    music = np.interp(
        T,
        [0, 0.8, 3.8, 4.4, 10.4, 16.4, 16.95, 17.2, 18.5, 22.0, 28.0, 33.15, 34.8, 36.0, 38.5, 40.0],
        [0.0, 0.9, 1.0, 1.0, 1.0, 1.0, 1.0, 0.72, 0.95, 1.0, 1.0, 1.0, 1.0, 0.95, 0.6, 0.0],
    )
    left *= music
    right *= music
    # fade edges
    fade = int(0.5 * SR)
    ramp = np.linspace(0, 1, fade) ** 1.4
    left[:fade] *= ramp
    right[:fade] *= ramp
    out_fade = int(1.8 * SR)
    ramp2 = np.linspace(1, 0, out_fade) ** 1.2
    left[-out_fade:] *= ramp2
    right[-out_fade:] *= ramp2

    # gentle glue + limiter
    mix = np.stack([left, right], axis=1)
    # high-pass at 32 Hz (FFT) to keep the sub tight
    n = len(mix)
    size = 1 << (n - 1).bit_length()
    freqs = np.fft.rfftfreq(size, 1 / SR)
    hp = np.clip((freqs - 24.0) / 20.0, 0, 1)
    for ch in range(2):
        spec = np.fft.rfft(mix[:, ch], size)
        spec *= hp
        mix[:, ch] = np.fft.irfft(spec, size)[:n]
    mix = np.tanh(mix * 1.15) / math.tanh(1.15)
    peak = np.max(np.abs(mix))
    if peak > 0:
        mix = mix / peak * 0.92
    data = (np.clip(mix, -1, 1) * 32767).astype("<i2")

    with wave.open(out_path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())

    # report
    mono = data.astype(np.float64).mean(axis=1) / 32768.0
    print(f"soundtrack: {out_path}")
    print(f"  peak {20*math.log10(max(1e-9, np.max(np.abs(mono)))):.1f} dBFS")
    from timeline import SCENES as _SCENES

    for label, a, b in _SCENES:
        seg = mono[int(a * SR) : int(b * SR)]
        rms = 20 * math.log10(max(1e-9, math.sqrt(np.mean(seg**2))))
        print(f"  {label:9s} rms {rms:6.1f} dBFS")


if __name__ == "__main__":
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out", "soundtrack.wav")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    build_soundtrack(out)
