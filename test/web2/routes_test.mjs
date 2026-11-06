// Tests for the new viewer's routing helpers (web2/routes.js). Run with
// `node --test test/web2/routes_test.mjs`, or through `dart test`
// (web2_js_test.dart).

import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  NAV, hashParts, navEntryFor, oldViewerBase, oldViewerAddress, searchRoute, tabTitle, percent,
  hashQuery, buildHash,
} from '../../web2/routes.js';

test('the nav rail has the three groups in order', () => {
  assert.deepEqual(NAV.map((g) => g.group), ['Operate', 'Correct', 'Investigate']);
  assert.deepEqual(NAV[0].items.map((i) => i.label), ['Control', 'Run history', 'Settings']);
  assert.deepEqual(NAV[1].items.map((i) => i.label), ['Takedowns', 'Author aliases', 'Dependency names']);
  assert.deepEqual(NAV[2].items.map((i) => i.label),
    ['Mods', 'Source posts', 'What changed', 'Catalog explorer', 'LLM test report', 'Files']);
  const ids = NAV.flatMap((g) => g.items.map((i) => i.id));
  assert.equal(new Set(ids).size, ids.length, 'every page id is different');
});

test('hash parts leave the query out', () => {
  assert.deepEqual(hashParts('#/runs/abc?x=1'), ['runs', 'abc']);
  assert.deepEqual(hashParts('#/'), []);
  assert.deepEqual(hashParts(''), []);
  assert.deepEqual(hashParts('#/posts/a%20b'), ['posts', 'a b']);
});

test('a page and its detail pages light the same nav entry', () => {
  assert.equal(navEntryFor([]).id, 'control');
  assert.equal(navEntryFor(['runs']).id, 'runs');
  assert.equal(navEntryFor(['runs', '20261105T230000Z-fetchAndUpdate']).id, 'runs');
  assert.equal(navEntryFor(['nope']), null);
});

test('the old viewer is found from the new one\'s own address', () => {
  assert.equal(oldViewerBase('/'), '/v1/');
  assert.equal(oldViewerBase('/index.html'), '/v1/');
  assert.equal(oldViewerBase('/v2/'), '/');
  assert.equal(oldViewerBase('/v2'), '/');
  assert.equal(oldViewerBase('/v2x/'), '/v1/');
  assert.equal(oldViewerAddress('/v2/', 'takedowns'), '/#/takedowns');
  assert.equal(oldViewerAddress('/', 'merge/changes'), '/v1/#/merge/changes');
});

test('search opens the right page in the old viewer', () => {
  assert.equal(searchRoute(''), null);
  assert.equal(searchRoute('   '), null);
  assert.equal(searchRoute('https://fractalsoftworks.com/forum/index.php?topic=18011.0'), 'topics/18011');
  assert.equal(searchRoute('fractalsoftworks.com/forum/index.php?topic=34161.msg1#msg1'), 'topics/34161');
  assert.equal(searchRoute('18011'), 'topics/18011');
  assert.equal(searchRoute(' 18011 '), 'topics/18011');
  assert.equal(searchRoute('1355071745366822950'), 'discord/1355071745366822950');
  assert.equal(
    searchRoute('https://discord.com/channels/187635036525166592/1355071745366822950'),
    'discord/1355071745366822950',
  );
  assert.equal(searchRoute('nexerelin'), 'topics?q=nexerelin');
  assert.equal(searchRoute('Lazy Lib & co'), 'topics?q=Lazy%20Lib%20%26%20co');
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
