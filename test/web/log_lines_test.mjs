import test from 'node:test';
import assert from 'node:assert/strict';
import { logLevel, errorLines } from '../../web/log_lines.js';

const info = '2026-10-29 18:04:41 [main] I/i->log/ Merging mods';
const warn = '2026-10-29 18:04:41 [main] W/w->parse/ Kept 17 names';
const error = '2026-10-29 18:04:41 [main] E/e->_getMessages/ Error getting messages';

test('logLevel reads the level mark', () => {
  assert.equal(logLevel(error), 'error');
  assert.equal(logLevel(warn), 'warn');
  assert.equal(logLevel(info), '');
});

test('the word error elsewhere in a line is not an error', () => {
  assert.equal(logLevel("  'Mining Strength Tooltips' by 'ERROR_CODE 509' from [ModSource.ModdingSubforum]"), '');
  assert.equal(logLevel('2026-10-29 18:04:41 [main] I/i->_rootRunUnary/ 3: Error while mixing'), '');
});

test('errorLines keeps each error with its later lines and nothing else', () => {
  const later = 'Discord request failed with HTTP 500';
  assert.deepEqual(
    errorLines([info, '  a later line of the info entry', error, later, later, warn, '  a later line of the warning', error]),
    [error, later, later, error],
  );
});

test('errorLines of a log with no errors is empty', () => {
  assert.deepEqual(errorLines([info, warn, 'plain']), []);
});
