const test = require('node:test');
const assert = require('node:assert/strict');
const lib = require('../mac/lib.cjs');
const { isAllowedDshUrl } = require('../bin/url-allowlist.cjs');

test('phaseForSession handles running/error/aborted/completed', () => {
  assert.equal(lib.phaseForSession(null), 'idle');
  assert.equal(lib.phaseForSession({ running: true }), 'working');
  assert.equal(lib.phaseForSession({ running: false, errorMessage: 'x' }), 'error');
  assert.equal(lib.phaseForSession({ running: false, lastTurn: { reason: 'error' } }), 'error');
  assert.equal(lib.phaseForSession({ running: false, lastTurn: { reason: 'aborted' } }), 'aborted');
  assert.equal(lib.phaseForSession({ running: false, lastTurn: { reason: 'completed' } }), 'done');
  assert.equal(lib.phaseForSession({ running: false }), 'idle');
});

test('heightForScale adapts the window height', () => {
  assert.equal(lib.heightForScale(1), 430);
  assert.equal(lib.heightForScale(0.8), 376);
  assert.equal(lib.heightForScale(1.2), 484);
  assert.equal(lib.heightForScale('bad'), 430);
});

test('sanitizeHitRects filters invalid values', () => {
  const rects = lib.sanitizeHitRects([
    [10, 20, 30, 40],
    [1, 2],
    ['a', 2, 3, 4],
    ['5', '6', '7', '8'],
    [1, 2, 3, 4, 5],
  ]);
  assert.deepEqual(rects, [[10, 20, 30, 40], [5, 6, 7, 8]]);
  assert.deepEqual(lib.sanitizeHitRects('bad'), []);
});

test('nodeCandidates prefers DSH_NODE and the DSH runtime', () => {
  const list = lib.nodeCandidates('/home/test/.dsh', { DSH_NODE: '/custom/node' }, '/usr/bin/electron');
  assert.equal(list[0], '/custom/node');
  assert.ok(list.some((item) => item.includes('dsh-runtimes')));
  assert.ok(list.includes('/opt/homebrew/bin/node'));
  assert.equal(list[list.length - 1], '/usr/bin/electron');
});

test('mergeUiConfig merges config defaults and ui overrides', () => {
  const defaults = lib.mergeUiConfig(null, { scale: 1.1, notify: false, sound: false });
  assert.equal(defaults.material, 'white');
  assert.equal(defaults.scale, 1.1);
  assert.equal(defaults.notify, false);
  assert.equal(defaults.sound, false);
  assert.equal(defaults.topmost, true);

  const merged = lib.mergeUiConfig({ left: 10, top: 20, material: 'glass', scale: 'bad', notify: true, pinned: 's1' }, { scale: 1.2, notify: false });
  assert.equal(merged.left, 10);
  assert.equal(merged.top, 20);
  assert.equal(merged.material, 'glass');
  assert.equal(merged.scale, 1.2);
  assert.equal(merged.notify, true);
  assert.equal(merged.pinned, 's1');
});

test('isAllowedDshUrl only allows loopback http(s) without credentials', () => {
  assert.equal(isAllowedDshUrl('http://127.0.0.1:11821'), true);
  assert.equal(isAllowedDshUrl('http://localhost:2375'), true);
  assert.equal(isAllowedDshUrl('http://[::1]:2375'), true);
  assert.equal(isAllowedDshUrl('https://example.com'), false);
  assert.equal(isAllowedDshUrl('file:///etc/passwd'), false);
  assert.equal(isAllowedDshUrl('javascript:alert(1)'), false);
  assert.equal(isAllowedDshUrl('data:text/html,x'), false);
  assert.equal(isAllowedDshUrl('http://user:pass@127.0.0.1:2375'), false);
  assert.equal(isAllowedDshUrl('http://127.0.0.1.evil.com:2375'), false);
});

test('isAllowedDshUrl only allows loopback http/https', () => {
  assert.equal(isAllowedDshUrl('http://127.0.0.1:11821'), true);
  assert.equal(isAllowedDshUrl('http://[::1]:11821'), true);
  assert.equal(isAllowedDshUrl('http://localhost:11821'), true);
  assert.equal(isAllowedDshUrl('https://example.com'), false);
  assert.equal(isAllowedDshUrl('file:///etc/passwd'), false);
  assert.equal(isAllowedDshUrl('javascript:alert(1)'), false);
  assert.equal(isAllowedDshUrl('data:text/html,x'), false);
  assert.equal(isAllowedDshUrl('http://user:pass@127.0.0.1:11821'), false);
});
