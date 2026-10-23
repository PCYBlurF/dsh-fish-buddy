/** 共享配置 schema：fish-core 与 doctor 共用，避免范围/键名漂移。 */
export const CONFIG_DEFAULTS = Object.freeze({
  pollMs: 600,
  maxSessionAgeHours: 12,
  tailBytes: 8 * 1024 * 1024,
  dshUrl: '',
  completionWindowMinutes: 10,
  activeWindowMinutes: 20,
  logMaxBytes: 512 * 1024,
});

export const CONFIG_RANGES = Object.freeze({
  pollMs: [200, 600000, true],
  maxSessionAgeHours: [1, 168, false],
  tailBytes: [64 * 1024, 64 * 1024 * 1024, true],
  completionWindowMinutes: [1, 1440, false],
  activeWindowMinutes: [1, 20160, false],
  logMaxBytes: [64 * 1024, 64 * 1024 * 1024, true],
});

export const UI_CONFIG_KEYS = Object.freeze(['mascot', 'scale', 'includeSubagents', 'notify', 'sound', 'tray', 'compact']);

export const CONFIG_KEYS = Object.freeze([...Object.keys(CONFIG_DEFAULTS), ...UI_CONFIG_KEYS]);

export function validateConfigValue(key, raw) {
  const range = CONFIG_RANGES[key];
  if (!range) return { ok: false, value: CONFIG_DEFAULTS[key] };
  const [min, max, integer] = range;
  const n = Number(raw);
  if (!Number.isFinite(n) || n < min || n > max) return { ok: false, value: CONFIG_DEFAULTS[key] };
  return { ok: true, value: integer ? Math.round(n) : n };
}
