// Words and addresses for the Mods list and the mod page. No DOM here, so
// Node can test it (test/web/mod_helpers_test.mjs).

/// Starmodder's own address. Each mod's page is `mods/<id>/` under it, and the
/// file that page reads is `mods/<id>.json`.
export const STARMODDER = 'https://starmodder.wispborne.com/';

export function starmodderPage(id) {
  return `${STARMODDER}mods/${encodeURIComponent(id)}/`;
}

export function starmodderFile(id) {
  return `${STARMODDER}mods/${encodeURIComponent(id)}.json`;
}

/// True for an http(s) address with a host. Addresses from scraped data are
/// only made into links when this holds: a `javascript:` address would run on
/// the viewer's own page, which also holds the job and settings controls. The
/// browser's own address parser decides, so tabs, line breaks and spaces
/// hidden in the scheme are read the way a link would read them.
export function isWebAddress(url) {
  if (typeof url !== 'string' || !url.trim()) return false;
  try {
    const parsed = new URL(url);
    return (parsed.protocol === 'http:' || parsed.protocol === 'https:') && !!parsed.hostname;
  } catch {
    return false;
  }
}

export function modHref(id) {
  return `#/mods/${encodeURIComponent(id)}`;
}

/// The catalog names a forum topic `forum`; the source post pages call it
/// `topic`. Nexus pages have no page of their own here.
const PAGE_KINDS = { forum: 'topic', topic: 'topic', discord: 'discord' };

/// The viewer address for a catalog source post, or null.
export function postHref(post) {
  const kind = PAGE_KINDS[post && post.kind];
  if (!kind || post.id == null || post.id === '') return null;
  return `#/posts/${kind}/${encodeURIComponent(post.id)}`;
}

/// The name of each kind of source post.
export function postKindWords(kind) {
  if (kind === 'forum' || kind === 'topic') return 'Forum topic';
  if (kind === 'discord') return 'Discord thread';
  if (kind === 'nexus') return 'Nexus page';
  return kind ? String(kind) : 'Post';
}

/// "Forum topic 9175", for a post with no title.
export function postFallbackName(post) {
  return `${postKindWords(post.kind)} ${post.id}`;
}

/// The keys the per-post jobs take (`topic:<id>`, `discord:<id>`) for a mod's
/// source posts. Nexus pages have no jobs.
export function postJobKeys(posts) {
  const keys = [];
  for (const post of posts || []) {
    const kind = PAGE_KINDS[post.kind];
    if (!kind || post.id == null || post.id === '') continue;
    const key = `${kind}:${post.id}`;
    if (!keys.includes(key)) keys.push(key);
  }
  return keys;
}

/// Whether the rules or the LLM found the mod on the post, in the old
/// viewer's words.
export function foundByWords(foundBy) {
  if (foundBy === 'llm') return 'Found by the LLM';
  if (foundBy === 'rulesAndLlm') return 'Found by the rules, joined by the LLM';
  if (foundBy === 'rules') return 'Found by the rules';
  return foundBy ? String(foundBy) : '';
}

/// How a post joined the mod, as the merge recorded it.
export function joinedByWords(joinedBy) {
  switch (joinedBy) {
    case 'first': return 'The mod started from this post';
    case 'sameId': return 'Already had this mod’s id';
    case 'forumLink': return 'Links to the mod’s forum topic';
    case 'name': return 'Same name and author';
    case 'download': return 'Shares a download';
    default: return joinedBy ? String(joinedBy) : '';
  }
}

/// Where one fact came from: `{ text, href, llmName }`. A source is a post
/// (`{ kind, id, llmName }`), or `rules`, or `merged` (made from several).
/// Null when the build recorded no source.
export function factSource(source) {
  if (source == null || source === '') return null;
  const kind = typeof source === 'string' ? source : source.kind;
  if (kind === 'rules') return { text: 'The rules', href: null, llmName: null };
  if (kind === 'merged' || kind === 'merge') return { text: 'Several posts, combined', href: null, llmName: null };
  if (typeof source === 'string') return { text: source, href: null, llmName: null };
  return {
    text: source.title || postFallbackName(source),
    href: postHref(source),
    llmName: source.llmName || source.llmModName || null,
  };
}

/// Names for the fields of a mod's facts. Anything else is spelled out from
/// its camelCase name.
const FIELD_NAMES = {
  name: 'Name',
  displayName: 'Shown name',
  authors: 'Authors',
  summary: 'Summary',
  aiSummary: 'AI summary',
  description: 'Description',
  aiDescription: 'AI description',
  version: 'Mod version',
  modVersion: 'Mod version',
  gameVersion: 'Game version',
  downloads: 'Downloads',
  changelog: 'Changelog',
  needs: 'Requires',
  optionalNeeds: 'Optional',
  conflicts: 'Conflicts',
  aiUse: 'AI use',
  supportLinks: 'Support the author',
  sourceCode: 'Source code',
  sourceCodeUrl: 'Source code',
  license: 'License',
  image: 'Picture',
  imageUrl: 'Picture',
  categories: 'Categories',
  saveCompatibility: 'Adding to a save',
  canAdd: 'Adding to a save (short answer)',
  updateNotes: 'Updating',
  removalCompatibility: 'Removing from a save',
  canRemove: 'Removing from a save (short answer)',
  nicknames: 'Also called',
  isTool: 'Tool',
  descriptionAnchors: 'Description cut from the post',
};

export function fieldName(field) {
  if (FIELD_NAMES[field]) return FIELD_NAMES[field];
  const words = String(field).replace(/([a-z0-9])([A-Z])/g, '$1 $2').toLowerCase();
  return words.charAt(0).toUpperCase() + words.slice(1);
}

/// A value in one short line: lists joined with commas, a needed mod by its
/// name, yes and no for true and false. Long text is cut with "…".
export function shortValue(value, max = 160) {
  const text = valueText(value);
  return text.length > max ? `${text.slice(0, max - 1)}…` : text;
}

function valueText(value) {
  if (value == null || value === '') return '—';
  if (value === true) return 'yes';
  if (value === false) return 'no';
  if (Array.isArray(value)) return value.length ? value.map(valueText).join(', ') : '—';
  if (typeof value === 'object') {
    for (const key of ['name', 'label', 'url', 'quote', 'sentence']) {
      if (typeof value[key] === 'string' && value[key]) return value[key];
    }
    const keys = Object.keys(value);
    if (!keys.length) return '—';
    return keys.map((k) => `${k}: ${valueText(value[k])}`).join('; ');
  }
  return String(value);
}

/// The site's short save answers, in the mod page's words.
export function saveAnswerWords(answer) {
  return { yes: 'Yes', no: 'No', depends: 'Depends' }[answer] || null;
}

/// The names a mod is credited under, without repeats (case is ignored).
export function distinctNames(names) {
  const seen = new Set();
  const out = [];
  for (const name of names || []) {
    const text = String(name || '').trim();
    const key = text.toLowerCase();
    if (!text || seen.has(key)) continue;
    seen.add(key);
    out.push(text);
  }
  return out;
}

/// The label of a "same person" pending change. The Author aliases page uses
/// the same words.
export function sameAuthorLabel(a, b) {
  return `"${a}" and "${b}" are the same person`;
}

/// The label of a "match this name to a mod" pending change. The Dependency
/// names page uses the same words.
export function matchLabel(written, modName) {
  return `"${written}" means "${modName}"`;
}
