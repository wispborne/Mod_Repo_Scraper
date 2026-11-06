// The jobs the Control page can start: the request each one sends and the
// sentence its confirm dialog shows. No DOM here, so Node can test it
// (test/web2/jobs_test.mjs).

import { kindLabel } from './routes.js';

export const SCOPES = [
  ['newData', 'New or changed topics'],
  ['all', 'All topics on selected boards'],
  ['librariesOnly', 'Libraries board only'],
];

export const BOARDS = [
  ['main', 'Main mods board'],
  ['lesser', 'Lesser mods board'],
  ['libraries', 'Libraries board'],
];

export const SOURCES = [
  ['discord', 'Discord'],
  ['nexus', 'Nexus'],
];

/// Default "Fetch and update" options for each visit.
export function defaultFetchOptions() {
  return {
    scope: 'newData',
    boards: ['main', 'lesser', 'libraries'],
    sources: ['discord'],
    runLlm: true,
  };
}

/// Whether "Fetch and update" has anything to fetch.
export function fetchHasWork(options) {
  return options.boards.length > 0 || options.sources.length > 0;
}

export function fetchRequest(options) {
  return {
    kind: 'fetchAndUpdate',
    scope: options.scope,
    boards: [...options.boards],
    modSources: [...options.sources],
    runLlm: options.runLlm,
    collectMergeDebug: true,
    replayAllowed: false,
  };
}

/// "Run LLM": `all` reads every post again, oldest answer first.
export function llmRequest(all) {
  return { kind: 'llmCoveragePass', runLlm: true, llmRereadAll: !!all };
}

export function rebuildRequest() {
  return { kind: 'rebuildFromSaved', collectMergeDebug: true };
}

export function publishRequest() {
  return { kind: 'publishOutputs' };
}

export function scanImagesRequest() {
  return { kind: 'describePictures', runLlm: true };
}

export function matchNamesRequest() {
  return { kind: 'matchRequirements', runLlm: true };
}

const BOARD_NAMES = { main: 'main', lesser: 'lesser mods', libraries: 'libraries' };
const SOURCE_NAMES = { forum: 'the forum', discord: 'Discord', nexus: 'Nexus' };
const SCOPE_WORDS = {
  newData: 'new or changed topics',
  all: 'every topic',
  librariesOnly: 'the libraries board',
  pages: 'the first few pages',
  topics: 'the named topics',
};

/// "a", "a and b", "a, b and c".
export function listWords(words) {
  if (words.length <= 1) return words.join('');
  return `${words.slice(0, -1).join(', ')} and ${words[words.length - 1]}`;
}

function boardWords(boards) {
  const names = (boards || []).map((b) => BOARD_NAMES[b] || b);
  if (!names.length) return 'no boards';
  return `the ${listWords(names)} ${names.length === 1 ? 'board' : 'boards'}`;
}

/// The one sentence a confirm dialog shows for a request.
export function describeJob(request) {
  switch (request.kind) {
    case 'fetchAndUpdate': {
      const boards = request.boards || [];
      const others = (request.modSources || []).filter((s) => s !== 'forum')
        .map((s) => SOURCE_NAMES[s] || s);
      const fetched = [];
      if (boards.length) {
        const scope = request.scope === 'librariesOnly'
          ? 'the libraries board'
          : `${SCOPE_WORDS[request.scope] || SCOPE_WORDS.newData} on ${boardWords(boards)}`;
        fetched.push(scope);
      }
      fetched.push(...others);
      const llm = request.runLlm
        ? ', update missing or outdated LLM results (LLM calls may cost money)'
        : ', with no LLM calls';
      return `Fetch ${listWords(fetched)}${llm}, then rebuild every output.`;
    }
    case 'llmCoveragePass':
      return request.llmRereadAll
        ? 'Read every saved forum topic and Discord thread again with the LLM, oldest answer first, up to the per-run call limit (LLM calls may cost money), then rebuild every output.'
        : 'Read saved posts that have no LLM answer or whose post or prompt changed, up to the per-run call limit (LLM calls may cost money), then rebuild every output.';
    case 'rebuildFromSaved':
      return 'Rebuild every output from saved files, with no network or LLM calls.';
    case 'publishOutputs':
      return 'Publish the current outputs and website to the GitHub repo TriOS reads (nothing is pushed if nothing changed).';
    case 'describePictures':
      return 'Describe saved pictures that have no description yet, up to the per-run call limit (LLM calls may cost money), then rebuild every output without reading any post again.';
    case 'matchRequirements':
      return 'Ask the LLM to match unmatched dependency names to mods (LLM calls may cost money), then rebuild every output without reading any post again.';
    default:
      return `Run "${kindLabel(request.kind)}" again with the same settings.`;
  }
}

/// The confirm dialog's button for a request.
export function confirmLabel(request) {
  switch (request.kind) {
    case 'publishOutputs': return 'Publish';
    case 'llmCoveragePass': return request.llmRereadAll ? 'Read every post' : 'Run LLM';
    case 'rebuildFromSaved': return 'Rebuild';
    default: return `Start ${kindLabel(request.kind).toLowerCase()}`;
  }
}

/// How long a run took or has taken, as "4m 05s".
export function duration(startedAt, finishedAt, now = Date.now()) {
  if (!startedAt) return '';
  const start = new Date(startedAt).getTime();
  const end = finishedAt ? new Date(finishedAt).getTime() : now;
  if (Number.isNaN(start) || Number.isNaN(end)) return '';
  const s = Math.max(0, Math.round((end - start) / 1000));
  if (s < 60) return `${s}s`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m ${String(s % 60).padStart(2, '0')}s`;
  return `${Math.floor(m / 60)}h ${String(m % 60).padStart(2, '0')}m`;
}
