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

// --- Jobs on ticked source posts ---

/// The jobs the Source posts list can run on its ticked posts. A job with
/// `topicsOnly` acts on the ticked forum topics and leaves Discord threads out.
export const POST_JOBS = [
  { kind: 'rescrapeTopics', label: 'Re-scrape', topicsOnly: true },
  { kind: 'extractLlm', label: 'Re-run LLM', topicsOnly: false },
  { kind: 'resolveDownloads', label: 'Recheck downloads', topicsOnly: true },
  { kind: 'describePictures', label: 'Scan images', topicsOnly: true },
];

/// Splits ticked post keys (`topic:<id>`, `discord:<id>`) into topic ids
/// (numbers) and Discord thread ids (text: too large for an exact JavaScript number).
export function tickedIds(keys) {
  const topicIds = [];
  const discordThreadIds = [];
  for (const key of keys || []) {
    const at = String(key).indexOf(':');
    const kind = String(key).slice(0, at);
    const id = String(key).slice(at + 1);
    if (kind === 'topic' && /^\d+$/.test(id)) topicIds.push(Number(id));
    else if (kind === 'discord' && /^\d+$/.test(id)) discordThreadIds.push(id);
  }
  return { topicIds, discordThreadIds };
}

/// How many of the ticked posts `kind` acts on.
export function postJobCount(kind, keys) {
  const { topicIds, discordThreadIds } = tickedIds(keys);
  const job = POST_JOBS.find((j) => j.kind === kind);
  return topicIds.length + (job && !job.topicsOnly ? discordThreadIds.length : 0);
}

/// The request for a job on the ticked posts.
export function postJobRequest(kind, keys) {
  const { topicIds, discordThreadIds } = tickedIds(keys);
  const request = { kind, topicIds, runLlm: true };
  if (kind === 'extractLlm' && discordThreadIds.length) request.discordThreadIds = discordThreadIds;
  return request;
}

function countWords(n, one, many) {
  return n === 1 ? `1 ${one}` : `${n} ${many}`;
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
      if (!fetched.length) {
        return request.runLlm
          ? 'Fetch nothing, update missing or outdated LLM results (LLM calls may cost money), then rebuild every output.'
          : 'Fetch nothing, with no LLM calls, then rebuild every output.';
      }
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
    case 'rescrapeTopics':
      return `Fetch ${countWords((request.topicIds || []).length, 'topic', 'topics')} from the forum again, resolve downloads and re-run LLM extraction, which makes network requests (LLM calls may cost money).`;
    case 'resolveDownloads':
      return `Recheck downloads for ${countWords((request.topicIds || []).length, 'topic', 'topics')} using saved posts, which makes network requests to check the links.`;
    case 'extractLlm': {
      const topics = (request.topicIds || []).length;
      const threads = (request.discordThreadIds || []).length;
      const threadWords = countWords(threads, 'Discord thread', 'Discord threads');
      if (!topics) {
        return `Re-run LLM extraction for ${threadWords} from the saved messages, then rebuild the catalog, mod details and website (LLM calls may cost money).`;
      }
      const what = threads
        ? `${countWords(topics, 'topic', 'topics')} and ${threadWords} from saved posts`
        : `${countWords(topics, 'topic', 'topics')} from saved posts`;
      return `Re-run LLM extraction for ${what}, reading other Discord threads joined to the same mods again only if their saved answers are out of date (LLM calls may cost money).`;
    }
    case 'describePictures':
      if ((request.topicIds || []).length) {
        return `Rescan all images in ${countWords(request.topicIds.length, 'topic', 'topics')} and in the Discord threads joined to the same mods without reading any post again, then rebuild the catalog, mod details and website (LLM calls may cost money).`;
      }
      return 'Describe saved pictures that have no description yet, up to the per-run call limit (LLM calls may cost money), then rebuild every output without reading any post again.';
    case 'matchRequirements':
      return 'Ask the LLM to match unmatched dependency names to mods (LLM calls may cost money), then rebuild every output without reading any post again.';
    case 'llmTest':
      return 'Test the LLM prompt on a few topics and save a report, leaving other data unchanged (LLM calls may cost money).';
    case 'saveCorrections': {
      const n = (request.corrections || []).length;
      const what = n === 1 ? '1 correction' : `${n} corrections`;
      return request.publishAfter
        ? `Save ${what}, rebuild every output from saved files, then publish, with no LLM calls.`
        : `Save ${what}, then rebuild every output from saved files, with no network or LLM calls.`;
    }
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
    case 'extractLlm': return 'Re-run LLM';
    case 'llmTest': return 'Run LLM test';
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
