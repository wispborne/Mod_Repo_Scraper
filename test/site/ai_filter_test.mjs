import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  AI_AREAS, aiFilterFromAddress, aiFilterIsOn, aiFilterOff, aiFilterToAddress, keepsForAi,
  withPreset,
} from '../../site/ai_filter.js';

const mods = [
  {
    id: 'ai-portraits', usesAi: true,
    aiUses: [{ area: 'portraits', how: 'generated' }],
  },
  {
    id: 'optional-portraits', usesAi: true,
    aiUses: [{ area: 'portraits', how: 'edited', optional: true }],
  },
  { id: 'assisted-code', usesAi: true, aiUses: [{ area: 'code', how: 'assisted' }] },
  { id: 'unsaid-how', usesAi: true, aiUses: [{ area: 'music' }] },
  { id: 'all-code', usesAi: true, aiUses: [{ area: 'code', how: 'generated', extent: 'all' }] },
  { id: 'edited-all-code', usesAi: true, aiUses: [{ area: 'code', how: 'edited', extent: 'all' }] },
  { id: 'no-ai', usesAi: false },
  { id: 'silent' },
];

const kept = (filter) => mods.filter((mod) => keepsForAi(mod, filter)).map((mod) => mod.id);
// Check all parts unless the test sets its own selection.
const withSettings = (settings) => ({
  ...aiFilterOff(), preset: 'custom', parts: new Set(AI_AREAS), ...settings,
});
const preset = (key) => withPreset(aiFilterOff(), key);
const hideAll = withSettings({ mode: 'hide' });
const hideArt = withSettings({
  mode: 'hide', parts: new Set(['portraits', 'illustrations', 'sprites', 'icons']),
});

test('the starting filter keeps every mod', () => {
  assert.deepEqual(kept(aiFilterOff()), mods.map((mod) => mod.id));
  assert.equal(aiFilterIsOn(aiFilterOff()), false);
});

test('only mode with no parts checked shows no mods', () => {
  const filter = { ...aiFilterOff(), mode: 'only' };
  assert.equal(aiFilterIsOn(filter), true);
  assert.deepEqual(kept(filter), []);
});

test('hiding all parts keeps mods with no AI or unknown AI use', () => {
  assert.deepEqual(kept(hideAll), ['no-ai', 'silent']);
});

test('hiding AI art keeps mods with AI code or music', () => {
  assert.deepEqual(kept(hideArt),
    ['assisted-code', 'unsaid-how', 'all-code', 'edited-all-code', 'no-ai', 'silent']);
});

test('only shows mods with AI use in the checked parts', () => {
  assert.deepEqual(kept(withSettings({ mode: 'only', parts: new Set(['code']) })),
    ['assisted-code', 'all-code', 'edited-all-code']);
  assert.deepEqual(kept(withSettings({ mode: 'only' })),
    ['ai-portraits', 'optional-portraits', 'assisted-code', 'unsaid-how', 'all-code',
      'edited-all-code']);
});

test('"No filter" keeps every mod', () => {
  assert.deepEqual(kept(preset('off')), mods.map((mod) => mod.id));
  assert.equal(aiFilterIsOn(preset('off')), false);
});

test('"Absolutely no AI" keeps only mods whose author says no AI was used', () => {
  assert.deepEqual(kept(preset('none')), ['no-ai']);
  assert.equal(aiFilterIsOn(preset('none')), true);
});

test('"No AI" keeps mods that say no AI was used or say nothing', () => {
  assert.deepEqual(kept(preset('noai')), ['no-ai', 'silent']);
});

test('"No AI images" hides AI art and nothing else', () => {
  assert.deepEqual(kept(preset('noimages')),
    ['assisted-code', 'unsaid-how', 'all-code', 'edited-all-code', 'no-ai', 'silent']);
});

test('"No vibecode" hides only mods whose code AI wrote all of', () => {
  assert.deepEqual(kept(preset('novibecode')),
    mods.map((mod) => mod.id).filter((id) => id !== 'all-code'));
});

test('Custom starts from the preset before it', () => {
  const custom = withPreset(preset('noimages'), 'custom');
  assert.equal(custom.preset, 'custom');
  assert.deepEqual(kept(custom), kept(preset('noimages')));
  // "Absolutely no AI" has no Custom mode, so Custom starts from hiding.
  assert.equal(withPreset(preset('none'), 'custom').mode, 'hide');
  // Custom has no control for "all of that part", so it is dropped.
  assert.equal(withPreset(preset('novibecode'), 'custom').wholeOnly, false);
});

test('the level decides whether edited and assisted work counts', () => {
  const hide = (level) => kept(withSettings({ mode: 'hide', level }));
  assert.deepEqual(hide('made'),
    ['optional-portraits', 'assisted-code', 'edited-all-code', 'no-ai', 'silent']);
  assert.deepEqual(hide('edited'), ['assisted-code', 'no-ai', 'silent']);
  assert.ok(!hide('made').includes('unsaid-how'),
    'AI use without a stated how counts at every level');
});

test('optional parts can be ignored', () => {
  assert.ok(kept(withSettings({ mode: 'hide', skipOptional: true }))
    .includes('optional-portraits'));
  assert.ok(!kept(withSettings({ mode: 'only', skipOptional: true }))
    .includes('optional-portraits'));
});

test('AI use with no named part counts as other', () => {
  const mod = { id: 'vague', usesAi: true };
  assert.equal(keepsForAi(mod, withSettings({ mode: 'hide', parts: new Set(['other']) })), false);
  assert.equal(keepsForAi(mod, withSettings({ mode: 'hide', parts: new Set(['code']) })), true);
});

test('the address restores the same filter settings', () => {
  const filters = [
    aiFilterOff(),
    hideAll, hideArt,
    withSettings({ mode: 'only', parts: new Set(['music', 'code']), level: 'made' }),
    withSettings({ mode: 'hide', parts: new Set(), skipOptional: true, level: 'edited' }),
    withSettings({ parts: new Set() }),
    preset('none'), preset('noai'), preset('noimages'), preset('novibecode'),
  ];
  for (const filter of filters) {
    const query = new URLSearchParams(
      Object.entries(aiFilterToAddress(filter)).filter(([, value]) => value));
    const back = aiFilterFromAddress(query);
    assert.deepEqual({ ...back, parts: [...back.parts].sort() },
      { ...filter, parts: [...filter.parts].sort() }, query.toString());
  }
});

test('the default filter adds nothing to the address', () => {
  assert.ok(Object.values(aiFilterToAddress(aiFilterOff())).every((value) => value === ''));
});

test('a preset is one key in the address', () => {
  assert.deepEqual(aiFilterToAddress(preset('noimages')),
    { ai: 'noimages', aiparts: '', ailevel: '', aioptional: '' });
});

test('links from before the presets open in Custom', () => {
  const filter = aiFilterFromAddress(new URLSearchParams('ai=only&aiparts=code'));
  assert.equal(filter.preset, 'custom');
  assert.equal(filter.mode, 'only');
  assert.equal(aiFilterFromAddress(new URLSearchParams('aiparts=music')).preset, 'custom');
});

test('the address lists checked parts in a fixed order', () => {
  const filter = withSettings({ parts: new Set(['code', 'music', 'portraits']) });
  assert.equal(aiFilterToAddress(filter).aiparts, 'portraits,music,code');
});

test('old hideai links still hide the parts they named', () => {
  const filter = aiFilterFromAddress(new URLSearchParams('hideai=portraits,music'));
  assert.equal(filter.mode, 'hide');
  assert.equal(filter.preset, 'custom');
  assert.deepEqual([...filter.parts].sort(), ['music', 'portraits']);
});

test('unknown address values are ignored', () => {
  const filter = aiFilterFromAddress(
    new URLSearchParams('ai=hide&aiparts=portraits,lasers&ailevel=loud'));
  assert.deepEqual([...filter.parts], ['portraits']);
  assert.equal(filter.level, 'any');
  const unknownMode = aiFilterFromAddress(new URLSearchParams('ai=sometimes'));
  assert.equal(unknownMode.mode, 'hide');
  assert.equal(aiFilterIsOn(unknownMode), false);
});
