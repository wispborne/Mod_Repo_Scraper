// Tests for the router's history entry numbers (web/history_steps.js). Run
// with `node --test test/web/history_steps_test.mjs`, or through `dart test`
// (web_js_test.dart).

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { stepOf, withStep, arrivedStep } from '../../web/history_steps.js';

test('an entry without a number has none', () => {
  assert.equal(stepOf(null), null);
  assert.equal(stepOf(undefined), null);
  assert.equal(stepOf({}), null);
  assert.equal(stepOf('text'), null);
  assert.equal(stepOf({ viewerStep: 'one' }), null);
});

test('a number written in is read back, and other values are kept', () => {
  assert.equal(stepOf(withStep(null, 3)), 3);
  assert.deepEqual(withStep({ page: 2 }, 3), { page: 2, viewerStep: 3 });
  assert.equal(stepOf(withStep({ viewerStep: 1 }, 0)), 0);
  // A state that is not an object is left alone.
  assert.equal(withStep('text', 3), 'text');
});

test('the first page shown is entry 0', () => {
  assert.deepEqual(arrivedStep(null, null), { step: 0, isNew: true });
});

test('a followed link comes straight after the shown page', () => {
  // Control (0) → Settings (1), then Control in the rail: a new entry.
  assert.deepEqual(arrivedStep(null, 1), { step: 2, isNew: true });
});

test('Back and Forward arrive at numbered entries', () => {
  // [W 0, Settings 1, X 2]: back from X to Settings, then back to W.
  assert.deepEqual(arrivedStep({ viewerStep: 1 }, 2), { step: 1, isNew: false });
  assert.deepEqual(arrivedStep({ viewerStep: 0 }, 1), { step: 0, isNew: false });
  // Forward from Settings to X.
  assert.deepEqual(arrivedStep({ viewerStep: 2 }, 1), { step: 2, isNew: false });
});
