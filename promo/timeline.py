"""Shared timing constants for the DSH Desktop Widget promo video.

Both the frame renderer and the soundtrack generator import this module so
that music hits, SFX and on-screen events stay in sync.
"""

FPS = 60
W = 1920
H = 1080
DURATION = 40.0
TOTAL_FRAMES = int(round(FPS * DURATION))

# (name, start, end) — tightened 60s cut down to 40s
SCENES = [
    ("intro", 0.0, 4.0),
    ("progress", 4.0, 10.6),
    ("states", 10.6, 16.0),
    ("celebrate", 16.0, 22.0),
    ("details", 22.0, 28.0),
    ("install", 28.0, 34.8),
    ("outro", 34.8, 40.0),
]

SCENE_BOUNDS = {name: (start, end) for name, start, end in SCENES}

# Key story beats (absolute seconds)
BEAT = {
    "title_in": 0.35,
    "progress_in": 4.30,
    "states_in": 10.90,
    "celebrate_start": 16.00,
    "completed": 16.95,
    "chime": 17.00,
    "toast_in": 17.35,
    "details_in": 22.30,
    "install_in": 28.40,
    "install_done": 33.15,
    "outro_in": 35.10,
    "end_fade": 38.60,
}

# Terminal typing schedule (absolute seconds) used by renderer + audio SFX.
TERM_TYPING = [
    ("cmd", 28.45, 29.65, 'git clone https://github.com/PCYBlurF/dsh-fish-buddy.git'),
    ("cmd", 29.85, 30.55, 'cd /d "%USERPROFILE%\\.dsh\\fish-buddy"'),
    ("cmd", 30.75, 31.20, 'install.cmd'),
]
TERM_OUTPUT = [
    (31.45, "[1/3] 停止旧实例 ...", "muted"),
    (31.85, "[2/3] 写入 cordis.patch.yml ...", "muted"),
    (32.25, "[3/3] 拉起挂件 ...", "muted"),
    (32.65, "安装完成，重启一次 DSH 即可", "ok"),
]
