// Tests for the page-free parts of a diff (web/diff_words.js). Run with
// `node --test test/web/diff_words_test.mjs`, or through `dart test`
// (web_js_test.dart).

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fieldLabel, changedInside, wordChanges } from '../../web/diff_words.js';

test('catalog field names read as plain words', () => {
  assert.equal(fieldLabel('modVersion'), 'mod version');
  assert.equal(fieldLabel('gameVersionReq'), 'game version');
  assert.equal(fieldLabel('authorsList'), 'authors');
  assert.equal(fieldLabel('urls'), 'links');
  assert.equal(fieldLabel('startsWith'), 'start');
  assert.equal(fieldLabel('endsWith'), 'end');
  assert.equal(fieldLabel('optionalNeeds'), 'optional needs');
  // Names that are already words are left alone.
  assert.equal(fieldLabel('LLM facts'), 'LLM facts');
  assert.equal(fieldLabel('summary — one line'), 'summary — one line');
  assert.equal(fieldLabel('categories'), 'categories');
});

test('two maps give only the keys that changed', () => {
  const lines = changedInside(
    { startsWith: 'PatchLib is a library mod that enables bytecode patching.', endsWith: 'Only install it if a mod requires it.' },
    { startsWith: 'PatchLib is a library mod that enables', endsWith: 'Only install it if a mod requires it.' },
  );
  assert.deepEqual(lines, [{
    name: 'start',
    before: 'PatchLib is a library mod that enables bytecode patching.',
    after: 'PatchLib is a library mod that enables',
  }]);
});

test('a list of maps is compared entry by entry, named after each entry', () => {
  const lines = changedInside(
    [{ area: 'code', how: 'assisted', extent: 'some' }, { area: 'writing', how: 'assisted', extent: 'some' }],
    [{ area: 'code', how: 'assisted' }, { area: 'writing', how: 'assisted' }],
  );
  assert.deepEqual(lines, [
    { name: 'code — extent', before: 'some', after: undefined },
    { name: 'writing — extent', before: 'some', after: undefined },
  ]);
});

test('a list of one map does not repeat the entry name', () => {
  const lines = changedInside(
    [{ name: 'Mikohime 28', kind: 'technical' }],
    [{ name: 'Mikohime 28', kind: 'withNotes' }],
  );
  assert.deepEqual(lines, [{ name: 'kind', before: 'technical', after: 'withNotes' }]);
});

test('values that cannot be compared inside are shown whole', () => {
  assert.equal(changedInside('a', 'b'), null);
  assert.equal(changedInside([1, 2], [1, 3]), null);
  // Lists of different lengths: entries cannot be paired up.
  assert.equal(changedInside([{ a: 1 }], [{ a: 1 }, { a: 2 }]), null);
  assert.equal(changedInside({ a: 1 }, [{ a: 1 }]), null);
});

const text = (pieces) => pieces.map((p) => p.text).join('');
const marked = (pieces) => pieces.filter((p) => p.changed).map((p) => p.text.trim());

test('changed words are marked, the rest kept', () => {
  const result = wordChanges(
    'Enables bytecode patching at runtime for Starsector.',
    'Enables bytecode patching at runtime to modify game and mod code behavior.',
  );
  assert.deepEqual(marked(result.before), ['for Starsector.']);
  assert.deepEqual(marked(result.after), ['to modify game and mod code behavior.']);
  assert.equal(text(result.before), 'Enables bytecode patching at runtime for Starsector.');
});

test('long unchanged stretches are cut to a few words beside the change', () => {
  const start = 'one two three four five six seven eight nine ten eleven twelve ';
  const result = wordChanges(`${start}old ending here.`, `${start}new ending here.`);
  assert.equal(result.before[0].gap, true);
  assert.equal(text(result.before), '… seven eight nine ten eleven twelve old ending here.');
  assert.equal(text(result.after), '… seven eight nine ten eleven twelve new ending here.');
});

test('short, unrelated or non-text values are not marked', () => {
  assert.equal(wordChanges('0.1.7', '0.1.8'), null);
  assert.equal(wordChanges(
    'Enables bytecode patching at runtime for Starsector and more.',
    'Provides an annotation-based API for registering patches and handlers to redirect code.',
  ), null);
  assert.equal(wordChanges(['a'], ['b']), null);
});
