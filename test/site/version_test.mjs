// The site's copy of TriOS's version comparison, held to TriOS's own cases.
//
// `site/version.js` copies `Version.compareVersions` from TriOS so the site
// and the launcher order versions the same way. The first three groups below
// are copied from TriOS's `test/version_sorting_test.dart`; if TriOS's tests
// change, change these with them. The last group is the site's own: Starsector
// numbers its releases like decimals, which TriOS's rules alone get wrong.

import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { describe, test } from 'node:test';

const source = await readFile(new URL('../../site/version.js', import.meta.url), 'utf8');
const { compareVersions, compareGameVersions, gameVersionFamily } = await import(
  `data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);

/// TriOS's list, oldest first.
const EXPECTED = [
  "0.0.1", "0.0.3", "0.0.4a", "0.0.4b", "0.0.4e", "0.0.4f", "0.1", "0.1.0",
  "0.1.1", "0.1.4", "0.1.5", "0.1.98.1a", "0.1b", "0.2.0", "0.2.9k", "0.3.1",
  "0.3.5", "0.3.5h", "0.3.5i", "0.3.7b", "0.3a", "0.4.0", "0.4.1", "0.4.1c",
  "0.4.2", "0.4.2a", "0.4.2c", "0.4.3", "0.5.0-RC1", "0.5.0", "0.5.0a", "0.5.0d",
  "0.5.0f", "0.5.0g", "0.5.1", "0.5.1a", "0.5.3rc1", "0.5.3rc1-wisp", "0.6.0d",
  "0.6.1c", "0.6.2d", "0.6.4.1", "0.6.5", "0.6.5d", "0.6.7", "0.6.8", "0.6.10",
  "0.7.2", "0.7.4a", "0.7.4d", "0.7.5a", "0.7.5b", "0.7.5c", "0.7.5c-rewritten-001",
  "0.9.6-rc1-Wisp-005", "0.10.1", "0.11.1", "0.11.1x", "0.11.2", "0.11.2b",
  "0.11.2c", "0.13.0", "0.13.2", "0.13.2a", "0.14.1b", "0.14.2", "0.16.1",
  "0.17rc1", "0.96a", "0.99-RC5", "0.99F", "versions are for suckers", "1.0.0Beta6",
  "1.0.0rc2", "1.0", "1.00", "1.0.0", "1.0.0b", "1.0.1", "1.0.3", "1.0.4",
  "1.0.5", "1.0.7", "1.01", "1.1.0", "1.1.b", "1.1.1", "1.1.1h", "1.1.2", "1.1.3",
  "1.2.0", "1.2.1", "1.2.2", "1.2.3", "1.2.4", "1.2.5", "1.2.6", "1.2.7", "1.2.10",
  "1.2.12", "1.2b", "1.2e", "1.3", "1.3.0", "1.3.2", "1.3.3", "1.3c", "1.4",
  "1.4.3", "1.4.5", "1.4.6", "1.4b", "1.5", "1.5.3", "1.5.5", "1.5.6", "1.5.7",
  "1.6.0", "1.6.1", "1.6.1-0.96a", "1.6.1c", "1.6.2", "1.6.3", "1.6.3a", "1.6.5",
  "1.6b", "1.6c", "1.7.0", "1.7.1", "1.7.2", "1.7.3", "1.7.4", "1.7.5", "1.8.0",
  "1.8.1", "1.8.2", "1.8.3", "1.8.4", "1.8.5", "1.09", "1.9", "1.9.0", "1.9.gg",
  "1.9.ggg", "1.9.gggg", "1.9.ggggggg", "1.9.2", "1.9.3", "1.9.5", "1.10.2",
  "1.11", "1.12.0", "1.12.SSS", "1.12.1", "1.12.4", "1.13.0", "1.13.SSS", "1.13.2",
  "1.14.0", "1.14.1", "1.15.1", "1.17.1", "1.18.3ad", "1.18.3ae", "1.18.3aj",
  "1.41rc2", "002", "2.0.0", "2.0.c", "2.0.e", "2.0.3", "2.0.4", "2.0.8-Part1",
  "2.0.9", "2.1.0", "2.1.8", "2.2", "2.2.0", "2.2.1", "2.3.0", "2.3.1", "2.3.2",
  "2.4.0", "2.4.2", "2.4.6", "2.5 Gramada", "2.5.2", "2.6.2c", "2.6.2e", "2.6.4",
  "2.7.0rc3", "2.8", "2.8b", "2.64", "3.0", "3.0.5", "3.0.6.1", "3.0.9", "3.1.3",
  "3.2.c UNOFFICIAL", "3.2.1", "3.3.c-wisp001", "3.3.5", "3.3.6", "3.3.7",
  "4.0.0", "4.0.2", "4.1.0", "4.3.2", "4.4.0", "4.4.1", "5.1.0", "5.1.1", "5.2.0",
  "5.3.3", "5.4.0", "5.4.1", "6.2.1", "6.2.3", "8.4.5", "2021.4.10", "2023.5.05",
];

describe("TriOS's cases", () => {
  test('problem comparisons', () => {
    const pairs = [
      ['1.9.0', '1.9.g'],
      ['1.9.g', '1.9.1'],
      ['0.5.1', '0.5.3rc1'],
      ['1.0', '1.00'],
      ['1.6.1-0.96a', '1.6.1c'],
      ['2.5 Gramada', '2.5.2'],
      ['1.1.0', '1.1.b'],
      ['1.12.SSS', '1.12.1'],
      ['0.14.5b', '0.15'],
      ['2023.05.05', '2024.10.04'],
      ['2024.10.04', '2025.03.30'],
      ['0.1.9-RC1', '0.1.9'],
    ];
    for (const [older, newer] of pairs) {
      assert.equal(compareVersions(older, newer), -1, `${older} should be older than ${newer}`);
      assert.equal(compareVersions(newer, older), 1, `${newer} should be newer than ${older}`);
    }
  });

  test('sorts the whole list back into order from any shuffle', () => {
    let seed = 1;
    const random = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
    for (let round = 0; round < 50; round++) {
      const shuffled = [...EXPECTED];
      for (let i = shuffled.length - 1; i > 0; i--) {
        const j = Math.floor(random() * (i + 1));
        [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
      }
      assert.deepEqual(shuffled.sort(compareVersions), EXPECTED);
    }
  });

  test('deeply nested versions', () => {
    const ascending = [
      '1.4.2.2.3.1.2', '1.4.2.2.4', '1.4.2.2.4.1', '1.4.2.2.4.2', '1.4.2.2.4.2.1',
      '1.4.2.2.4.3', '1.4.2.2.4.3.1', '1.4.2.2.4.3.2', '1.4.2.2.4.3.2 (2)',
      '1.4.2.2.4.3.3', '1.4.2.2.4.3.3.4', '1.4.2.2.4.3.3.5', '1.4.2.2.4.3.3.6',
    ];
    for (let i = 0; i < ascending.length - 1; i++) {
      assert.equal(compareVersions(ascending[i], ascending[i + 1]), -1,
        `${ascending[i]} should sort before ${ascending[i + 1]}`);
    }
  });
});

describe('Starsector game versions', () => {
  test('come out in release order', () => {
    const released = [
      '0.54.1a', '0.6.1a', '0.6.2a', '0.65.1a', '0.65.2a', '0.7.1a', '0.7.2a',
      '0.8a', '0.8.1a', '0.81a', '0.9a', '0.9.1a', '0.95a', '0.95.1a', '0.96a',
      '0.97a', '0.98a-RC8', '0.98a',
    ];
    assert.deepEqual([...released].reverse().sort(compareGameVersions), released);
  });

  test('a missing "0." is put back', () => {
    assert.equal(gameVersionFamily('.98a'), '0.98');
    assert.equal(gameVersionFamily('97a-RC11'), '0.97');
    assert.equal(compareGameVersions('97a-RC11', '0.98a'), -1);
    assert.equal(compareGameVersions('.98a', '0.97a'), 1);
  });

  test('spellings of one release share a family', () => {
    for (const spelling of ['0.98a', '0.98', '0.98a-RC8', 'v0.98a']) {
      assert.equal(gameVersionFamily(spelling), '0.98');
    }
    assert.equal(gameVersionFamily('0.95.1a'), '0.95.1');
  });
});
