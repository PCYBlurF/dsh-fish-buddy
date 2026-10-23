const test = require('node:test');
const assert = require('node:assert/strict');

process.env.DSH_FISH_TEST = '1';

test('core model resets retry on tool call', async () => {
  const core = await import('../bin/fish-core.mjs');
  const model = core.modelFromEvents([
    { type: 'session', time: 1, id: 's1', cwd: 'G:/x' },
    { type: 'turn/start', time: 2, data: { turn: 1 } },
    { type: 'llm/retry', time: 3, data: {} },
    { type: 'tool/call', time: 4, data: { name: 'read' } },
  ]);
  assert.equal(model.retrying, 0);
  assert.equal(model.lastTool.name, 'read');
});

test('core job activity labels', async () => {
  const core = await import('../bin/fish-core.mjs');
  const model = core.modelFromEvents([
    { type: 'session', time: 1, id: 's2', cwd: 'G:/x' },
    { type: 'turn/start', time: 2, data: { turn: 1 } },
    { type: 'job/queued', time: 3, data: {} },
  ]);
  assert.equal(core.activityLabel(model).kind, 'job');
  assert.match(core.activityLabel(model).text, /排队/);
});
