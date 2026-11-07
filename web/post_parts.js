// Shared parts of the source post page and the topic history page: the
// sandboxed post frame, picture and link lists, download tables, the LLM's
// mods with their downloads and extras, the per-post job buttons, and the
// check for whether the published mod details are behind the saved data.

import { el, api, shortTime, infoButton } from './lib.js';
import { icon } from './icons.js';
import { confirmAndStart } from './actions.js';
import { rebuildRequest } from './jobs.js';
import { webAddress, shortAddress } from './mod_words.js';

// --- Small shapes ---

/// A small outlined label. `tone` is '', 'good', 'warn', 'bad' or 'strong'.
export function badge(text, tone = '') {
  return el('span', { class: `pp-badge${tone ? ` ${tone}` : ''}`, text });
}

/// A section of the page: a heading bar, then its contents. `hint` is shown
/// when the pointer rests on the heading.
export function section(title, count, children, hint = null) {
  return el('section', { class: 'pp-section' }, [
    el('h3', { class: 'pp-section-head', title: hint }, [
      el('span', { class: 'panel-heading', text: title }),
      count == null ? null : el('span', { class: 'pp-section-count', text: String(count) }),
    ]),
    el('div', { class: 'pp-section-body' }, children),
  ]);
}

/// A sub-heading inside a section.
export function subhead(text, children = []) {
  return el('h4', { class: 'pp-subhead' }, [text, ...children]);
}

/// A muted line for something missing or empty.
export function emptyLine(text) {
  return el('p', { class: 'pp-empty', text });
}

/// A link that opens in a new tab. An address that is not http(s) is shown
/// as plain text instead, so scraped data can never put a script in a link.
export function outLink(href, text, attrs = {}) {
  const link = webAddress(href);
  if (!link) return el('span', { ...attrs, text });
  return el('a', { ...attrs, href: link, target: '_blank', rel: 'noopener', text });
}

export function fold(label, content) {
  return el('details', { class: 'pp-fold' }, [el('summary', { text: label }), content]);
}

/// Label and value pairs; empty values are left out. A pair may carry a third
/// item, a node to show instead of plain text.
export function fieldList(rows) {
  const list = el('dl', { class: 'pp-fields' });
  for (const [label, value, node] of rows) {
    if (!node && (value == null || value === '')) continue;
    list.append(
      el('dt', { text: label }),
      el('dd', {}, [node || String(value)]),
    );
  }
  return list;
}

/// An ISO time for reading, in the reader's own time zone, written the way
/// the rest of the viewer writes times ("5 Nov 23:07").
export function when(iso) {
  if (!iso) return null;
  return shortTime(iso) || String(iso);
}

const MONTHS = ['january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september',
  'october', 'november', 'december'];

/// A date as the forum writes it ("August 05, 2025, 05:32:14 PM"), written
/// like the viewer's other times, with the forum's own words on hover. The
/// forum gives no time zone, so the time is read as the reader's own. An edit
/// date may end in "by <name>", which is kept. Text that is not in that form
/// ("Today at 03:12:22 PM") is shown as it is.
export function forumTime(text) {
  if (!text) return null;
  const m = String(text).match(/^([A-Za-z]+) (\d{1,2}), (\d{4}), (\d{1,2}):(\d{2}):(\d{2}) (AM|PM)( by .+)?$/);
  const month = m ? MONTHS.indexOf(m[1].toLowerCase()) : -1;
  if (!m || month < 0) return el('span', { text: String(text) });
  const hour = (Number(m[4]) % 12) + (m[7] === 'PM' ? 12 : 0);
  const at = new Date(Number(m[3]), month, Number(m[2]), hour, Number(m[5]), Number(m[6]));
  return el('span', { title: String(text), text: `${shortTime(at.toISOString())}${m[8] || ''}` });
}

// --- The post itself ---

// Styles the forum's bbc_* classes inside the sandboxed frame, in the
// viewer's colours. The frame cannot read the viewer's stylesheet.
const FRAME_CSS = `
  * { scrollbar-width: thin; scrollbar-color: #4a4130 #11151a; }
  body { background: #11151a; color: #dce2e8;
    font-family: 'Segoe UI', system-ui, sans-serif; line-height: 1.5;
    padding: 14px; margin: 0; font-size: 14px; }
  a, a.bbc_link { color: #e3b45a; }
  img, img.bbc_img { max-width: 100%; height: auto; }
  table, table.bbc_table { border-collapse: collapse; margin: 8px 0; }
  table.bbc_table td, table.bbc_table th { border: 1px solid #222a33; padding: 4px 8px; }
  .bbc_tt, code, pre { font-family: 'IBM Plex Mono', Consolas, monospace; background: #171c22; padding: 1px 4px; }
  pre { padding: 10px; overflow: auto; }
  blockquote, .quote { border-left: 3px solid #4a4130; margin: 8px 0; padding: 4px 12px; background: #171c22; }
  .bbc_spoiler, .spoiler { border: 1px dashed #4a4130; padding: 8px; margin: 8px 0; }
  h1, h2, h3 { color: #f2e6cc; }
`;

/// The post's HTML in a sandboxed frame. The empty sandbox stops any script
/// in the scraped HTML from running. This is the only place the viewer shows
/// HTML from the data.
export function postFrame(html) {
  const doc = `<!DOCTYPE html><html><head><meta charset="utf-8"><style>${FRAME_CSS}</style></head><body>${html}</body></html>`;
  const frame = el('iframe', { class: 'pp-frame', title: 'Post text' });
  frame.setAttribute('sandbox', '');
  frame.setAttribute('srcdoc', doc);
  return frame;
}

/// Every link in a post, marked as a download, external or internal.
export function linkList(links) {
  return el('ul', { class: 'pp-links' }, links.map((link) => el('li', {}, [
    link.isDownloadable
      ? badge('Download', 'good')
      : badge(link.isExternal ? 'External' : 'Internal'),
    outLink(link.url, linkWords(link), { title: webAddress(link.url) }),
  ])));
}

/// A link's own words, or its address written short when it has none (or
/// its words are only the address again).
function linkWords(link) {
  const text = (link.text || '').trim();
  if (text && normUrl(text) !== normUrl(link.url)) return text;
  return shortAddress(link.url) || link.url;
}

// --- Pictures ---

/// How well a picture would do as a mod's card picture.
const FIT_BADGES = {
  good: ['good', 'Good'],
  okay: ['warn', 'Fair'],
  poor: ['bad', 'Poor'],
};

/// The picture kinds the model answers with, as words.
const PICTURE_KINDS = {
  screenshot: 'Screenshot', logo: 'Logo', banner: 'Banner', art: 'Artwork', button: 'Button',
  badge: 'Badge', divider: 'Divider', missing: 'Missing', other: 'Other',
};

/// True when [url] is a Discord attachment whose signed address has run out.
/// Discord writes the end time in `ex`, as seconds in hexadecimal.
function discordLinkExpired(url) {
  let address;
  try {
    address = new URL(url);
  } catch {
    return false;
  }
  if (!/(^|\.)discordapp\.(com|net)$/.test(address.hostname)) return false;
  const ends = parseInt(address.searchParams.get('ex') || '', 16);
  return Number.isFinite(ends) && ends * 1000 < Date.now();
}

/// What was saved about one picture: its kind, card rating and description,
/// or that it could not be described. Which model looked, where, when and
/// with which prompt version is shown on hover.
function pictureSeen(seen) {
  const facts = [];
  if (seen.model) facts.push(`Model: ${seen.model}`);
  if (seen.endpoint) facts.push(`Endpoint: ${seen.endpoint}`);
  if (seen.at) facts.push(`Run: ${shortTime(seen.at)}`);
  if (seen.v != null) facts.push(`Prompt version: ${seen.v}${seen.current === false ? ' (outdated)' : ''}`);
  const line = el('div', { class: 'pp-seen-line', title: facts.join('\n') || null });
  if (seen.caption) {
    const [tone, fitText] = FIT_BADGES[seen.fit] || ['', 'Not rated'];
    line.append(...[
      badge(PICTURE_KINDS[seen.kind] || 'Other', 'strong'),
      el('span', { class: `pp-badge${tone ? ` ${tone}` : ''}`, title: 'Thumbnail rating', text: fitText }),
      seen.current === false
        ? el('span', { class: 'pp-badge warn', title: 'Description created with an older prompt version.', text: 'Out of date' })
        : null,
      seen.caption,
    ].filter((part) => part != null));
  } else if (seen.unreadable) {
    line.append(el('span', {
      class: 'pp-badge bad', title: `Error: ${seen.unreadable}`, text: 'Could not describe image.',
    }));
  }
  return el('div', { class: 'pp-seen' }, [line]);
}

/// One picture: its thumbnail, linked to the picture, and what was saved
/// about it.
function pictureItem(img, seen) {
  const web = webAddress(img.originalUrl);
  const thumb = el('img', {
    class: 'pp-thumb', src: web, alt: img.alt || '',
    loading: 'lazy', referrerpolicy: 'no-referrer',
  });
  const text = el('div', { class: 'pp-picture-text' }, [
    img.alt ? el('div', { class: 'pp-picture-alt', text: img.alt }) : null,
  ]);
  if (discordLinkExpired(img.originalUrl)) {
    text.append(el('div', {
      class: 'pp-seen warn-text',
      title: 'Run “Fetch and update” with Discord selected to refresh this link.',
      text: 'Link expired.',
    }));
  }
  if (seen) text.append(pictureSeen(seen));
  return el('li', { class: 'pp-picture' }, [
    web
      ? el('a', { class: 'pp-thumb-link', href: web, target: '_blank', rel: 'noopener', title: `Open image\n${web}` }, [thumb])
      : thumb,
    text,
  ]);
}

/// The pictures in one post. Pictures the model has described come first,
/// each with its description; the rest are folded away as thumbnails.
/// `captions` is keyed by the picture's address. Each picture is
/// `{ originalUrl, alt }`.
export function imageList(images, captions = {}) {
  const described = images.filter((img) => captions[img.originalUrl]);
  const rest = images.filter((img) => !captions[img.originalUrl]);
  const parts = [];
  if (described.length) {
    parts.push(el('ul', { class: 'pp-pictures' }, described.map((img) => pictureItem(img, captions[img.originalUrl]))));
  }
  if (rest.length) {
    const list = el('ul', { class: 'pp-pictures' }, rest.map((img) => pictureItem(img, null)));
    // With nothing described, the pictures are shown as they are.
    parts.push(described.length ? fold(`Without descriptions (${rest.length})`, list) : list);
  }
  return el('div', { class: 'pp-picture-groups' }, parts);
}

/// A Discord picture in the shape `imageList` takes.
export function discordImage(image) {
  return { originalUrl: image.url, alt: image.description || image.filename };
}

// --- Downloads ---

/// A rule-based download as the topic and Discord routes serve it (the
/// resolver's candidate), in one plain shape.
export function downloadRowFromCandidate(c) {
  return {
    url: c.sourceUrl || '',
    directUrl: c.resolvedUrl || null,
    host: c.sourceHost || '',
    fileName: c.archiveFilename || null,
    confidence: c.confidence || '',
    requiresManualStep: !!c.requiresManualStep,
    linkText: c.linkText || '',
  };
}

export function normUrl(u) {
  return String(u || '').trim().toLowerCase()
    .replace(/^https?:\/\//, '').replace(/\/+$/, '');
}

/// Shortens cell text and keeps the full value on hover.
function clampCell(text, max = 40) {
  const s = String(text || '');
  if (!s) return '—';
  if (s.length <= max) return s;
  return el('span', { title: s, text: `${s.slice(0, max - 1)}…` });
}

const CONFIDENCE_TONES = { high: 'good-text', medium: 'warn-text', low: 'failed-text' };

function confidenceCell(confidence) {
  return el('td', { class: CONFIDENCE_TONES[confidence] || '', text: confidence || '—' });
}

function table(headings, rows) {
  return el('div', { class: 'table-wrap pp-table-wrap' }, [
    el('table', { class: 'table pp-dl' }, [
      el('thead', {}, el('tr', {}, headings.map((h) => el('th', { text: h })))),
      el('tbody', {}, rows),
    ]),
  ]);
}

/// A link to a download: its words, or "Open", with the address on hover.
/// Words that are only an address are written short.
function downloadLink(words, href) {
  if (!href) return '—';
  const text = (webAddress(words) && shortAddress(words)) || words || 'Open';
  return outLink(href, text, { class: 'pp-url', title: href });
}

/// The button that shows a download's details: `rows` as label and value pairs.
function downloadDetails(rows) {
  return infoButton('Download details', 'Download details', () => [fieldList(rows)]);
}

const YES_NO = (v) => (v ? 'Yes' : 'No');
const CONFIDENCE_WORDS = { high: 'High', medium: 'Medium', low: 'Low' };

/// The downloads the rules found, in the plain shape above.
export function assumedTable(rows) {
  if (!rows.length) return emptyLine('No downloads found.');
  return table(
    ['File', 'Host', 'Link', ''],
    rows.map((r) => el('tr', {}, [
      el('td', {}, [clampCell(r.fileName)]),
      el('td', { text: r.host || '—' }),
      el('td', {}, [downloadLink(r.linkText, r.directUrl || r.url)]),
      el('td', { class: 'pp-row-info' }, [downloadDetails([
        ['Confidence', CONFIDENCE_WORDS[r.confidence] || r.confidence || '—'],
        ['Extra step', YES_NO(r.requiresManualStep)],
        ['Link text', r.linkText],
        ['Original link', r.url],
        ['Download link', r.directUrl && r.directUrl !== r.url ? r.directUrl : null],
      ])]),
    ])),
  );
}

/// The download kinds the LLM answers with, as words.
const DOWNLOAD_KINDS = { direct: 'Download', mirror: 'Mirror', trios: 'Install with TriOS' };

/// One mod's downloads as the LLM listed them. A download whose address is
/// not in `ruleUrls` is one the rules missed: its row is marked, and its
/// details say the LLM found it.
export function llmDownloadsTable(downloads, ruleUrls) {
  if (!downloads.length) return emptyLine('No downloads listed.');
  return table(
    ['File', 'Host', 'Link', ''],
    downloads.map((d) => {
      const rulesMissed = !ruleUrls.has(normUrl(d.url));
      return el('tr', { class: rulesMissed ? 'pp-llm-only' : '' }, [
        el('td', {}, [clampCell(d.fileName)]),
        el('td', { text: d.sourceHost || '—' }),
        el('td', {}, [downloadLink(d.label, d.resolvedDirectUrl || d.url)]),
        el('td', { class: 'pp-row-info' }, [downloadDetails([
          ['Type', DOWNLOAD_KINDS[d.kind || 'direct'] || d.kind],
          ['Source', rulesMissed ? 'LLM' : 'Rules'],
          ['Confidence', CONFIDENCE_WORDS[d.confidence] || d.confidence || '—'],
          ['Extra step', YES_NO(d.requiresManualStep)],
          ['Original link', d.url],
          ['Download link', d.resolvedDirectUrl && d.resolvedDirectUrl !== d.url ? d.resolvedDirectUrl : null],
        ])]),
      ]);
    }),
  );
}

// --- The LLM's mods ---

/// The roles the LLM gives a mod, as words.
const ROLES = { main: 'Main', addon: 'Add-on', separate: 'Other mod', variant: 'Alternate version' };

function roleBadge(role) {
  const r = role || 'main';
  return badge(ROLES[r] || r, r === 'main' ? 'strong' : '');
}

/// Every mod the LLM found, each with its downloads and extras.
export function llmModsBlock(mods, ruleUrls) {
  return el('div', { class: 'pp-mods' }, mods.map((mod) => modCard(mod, ruleUrls)));
}

function modCard(mod, ruleUrls) {
  const card = el('article', { class: 'pp-mod' });
  // The site builder uses the description's first and last words to cut the
  // author's text out of a shared thread. They are shown on request.
  const anchors = mod.descriptionAnchors;
  card.append(el('div', { class: 'pp-mod-head' }, [
    el('span', { class: 'pp-mod-name', text: mod.name || 'Unnamed mod' }),
    roleBadge(mod.role),
    mod.isTool ? badge('Tool') : null,
    mod.requires ? el('span', { class: 'dim', text: `Requires ${mod.requires}` }) : null,
    anchors && anchors.startsWith && anchors.endsWith
      ? infoButton('Mod details', 'Description details', () => [fieldList([
        ['Start', `"${anchors.startsWith}"`],
        ['End', `"${anchors.endsWith}"`],
      ])])
      : null,
  ]));
  // Other names the post uses for the mod; the public site's search matches on them.
  if ((mod.nicknames || []).length) {
    card.append(fieldList([['Also called', mod.nicknames.join(', ')]]));
  }
  if (mod.image) {
    // Stored as `ext:<url>`, like the thread thumbnail.
    const src = webAddress(String(mod.image).replace(/^ext:/, ''));
    if (src) card.append(el('img', {
      class: 'pp-mod-image', src, alt: mod.name || 'Mod image', loading: 'lazy', referrerpolicy: 'no-referrer',
    }));
  }
  card.append(llmDownloadsTable(mod.downloads || [], ruleUrls));
  if (mod.extras) card.append(extrasBlock(mod.extras));
  return card;
}

function extrasBlock(extras) {
  const box = el('div', { class: 'pp-extras' });

  // The model's own words, shown first.
  const summary = extras.summary;
  const hasSummary = !!(summary && (summary.sentence || summary.paragraph));
  if (hasSummary) {
    box.append(subhead('Summary'));
    if (summary.sentence) box.append(el('p', { class: 'pp-summary-sentence', text: summary.sentence }));
    if (summary.paragraph) box.append(el('p', { class: 'pp-summary-paragraph', text: summary.paragraph }));
  }

  // Fields copied word for word from the post.
  const rows = [];
  if (extras.version) rows.push(['Mod version', extras.version]);
  if (extras.license) rows.push(['License', extras.license]);
  if (extras.sourceCode) rows.push(['Source code', null, outLink(extras.sourceCode, 'View source', { title: extras.sourceCode })]);
  // Each save question: the short answer, with the post's own words on hover.
  const saveRow = (label, answer, words) => {
    if (!words) return;
    const short = { yes: 'Yes', no: 'No', depends: 'Depends' }[answer];
    rows.push([label, null, short ? el('span', { title: words, text: short }) : el('span', { text: words })]);
  };
  saveRow('Add to existing save', extras.canAdd, extras.saveCompatibility);
  // One row per update note, each naming the release it was written for.
  for (const note of extras.updateNotes || []) {
    saveRow(note.version ? `Update to ${note.version}` : 'Update', note.answer, note.quote);
  }
  saveRow('Remove from existing save', extras.canRemove, extras.removalCompatibility);
  if ((extras.needs || []).length) rows.push(['Requires', extras.needs.join(', ')]);
  if ((extras.optionalNeeds || []).length) rows.push(['Optional', extras.optionalNeeds.join(', ')]);
  if ((extras.conflicts || []).length) {
    // Each name, with the kind of conflict and the author's words on hover.
    rows.push(['Conflicts', null, el('span', {}, extras.conflicts.flatMap((c, i) => [
      i ? ', ' : null,
      el('span', { class: 'pp-hover', title: [c.kind, c.quote].filter(Boolean).join(': '), text: c.name }),
    ]))]);
  }
  // No aiUse at all means the post was read before the prompt asked, so the
  // row is left out; an aiUse with no answer means it was read and says nothing.
  const aiUse = extras.aiUse;
  if (aiUse && aiUse.usesAi == null) {
    rows.push(['AI use', 'Not stated']);
  } else if (aiUse) {
    rows.push(['AI use', null, el('span', { title: aiUse.quote || null, text: aiUse.usesAi ? 'Yes' : 'No' })]);
    // Each part, with how much AI did on hover.
    const uses = (aiUse.uses || []).map((use) => {
      const notes = [use.how, use.extent, use.optional ? 'Optional' : null].filter(Boolean);
      return el('span', { class: notes.length ? 'pp-hover' : null, title: notes.join(', ') || null, text: use.area });
    });
    if (uses.length) rows.push(['AI used for', null, el('span', {}, uses.flatMap((u, i) => [i ? ', ' : null, u]))]);
    if ((aiUse.tools || []).length) rows.push(['AI tools', aiUse.tools.join(', ')]);
  }
  if ((extras.supportLinks || []).length) {
    rows.push(['Donate', null, el('span', { class: 'pp-support' }, extras.supportLinks.flatMap((s, i) => [
      i ? ', ' : null,
      outLink(s.url, s.label || s.type || 'Donate', { title: s.url }),
    ]))]);
  }
  if (rows.length) {
    box.append(subhead('Details'), fieldList(rows));
  }

  const changelog = extras.changelog;
  const entries = (changelog && changelog.entries) || {};
  const hasChangelog = !!(changelog && (changelog.link || Object.keys(entries).length));
  if (hasChangelog) {
    box.append(subhead('Version history'));
    if (changelog.link) box.append(el('p', {}, [outLink(changelog.link, 'View version history', { title: changelog.link })]));
    for (const [version, text] of Object.entries(entries)) {
      box.append(fold(version, el('pre', { class: 'pp-pre', text })));
    }
  }

  if (!hasSummary && !rows.length && !hasChangelog) {
    box.append(subhead('Details'), emptyLine('No details found.'));
  }
  return box;
}

/// The info button beside "LLM results": which model and endpoint wrote the
/// answer, and the prompt version when it is known. Older answers may not say.
export function llmDetails(llm, promptVersion = null) {
  return infoButton('LLM details', 'LLM details', () => [fieldList([
    ['Model', llm.model || 'Not recorded'],
    ['Endpoint', llm.endpoint || 'Not recorded'],
    ['Prompt version', promptVersion],
  ])]);
}

// --- Jobs ---

/// Starts a job after its confirm dialog, then opens its run.
async function start(request) {
  const record = await confirmAndStart(request);
  if (record && record.id) location.hash = `#/runs/${encodeURIComponent(record.id)}`;
}

/// The job buttons for one forum topic. Drawn only when the manager is on.
export function topicJobButtons(topicId) {
  const job = (text, kind) => el('button', {
    type: 'button',
    class: 'button',
    text,
    onclick: () => start({ kind, topicIds: [topicId], runLlm: true }),
  });
  return [
    job('Re-scrape', 'rescrapeTopics'),
    job('Re-run LLM', 'extractLlm'),
    job('Recheck downloads', 'resolveDownloads'),
    job('Scan images', 'describePictures'),
  ];
}

/// The job button for one Discord thread. Drawn only when the manager is on.
export function discordJobButtons(threadId) {
  return [el('button', {
    type: 'button',
    class: 'button',
    text: 'Re-run LLM',
    onclick: () => start({ kind: 'extractLlm', discordThreadIds: [threadId], runLlm: true }),
  })];
}

/// The button that rebuilds every output, wherever unpublished changes are
/// pointed out.
export function rebuildButton() {
  return el('button', {
    type: 'button',
    class: 'button primary',
    text: 'Rebuild from saved',
    title: 'Include the saved changes in the build.',
    onclick: () => start(rebuildRequest()),
  });
}

// --- Is the published mod details file behind? ---

/// Whether the published mod details reflect this topic's saved data:
///   noBundle — nothing published yet
///   absent   — published, but this topic is not in it
///   stale    — this topic was scraped after the mod details were built
///   current  — up to date for this topic
export function bundleStaleness({ index, detail, builtAt, inBundle, hasBundle }) {
  if (!hasBundle) return { state: 'noBundle' };
  if (!inBundle) return { state: 'absent' };
  const builtMs = new Date(builtAt).getTime();
  const scraped = [index.scrapedAt, detail && detail.scrapedAt]
    .filter(Boolean)
    .map((s) => new Date(s).getTime())
    .filter((n) => !Number.isNaN(n));
  const newest = scraped.length ? Math.max(...scraped) : 0;
  if (newest && !Number.isNaN(builtMs) && newest > builtMs) {
    return { state: 'stale', scrapedAt: new Date(newest).toISOString(), builtAt };
  }
  return { state: 'current' };
}

/// Compares a topic's saved data with the published mod details.
export async function topicStaleness(topicId, index, detail) {
  const [meta, presence] = await Promise.all([
    api('bundle/meta').catch(() => null),
    api('bundle/mods', { q: String(topicId), pageSize: 500 }).catch(() => null),
  ]);
  const inBundle = !!(presence && (presence.items || [])
    .some((r) => String((r.index || {}).topicId) === String(topicId)));
  const builtAt = (meta && meta.meta) ? meta.meta.generatedAt : null;
  return bundleStaleness({ index: index || {}, detail, builtAt, inBundle, hasBundle: !!builtAt });
}

/// The warning shown when the published mod details are behind this topic's
/// saved data, or null when they are up to date. The times and what to do
/// are behind its info button.
export function stalenessBanner(staleness, managerOn) {
  if (!staleness || staleness.state === 'current') return null;
  let heading;
  let details;
  switch (staleness.state) {
    case 'stale':
      heading = 'Mod details are out of date.';
      details = [fieldList([
        ['Last scraped', when(staleness.scrapedAt)],
        ['Last build', when(staleness.builtAt)],
      ])];
      break;
    case 'absent':
      heading = 'Not included in built details.';
      details = [el('p', { text: 'This page shows saved data. “Rebuild from saved” updates the output files.' })];
      break;
    default: // noBundle
      heading = 'No build yet.';
      details = [el('p', { text: 'This page shows saved data. “Rebuild from saved” creates the output files.' })];
  }
  return el('div', { class: 'pp-banner' }, [
    el('div', { class: 'pp-banner-text' }, [el('strong', { text: heading }), infoButton('Build details', 'Build details', details)]),
    managerOn ? rebuildButton() : null,
  ]);
}
