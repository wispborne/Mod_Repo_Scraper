// Shared parts of the source post page and the topic history page: the
// sandboxed post frame, picture and link lists, download tables, the LLM's
// mods with their downloads and extras, the per-post job buttons, and the
// check for whether the published mod details are behind the saved data.
// Ported from the old viewer's web/views/extraction_views.js.

import { el, api } from './lib.js';
import { confirmAndStart } from './actions.js';
import { rebuildRequest } from './jobs.js';

// --- Small shapes ---

/// A small outlined label. `tone` is '', 'good', 'warn', 'bad' or 'strong'.
export function badge(text, tone = '') {
  return el('span', { class: `pp-badge${tone ? ` ${tone}` : ''}`, text });
}

/// A section of the page: a heading bar, then its contents.
export function section(title, count, children) {
  return el('section', { class: 'pp-section' }, [
    el('h3', { class: 'pp-section-head' }, [
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

/// A link that opens in a new tab, marked as leaving the viewer.
export function outLink(href, text) {
  return el('a', { href, target: '_blank', rel: 'noopener', text });
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

/// An ISO time for reading, in the reader's own time zone.
export function when(iso) {
  if (!iso) return null;
  const at = new Date(iso);
  return Number.isNaN(at.getTime()) ? String(iso) : at.toLocaleString();
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
      ? badge('download', 'good')
      : badge(link.isExternal ? 'external' : 'internal'),
    outLink(link.url, link.text || link.url),
  ])));
}

// --- Pictures ---

const FIT_BADGES = {
  good: ['good', 'Good for a mod card'],
  okay: ['warn', 'Okay for a mod card'],
  poor: ['bad', 'Poor for a mod card'],
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

/// What was saved about one picture: its kind, card fit and description, or
/// why it could not be read, then which model looked, where, when and with
/// which version of the caption prompt.
function pictureSeen(seen) {
  const box = el('div', { class: 'pp-seen' });
  if (seen.caption) {
    const [tone, fitText] = FIT_BADGES[seen.fit]
      || ['', seen.fit ? `For a mod card: ${seen.fit}` : 'Card picture rating not saved'];
    box.append(el('div', { class: 'pp-seen-line' }, [
      badge(seen.kind || 'other', 'strong'), badge(fitText, tone), seen.caption,
    ]));
  } else if (seen.unreadable) {
    box.append(el('div', { class: 'pp-seen-line' }, [
      badge('Could not read', 'bad'),
      `The model's server could not read this picture: ${seen.unreadable}`,
    ]));
  }
  const facts = [];
  if (seen.model) facts.push(seen.model);
  if (seen.endpoint) facts.push(seen.endpoint);
  if (seen.at) facts.push(new Date(seen.at).toLocaleString());
  if (seen.v != null) {
    facts.push(seen.current === false ? `caption prompt v${seen.v} (outdated)` : `caption prompt v${seen.v}`);
  }
  if (facts.length) box.append(el('div', { class: 'pp-seen-facts', text: facts.join(' · ') }));
  return box;
}

/// The pictures in one post, each with everything saved about what the model
/// saw in it. `captions` is keyed by the picture's address. Each picture is
/// `{ originalUrl, alt }`.
export function imageList(images, captions = {}) {
  return el('ul', { class: 'pp-pictures' }, images.map((img) => {
    const text = el('div', { class: 'pp-picture-text' }, [
      img.alt ? el('div', { class: 'pp-picture-alt', text: img.alt }) : null,
      el('a', { class: 'pp-url', href: img.originalUrl, target: '_blank', rel: 'noopener', text: img.originalUrl }),
    ]);
    if (discordLinkExpired(img.originalUrl)) {
      text.append(el('div', {
        class: 'pp-seen warn-text',
        text: 'This Discord address has expired. Fetch Discord again to get a working one.',
      }));
    }
    const seen = captions[img.originalUrl];
    if (seen) text.append(pictureSeen(seen));
    return el('li', { class: 'pp-picture' }, [
      el('a', { class: 'pp-thumb-link', href: img.originalUrl, target: '_blank', rel: 'noopener' }, [
        el('img', {
          class: 'pp-thumb', src: img.originalUrl, alt: img.alt || '',
          loading: 'lazy', referrerpolicy: 'no-referrer',
        }),
      ]),
      text,
    ]);
  }));
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

/// Shortens a URL in the middle, keeping the host and file name visible.
function shortUrl(u, max = 52) {
  const s = String(u || '');
  if (s.length <= max) return s;
  return `${s.slice(0, max - 16)}…${s.slice(-14)}`;
}

/// A shortened URL; the link and its hover text keep the full address.
function urlLink(display, href) {
  return el('a', { class: 'pp-url', href, target: '_blank', rel: 'noopener', title: href, text: display });
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

/// The rule-based downloads, in the plain shape above.
export function assumedTable(rows) {
  if (!rows.length) return emptyLine('No downloads found by rules.');
  return table(
    ['Confidence', 'Host', 'File name', 'Extra step required', 'Link text', 'Source URL'],
    rows.map((r) => {
      const url = r.url || r.directUrl || '';
      return el('tr', {}, [
        confidenceCell(r.confidence),
        el('td', { text: r.host || '—' }),
        el('td', {}, [clampCell(r.fileName)]),
        el('td', { text: r.requiresManualStep ? 'yes' : '' }),
        el('td', {}, [clampCell(r.linkText)]),
        el('td', {}, [url ? urlLink(shortUrl(url), r.directUrl || r.url) : '—']),
      ]);
    }),
  );
}

/// One mod's downloads as the LLM listed them. A download whose address is
/// not in `ruleUrls` is one the rules missed, and is marked as found by the LLM.
export function llmDownloadsTable(downloads, ruleUrls) {
  if (!downloads.length) return emptyLine('No downloads listed for this mod.');
  return table(
    ['Kind', 'Found by', 'Confidence', 'Host', 'File name', 'Extra step required', 'URL'],
    downloads.map((d) => {
      const rulesMissed = !ruleUrls.has(normUrl(d.url));
      const display = d.label ? `${d.label} — ${shortUrl(d.url)}` : shortUrl(d.url);
      return el('tr', { class: rulesMissed ? 'pp-llm-only' : '' }, [
        el('td', {}, [badge(d.kind || 'direct', d.kind === 'trios' ? 'strong' : '')]),
        el('td', {}, [rulesMissed ? badge('LLM', 'strong') : badge('Rules')]),
        confidenceCell(d.confidence),
        el('td', { text: d.sourceHost || '—' }),
        el('td', {}, [clampCell(d.fileName)]),
        el('td', { text: d.requiresManualStep ? 'yes' : '' }),
        el('td', {}, [d.url ? urlLink(display, d.resolvedDirectUrl || d.url) : '—']),
      ]);
    }),
  );
}

// --- The LLM's mods ---

function roleBadge(role) {
  return badge(role || 'main', (role || 'main') === 'main' ? 'strong' : '');
}

/// Every mod the LLM found, each with its downloads and extras.
export function llmModsBlock(mods, ruleUrls) {
  return el('div', { class: 'pp-mods' }, mods.map((mod) => modCard(mod, ruleUrls)));
}

function modCard(mod, ruleUrls) {
  const card = el('article', { class: 'pp-mod' });
  card.append(el('div', { class: 'pp-mod-head' }, [
    el('span', { class: 'pp-mod-name', text: mod.name || '(unnamed mod)' }),
    roleBadge(mod.role),
    mod.isTool ? badge('tool') : null,
    mod.requires ? el('span', { class: 'dim', text: `requires ${mod.requires}` }) : null,
  ]));
  // Other names the post uses for the mod; the public site's search matches on them.
  if ((mod.nicknames || []).length) {
    card.append(fieldList([['Also called', mod.nicknames.join(', ')]]));
  }
  if (mod.image) {
    // Stored as `ext:<url>`, like the thread thumbnail.
    const src = String(mod.image).replace(/^ext:/, '');
    card.append(el('img', {
      class: 'pp-mod-image', src, alt: mod.name || 'mod image', loading: 'lazy', referrerpolicy: 'no-referrer',
    }));
  }
  card.append(llmDownloadsTable(mod.downloads || [], ruleUrls));
  if (mod.extras) card.append(extrasBlock(mod.extras));
  // The site builder uses these to cut the author's text out of a shared thread.
  const anchors = mod.descriptionAnchors;
  if (anchors && anchors.startsWith && anchors.endsWith) {
    card.append(fieldList([
      ['Description starts with', `"${anchors.startsWith}"`],
      ['Description ends with', `"${anchors.endsWith}"`],
    ]));
  }
  return card;
}

function extrasBlock(extras) {
  const box = el('div', { class: 'pp-extras' });

  // The model's own words, shown first.
  const summary = extras.summary;
  const hasSummary = !!(summary && (summary.sentence || summary.paragraph));
  if (hasSummary) {
    box.append(subhead('LLM summary'));
    if (summary.sentence) box.append(el('p', { class: 'pp-summary-sentence', text: summary.sentence }));
    if (summary.paragraph) box.append(el('p', { class: 'pp-summary-paragraph', text: summary.paragraph }));
  }

  // Fields copied word for word from the post.
  const rows = [];
  if (extras.version) rows.push(['Mod version', extras.version]);
  if (extras.license) rows.push(['License', extras.license]);
  if (extras.sourceCode) rows.push(['Source code', null, outLink(extras.sourceCode, extras.sourceCode)]);
  // Each save question: the short answer, then the post's own words.
  const saveRow = (label, answer, words) => {
    if (!words) return;
    const short = { yes: 'Yes', no: 'No', depends: 'Depends' }[answer];
    rows.push([label, short ? `${short} — ${words}` : words]);
  };
  saveRow('Adding to a save', extras.canAdd, extras.saveCompatibility);
  // One row per update note, each naming the release it was written for.
  for (const note of extras.updateNotes || []) {
    saveRow(note.version ? `Updating to ${note.version}` : 'Updating', note.answer, note.quote);
  }
  saveRow('Removing from a save', extras.canRemove, extras.removalCompatibility);
  if ((extras.needs || []).length) rows.push(['Needs', extras.needs.join(', ')]);
  if ((extras.optionalNeeds || []).length) rows.push(['Optional', extras.optionalNeeds.join(', ')]);
  if ((extras.conflicts || []).length) {
    rows.push(['Conflicts', extras.conflicts
      .map((c) => `${c.name}${c.kind ? ` (${c.kind})` : ''}: “${c.quote}”`)
      .join(' · ')]);
  }
  // No aiUse at all means the post was read before the prompt asked, so the
  // row is left out; an aiUse with no answer means it was read and says nothing.
  const aiUse = extras.aiUse;
  if (aiUse && aiUse.usesAi == null) {
    rows.push(['AI use', 'Not stated in the post']);
  } else if (aiUse) {
    rows.push(['AI use', `${aiUse.usesAi ? 'Yes' : 'No'} — ${aiUse.quote}`]);
    const uses = (aiUse.uses || []).map((use) => {
      const notes = [use.how, use.extent, use.optional ? 'optional' : null].filter(Boolean);
      return notes.length ? `${use.area} (${notes.join(', ')})` : use.area;
    });
    if (uses.length) rows.push(['AI used for', uses.join(' · ')]);
    if ((aiUse.tools || []).length) rows.push(['AI tools named', aiUse.tools.join(', ')]);
  }
  if ((extras.supportLinks || []).length) {
    rows.push(['Support links', null, el('div', { class: 'pp-support' }, extras.supportLinks.map((s) => (
      el('div', { class: 'pp-support-link' }, [
        badge(s.type || 'other'),
        s.label ? el('span', { text: s.label }) : null,
        el('a', { class: 'pp-url', href: s.url, target: '_blank', rel: 'noopener', text: s.url }),
      ])
    )))]);
  }
  if (rows.length) {
    box.append(subhead('Extracted details'), fieldList(rows));
  }

  const changelog = extras.changelog;
  const entries = (changelog && changelog.entries) || {};
  const hasChangelog = !!(changelog && (changelog.link || Object.keys(entries).length));
  if (hasChangelog) {
    box.append(subhead('Changelog'));
    if (changelog.link) box.append(el('p', {}, [outLink(changelog.link, changelog.link)]));
    for (const [version, text] of Object.entries(entries)) {
      box.append(fold(version, el('pre', { class: 'pp-pre', text })));
    }
  }

  if (!hasSummary && !rows.length && !hasChangelog) {
    box.append(subhead('Extracted details'), emptyLine('No additional details found.'));
  }
  return box;
}

/// Which model and endpoint wrote an LLM answer. Older answers may not say.
export function llmSourceLine(llm) {
  let text;
  if (llm.model && llm.endpoint) text = `Model: ${llm.model} · Endpoint: ${llm.endpoint}`;
  else if (llm.model) text = `Model: ${llm.model}`;
  else if (llm.endpoint) text = `Endpoint: ${llm.endpoint}`;
  else text = 'Model and endpoint not recorded.';
  return el('p', { class: 'pp-source-line', text });
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
/// saved data, or null when they are up to date.
export function stalenessBanner(staleness, managerOn) {
  if (!staleness || staleness.state === 'current') return null;
  let heading;
  let detail;
  switch (staleness.state) {
    case 'stale':
      heading = 'Mod details are out of date.';
      detail = `Thread scraped ${when(staleness.scrapedAt)}; details built ${when(staleness.builtAt)}. `
        + 'Rebuild from saved to include these changes.';
      break;
    case 'absent':
      heading = 'This thread is not in the built mod details.';
      detail = 'This page shows locally saved data. Rebuild from saved to update the output files.';
      break;
    default: // noBundle
      heading = 'Mod details have not been built yet.';
      detail = 'This page shows locally saved data. Rebuild from saved to create the output files.';
  }
  return el('div', { class: 'pp-banner' }, [
    el('div', { class: 'pp-banner-text' }, [el('strong', { text: heading }), el('span', { text: detail })]),
    managerOn ? rebuildButton() : null,
  ]);
}
