'use strict';

const path = require('path');

const BASE_HEIGHT = 430;
const PET_BASE = 270;

function heightForScale(scale) {
  const value = Number(scale);
  const normalized = Number.isFinite(value) ? value : 1;
  return Math.round(BASE_HEIGHT + (normalized - 1) * PET_BASE);
}

function phaseForSession(session) {
  if (!session) return 'idle';
  if (session.running) return 'working';
  if (session.errorMessage) return 'error';
  const reason = session.lastTurn && session.lastTurn.reason;
  if (reason === 'error') return 'error';
  if (reason === 'aborted') return 'aborted';
  if (reason === 'completed') return 'done';
  return 'idle';
}

function sanitizeHitRects(rects, max = 6) {
  if (!Array.isArray(rects)) return [];
  return rects
    .filter((rect) => Array.isArray(rect) && rect.length === 4 && rect.every((value) => Number.isFinite(Number(value))))
    .slice(0, max)
    .map((rect) => rect.map(Number));
}

function mergeUiConfig(raw, config) {
  const source = raw && typeof raw === 'object' ? raw : {};
  const cfg = config && typeof config === 'object' ? config : {};
  const hasNumber = (value) => value !== null && value !== undefined && Number.isFinite(Number(value));
  const hasScale = hasNumber(source.scale);
  const scale = hasScale ? Number(source.scale) : (hasNumber(cfg.scale) ? Number(cfg.scale) : 0.9);
  return {
    left: hasNumber(source.left) ? Number(source.left) : null,
    top: hasNumber(source.top) ? Number(source.top) : null,
    material: ['default', 'white', 'glass'].includes(source.material) ? source.material : 'white',
    scale: Math.max(0.7, Math.min(1.3, scale)),
    notify: typeof source.notify === 'boolean' ? source.notify : cfg.notify !== false,
    sound: typeof source.sound === 'boolean' ? source.sound : cfg.sound !== false,
    topmost: typeof source.topmost === 'boolean' ? source.topmost : true,
    pinned: typeof source.pinned === 'string' ? source.pinned : '',
  };
}

function nodeCandidates(home, env = {}, execPath = '') {
  const list = [];
  if (env && env.DSH_NODE) list.push(env.DSH_NODE);
  if (home) {
    list.push(path.join(home, 'dsh-runtimes', 'dsh-primary-runtime', 'dependencies', 'node', 'bin', 'node'));
  }
  list.push('/opt/homebrew/bin/node', '/usr/local/bin/node');
  if (execPath) list.push(execPath);
  return list;
}

module.exports = { heightForScale, phaseForSession, sanitizeHitRects, mergeUiConfig, nodeCandidates };
