// Tests for what the Post guide page remembers in the browser
// (web/post_guide_marks.js). Run with
// `node --test test/web/post_guide_marks_test.mjs`, or through `dart test`
// (web_js_test.dart).

import { test, beforeEach } from 'node:test';
import assert from 'node:assert/strict';

// A stand-in for the browser's localStorage.
const stored = new Map();
globalThis.localStorage = {
  getItem: (k) => (stored.has(k) ? stored.get(k) : null),
  setItem: (k, v) => stored.set(k, String(v)),
  removeItem: (k) => stored.delete(k),
};

const {
  READ_KEY, MARKS_KEY, FOLLOW_UP_DAYS, threadState, lastRead, readChange, markAllRead,
  allMarks, setMark, markOf, needsAction,
} = await import('../../web/post_guide_marks.js');

beforeEach(() => stored.clear());

const req = (id) => ({ id, reason: id, required: true });
const rec = (id) => ({ id, reason: id, required: false });
const row = (topicId, status, missing = []) => ({ topicId, status, missing });
const day = (n) => new Date(Date.UTC(2026, 10, 1 + n));

test('the keys are the ones the page writes', () => {
  assert.equal(READ_KEY, 'viewerPostGuideRead');
  assert.equal(MARKS_KEY, 'viewerPostGuideMarks');
});

test('a thread state ignores the order of missing items', () => {
  assert.equal(threadState(row(1, 'failed', [req('b'), req('a')])),
    threadState(row(1, 'failed', [req('a'), req('b')])));
});

test('everything is new before the reader has marked anything as read', () => {
  assert.equal(lastRead(), null);
  assert.deepEqual(readChange(row(1, 'failed', [req('a')])), { change: 'new', was: null });
});

test('after marking all as read, only new and changed threads show', () => {
  markAllRead([row(1, 'failed', [req('a')]), row(2, 'follows'), row(3, 'unknown')], day(0));
  assert.equal(lastRead().at, day(0).toISOString());
  assert.equal(readChange(row(1, 'failed', [req('a')])).change, null);
  assert.equal(readChange(row(4, 'imperfect', [rec('x')])).change, 'new');
  // Fixed since last read.
  assert.deepEqual(readChange(row(1, 'follows')), { change: 'changed', was: 'failed' });
  // Checked for the first time.
  assert.deepEqual(readChange(row(3, 'failed', [req('a')])), { change: 'changed', was: 'unknown' });
  // Same status, another item missing.
  assert.equal(readChange(row(1, 'failed', [req('a'), rec('x')])).change, 'changed');
});

test('a failing thread with no mark needs action; other statuses never do', () => {
  assert.equal(needsAction(row(1, 'failed', [req('a')])), true);
  assert.equal(needsAction(row(2, 'imperfect', [rec('x')])), false);
  assert.equal(needsAction(row(3, 'follows')), false);
  assert.equal(needsAction(row(4, 'unknown')), false);
});

test('an ignored thread stays dealt with until something else required goes missing', () => {
  const r = row(1, 'failed', [req('a'), rec('x')]);
  setMark(r, 'ignored', day(0));
  assert.deepEqual(allMarks()['1'], { kind: 'ignored', on: day(0).toISOString(), status: 'failed', missing: ['a'] });
  assert.equal(needsAction(r, allMarks(), day(100)), false);
  // A recommendation going missing does not matter.
  assert.equal(needsAction(row(1, 'failed', [req('a'), rec('y')]), allMarks(), day(1)), false);
  // A required one does.
  const worse = row(1, 'failed', [req('a'), req('b')]);
  assert.equal(markOf(worse, allMarks(), day(1)).due, 'changed');
  assert.equal(needsAction(worse, allMarks(), day(1)), true);
});

test('a contacted author gets FOLLOW_UP_DAYS before the thread needs action again', () => {
  const r = row(1, 'failed', [req('a')]);
  setMark(r, 'contacted', day(0));
  assert.equal(needsAction(r, allMarks(), day(FOLLOW_UP_DAYS - 1)), false);
  assert.equal(markOf(r, allMarks(), day(FOLLOW_UP_DAYS)).due, 'time');
  assert.equal(needsAction(r, allMarks(), day(FOLLOW_UP_DAYS)), true);
  // Fixing part of it is still covered by the mark.
  setMark(row(2, 'failed', [req('a'), req('b')]), 'contacted', day(0));
  assert.equal(needsAction(row(2, 'failed', [req('b')]), allMarks(), day(1)), false);
});

test('clearing a mark puts the thread back', () => {
  const r = row(1, 'failed', [req('a')]);
  setMark(r, 'ignored', day(0));
  setMark(r, null);
  assert.equal(allMarks()['1'], undefined);
  assert.equal(needsAction(r), true);
});

test('marks on a thread that now follows the guide go when everything is marked as read', () => {
  setMark(row(1, 'failed', [req('a')]), 'contacted', day(0));
  setMark(row(2, 'failed', [req('a')]), 'ignored', day(0));
  setMark(row(3, 'imperfect', [rec('x')]), 'contacted', day(0));
  // Marked while it already followed the guide: kept.
  setMark(row(4, 'follows'), 'ignored', day(0));
  markAllRead([row(1, 'follows'), row(2, 'failed', [req('a')]), row(3, 'follows'), row(4, 'follows')], day(1));
  assert.deepEqual(Object.keys(allMarks()).sort(), ['2', '4']);
});

test('a mark saved before any thread could be marked counts as made on a failed thread', () => {
  stored.set(MARKS_KEY, JSON.stringify({ 1: { kind: 'ignored', on: day(0).toISOString(), missing: ['a'] } }));
  markAllRead([row(1, 'follows')], day(1));
  assert.deepEqual(allMarks(), {});
});

test('a thread that did not fail can be marked, and comes back when it fails', () => {
  const r = row(1, 'imperfect', [rec('x')]);
  assert.equal(needsAction(r), false);
  setMark(r, 'ignored', day(0));
  assert.deepEqual(markOf(r, allMarks(), day(1)), { kind: 'ignored', on: day(0).toISOString(), due: null });
  assert.equal(needsAction(r, allMarks(), day(100)), false);
  assert.equal(needsAction(row(1, 'failed', [req('a')]), allMarks(), day(1)), true);
});

test('a contacted author with recommendations still missing after FOLLOW_UP_DAYS needs a follow-up', () => {
  setMark(row(1, 'imperfect', [rec('x')]), 'contacted', day(0));
  assert.equal(needsAction(row(1, 'imperfect', [rec('x')]), allMarks(), day(FOLLOW_UP_DAYS)), true);
  // Fixed: nothing to follow up.
  assert.equal(markOf(row(1, 'follows'), allMarks(), day(FOLLOW_UP_DAYS)).due, null);
  assert.equal(needsAction(row(1, 'follows'), allMarks(), day(FOLLOW_UP_DAYS)), false);
});

test('unreadable storage reads as nothing saved', () => {
  stored.set(READ_KEY, 'not json');
  stored.set(MARKS_KEY, '[1,2]');
  assert.equal(lastRead(), null);
  assert.deepEqual(allMarks(), {});
});
