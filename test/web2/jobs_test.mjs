// Tests for the Control page's job requests and confirm sentences
// (web2/jobs.js). Run with `node --test test/web2/jobs_test.mjs`, or through
// `dart test` (web2_js_test.dart).

import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  defaultFetchOptions, fetchHasWork, fetchRequest, llmRequest, rebuildRequest, publishRequest,
  scanImagesRequest, matchNamesRequest, describeJob, listWords, duration,
} from '../../web2/jobs.js';

test('Fetch and update starts with today\'s defaults', () => {
  assert.deepEqual(fetchRequest(defaultFetchOptions()), {
    kind: 'fetchAndUpdate',
    scope: 'newData',
    boards: ['main', 'lesser', 'libraries'],
    modSources: ['discord'],
    runLlm: true,
    collectMergeDebug: true,
    replayAllowed: false,
  });
});

test('Fetch and update needs a board or a source', () => {
  assert.equal(fetchHasWork({ boards: [], sources: [] }), false);
  assert.equal(fetchHasWork({ boards: [], sources: ['nexus'] }), true);
  assert.equal(fetchHasWork({ boards: ['main'], sources: [] }), true);
});

test('the default options are a fresh copy each time', () => {
  const a = defaultFetchOptions();
  a.boards.pop();
  assert.equal(defaultFetchOptions().boards.length, 3);
});

test('Run LLM sends llmRereadAll only for All', () => {
  assert.deepEqual(llmRequest(false), { kind: 'llmCoveragePass', runLlm: true, llmRereadAll: false });
  assert.deepEqual(llmRequest(true), { kind: 'llmCoveragePass', runLlm: true, llmRereadAll: true });
});

test('the other jobs', () => {
  assert.deepEqual(rebuildRequest(), { kind: 'rebuildFromSaved', collectMergeDebug: true });
  assert.deepEqual(publishRequest(), { kind: 'publishOutputs' });
  assert.deepEqual(scanImagesRequest(), { kind: 'describePictures', runLlm: true });
  assert.deepEqual(matchNamesRequest(), { kind: 'matchRequirements', runLlm: true });
});

test('every confirm dialog says one sentence', () => {
  const requests = [
    fetchRequest(defaultFetchOptions()),
    fetchRequest({ scope: 'all', boards: ['main'], sources: [], runLlm: false }),
    fetchRequest({ scope: 'newData', boards: [], sources: ['discord', 'nexus'], runLlm: true }),
    llmRequest(false),
    llmRequest(true),
    rebuildRequest(),
    publishRequest(),
    scanImagesRequest(),
    matchNamesRequest(),
    { kind: 'takeDown' },
  ];
  for (const r of requests) {
    const sentence = describeJob(r);
    assert.match(sentence, /^[A-Z].*\.$/, sentence);
    assert.equal(sentence.split(/\.\s/).length, 1, `one sentence: ${sentence}`);
  }
});

test('the fetch sentence names what is fetched and the LLM', () => {
  assert.equal(
    describeJob(fetchRequest(defaultFetchOptions())),
    'Fetch new or changed topics on the main, lesser mods and libraries boards and Discord, update missing or outdated LLM results (LLM calls may cost money), then rebuild every output.',
  );
  assert.equal(
    describeJob(fetchRequest({ scope: 'all', boards: ['main'], sources: [], runLlm: false })),
    'Fetch every topic on the main board, with no LLM calls, then rebuild every output.',
  );
  assert.equal(
    describeJob(fetchRequest({ scope: 'newData', boards: [], sources: ['nexus'], runLlm: false })),
    'Fetch Nexus, with no LLM calls, then rebuild every output.',
  );
});

test('Run LLM All says it reads every post and may cost money', () => {
  const sentence = describeJob(llmRequest(true));
  assert.match(sentence, /every saved forum topic and Discord thread/);
  assert.match(sentence, /call limit/);
  assert.match(sentence, /cost money/);
});

test('lists read naturally', () => {
  assert.equal(listWords([]), '');
  assert.equal(listWords(['a']), 'a');
  assert.equal(listWords(['a', 'b']), 'a and b');
  assert.equal(listWords(['a', 'b', 'c']), 'a, b and c');
});

test('durations', () => {
  const start = '2026-11-05T10:00:00Z';
  assert.equal(duration(start, '2026-11-05T10:00:17Z'), '17s');
  assert.equal(duration(start, '2026-11-05T10:04:05Z'), '4m 05s');
  assert.equal(duration(start, '2026-11-05T12:07:00Z'), '2h 07m');
  assert.equal(duration(null, null), '');
  assert.equal(duration(start, null, Date.parse('2026-11-05T10:00:30Z')), '30s');
});
