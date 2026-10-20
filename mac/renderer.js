/* DSH 大肥鱼 · macOS renderer */
(() => {
  const ASSETS = '../assets/whale/';
  const FRAMES = {
    idle: ['idle_0', 'idle_1', 'idle_2'],
    working: ['working_0', 'working_1', 'working_2'],
    celebrate: ['celebrate_0', 'celebrate_1', 'celebrate_2'],
    error: ['error_0', 'error_1'],
    sleep: ['sleep_0', 'sleep_1'],
    think: ['think_0'],
  };
  const INTERVALS = { idle: 560, working: 170, celebrate: 150, error: 260, sleep: 900, think: 900 };
  const DOT = { idle: '#5C6B95', working: '#7C93FF', done: '#3DDC97', error: '#FF6B6B', balance: '#7C93FF' };

  const api = window.buddy || {
    bootstrap: async () => ({ material: 'white', scale: 0.9 }),
    onState: () => {},
    onCommand: () => {},
    balance: async () => ({ title: 'DeepSeek 余额', text: '¥261.55', meta: 'deepseek-flash · 可用 · 双击刷新', ok: true }),
    menu: () => {},
    dragStart: () => {},
    dragMove: () => {},
    dragEnd: () => {},
    saveUi: () => {},
  };

  const $ = (id) => document.getElementById(id);
  const stage = $('stage');
  const bubble = $('bubble');
  const dot = $('dot');
  const title = $('title');
  const count = $('count');
  const bar = $('bar');
  const fill = $('fill');
  const task = $('task');
  const meta = $('meta');
  const pet = $('pet');
  const sprite = $('sprite');

  const images = {};
  for (const [name, list] of Object.entries(FRAMES)) {
    for (const frame of list) {
      const image = new Image();
      image.src = ASSETS + frame + '.png';
      images[frame] = image;
    }
  }
  let spriteName = '';
  let spriteTimer = null;
  function setSprite(name) {
    if (!FRAMES[name]) name = 'idle';
    if (spriteName === name) return;
    spriteName = name;
    clearInterval(spriteTimer);
    const list = FRAMES[name];
    let index = 0;
    sprite.src = ASSETS + list[0] + '.png';
    if (list.length > 1) {
      spriteTimer = setInterval(() => {
        index = (index + 1) % list.length;
        sprite.src = ASSETS + list[index] + '.png';
      }, INTERVALS[name] || 500);
    }
  }

  function formatDuration(ms) {
    let seconds = Math.floor((Number(ms) || 0) / 1000);
    if (!Number.isFinite(seconds) || seconds < 0) seconds = 0;
    const minutes = Math.floor(seconds / 60);
    return minutes + ':' + String(seconds % 60).padStart(2, '0');
  }

  function setBubbleVisible(visible) {
    bubble.classList.toggle('hidden', !visible);
  }

  function setDot(color) {
    dot.style.background = color;
  }

  function setBar(ratio, done) {
    if (ratio === null) {
      bar.classList.remove('show');
      return;
    }
    bar.classList.add('show');
    const percent = Math.max(0, Math.min(1, ratio));
    fill.style.width = (percent * 100).toFixed(1) + '%';
    fill.style.background = done ? '#3DDC97' : '#6F8CFF';
  }

  let balanceShowing = false;
  let balanceBusy = false;
  let balanceUntil = 0;
  let lastState = null;
  let idleSince = null;
  let manualHidden = false;

  function renderState(state) {
    if (!state) {
      if (!balanceShowing) {
        title.textContent = 'DSH 大肥鱼';
        task.textContent = '等待 DSH 状态…';
        meta.textContent = '双击看模型余额';
        count.textContent = '';
        setDot(DOT.idle);
        setBar(null);
        setSprite('idle');
      }
      return;
    }
    lastState = state;
    if (balanceShowing) return;
    if (manualHidden) { setBubbleVisible(false); return; }

    const session = state.session;
    const phase = state.phase || 'idle';
    const now = Number(state.now) || Date.now();

    if (!session || phase === 'idle') {
      if (!idleSince) idleSince = Date.now();
      const idleFor = (Date.now() - idleSince) / 1000;
      title.textContent = 'DSH 大肥鱼';
      task.textContent = '待命中，有任务就交给我吧～';
      meta.textContent = '双击看模型余额';
      count.textContent = '';
      setDot(DOT.idle);
      setBar(null);
      setSprite(idleFor > 25 ? 'sleep' : 'idle');
      setBubbleVisible(idleFor <= 12);
      return;
    }

    idleSince = null;
    const sessionTitle = session.title || '新的任务';

    if (session.errorMessage || (session.lastTurn && session.lastTurn.reason === 'error')) {
      title.textContent = '出错了';
      task.textContent = session.errorMessage || '任务中断';
      meta.textContent = '双击看模型余额';
      count.textContent = '';
      setDot(DOT.error);
      setBar(null);
      setSprite('error');
      setBubbleVisible(true);
      return;
    }

    if (phase === 'done') {
      const endedAt = session.lastTurn && session.lastTurn.endedAt ? session.lastTurn.endedAt : now;
      const duration = session.lastTurn ? session.lastTurn.durationMs : 0;
      title.textContent = '任务完成啦！';
      task.textContent = sessionTitle;
      meta.textContent = '用时 ' + formatDuration(duration) + ' · 双击看余额';
      count.textContent = '';
      setDot(DOT.done);
      const progress = session.progress;
      if (progress && Number(progress.total) > 0) {
        setBar(1, true);
        count.textContent = progress.total + '/' + progress.total;
      } else {
        setBar(null);
      }
      setSprite('celebrate');
      setBubbleVisible(now - endedAt <= 12000);
      return;
    }

    // working
    const activity = session.activity || {};
    const activityText = String(activity.text || '');
    const detail = String(activity.detail || '');
    let current = '';
    if (activityText && detail && detail !== activityText) current = activityText + ' · ' + detail;
    else if (activityText) current = activityText;
    else current = '思考中…';

    title.textContent = sessionTitle;
    task.textContent = '正在：' + current;
    const startedAt = Number(session.turnStartedAt) || now;
    const elapsed = Math.max(0, now - startedAt);
    const step = Number(session.step) || 0;
    meta.textContent = '已用 ' + formatDuration(elapsed) + (step > 0 ? ' · 第 ' + step + ' 步' : '');

    const progress = session.progress;
    if (progress && Number(progress.total) > 0) {
      setBar(Number(progress.completed || 0) / Number(progress.total), false);
      count.textContent = Number(progress.completed || 0) + '/' + progress.total;
    } else {
      setBar(null);
      count.textContent = '';
    }
    setDot(DOT.working);
    setSprite('working');
    setBubbleVisible(true);
  }

  function showBubble() {
    setBubbleVisible(true);
  }

  function toggleBubble() {
    if (bubble.classList.contains('hidden')) {
      manualHidden = false;
      showBubble();
      if (lastState) renderState(lastState);
    } else {
      manualHidden = true;
      setBubbleVisible(false);
    }
  }

  async function showBalance() {
    if (balanceBusy) return;
    balanceBusy = true;
    balanceShowing = true;
    manualHidden = false;
    balanceUntil = 0;
    showBubble();
    title.textContent = '模型余额';
    task.textContent = '查询中…';
    meta.textContent = '正在连接 provider';
    count.textContent = '';
    setDot(DOT.balance);
    setBar(null);
    try {
      const result = await api.balance();
      title.textContent = result.title || '模型余额';
      task.textContent = result.text || '暂无余额信息';
      meta.textContent = result.meta || '双击刷新';
      setDot(result.ok ? DOT.done : DOT.error);
    } catch (error) {
      title.textContent = '模型余额';
      task.textContent = '查询失败';
      meta.textContent = String(error && error.message ? error.message : error).slice(0, 60);
      setDot(DOT.error);
    }
    balanceBusy = false;
    balanceUntil = Date.now() + 3000;
    setTimeout(() => {
      if (Date.now() < balanceUntil) return;
      balanceShowing = false;
      if (lastState) renderState(lastState);
      else setBubbleVisible(false);
    }, 3100);
  }

  function applyMaterial(material) {
    const value = ['default', 'white', 'glass'].includes(material) ? material : 'white';
    document.body.classList.remove('mat-default', 'mat-white', 'mat-glass');
    document.body.classList.add('mat-' + value);
    api.saveUi({ material: value });
  }

  function applyScale(scale) {
    const value = Math.max(0.7, Math.min(1.3, Number(scale) || 0.9));
    document.documentElement.style.setProperty('--scale', String(value));
    api.saveUi({ scale: value });
  }

  // ── 拖拽与点击 ────────────────────────────────────────────────────────
  let down = null;
  let moved = false;
  let clickTimer = null;

  stage.addEventListener('mousedown', (event) => {
    if (event.button !== 0) return;
    down = { sx: event.screenX, sy: event.screenY };
    moved = false;
    api.dragStart(event.screenX, event.screenY);
  });

  window.addEventListener('mousemove', (event) => {
    if (!down) return;
    const dx = event.screenX - down.sx;
    const dy = event.screenY - down.sy;
    if (Math.abs(dx) + Math.abs(dy) > 4) moved = true;
    if (moved) api.dragMove(event.screenX, event.screenY);
  });

  window.addEventListener('mouseup', () => {
    if (!down) return;
    down = null;
    api.dragEnd();
    if (moved) {
      moved = false;
      return;
    }
    if (clickTimer) {
      clearTimeout(clickTimer);
      clickTimer = null;
      showBalance();
    } else {
      clickTimer = setTimeout(() => {
        clickTimer = null;
        toggleBubble();
      }, 240);
    }
  });

  window.addEventListener('contextmenu', (event) => {
    event.preventDefault();
    api.menu();
  });

  api.onCommand((command, value) => {
    if (command === 'pet') {
      pet.classList.remove('hop');
      void pet.offsetWidth;
      pet.classList.add('hop');
      setTimeout(() => pet.classList.remove('hop'), 560);
    } else if (command === 'material') {
      applyMaterial(value);
    } else if (command === 'scale') {
      applyScale(value);
    }
  });

  api.onState((state) => renderState(state));

  api.bootstrap().then((info) => {
    if (info && info.material) {
      document.body.classList.remove('mat-default', 'mat-white', 'mat-glass');
      document.body.classList.add('mat-' + info.material);
    }
    if (info && Number.isFinite(Number(info.scale))) {
      document.documentElement.style.setProperty('--scale', String(info.scale));
    }
  }).catch(() => {});

  setSprite('idle');

  // 浏览器里直接打开时给一个演示状态，方便检查样式
  if (!window.buddy) {
    const demo = {
      phase: 'working',
      now: Date.now(),
      dshUrl: 'http://127.0.0.1:13513',
      session: {
        title: 'DSH任务进度桌面小插件',
        running: true,
        turnStartedAt: Date.now() - 83000,
        step: 3,
        activity: { text: '执行 bash', detail: 'macOS 预览' },
        progress: null,
        lastTurn: { durationMs: 24907, endedAt: Date.now() - 6000, reason: 'completed' },
      },
    };
    setTimeout(() => renderState(demo), 150);
    setTimeout(() => {
      renderState({
        ...demo,
        phase: 'done',
        now: Date.now(),
        session: { ...demo.session, running: false, lastTurn: { durationMs: 83000, endedAt: Date.now(), reason: 'completed' } },
      });
    }, 5000);
  }
})();
