// Tests for the Control page's job requests and confirm sentences
// (web/jobs.js). Run with `node --test test/web/jobs_test.mjs`, or through
// `dart test` (web_js_test.dart).

import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  defaultFetchOptions, fetchHasWork, fetchRequest, llmRequest, rebuildRequest, publishRequest,
  scanImagesRequest, matchNamesRequest, describeJob, listWords, duration,
  POST_JOBS, tickedIds, postJobCount, postJobRequest,
} from '../../web/jobs.js';

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
    { kind: 'llmTest' },
    ...POST_JOBS.flatMap((job) => [
      postJobRequest(job.kind, ['topic:1']),
      postJobRequest(job.kind, ['topic:1', 'topic:2', 'discord:1203053249377079297']),
    ]),
    postJobRequest('extractLlm', ['discord:1203053249377079297']),
    postJobRequest('extractLlm', ['discord:1', 'discord:2']),
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

test('a fetch that names nothing to fetch still reads as a sentence', () => {
  assert.equal(
    describeJob({ kind: 'fetchAndUpdate' }),
    'Fetch nothing, with no LLM calls, then rebuild every output.',
  );
});

test('Run LLM All says it reads every post and may cost money', () => {
  const sentence = describeJob(llmRequest(true));
  assert.match(sentence, /every saved forum topic and Discord thread/);
  assert.match(sentence, /call limit/);
  assert.match(sentence, /cost money/);
});

test('the LLM test sentence says it changes nothing else and may cost money', () => {
  assert.equal(
    describeJob({ kind: 'llmTest' }),
    'Test the LLM prompt on a few topics and save a report, leaving other data unchanged (LLM calls may cost money).',
  );
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

test('ticked posts split into topic ids and Discord thread ids', () => {
  assert.deepEqual(tickedIds(['topic:12', 'discord:1203053249377079297', 'topic:7', 'nexus:3', 'junk']), {
    topicIds: [12, 7],
    discordThreadIds: ['1203053249377079297'],
  });
});

test('a job on ticked posts sends the topics, and Re-run LLM the threads too', () => {
  const ticked = ['topic:1', 'topic:2', 'discord:1203053249377079297'];
  assert.deepEqual(postJobRequest('extractLlm', ticked), {
    kind: 'extractLlm',
    topicIds: [1, 2],
    runLlm: true,
    discordThreadIds: ['1203053249377079297'],
  });
  assert.deepEqual(postJobRequest('rescrapeTopics', ticked), { kind: 'rescrapeTopics', topicIds: [1, 2], runLlm: true });
  assert.deepEqual(postJobRequest('extractLlm', ['topic:3']), { kind: 'extractLlm', topicIds: [3], runLlm: true });
});

test('a job that works only on topics counts only the ticked topics', () => {
  const ticked = ['topic:1', 'topic:2', 'discord:9'];
  assert.equal(postJobCount('extractLlm', ticked), 3);
  for (const kind of ['rescrapeTopics', 'resolveDownloads', 'describePictures']) {
    assert.equal(postJobCount(kind, ticked), 2, kind);
    assert.equal(postJobCount(kind, ['discord:9']), 0, kind);
  }
});

test('the per-post sentences', () => {
  assert.equal(
    describeJob(postJobRequest('rescrapeTopics', ['topic:1'])),
    'Fetch 1 topic from the forum again, resolve downloads and re-run LLM extraction, which makes network requests (LLM calls may cost money).',
  );
  assert.equal(
    describeJob(postJobRequest('resolveDownloads', ['topic:1', 'topic:2'])),
    'Recheck downloads for 2 topics using saved posts, which makes network requests to check the links.',
  );
  assert.equal(
    describeJob(postJobRequest('extractLlm', ['topic:1', 'discord:9'])),
    'Re-run LLM extraction for 1 topic and 1 Discord thread from saved posts, reading other Discord threads joined to the same mods again only if their saved answers are out of date (LLM calls may cost money).',
  );
  assert.equal(
    describeJob(postJobRequest('extractLlm', ['discord:9', 'discord:10'])),
    'Re-run LLM extraction for 2 Discord threads from the saved messages, then rebuild the catalog, mod details and website (LLM calls may cost money).',
  );
  assert.equal(
    describeJob(postJobRequest('describePictures', ['topic:1', 'topic:2'])),
    'Rescan all images in 2 topics and in the Discord threads joined to the same mods without reading any post again, then rebuild the catalog, mod details and website (LLM calls may cost money).',
  );
  // With no topics, Scan images is still the Control page's job.
  assert.match(describeJob(scanImagesRequest()), /^Describe saved pictures/);
});
