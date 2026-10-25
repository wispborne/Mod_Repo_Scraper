import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  ANY_GAME, describeFilters, filterQuery, filtersAreOff, keepFilters, matchingSaved,
  noFilters, readFilters, readSavedFilters, restoreSaved, sameFilters, savedFiltersJson,
  withSaved, withoutSaved,
} from '../../site/filter_set.js';

const CURRENT = '0.98';

test('key order makes no difference', () => {
  assert.ok(sameFilters('only=download&category=Ship%20Packs',
    'category=Ship%20Packs&only=download', CURRENT));
  assert.equal(keepFilters('only=download&category=Ship%20Packs', CURRENT),
    'category=Ship+Packs&only=download');
});

test('the current release matches a set with no game', () => {
  assert.ok(sameFilters('game=0.98', '', CURRENT));
  // A full spelling is read as its release.
  assert.ok(sameFilters('game=0.98a', '', CURRENT));
  assert.ok(!sameFilters('game=0.97', '', CURRENT));
  assert.ok(!sameFilters('game=any', '', CURRENT));
});

test('a set saved on the current release follows the next release', () => {
  const saved = filterQuery(readFilters('game=0.98a&only=download', CURRENT), CURRENT);
  assert.equal(saved, 'only=download');
  assert.equal(readFilters(saved, '0.99').game, '0.99');
});

test('a set saved on an older release keeps it', () => {
  const saved = keepFilters('game=0.97a', CURRENT);
  assert.equal(readFilters(saved, '0.99').game, '0.97');
});

test('nothing remembered means the current release and nothing else', () => {
  assert.equal(keepFilters('', CURRENT), '');
  const filters = readFilters('', CURRENT);
  assert.equal(filters.game, CURRENT);
  assert.ok(!filtersAreOff(filters));
});

test('the search, sort, shuffle and page are dropped', () => {
  assert.equal(
    keepFilters('q=nex&sort=random&seed=12&page=3&author=Histidine&not=nowip', CURRENT),
    'not=nowip');
});

test('old links are read in today\'s form', () => {
  assert.equal(keepFilters('older=1', CURRENT), 'game=any');
  assert.equal(keepFilters('category=Everything%20else', CURRENT),
    'category=Miscellaneous');
  assert.equal(keepFilters('hideai=portraits', CURRENT), 'ai=custom&aiparts=portraits');
});

test('an AI filter that hides nothing matches none', () => {
  assert.ok(sameFilters('ai=custom', '', CURRENT));
  assert.ok(!sameFilters('ai=noai', '', CURRENT));
});

test('every filter off', () => {
  assert.ok(filtersAreOff(noFilters()));
  assert.equal(filterQuery(noFilters(), CURRENT), `game=${ANY_GAME}`);
  assert.ok(filtersAreOff(readFilters('game=any', CURRENT)));
  assert.ok(!filtersAreOff(readFilters('game=any&ai=noai', CURRENT)));
});

test('a set in a few words', () => {
  const label = (family) => (family === '0.98' ? '0.98a' : family);
  assert.equal(describeFilters(readFilters('only=download', CURRENT), label),
    '0.98a · Has a download');
  assert.equal(describeFilters(readFilters('game=any&not=addable&ai=noai', CURRENT), label),
    'Not safe to add mid-game · AI use: No AI');
  assert.equal(describeFilters(noFilters(), label), '');
});

test('an unreadable saved list is empty', () => {
  assert.deepEqual(readSavedFilters('{not json'), []);
  assert.deepEqual(readSavedFilters('{"name":"x"}'), []);
  assert.deepEqual(readSavedFilters(null), []);
  assert.deepEqual(
    readSavedFilters('[{"name":"  A  ","filters":"only=download"},{"name":""},7]'),
    [{ name: 'A', filters: 'only=download' }]);
});

test('saving under a name already taken replaces that entry where it stands', () => {
  let list = withSaved([], 'One', 'only=download');
  list = withSaved(list, 'Two', 'not=nowip');
  list = withSaved(list, 'one ', 'game=any');
  assert.deepEqual(list, [
    { name: 'one', filters: 'game=any' },
    { name: 'Two', filters: 'not=nowip' },
  ]);
  assert.deepEqual(readSavedFilters(savedFiltersJson(list)), list);
});

test('a deleted entry is restored to where it was', () => {
  const list = [
    { name: 'A', filters: '' }, { name: 'B', filters: 'game=any' },
    { name: 'C', filters: 'only=source' },
  ];
  const { list: left, removed } = withoutSaved(list, 'B');
  assert.deepEqual(left.map((e) => e.name), ['A', 'C']);
  assert.deepEqual(restoreSaved(left, removed), list);
  // One saved under the same name since is kept.
  const again = withSaved(left, 'B', 'only=download');
  assert.deepEqual(restoreSaved(again, removed), again);
});

test('the matching saved filter is found by comparing filters', () => {
  const list = [{ name: 'Mine', filters: 'only=download' }];
  assert.equal(matchingSaved(list, 'game=0.98&only=download', CURRENT)?.name, 'Mine');
  assert.equal(matchingSaved(list, 'game=any&only=download', CURRENT), null);
});
