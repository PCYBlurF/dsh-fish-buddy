"""All seven scenes of the DSH Fish Buddy promo.

Scene functions draw onto a transparent supersampled Canvas in logical
1920x1080 coordinates. The build script handles fades, camera drift,
background and compositing.
"""

from __future__ import annotations

import math

from PIL import Image

from promolib import (
    C,
    H,
    W,
    Canvas,
    _a,
    _with_alpha,
    bubble_body,
    clamp,
    draw_bubble,
    draw_check_badge,
    draw_kicker,
    draw_logo_mark,
    draw_mascot,
    draw_pill,
    draw_sparkle,
    ease_in_out,
    ease_out_back,
    ease_out_cubic,
    fish_icon,
    glow_layer,
    ground_shadow,
    hexc,
    inv_lerp,
    lerp,
    mascot_frame,
    mix,
    panel_art,
    radial_sprite,
    seeded,
    smoothstep,
    spring,
    wallpaper_art,
)
from timeline import (
    BEAT,
    SCENE_BOUNDS,
    TERM_OUTPUT,
    TERM_TYPING,
)

CEL_T0 = SCENE_BOUNDS["celebrate"][0]


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------


def appear(lt, start, dur=0.7):
    p = ease_out_cubic(inv_lerp(start, start + dur, lt))
    return p


def fade_slide(lt, start, dur=0.7, dist=22):
    p = float(spring(lt - start, 10.5, 7.0)) if lt >= start else 0.0
    p = clamp(p)
    return p, (1 - p) * dist


def draw_bullets(cv, x, y, items, lt, alpha=1.0, gap=68, size=25, sub_size=18):
    for i, (title, sub, kind) in enumerate(items):
        a = appear(lt, 0.35 + i * 0.15)
        if a <= 0:
            continue
        yy = y + i * gap + (1 - a) * 16
        # icon
        ix, iy = x + 20, yy + 16
        cv.circle(ix, iy, 19, fill=_a((124, 147, 255, 22), a))
        cv.circle(ix, iy, 19, outline=_a((124, 147, 255, 70), a), width=1.3)
        _icon(cv, kind, ix, iy, 9, _a((169, 186, 255, 255), a))
        cv.text(
            (x + 56, yy - 2),
            title,
            size,
            _a(C["ink"], a),
            "b",
            alpha=a,
        )
        if sub:
            cv.text((x + 56, yy + size + 8), sub, sub_size, _a(C["ink3"], a), "r", alpha=a)


def _icon(cv, kind, cx, cy, r, color):
    if kind == "file":
        cv.rrect(cx - r * 0.72, cy - r * 0.9, r * 1.44, r * 1.8, r * 0.22, outline=color, width=1.5)
        cv.line([(cx - r * 0.38, cy - r * 0.2), (cx + r * 0.4, cy - r * 0.2)], color, 1.5)
        cv.line([(cx - r * 0.38, cy + r * 0.25), (cx + r * 0.4, cy + r * 0.25)], color, 1.5)
    elif kind == "list":
        for k in range(3):
            yy = cy - r * 0.6 + k * r * 0.6
            cv.circle(cx - r * 0.5, yy, r * 0.16, fill=color)
            cv.line([(cx - r * 0.15, yy), (cx + r * 0.62, yy)], color, 1.6)
    elif kind == "clock":
        cv.circle(cx, cy, r * 0.82, outline=color, width=1.6)
        cv.line([(cx, cy), (cx, cy - r * 0.5)], color, 1.6)
        cv.line([(cx, cy), (cx + r * 0.38, cy + r * 0.18)], color, 1.6)
    elif kind == "layers":
        for k, dy in enumerate((0.42, 0.0, -0.42)):
            cv.polygon(
                [
                    (cx, cy + dy * r - r * 0.34),
                    (cx + r * 0.85, cy + dy * r),
                    (cx, cy + dy * r + r * 0.34),
                    (cx - r * 0.85, cy + dy * r),
                ],
                outline=color,
                width=1.1,
            )
    elif kind == "coin":
        cv.circle(cx, cy, r * 0.85, outline=color, width=1.6)
        cv.text((cx, cy), "¥", r * 1.0, color, "enb", anchor="mm")
    elif kind == "chat":
        cv.rrect(cx - r * 0.9, cy - r * 0.72, r * 1.8, r * 1.3, r * 0.3, outline=color, width=1.5)
        cv.polygon([(cx - r * 0.3, cy + r * 0.55), (cx - r * 0.5, cy + r * 0.95), (cx + r * 0.1, cy + r * 0.55)], fill=color)


def pill_row(cv, x, cy, labels, alpha=1.0, size=20, gap=14, pad_x=22, pad_y=11,
             color=(199, 211, 242, 255), border=(255, 255, 255, 40), fill=(255, 255, 255, 7)):
    cx = x
    for label in labels:
        w = cv.text_len(label, size, "r") + pad_x * 2
        draw_pill(cv, cx + w / 2, cy, label, size, pad_x, pad_y, alpha, color, border, fill)
        cx += w + gap
    return cx - gap


def chip_row_centered(cv, cy, labels, alpha=1.0, size=20, gap=14):
    widths = [cv.text_len(lb, size, "r") + 44 for lb in labels]
    total = sum(widths) + gap * (len(labels) - 1)
    x = (W - total) / 2
    cx = x
    for i, lb in enumerate(labels):
        draw_pill(cv, cx + widths[i] / 2, cy, lb, size, 22, 11, alpha)
        cx += widths[i] + gap
    return total


def section_head(cv, x, y, kicker, title, alpha=1.0, title_size=58, kicker_color=C["blue2"]):
    if alpha <= 0:
        return
    cv.text((x, y), kicker, 21, _a(kicker_color, alpha), "b", ls=1.2, alpha=alpha)
    cv.rect(x, y + 33, 30, 2, fill=_a((124, 147, 255, 120), alpha))
    cv.text((x, y + 48), title, title_size, _a(C["ink"], alpha), "b", lh=1.36, alpha=alpha)


# --------------------------------------------------------------------------
# 01 — intro
# --------------------------------------------------------------------------


def scene_intro(cv: Canvas, t, lt):
    # Q-version mascot, cropped by the frame bottom
    m_alpha = smoothstep(inv_lerp(0.05, 0.85, lt))
    draw_mascot(cv, "idle", t, 1372, 1092, 620, m_alpha, breathe=0.012, fade_bottom=0.0)

    # soft halo behind text, left
    halo = glow_layer(500, (90, 120, 230), 34 * smoothstep(inv_lerp(0.35, 1.4, lt)), 2.4)
    cv.img.alpha_composite(halo, (int(150 * cv.ss - halo.width / 2), int(470 * cv.ss - halo.height / 2)))

    # kicker — the product category clearly says "插件"
    p = appear(lt, 0.20, 0.55)
    if p > 0:
        x, y = 150, 268
        cv.rect(x, y + 8, 3 * p, 20, fill=_a(C["blue"], p))
        en = "DEEPSEEK HARNESS"
        cv.text((x + 18, y), en, 17, _a(C["ink3"], p), "ensb", ls=2.8, alpha=p)
        w = cv.text_len(en, 17, "ensb") + 2.8 * (len(en) - 1)
        cv.text((x + 32 + w, y), "·  桌面进度插件", 17, _a(C["ink3"], p), "r", alpha=p)

    # wordmark — product name has no "大肥鱼"
    p = appear(lt, 0.32, 0.65)
    if p > 0:
        y = 320 + (1 - p) * 26
        cv.text((150, y), "DSH", 100, _a(C["ink"], p), "b", alpha=p)
        dsh_w = cv.text_len("DSH", 100, "b")
        cv.text((150 + dsh_w + 18, y), "桌面挂件", 100, _a(C["blue2"], p), "b", alpha=p)
        gl = glow_layer(360, (124, 147, 255), int(26 * p), 2.2)
        cv.img.alpha_composite(gl, (int(340 * cv.ss - gl.width / 2), int((y + 62) * cv.ss - gl.height / 2)))

    # small line — the cute nickname
    p = appear(lt, 0.85, 0.6)
    if p > 0:
        icon = fish_icon(28 * cv.ss)
        cv.img.alpha_composite(_with_alpha(icon, p), (int(150 * cv.ss), int(453 * cv.ss)))
        cv.text((188, 456), "可爱大肥鱼桌面挂件", 25, _a(C["ink3"], p), "r", alpha=p)

    # accent rule
    p = appear(lt, 1.05, 0.5)
    if p > 0:
        w = 250 * p
        cv.rrect(150, 512, w, 5, 2.5, fill=_a(C["blue"], p * 0.9))
        cv.rrect(160 + w, 512, w * 0.35, 5, 2.5, fill=_a(C["blue2"], p * 0.7))

    # feature line
    p = appear(lt, 1.15, 0.7)
    if p > 0:
        cv.text(
            (150, 536 + (1 - p) * 16),
            "实时任务进度  ·  完成提醒  ·  多会话",
            32,
            _a(C["ink2"], p),
            "r",
            alpha=p,
        )

    # feature chips
    p = appear(lt, 1.55, 0.7)
    if p > 0:
        pill_row(cv, 150, 648 + (1 - p) * 14, ["实时进度", "完成提醒", "多会话", "可调大小"], p, size=20)

    # meta
    p = appear(lt, 2.15, 0.7)
    if p > 0:
        cv.circle(158, 752, 4, fill=_a(C["green"], p))
        cv.text(
            (176, 738),
            "for DeepSeek Harness   ·   Windows 10/11   ·   MIT License",
            19,
            _a(C["muted"], p),
            "r",
            alpha=p,
        )

    # floating motes
    for i in range(9):
        r = seeded(i, 31)
        ph = r.uniform(0, math.tau)
        a = smoothstep(inv_lerp(0.9 + i * 0.06, 1.8 + i * 0.06, lt))
        if a <= 0:
            continue
        x = 1080 + r.uniform(0, 620) + 14 * math.sin(t * 0.6 + ph)
        y = 300 + r.uniform(0, 560) + 18 * math.cos(t * 0.45 + ph)
        rr = r.uniform(1.2, 3.0)
        tw = 0.5 + 0.5 * math.sin(t * 1.6 + ph)
        col = (255, 216, 107) if i % 3 == 0 else (190, 210, 255)
        cv.circle(x, y, rr, fill=_a((*col, int(150 * tw)), a))
        if i % 3 == 0:
            draw_sparkle(cv, x, y, 6 * tw, col, a * 0.8, rot=t * 0.4)


# --------------------------------------------------------------------------
# 02 — real-time progress
# --------------------------------------------------------------------------


def _progress_value(lt):
    milestones = [1.05, 2.10, 3.15, 4.20]
    vals = [0.0, 0.2, 0.4, 0.6, 0.8]
    p = 0.0
    for i, tm in enumerate(milestones):
        u = ease_in_out(inv_lerp(tm, tm + 0.5, lt))
        p = lerp(p, vals[i + 1], u)
    return p


TASKS = [
    "正在：接入实时进度气泡与完成提醒",
    "正在：调整帧动画与材质切换",
    "正在：补齐 Windows 完成通知",
    "正在：打包 1080p 60fps 预览",
]


def scene_progress(cv: Canvas, t, lt):
    # left copy
    section_head(cv, 140, 208, "01 / 实时进度", "她的气泡里，\n装着整条任务链", title_size=60)
    p = appear(lt, 0.45, 0.65)
    if p > 0:
        cv.text(
            (140, 452),
            "不用切窗口，也不用猜她干到哪一步。",
            25,
            _a(C["ink3"], p),
            "r",
            alpha=p,
        )
    bullets = [
        ("读取本机会话日志", "不联网、不调用 DSH API", "file"),
        ("任务标题 · todo 进度 · 当前工具", "一屏就能看到跑到哪儿了", "list"),
        ("已用时间 · 步骤数 · 目标轮次", "长任务也有参照", "clock"),
    ]
    draw_bullets(cv, 140, 512, bullets, lt, gap=76, size=25, sub_size=18)

    # live indicator
    p = appear(lt, 1.0, 0.6)
    if p > 0:
        pulse = 0.5 + 0.5 * math.sin(t * 3.0)
        cv.circle(150, 778, 4.5, fill=_a((61, 220, 151, int(140 + 90 * pulse)), p))
        cv.text((166, 764), "每 400ms 刷新一次，任务一动，她就动", 18, _a(C["muted"], p), "r", alpha=p)

    # ---- right: widget mock
    bw = 770.0
    scale = bw / 348.0
    bx, by = 980, 345
    a = smoothstep(inv_lerp(0.25, 0.9, lt))
    if a <= 0:
        return
    by_anim = by + (1 - ease_out_cubic(inv_lerp(0.25, 1.0, lt))) * 46

    title_full = "把这段视频剪成 3 分钟短片"
    typed = int(clamp((lt - 0.35) / 0.8) * len(title_full))
    title = title_full[:typed]

    prog = _progress_value(lt)
    count = f"{min(5, max(0, int(round(prog * 5))))}/5"
    idx = clamp(int((prog + 1e-6) / 0.2), 0, 3)
    task = TASKS[idx]
    elapsed = 83 + 49 * smoothstep(inv_lerp(0, 5.9, lt))
    step = 7 + int(5 * smoothstep(inv_lerp(0, 5.9, lt)))
    meta = f"已用 {int(elapsed)//60:02d}:{int(elapsed)%60:02d} · 第 {step} 步"

    h = draw_bubble(
        cv, bx, by_anim, bw, scale, title, count, prog, task, meta,
        "default", False, a, dot_phase=t,
    )

    # typing caret
    if 0.35 <= lt <= 1.22:
        tw = cv.text_len(title, 13.5 * scale, "b")
        if math.sin(t * 12) > -0.2:
            cv.rect(bx + 16 * scale + 14 * scale + tw + 2, by_anim + 12 * scale + 2,
                    2.0 * scale, 15 * scale, fill=_a((169, 186, 255, 210), a))

    # mascot below
    ma = smoothstep(inv_lerp(0.65, 1.35, lt))
    draw_mascot(cv, "working", t + 0.4, 1370, 1090, 520, ma, fade_bottom=0.0)

    # annotations
    notes = [
        (1072, 248, "01", "任务标题", 1.55),
        (1302, 248, "02", "todo 进度", 2.25),
        (1532, 248, "03", "当前待办", 2.95),
    ]
    for (nx, ny, num, label, nt) in notes:
        pa = smoothstep(inv_lerp(nt, nt + 0.55, lt))
        if pa <= 0:
            continue
        dotp = 0.5 + 0.5 * math.sin(t * 2.2 + float(num))
        cv.circle(nx + 11, ny + 11, 11, fill=_a((124, 147, 255, 30), pa))
        cv.circle(nx + 11, ny + 11, 11, outline=_a((169, 186, 255, int(120 + 60 * dotp)), pa), width=1.2)
        cv.text((nx + 11, ny + 12), num, 11, _a(C["blue2"], pa), "enb", anchor="mm")
        cv.text((nx + 30, ny), label, 19, _a(C["ink2"], pa), "r", alpha=pa)
        # leader line to bubble top
        top = by_anim - 6
        cv.line([(nx + 11, ny + 24), (nx + 11, top)], _a((124, 147, 255, 55), pa), 1.1)
        cv.circle(nx + 11, top, 2.6, fill=_a((169, 186, 255, 190), pa))


# --------------------------------------------------------------------------
# 03 — state animations
# --------------------------------------------------------------------------


STATE_CARDS = [
    ("think", "思考", "THINKING", (0, 0, 0), (169, 186, 255)),
    ("working", "工作", "WORKING", (0, 0, 0), (124, 147, 255)),
    ("idle", "待命", "IDLE", (0, 0, 0), (140, 240, 198)),
    ("sleep", "打瞌睡", "SLEEPY", (0, 0, 0), (143, 163, 217)),
    ("celebrate", "完成", "DONE", (0, 0, 0), (255, 216, 107)),
    ("error", "出错", "ERROR", (0, 0, 0), (255, 107, 122)),
]


def scene_states(cv: Canvas, t, lt):
    cv.text((W / 2, 88), "02  /  状态动画", 20, _a(C["blue2"], 1), "b", anchor="mm", ls=1.2)
    cv.text((W / 2, 168), "六种状态，各有表情", 56, _a(C["ink"], 1), "b", anchor="mm")

    cy = 322
    cw, ch, gap = 250, 344, 26
    x0 = (W - (cw * 6 + gap * 5)) / 2
    for i, (state, label, en, _, accent) in enumerate(STATE_CARDS):
        p = spring(lt - (0.18 + i * 0.065), 12.0, 7.5) if lt > 0.18 + i * 0.065 else 0.0
        p = clamp(p)
        if p <= 0:
            continue
        x = x0 + i * (cw + gap)
        y = cy + (1 - p) * 62 + 2.2 * math.sin(t * 0.85 + i * 1.3) * p
        alpha = smoothstep(inv_lerp(0, 0.5, p))
        # card
        art = panel_art(cw * cv.ss, ch * cv.ss, 24 * cv.ss,
                        tint=(255, 255, 255, 8), border=(255, 255, 255, 24))
        art = _with_alpha(art, alpha)
        cv.img.alpha_composite(art, (int(x * cv.ss), int(y * cv.ss)))
        # accent glow on top edge
        gl = glow_layer(150, accent, int(26 * alpha), 2.0)
        cv.img.alpha_composite(gl, (int((x + cw / 2) * cv.ss - gl.width / 2), int((y + 4) * cv.ss - gl.height / 2)))
        # accent bar
        cv.rrect(x + cw / 2 - 26, y + 1, 52, 3, 1.5, fill=_a((*accent, 210), alpha))
        # mascot
        mv = 1.0 + 0.01 * math.sin(t * 2.0 + i)
        mh = 178 * mv
        draw_mascot(
            cv, state, t + i * 0.37, x + cw / 2, y + 248, mh, alpha,
            breathe=0.006, glow=False, bob=2.2,
        )
        cv.text((x + cw / 2, y + 258), label, 26, _a(C["ink"], alpha), "b", anchor="mm")
        cv.text((x + cw / 2, y + 296), en, 12, _a((*accent, 210), alpha), "ensb", anchor="mm", ls=2.4)

    p = appear(lt, 0.95, 0.7)
    if p > 0:
        cv.text((W / 2, 742), "从托腮思考到举手庆祝，她一直都在。", 27, _a(C["ink2"], p), "r", anchor="mm")
        cv.text((W / 2, 792), "帧动画会跟着 DSH 的实时状态自动切换", 19, _a(C["muted"], p), "r", anchor="mm")


# --------------------------------------------------------------------------
# 04 — completion celebration
# --------------------------------------------------------------------------


def scene_celebrate(cv: Canvas, t, lt):
    cv.text((W / 2, 74), "03  /  完成提醒", 20, _a(C["green"], 1), "b", anchor="mm", ls=1.2)
    cv.text((W / 2, 152), "干完了，她会替你高兴", 56, _a(C["ink"], 1), "b", anchor="mm")
    p = appear(lt, 0.3, 0.6)
    if p > 0:
        cv.text((W / 2, 218), "跳起来  ·  放星光  ·  响一声  ·  桌面通知", 23, _a(C["ink3"], p), "r", anchor="mm")

    done = lt >= (BEAT["completed"] - CEL_T0)
    # completion pop
    pop = 1.0
    if done:
        age = lt - (BEAT["completed"] - CEL_T0)
        pop = 1.0 + 0.018 * math.exp(-age * 7.0) * math.cos(age * 22.0)
    bw = 730 * pop
    scale = bw / 348.0
    bx = W / 2 - bw / 2
    by = 272 + (1 - ease_out_cubic(inv_lerp(0.05, 0.5, lt))) * 30

    if not done:
        prog = 0.8 + 0.0 * lt
        title = "把这段视频剪成 3 分钟短片"
        task = "正在：打包 1080p 60fps 预览"
        meta = "已用 01:58 · 第 11 步"
        count = "4/5"
        ok = False
    else:
        age = clamp((lt - (BEAT["completed"] - CEL_T0)) / 0.55)
        prog = 0.8 + 0.2 * ease_out_cubic(age)
        title = "任务完成啦！"
        task = "把这段视频剪成 3 分钟短片"
        meta = "用时 02:12 · 双击打开 DSH"
        count = f"{min(5, max(0, int(round(prog * 5))))}/5"
        ok = True

    a = smoothstep(inv_lerp(0.0, 0.45, lt))
    draw_bubble(cv, bx, by, bw, scale, title, count, prog, task, meta,
                "default", ok, a, dot_phase=t)

    # mascot
    m_alpha = smoothstep(inv_lerp(0.0, 0.4, lt))
    draw_mascot(
        cv, "celebrate" if done else "working", t + (0.0 if done else 1.7),
        960, 1092, 580, m_alpha, breathe=0.014,
        glow_color=(255, 216, 107, 120) if done else (124, 147, 255, 120),
        fade_bottom=0.0,
    )

    # starlight burst
    if done:
        _burst(cv, t, lt - (BEAT["completed"] - CEL_T0), (960, 900))
        _burst(cv, t, lt - 3.5, (960, 930), n=22, amp=0.55)
        # check badge
        bage = lt - (BEAT["completed"] - CEL_T0) - 0.15
        if bage > 0:
            s = clamp(spring(bage, 13.0, 7.0)) * (1 + 0.018 * math.sin(t * 3.6))
            draw_check_badge(cv, 1150, 872, 38, smoothstep(inv_lerp(0, 0.3, bage)), s)
        # ambient rising sparkles
        _ambient_sparkles(cv, t, lt - (BEAT["completed"] - CEL_T0), (960, 900))

    # notification toast
    ta = smoothstep(inv_lerp(BEAT["toast_in"] - CEL_T0, BEAT["toast_in"] - CEL_T0 + 0.55, lt))
    if ta > 0:
        tpp = ease_out_back(inv_lerp(BEAT["toast_in"] - CEL_T0, BEAT["toast_in"] - CEL_T0 + 0.65, lt))
        tx = 1400 + (1 - tpp) * 90
        ty = 300 - (1 - tpp) * 26
        _toast(cv, tx, ty, 430, 118, ta)
        cv.text((tx + 20, ty + 138), "Windows 桌面通知", 15, _a(C["muted"], ta * 0.9), "r")
        # toast auto-dismiss timer
        left = clamp(1.0 - (lt - (BEAT["toast_in"] - CEL_T0)) / 4.0)
        if 0 < left < 1:
            cv.rect(tx + 1, ty + 116, (430 - 2) * left, 2, fill=_a((61, 220, 151, 130), ta))


def _toast(cv, x, y, w, h, alpha):
    pad = int(26 * cv.ss)
    from promolib import shadow_white

    sh = shadow_white(int(w * cv.ss), int(h * cv.ss), int(14 * cv.ss), int(18 * cv.ss), pad=pad)
    sh = _with_alpha(sh, 0.55 * alpha)
    cv.img.alpha_composite(sh, (int(x * cv.ss) - pad, int((y + 8) * cv.ss) - pad))
    cv.rrect(x, y, w, h, 14, fill=_a((26, 34, 56, 246), alpha), outline=_a((255, 255, 255, 34), alpha), width=1.0)
    # icon
    draw_check_badge(cv, x + 42, y + h / 2, 19, alpha)
    cv.text((x + 76, y + 22), "DSH 桌面挂件", 15, _a((159, 176, 216), alpha), "r", alpha=alpha)
    cv.text((x + 76, y + 44), "任务完成", 24, _a(C["ink"], alpha), "b", alpha=alpha)
    cv.text((x + 76, y + 80), "把这段视频剪成 3 分钟短片", 16, _a((199, 211, 242), alpha), "r", alpha=alpha)



def _burst(cv, t, age, origin, n=54, amp=1.0):
    if age < 0 or age > 3.0:
        return
    ox, oy = origin
    for i in range(n):
        r = seeded(i, 77)
        ang = r.uniform(-math.pi, math.pi)
        spd = r.uniform(120, 620) * amp
        life = r.uniform(1.1, 2.6)
        if age > life:
            continue
        u = age / life
        dist = spd * (1 - (1 - u) ** 2.4)
        x = ox + math.cos(ang) * dist
        y = oy + math.sin(ang) * dist * 0.72 + 150 * u * u
        a = (1 - u) ** 1.3
        size = r.uniform(2.2, 7.5) * (1 - 0.35 * u) * min(1.0, amp + 0.25)
        kind = r.random()
        if kind < 0.42:
            draw_sparkle(cv, x, y, size * 1.9, (255, 216, 107), a, rot=r.uniform(0, math.tau) + age * 2)
        elif kind < 0.75:
            cv.circle(x, y, size * 0.8, fill=_a((255, 236, 170, 255), a))
        else:
            cv.circle(x, y, size * 0.7, fill=_a((190, 255, 220, 255), a))


def _ambient_sparkles(cv, t, age, origin):
    if age < 0:
        return
    ox, oy = origin
    for i in range(22):
        r = seeded(i, 91)
        ph = r.uniform(0, math.tau)
        speed = r.uniform(18, 50)
        basex = ox + r.uniform(-310, 310)
        y = oy - ((age * speed + r.uniform(0, 300)) % 480)
        x = basex + 18 * math.sin(age * 0.8 + ph)
        a = smoothstep(inv_lerp(0, 0.6, age)) * (0.35 + 0.4 * (0.5 + 0.5 * math.sin(age * 2.2 + ph)))
        a *= smoothstep(clamp((oy - y) / 480.0))
        if a > 0.02:
            if i % 3 == 0:
                draw_sparkle(cv, x, y, 4.5 + i % 3, (255, 216, 107), a, rot=age * 1.2 + ph)
            else:
                cv.circle(x, y, 1.4 + (i % 3) * 0.5, fill=_a((255, 245, 210, 255), a * 0.9))


# --------------------------------------------------------------------------
# 05 — details
# --------------------------------------------------------------------------


def scene_details(cv: Canvas, t, lt):
    section_head(cv, 140, 84, "04 / 更多细节", "细节，也照顾到了", title_size=52)

    panels = [
        (120, "layers", "三档材质", "深蓝 · 白色磨砂 · 透明玻璃", 1.0),
        (690, "coin", "双击查余额", "DeepSeek / OpenRouter / Moonshot", 1.2),
        (1260, "chat", "多会话", "自动跟随，也可手动固定", 1.4),
    ]
    pw, ph = 540, 486
    py = 268
    for i, (px, icon, title, sub, delay) in enumerate(panels):
        p = clamp(spring(lt - (0.10 + i * 0.09), 11.5, 7.0)) if lt > 0.10 + i * 0.09 else 0.0
        if p <= 0:
            continue
        alpha = smoothstep(inv_lerp(0, 0.5, p))
        yy = py + (1 - p) * 46
        art = panel_art(pw * cv.ss, ph * cv.ss, 26 * cv.ss,
                        tint=(255, 255, 255, 7), border=(255, 255, 255, 22))
        cv.img.alpha_composite(_with_alpha(art, alpha), (int(px * cv.ss), int(yy * cv.ss)))
        cv.circle(px + 46, yy + 50, 17, fill=_a((124, 147, 255, 26), alpha))
        _icon(cv, icon, px + 46, yy + 50, 15, _a(C["blue2"], alpha))
        cv.text((px + 74, yy + 34), title, 26, _a(C["ink"], alpha), "b", alpha=alpha)
        cv.text((px + 36, yy + 78), sub, 16, _a(C["muted"], alpha), "r", alpha=alpha)
        cv.text((px + pw - 36, yy + 34), f"0{i+1}", 14, _a((124, 147, 255), alpha * 0.6), "enb",
                anchor="ra", ls=1.6)

    # ---- panel 1: materials
    if lt > 0.45:
        px = 120
        cycle = ((t - 0.5) / 1.8) % 1.0
        idx = int((t - 0.5) / 1.8) % 3
        blend = smoothstep(inv_lerp(0.86, 1.0, cycle))
        styles = ["default", "white", "glass"]
        wp = wallpaper_art(450 * cv.ss, 188 * cv.ss, 18 * cv.ss)
        cv.img.alpha_composite(wp, (int(156 * cv.ss), int(378 * cv.ss)))
        sx, sy, sw = px + 61, 402, 400
        sc = sw / 348.0
        cur = styles[idx]
        nxt = styles[(idx + 1) % 3]
        if blend > 0 and lt > 0.9:
            draw_bubble(cv, sx, sy, sw, sc, "实时进度", "2/5", 0.4, "从深蓝到透明的三种材质", "右键 → 材质",
                        cur, False, 1.0 - blend)
            draw_bubble(cv, sx, sy, sw, sc, "实时进度", "2/5", 0.4, "从深蓝到透明的三种材质", "右键 → 材质",
                        nxt, False, blend)
        else:
            draw_bubble(cv, sx, sy, sw, sc, "实时进度", "2/5", 0.4, "从深蓝到透明的三种材质", "右键 → 材质",
                        cur, False, 1.0)

        labels = [("深蓝色", "default"), ("白色磨砂", "white"), ("透明玻璃", "glass")]
        lx = px + 58
        for j, (lb, sty) in enumerate(labels):
            active = styles[idx] == sty
            yy = 606
            cv.circle(lx + 4, yy + 8, 4, fill=_a((169, 186, 255) if active else (110, 125, 165), 1))
            if active:
                cv.circle(lx + 4, yy + 8, 10, outline=_a((124, 147, 255, 80), 1), width=1.0)
            cv.text((lx + 16, yy), lb, 17, _a(C["ink"] if active else C["muted"], 1), "r")
            lx += 132
        cv.text((px + 36, 664), "选择会保存在 ui.json", 14, _a(C["muted"], 0.8), "r")

    # ---- panel 2: balance
    if lt > 0.6:
        px = 690
        card_x, card_y, card_w, card_h = px + 36, 378, 468, 196
        cv.rrect(card_x, card_y, card_w, card_h, 18, fill=(255, 255, 255, 9),
                 outline=(255, 255, 255, 30), width=1.0)
        cv.circle(card_x + 36, card_y + 38, 15, fill=_a((124, 147, 255, 90), 1))
        cv.text((card_x + 36, card_y + 38), "D", 15, _a(C["white"], 1), "enb", anchor="mm")
        cv.text((card_x + 60, card_y + 24), "DeepSeek", 19, _a(C["ink2"], 1), "r")
        cv.text((card_x + card_w - 28, card_y + 26), "余额", 15, _a(C["muted"], 1), "r", anchor="ra")
        cv.text((card_x + 34, card_y + 72), "¥ 42.00", 46, _a(C["ink"], 1), "b")
        cv.text((card_x + 34, card_y + 136), "双击角色查询 · 约 3 秒后回到任务进度", 15, _a(C["ink3"], 1), "r")
        # tiny refresh arc
        arc = _arc(cv, card_x + card_w - 44, card_y + 108, 16, t, (61, 220, 151))
        cv.text((px + 36, 592), "API Key 读取环境变量或 ~/.dsh/.credentials.yaml", 13,
                _a(C["muted"], 0.85), "r")
        # supported providers
        cxx = px + 36
        for lb in ["DeepSeek", "OpenRouter", "Moonshot"]:
            cw = cv.text_len(lb, 14, "r") + 34
            cv.rrect(cxx, 648, cw, 34, 17, fill=(255, 255, 255, 8),
                     outline=(255, 255, 255, 26), width=1.0)
            cv.circle(cxx + 14, 665, 3.6, fill=(61, 220, 151, 220))
            cv.text((cxx + 24, 656), lb, 14, _a(C["ink3"], 1), "r")
            cxx += cw + 10

    # ---- panel 3: sessions
    if lt > 0.75:
        px = 1260
        rows = [
            ("接入实时进度气泡", "运行中", True),
            ("调整帧动画与材质切换", "已结束", False),
            ("打包 1080p 60fps 预览", "已结束", False),
        ]
        ry = 384
        for i, (title, tag, running) in enumerate(rows):
            yy = ry + i * 76
            cv.rrect(px + 30, yy, pw - 60, 62, 12,
                     fill=(255, 255, 255, 7) if running else (255, 255, 255, 3),
                     outline=(124, 147, 255, 60) if running else (255, 255, 255, 16), width=1.0)
            if running:
                pulse = 0.5 + 0.5 * math.sin(t * 3.0)
                cv.circle(px + 54, yy + 31, 5, fill=_a((61, 220, 151, 255), 1))
                cv.circle(px + 54, yy + 31, 9 + 4 * pulse, outline=_a((61, 220, 151, int(70 - 50 * pulse)), 1), width=1.0)
            else:
                cv.circle(px + 54, yy + 31, 4.5, outline=_a((143, 163, 217, 180), 1), width=1.2)
            cv.text((px + 72, yy + 20), title, 18, _a(C["ink2"] if running else C["ink3"], 1), "r")
            cv.text((px + pw - 52, yy + 22), tag, 13, _a(C["green"] if running else C["muted"], 1),
                    "r", anchor="ra")
        cv.text((px + 36, 664), "右键 → 会话：自动 / 固定某一个", 14, _a(C["muted"], 0.85), "r")

    # bottom chips
    p = appear(lt, 1.15, 0.7)
    if p > 0:
        chip_row_centered(cv, 838 + (1 - p) * 14,
                          ["Ctrl+Alt+H 一键隐藏", "70% – 140% 大小", "透明置顶", "只读本机会话日志"],
                          p, size=19)


def _arc(cv, cx, cy, r, t, color):
    a0 = (t * 80.0) % 360.0
    a1 = a0 + 275
    cv.arc(cx, cy, r, a0, a1, _a((*color, 230), 1), 2.4)
    ang = math.radians(a1)
    tipx, tipy = cx + r * math.cos(ang), cy + r * math.sin(ang)
    tx, ty = -math.sin(ang), math.cos(ang)
    nx, ny = math.cos(ang), math.sin(ang)
    cv.polygon(
        [(tipx, tipy),
         (tipx - tx * 9 + nx * 4.5, tipy - ty * 9 + ny * 4.5),
         (tipx - tx * 9 - nx * 4.5, tipy - ty * 9 - ny * 4.5)],
        fill=_a((*color, 230), 1),
    )


# --------------------------------------------------------------------------
# 06 — installation
# --------------------------------------------------------------------------


def _term_line(cv, x, y, prompt, text, color, size=19, alpha=1.0):
    if prompt:
        cv.text((x, y), "$", size, _a((110, 210, 160), alpha), "monob", alpha=alpha)
    cx = x + (18 if prompt else 0)
    cv.mix_text((cx, y), text, size, _a(color, alpha), cjk="r", latin="mono", alpha=alpha)
    return cx + cv.mix_len(text, size)


def scene_install(cv: Canvas, t, lt):
    section_head(cv, 140, 84, "05 / 安装", "三步，住进你的桌面", title_size=52)

    # steps
    steps = [("01", "克隆仓库"), ("02", "运行 install.cmd"), ("03", "重启 DSH")]
    active = 0 if t < 29.85 else (1 if t < 33.15 else 2)
    sx = [330, 700, 1070]
    cv.line([(sx[0] + 22, 258), (sx[-1] - 10, 258)], (255, 255, 255, 26), 1.4)
    for i, ((num, label), x) in enumerate(zip(steps, sx)):
        on = i == active
        p = appear(lt, 0.12 + i * 0.1, 0.5)
        cv.circle(x, 258, 21, fill=_a((124, 147, 255, 230) if on else (255, 255, 255, 10), p))
        cv.circle(x, 258, 21, outline=_a((169, 186, 255, 200) if on else (255, 255, 255, 55), p), width=1.2)
        cv.text((x, 259), num, 13, _a(C["ink"] if on else C["ink3"], p), "enb", anchor="mm")
        cv.text((x, 288), label, 19, _a(C["ink"] if on else C["ink3"], p), "r", anchor="ma", alpha=p)
        if on:
            gl = glow_layer(130, (124, 147, 255), int(22 * p), 2.2)
            cv.img.alpha_composite(gl, (int(x * cv.ss - gl.width / 2), int(258 * cv.ss - gl.height / 2)))

    # terminal window
    tx, ty, tw, th = 140, 330, 1040, 430
    from promolib import shadow_white

    a = smoothstep(inv_lerp(0.10, 0.60, lt))
    pad = int(24 * cv.ss)
    sh = shadow_white(int(tw * cv.ss), int(th * cv.ss), int(16 * cv.ss), int(20 * cv.ss), pad=pad)
    cv.img.alpha_composite(_with_alpha(sh, 0.6 * a), (int(tx * cv.ss) - pad, int((ty + 10) * cv.ss) - pad))
    cv.rrect(tx, ty, tw, th, 16, fill=_a((7, 11, 22, 244), a), outline=_a((255, 255, 255, 26), a), width=1.0)
    # title bar
    cv.rrect(tx, ty, tw, 50, 16, fill=_a((255, 255, 255, 9), a))
    cv.rect(tx, ty + 24, tw, 26, fill=_a((255, 255, 255, 9), a))
    cv.line([(tx, ty + 50), (tx + tw, ty + 50)], _a((255, 255, 255, 22), a), 1.0)
    for i, col in enumerate([(255, 107, 122), (255, 196, 112), (61, 220, 151)]):
        cv.circle(tx + 26 + i * 19, ty + 25, 5, fill=_a((*col, 170), a))
    cv.mix_text((tx + 90, ty + 15), r"C:\Users\你\.dsh\fish-buddy", 14, _a(C["muted"], 1), cjk="r", latin="mono")
    cv.text((tx + tw - 24, ty + 15), "Windows PowerShell", 13, _a((110, 125, 160), a), "r", anchor="ra")

    # terminal content
    if a <= 0:
        return
    lx, ly = tx + 28, ty + 78
    step = 33
    line = 0
    typing_now = False
    for (kind, t0, t1, cmd) in TERM_TYPING:
        if t < t0:
            break
        reveal = int(clamp((t - t0) / max(0.2, t1 - t0)) * len(cmd))
        done = t >= t1
        shown = cmd if done else cmd[:reveal]
        _term_line(cv, lx, ly + line * step, True, shown, (232, 238, 251), alpha=1.0)
        line += 1
        if not done and t >= t0:
            typing_now = True
            cx = lx + 18 + cv.mix_len(shown, 19)
            if math.sin(t * 14) > -0.3:
                cv.rect(cx + 2, ly + (line - 1) * step + 2, 9, 23, fill=(232, 238, 251, 225))
    if t < TERM_TYPING[0][1]:
        if math.sin(t * 14) > -0.3:
            cv.rect(lx + 18, ly + 2, 9, 23, fill=(232, 238, 251, 225))

    line += 1
    for (t_out, text, kind) in TERM_OUTPUT:
        if t < t_out:
            break
        yy = ly + line * step
        col = (110, 220, 160) if kind == "ok" else (150, 165, 200)
        if kind == "ok":
            cv.line([(lx + 2, yy + 12), (lx + 7, yy + 17), (lx + 16, yy + 5)], (110, 220, 160), 2.0)
            cv.mix_text((lx + 26, yy), text, 19, col, cjk="r", latin="mono", alpha=1.0)
        else:
            cv.mix_text((lx + 14, yy), text, 19, col, cjk="r", latin="mono", alpha=1.0)
        line += 1

    # caret waiting for output
    if TERM_TYPING[-1][2] <= t < TERM_OUTPUT[0][0]:
        cx = lx + 18 + cv.mix_len(TERM_TYPING[-1][3], 19)
        if math.sin(t * 14) > -0.3:
            cv.rect(cx + 2, ly + 2 * step + 2, 9, 23, fill=(232, 238, 251, 225))

    # terminal status bar
    cv.line([(tx + 1, ty + th - 38), (tx + tw - 1, ty + th - 38)], (255, 255, 255, 16), 1.0)
    cv.circle(tx + 30, ty + th - 19, 3.5, fill=(61, 220, 151, 210))
    cv.text((tx + 42, ty + th - 30), "fish-buddy", 13, (128, 144, 184, 255), "mono")
    cv.text((tx + tw - 24, ty + th - 30), "PowerShell 5.1  ·  main", 12, (110, 125, 160, 255), "r", anchor="ra")

    # success state border glow
    if t >= 32.9:
        age = t - 32.9
        gl = glow_layer(600, (61, 220, 151), int(26 * math.exp(-age * 1.6)), 2.4)
        cv.img.alpha_composite(gl, (int((tx + tw * 0.5) * cv.ss - gl.width / 2), int((ty + th * 0.6) * cv.ss - gl.height / 2)))

    cv.text((tx, ty + th + 26), "环境要求：Windows 10/11 + 已安装 DSH Desktop", 17, _a(C["muted"], a), "r")

    # right: mascot + chips
    ma = smoothstep(inv_lerp(0.45, 1.05, lt))
    draw_mascot(cv, "idle", t + 2.0, 1512, 1092, 500, ma, fade_bottom=0.0)

    # tiny speech bubble after success
    if t >= BEAT["install_done"]:
        sp = clamp(spring(t - BEAT["install_done"], 12.0, 7.0))
        sx2, sy2, sw2 = 1408, 520, 208
        cv.rrect(sx2, sy2, sw2, 76, 18, fill=_a((22, 33, 61, 246), sp * a),
                 outline=_a((255, 255, 255, 46), sp * a), width=1.0)
        cv.text((sx2 + 24, sy2 + 18), "重启后见！", 22, _a(C["ink"], sp * a), "b", alpha=sp * a)
        cv.text((sx2 + 24, sy2 + 48), "我会在这里等你", 14, _a(C["ink3"], sp * a), "r", alpha=sp * a)
        cv.polygon([(sx2 + 84, sy2 + 76), (sx2 + 116, sy2 + 76), (sx2 + 132, sy2 + 96)],
                   fill=_a((22, 33, 61, 246), sp * a))


# --------------------------------------------------------------------------
# 07 — outro
# --------------------------------------------------------------------------


def scene_outro(cv: Canvas, t, lt):
    p = appear(lt, 0.10, 0.6)
    chip_row_centered(cv, 210, ["实时进度", "完成提醒", "多会话", "可调大小", "MIT 开源"], p, size=19)

    ma = smoothstep(inv_lerp(0.10, 0.70, lt))
    gl = glow_layer(300, (255, 216, 107), int(30 * ma), 2.1)
    cv.img.alpha_composite(gl, (int(960 * cv.ss - gl.width / 2), int(668 * cv.ss - gl.height / 2)))
    ground_shadow(cv, 960, 660, 330, alpha=0.62 * ma)
    draw_mascot(cv, "celebrate", t + 1.2, 960, 650, 390, ma, breathe=0.012,
                glow_color=(255, 216, 107, 110), fade_bottom=0.10)

    for i in range(12):
        r = seeded(i, 41)
        ph = r.uniform(0, math.tau)
        a = ma * (0.5 + 0.5 * math.sin(t * 1.6 + ph))
        x = 960 + r.uniform(-330, 330)
        y = 380 + r.uniform(-120, 180)
        if i % 2 == 0:
            draw_sparkle(cv, x, y, 4 + r.uniform(0, 4), (255, 216, 107), a * 0.8, rot=t * 0.5 + ph)
        else:
            cv.circle(x, y, 1.6, fill=_a((220, 232, 255, 255), a * 0.7))

    p = appear(lt, 0.30, 0.6)
    if p > 0:
        cv.text((W / 2, 706), "DSH 桌面挂件", 74, _a(C["ink"], p), "b", anchor="mm")
        cv.text((W / 2, 786), "可爱大肥鱼桌面挂件", 23, _a(C["blue2"], p), "r", anchor="mm")
        cv.text((W / 2, 840), "让 AI 的每一次奔跑，都有人在旁边陪着。", 28, _a(C["ink2"], p), "r", anchor="mm")

    p = appear(lt, 0.60, 0.6)
    if p > 0:
        label = "github.com/PCYBlurF/dsh-fish-buddy"
        draw_pill(cv, W / 2, 904, label, 21, 38, 13, p,
                  color=(199, 211, 242, 255), border=(124, 147, 255, 100), fill=(124, 147, 255, 24), kind="mono")

    p = appear(lt, 0.80, 0.6)
    if p > 0:
        cv.text((W / 2, 982), "DSH 桌面进度插件  ·  MIT License  ·  Windows 10/11  ·  macOS 实验性  ·  非官方同人项目",
                16, _a(C["muted"], p), "r", anchor="mm")


SCENE_FNS = {
    "intro": scene_intro,
    "progress": scene_progress,
    "states": scene_states,
    "celebrate": scene_celebrate,
    "details": scene_details,
    "install": scene_install,
    "outro": scene_outro,
}

LIGHT_KEYS = [
    (0.0, (100, 128, 235), (1340, 560), 1.0),
    (4.0, (110, 138, 245), (1350, 590), 1.0),
    (10.6, (128, 140, 250), (960, 540), 1.0),
    (16.0, (90, 200, 170), (960, 640), 1.15),
    (22.0, (118, 140, 245), (960, 560), 0.95),
    (28.0, (110, 145, 245), (1520, 620), 1.0),
    (34.8, (170, 170, 240), (960, 500), 1.2),
    (40.0, (190, 170, 225), (960, 500), 1.1),
]
