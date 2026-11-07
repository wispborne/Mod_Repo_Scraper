// Tests for the viewer's routing helpers (web/routes.js). Run with
// `node --test test/web/routes_test.mjs`, or through `dart test`
// (web_js_test.dart).

import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  NAV, hashParts, navEntryFor, movedAddress, searchRoute, tabTitle, percent,
  hashQuery, buildHash,
} from '../../web/routes.js';

test('the nav rail has the three groups in order', () => {
  assert.deepEqual(NAV.map((g) => g.group), ['Operate', 'Correct', 'Investigate']);
  assert.deepEqual(NAV[0].items.map((i) => i.label), ['Control', 'Run history', 'Settings']);
  assert.deepEqual(NAV[1].items.map((i) => i.label), ['Takedowns', 'Author aliases', 'Dependency matching']);
  assert.deepEqual(NAV[2].items.map((i) => i.label),
    ['Mods', 'Source posts', 'Post guide checks', 'What changed', 'Catalog explorer', 'LLM test report', 'Files']);
  const ids = NAV.flatMap((g) => g.items.map((i) => i.id));
  assert.equal(new Set(ids).size, ids.length, 'every page id is different');
});

test('hash parts leave the query out', () => {
  assert.deepEqual(hashParts('#/runs/abc?x=1'), ['runs', 'abc']);
  assert.deepEqual(hashParts('#/'), []);
  assert.deepEqual(hashParts(''), []);
  assert.deepEqual(hashParts('#/posts/a%20b'), ['posts', 'a b']);
});

test('a broken % escape is kept as written instead of throwing', () => {
  assert.deepEqual(hashParts('#/mods/50%off'), ['mods', '50%off']);
  assert.deepEqual(hashParts('#/mods/%E0%A4%A'), ['mods', '%E0%A4%A']);
  assert.equal(movedAddress('#/mods/50%off'), null);
  assert.equal(navEntryFor(hashParts('#/mods/50%off')).id, 'mods');
});

test('a page and its detail pages light the same nav entry', () => {
  assert.equal(navEntryFor([]).id, 'control');
  assert.equal(navEntryFor(['runs']).id, 'runs');
  assert.equal(navEntryFor(['runs', '20261105T230000Z-fetchAndUpdate']).id, 'runs');
  assert.equal(navEntryFor(['nope']), null);
});

test('addresses from the old viewer open their new pages', () => {
  assert.equal(movedAddress('#/home'), '#/control');
  assert.equal(movedAddress('#/topics'), '#/posts');
  assert.equal(movedAddress('#/topics?q=lazy&filters=noDownload'), '#/posts?q=lazy');
  assert.equal(movedAddress('#/topics/18011'), '#/posts/topic/18011');
  assert.equal(movedAddress('#/bundle/18011'), '#/posts/topic/18011');
  assert.equal(movedAddress('#/topics/18011/history'), '#/posts/topic/18011/history');
  assert.equal(movedAddress('#/bundle/18011/history'), '#/posts/topic/18011/history');
  assert.equal(movedAddress('#/bundle/changes?a=x&b=working'), '#/changes?tab=facts&a=x&b=working');
  assert.equal(movedAddress('#/merge/changes?a=x&b=y'), '#/changes?tab=mods&a=x&b=y');
  assert.equal(movedAddress('#/discord/1355071745366822950'), '#/posts/discord/1355071745366822950');
  assert.equal(movedAddress('#/modrepo?q=nex'), '#/mods?q=nex');
  assert.equal(movedAddress('#/modrepo/12'), '#/mods');
  assert.equal(movedAddress('#/merge'), '#/explorer');
  assert.equal(movedAddress('#/merge/groups/7?run=r1'), '#/explorer/groups/7?run=r1');
  assert.equal(movedAddress('#/merge/removals/sameSource'), '#/explorer/removals?kind=sameSource');
  assert.equal(movedAddress('#/log'), '#/files');
  assert.equal(movedAddress('#/requirement-names'), '#/dependency-matching');
  assert.equal(movedAddress('#/requirement-names/anything?x=1'), '#/dependency-matching');
  assert.equal(movedAddress('#/dependency-names?match=unmatched&q=nex'), '#/dependency-matching?match=unmatched&q=nex');
});

test('addresses this viewer uses are left alone', () => {
  for (const hash of ['', '#/', '#/control', '#/runs/abc', '#/takedowns', '#/author-aliases',
    '#/dependency-matching', '#/llm-test', '#/files', '#/posts/topic/1', '#/mods/nexerelin', '#/changes?tab=mods']) {
    assert.equal(movedAddress(hash), null, hash);
  }
});

test('an address or id opens its page here, and other text names no page', () => {
  assert.equal(searchRoute(''), null);
  assert.equal(searchRoute('   '), null);
  assert.equal(searchRoute('https://fractalsoftworks.com/forum/index.php?topic=18011.0'), '#/posts/topic/18011');
  assert.equal(searchRoute('fractalsoftworks.com/forum/index.php?topic=34161.msg1#msg1'), '#/posts/topic/34161');
  assert.equal(searchRoute('18011'), '#/posts/topic/18011');
  assert.equal(searchRoute(' 18011 '), '#/posts/topic/18011');
  assert.equal(searchRoute('1355071745366822950'), '#/posts/discord/1355071745366822950');
  assert.equal(
    searchRoute('https://discord.com/channels/187635036525166592/1355071745366822950'),
    '#/posts/discord/1355071745366822950',
  );
  assert.equal(
    searchRoute('https://discordapp.com/channels/187635036525166592/1355071745366822950/1355071745366822950'),
    '#/posts/discord/1355071745366822950',
  );
  assert.equal(searchRoute('20261105T230000Z-fetchAndUpdate'), '#/runs/20261105T230000Z-fetchAndUpdate');
  assert.equal(searchRoute(' 20261105T230000Z-rebuildFromSaved '), '#/runs/20261105T230000Z-rebuildFromSaved');
  // Other text is a search.
  assert.equal(searchRoute('nexerelin'), null);
  assert.equal(searchRoute('Lazy Lib & co'), null);
  assert.equal(searchRoute('20261105T230000Z'), null);
  assert.equal(searchRoute('18011 lazy'), null);
});

test('the tab title follows the run', () => {
  const current = { record: { request: { kind: 'fetchAndUpdate' } }, itemsDone: 40, itemsTotal: 100 };
  assert.equal(tabTitle({ pageName: 'Control', current, ended: null }), '▶ Fetch and update 40% · Mod Repo Viewer');
  assert.equal(
    tabTitle({ pageName: 'Control', current: { ...current, itemsTotal: 0 }, ended: null }),
    '▶ Fetch and update · Mod Repo Viewer',
  );
  assert.equal(tabTitle({ pageName: 'Control', current: null, ended: 'completed' }), '✓ Done · Control · Mod Repo Viewer');
  assert.equal(tabTitle({ pageName: 'Control', current: null, ended: 'failed' }), '✗ Failed · Control · Mod Repo Viewer');
  assert.equal(tabTitle({ pageName: 'Control', current: null, ended: 'interrupted' }), '✗ Interrupted · Control · Mod Repo Viewer');
  assert.equal(tabTitle({ pageName: 'Files', current: null, ended: 'cancelled' }), 'Files · Mod Repo Viewer');
});

test('percent is whole and never over 100', () => {
  assert.equal(percent(412, 1031), 39);
  assert.equal(percent(5, 0), null);
  assert.equal(percent(12, 10), 100);
});

test('the address query is read and written', () => {
  assert.equal(hashQuery('#/runs?page=2').get('page'), '2');
  assert.equal(hashQuery('#/runs').get('page'), null);
  assert.equal(buildHash(['runs'], { page: 2 }), '#/runs?page=2');
  assert.equal(buildHash(['runs'], { page: null, q: '' }), '#/runs');
  assert.equal(buildHash(['posts', 'a b'], { q: 'lazy lib' }), '#/posts/a%20b?q=lazy+lib');
  assert.deepEqual(hashParts(buildHash(['runs', 'x/y'])), ['runs', 'x/y']);
});
