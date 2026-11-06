// Tests for the Mods list and mod page helpers (web/mod_words.js) and the
// shared mod picker's search (web/mod_picker.js). Run with
// `node --test test/web/mod_helpers_test.mjs`, or through `dart test`
// (web_js_test.dart).

import { test } from 'node:test';
import assert from 'node:assert/strict';

const words = await import('../../web/mod_words.js');
const { looseKey, findMods } = await import('../../web/mod_picker.js');

test('a catalog forum post opens its topic page; a Nexus page has none', () => {
  assert.equal(words.postHref({ kind: 'forum', id: '9175' }), '#/posts/topic/9175');
  assert.equal(words.postHref({ kind: 'discord', id: '1355540819095978154' }), '#/posts/discord/1355540819095978154');
  assert.equal(words.postHref({ kind: 'nexus', id: '28' }), null);
  assert.equal(words.postHref({ kind: 'forum', id: '' }), null);
});

test('job keys cover forum topics and Discord threads once each, and leave Nexus out', () => {
  const keys = words.postJobKeys([
    { kind: 'forum', id: '9175' },
    { kind: 'discord', id: '1355540819095978154' },
    { kind: 'nexus', id: '28' },
    { kind: 'forum', id: '9175' },
  ]);
  assert.deepEqual(keys, ['topic:9175', 'discord:1355540819095978154']);
});

test('found-by words', () => {
  assert.equal(words.foundByWords('rules'), 'Found by the rules');
  assert.equal(words.foundByWords('llm'), 'Found by the LLM');
  assert.equal(words.foundByWords('rulesAndLlm'), 'Found by the rules, joined by the LLM');
  assert.equal(words.foundByWords(undefined), '');
});

test('a fact\'s source names the post and the LLM answer, the rules, or several posts', () => {
  assert.deepEqual(words.factSource({ kind: 'discord', id: '1', llmName: 'Nexerelin' }), {
    text: 'Discord thread 1', href: '#/posts/discord/1', llmName: 'Nexerelin',
  });
  assert.equal(words.factSource({ kind: 'forum', id: '9175', title: 'Nexerelin v0.12' }).text, 'Nexerelin v0.12');
  assert.equal(words.factSource('rules').text, 'The rules');
  assert.equal(words.factSource({ kind: 'merged' }).text, 'Several posts, combined');
  assert.equal(words.factSource(null), null);
});

test('field names read as words, known ones as the site says them', () => {
  assert.equal(words.fieldName('needs'), 'Requires');
  assert.equal(words.fieldName('modVersion'), 'Mod version');
  assert.equal(words.fieldName('someNewField'), 'Some new field');
});

test('a short value joins lists, names objects and cuts long text', () => {
  assert.equal(words.shortValue(['a', 'b']), 'a, b');
  assert.equal(words.shortValue([{ name: 'LazyLib', id: 'lazylib' }]), 'LazyLib');
  assert.equal(words.shortValue(true), 'yes');
  assert.equal(words.shortValue(null), '—');
  assert.equal(words.shortValue('x'.repeat(200), 10), `${'x'.repeat(9)}…`);
});

test('credited names are listed once, ignoring capitals', () => {
  assert.deepEqual(words.distinctNames(['Histidine', 'histidine', ' Zaphide ', '']), ['Histidine', 'Zaphide']);
});

test('pending labels use the correction pages\' words', () => {
  assert.equal(words.sameAuthorLabel('A', 'B'), '"A" and "B" are the same person');
  assert.equal(words.matchLabel('Lazy Lib', 'LazyLib'), '"Lazy Lib" means "LazyLib"');
});

test('Starmodder addresses', () => {
  assert.equal(words.starmodderPage('nexerelin'), 'https://starmodder.wispborne.com/mods/nexerelin/');
  assert.equal(words.starmodderFile('nexerelin'), 'https://starmodder.wispborne.com/mods/nexerelin.json');
});

test('the picker finds the same name first, then names starting with it', () => {
  const mods = [
    { id: 'lazylib-extras', name: 'LazyLib Extras' },
    { id: 'lazylib', name: 'LazyLib' },
    { id: 'graphicslib', name: 'GraphicsLib' },
  ];
  assert.equal(looseKey('Lazy-Lib!'), 'lazylib');
  assert.deepEqual(findMods(mods, 'Lazy Lib').map((m) => m.id), ['lazylib', 'lazylib-extras']);
  // A spelling with a version on the end still finds the mod.
  assert.deepEqual(findMods(mods, 'GraphicsLib 1.9').map((m) => m.id), ['graphicslib']);
  assert.deepEqual(findMods(mods, ''), []);
});

test('only http(s) addresses with a host count as web addresses', () => {
  for (const url of [
    'https://fractalsoftworks.com/forum/index.php?topic=1',
    'http://example.com/a.zip',
    'HTTPS://EXAMPLE.COM/',
  ]) assert.equal(words.isWebAddress(url), true, url);
  for (const url of [
    'javascript:alert(1)',
    ' JavaScript:alert(1)',
    'java\tscript:alert(1)',
    '\u0001javascript:alert(1)',
    'data:text/html,<script>alert(1)</script>',
    'vbscript:msgbox(1)',
    'file:///C:/Windows',
    'mailto:someone@example.com',
    '/relative/path',
    '#/mods/alpha',
    'http://',
    '',
    '   ',
    null,
    undefined,
    42,
  ]) assert.equal(words.isWebAddress(url), false, String(url));
});
