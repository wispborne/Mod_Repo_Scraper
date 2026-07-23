// #/bundle — forum-data-bundle.json browser (4.4) + TriOS-style card preview (4.5).
//   #/bundle              bundle meta + searchable, paged entries
//   #/bundle/<index>      one bundle entry, with a labeled card approximation
//   #/bundle/changes      what changed between two saved bundles

import { api, el, clear, missingPanel, MissingFile, pager, pageSizePreference, go } from '../lib.js';
import * as manager from '../manager.js';
import { changesPage } from './bundle_compare.js';
import {
  postFrame, imageList, linkList, fieldList, fold, assumedTable, llmModsBlock,
  downloadRowFromBundle, downloadRowFromCandidate, normUrl, topicActionBar,
} from './extraction_views.js';

const state = { q: '', page: 0, pageSize: pageSizePreference() };

export async function render(root, parts) {
  clear(root);
  if (parts.length && parts[0] !== 'changes') return entry(root, parts[0]);

  root.append(el('h1', { text: 'Forum Data Bundle (what TriOS receives)' }));
  root.append(subnav(parts));

  if (parts[0] === 'changes') return changesPage(root);

  const meta = await api('bundle/meta');
  if (meta instanceof MissingFile) return root.append(missingPanel(meta));
  if (meta.meta) {
    const m = meta.meta;
    root.append(el('div', { class: 'stat-grid' }, [
      stat('Updated at', meta.updatedAt || '—'),
      stat('Total mods', m.totalMods ?? '—'),
      stat('Total details', m.totalDetails ?? '—'),
      stat('Assumed dl entries', m.totalAssumedDownloadEntries ?? '—'),
      stat('Placeholders', m.placeholderDetailCount ?? '—'),
    ]));
  }

  const toolbar = el('div', { class: 'toolbar' });
  const search = el('input', { type: 'search', placeholder: 'Search title, author or thread id…', value: state.q });
  let d;
  search.addEventListener('input', () => {
    clearTimeout(d);
    d = setTimeout(() => { state.q = search.value.trim(); state.page = 0; load(); }, 250);
  });
  toolbar.append(search);
  root.append(toolbar);
  const results = el('div', {});
  root.append(results);

  async function load() {
    clear(results).append(el('div', { class: 'loading', text: 'Loading…' }));
    const data = await api('bundle/mods', { q: state.q, page: state.page, pageSize: state.pageSize });
    clear(results);
    if (data instanceof MissingFile) return results.append(missingPanel(data));

    const wrap = el('div', { class: 'table-wrapper' });
    const table = el('table');
    table.append(el('thead', {}, el('tr', {}, [
      el('th', { text: 'Title' }), el('th', { text: 'Author' }),
      el('th', { text: 'Game ver' }), el('th', { text: 'Detail?' }),
      el('th', { text: 'Assumed dl' }),
    ])));
    const tb = el('tbody');
    for (const row of data.items) {
      const idx = row.index || {};
      const dl = (row.assumedDownloads || []).length;
      tb.append(el('tr', { class: 'clickable', onclick: () => go(`#/bundle/${idx.topicId}`) }, [
        el('td', { text: idx.title || '(empty)' }),
        el('td', { text: idx.author || '' }),
        el('td', { text: idx.gameVersion || '—' }),
        el('td', { text: row.detail ? 'yes' : 'no' }),
        el('td', { class: 'num', text: String(dl) }),
      ]));
    }
    table.append(tb);
    wrap.append(table);
    results.append(wrap);
    if (!data.items.length) results.append(el('p', { class: 'loading', text: 'No entries match.' }));
    results.append(pager(data.page, data.pageSize, data.total,
      (p) => { state.page = p; load(); },
      (size) => { state.pageSize = size; state.page = 0; load(); }));
  }
  load();
}

/// Two pages: the bundle as published, and what changed since last time.
function subnav(parts) {
  const on = parts[0] === 'changes' ? 'changes' : 'browse';
  const tab = (label, hash, active) =>
    el('a', { class: 'chip' + (active ? ' on' : ''), href: hash, text: label });
  return el('div', { class: 'toolbar' }, [
    tab('Browse', '#/bundle', on === 'browse'),
    tab('Diff Viewer', '#/bundle/changes', on === 'changes'),
  ]);
}

async function entry(root, topicId) {
  root.append(el('a', { class: 'back-link', href: '#/bundle', text: '‹ Back to bundle' }));
  // Search by the topic's own id rather than pulling the whole bundle down —
  // the search matches ids too, so this is a handful of rows at most.
  const data = await api('bundle/mods', { q: String(topicId), pageSize: 500 });
  if (data instanceof MissingFile) return root.append(missingPanel(data));

  // Job buttons only exist when there is a manager to send jobs to.
  const status = manager.status() || await manager.refresh();
  const managerOn = !!(status && status.on);

  const match = (data.items || []).find((r) => String((r.index || {}).topicId) === String(topicId));
  if (match) {
    const idx = match.index || {};
    return renderEntry(root, {
      index: idx,
      detail: match.detail,
      // The bundle's own download shape, which names its fields differently
      // from the resolver's.
      downloads: (match.assumedDownloads || []).map(downloadRowFromBundle),
      // In both places the LLM output is a mods list on the topic's `llm` field.
      llm: match.llm || idx.llm,
      fromBundle: true,
      topicId: Number(topicId),
      managerOn,
    });
  }

  // Not in the published bundle — fall back to what is on disk for this topic,
  // so the page still shows something, and say so.
  const td = await api(`topics/${encodeURIComponent(topicId)}`);
  if (td && !(td instanceof MissingFile) && !td.error) {
    return renderEntry(root, {
      index: td.index || {},
      detail: td.detail,
      downloads: (td.assumedDownloads || []).map(downloadRowFromCandidate),
      llm: td.llm,
      fromBundle: false,
      topicId: Number(topicId),
      managerOn,
    });
  }
  root.append(el('p', { class: 'loading', text: 'Entry not found in the bundle.' }));
}

// The card preview shows the main mod's summary. Prefer the mod tagged `main`,
// else the first mod. Returns that mod's extras, or null when there is no LLM
// output.
function primaryExtras(llm) {
  const mods = (llm && llm.mods) || [];
  if (!mods.length) return null;
  const main = mods.find((m) => m.role === 'main') || mods[0];
  return main.extras || null;
}

// Everything the bundle holds for one mod, in two rows: the plain fields
// beside the card preview, then the post beside what was pulled out of it —
// the same post/extraction split the topic inspector uses. Nothing in the
// entry is left out — this page is how you check what TriOS actually receives.
function renderEntry(root, entry) {
  const { index: idx, detail, downloads, llm, fromBundle, topicId, managerOn } = entry;
  const mods = (llm && llm.mods) || [];

  root.append(el('h1', { text: idx.title || `Topic ${topicId}` }));

  const links = el('div', { class: 'toolbar' });
  if (idx.topicUrl) {
    links.append(el('a', { class: 'chip', href: idx.topicUrl, target: '_blank', text: 'Open on the forum ↗' }));
  }
  links.append(el('a', { class: 'chip', href: `#/topics/${topicId}`, text: 'Topic inspector' }));
  root.append(links);

  // The same three per-topic jobs the topic inspector offers, when there is a
  // manager to send them to. A finished job republishes the bundle, so this
  // page shows the new answer after a reload.
  if (managerOn) root.append(topicActionBar(topicId));

  if (!fromBundle) {
    root.append(el('div', { class: 'approx-label', text: 'This topic is not in the published bundle — showing what is saved on disk for it instead.' }));
  }

  // Top row: every plain field, beside the card preview.
  const top = el('div', { class: 'split-side' });

  const fields = el('div', { class: 'panel' });
  fields.append(el('h2', { text: 'Bundle fields' }));
  const cols = el('div', { class: 'field-cols' });

  const thumb = thumbUrl(idx.thumbnailPath);
  const threadCol = el('div', {});
  threadCol.append(el('h3', { text: 'Thread' }));
  threadCol.append(fieldList([
    ['Topic id', idx.topicId],
    ['Author', idx.author],
    ['Game version', idx.gameVersion],
    ['Category', idx.category],
    ['Replies', idx.replies],
    ['Views', idx.views],
    ['Created', idx.createdDate],
    ['Last post', idx.lastPostDate],
    ['Last post by', idx.lastPostBy],
    ['In the mod index', idx.inModIndex == null ? null : (idx.inModIndex ? 'yes' : 'no')],
    ['Archived mod index', idx.isArchivedModIndex ? 'yes' : null],
    ['Work in progress', idx.isWip ? 'yes' : null],
    ['Source board', idx.sourceBoard],
    ['Scraped at', stamp(idx.scrapedAt)],
    ['Thumbnail', thumb, thumb
      ? el('a', { href: thumb, target: '_blank', text: thumb }) : null],
  ]));

  const postCol = el('div', {});
  postCol.append(el('h3', { text: 'First post' }));
  if (detail) {
    // Skip what just repeats the thread column — only post-only fields, and
    // shared ones when the post disagrees with the thread.
    const differs = (v, threadValue) => (v && v !== threadValue ? v : null);
    postCol.append(fieldList([
      ['Title', differs(detail.title, idx.title)],
      ['Author', differs(detail.author, idx.author)],
      ['Game version', differs(detail.gameVersion, idx.gameVersion)],
      ['Category', differs(detail.category, idx.category)],
      ['Author title', detail.authorTitle],
      ['Author post count', detail.authorPostCount],
      ['Author avatar', detail.authorAvatarPath],
      ['Posted', detail.postDate],
      ['Last edited', detail.lastEditDate],
      ['Placeholder only', detail.isPlaceholderDetail ? 'yes' : null],
      ['Scraped at', stamp(detail.scrapedAt)],
    ]));
  } else {
    postCol.append(el('p', { class: 'loading', text: 'No post saved for this thread.' }));
  }

  cols.append(threadCol, postCol);
  fields.append(cols);

  const cardCol = el('div', {});
  cardCol.append(el('h2', { style: 'margin-top:0', text: 'TriOS card' }));
  cardCol.append(el('div', { class: 'approx-label', text: 'An approximation — TriOS is the source of truth for how mods display.' }));
  cardCol.append(card(idx, detail, downloads, primaryExtras(llm)));

  top.append(fields, cardCol);
  root.append(top);

  // Bottom row: the post itself, beside what was pulled out of it.
  const bottom = el('div', { class: 'split' });

  const post = el('div', { class: 'panel' });
  post.append(el('h2', { text: 'Post' }));
  if (detail && detail.contentHtml) {
    post.append(postFrame(detail.contentHtml));
  } else {
    post.append(el('p', { class: 'loading', text: 'No post text in the bundle for this thread.' }));
  }
  if (detail && (detail.images || []).length) {
    post.append(fold(`Images (${detail.images.length})`, imageList(detail.images)));
  }
  if (detail && (detail.links || []).length) {
    post.append(fold(`Links (${detail.links.length})`, linkList(detail.links)));
  }

  const found = el('div', { class: 'panel' });
  found.append(el('h2', { text: 'Pulled out of the post' }));

  // A download the LLM lists whose post URL is not in the rule-based list is
  // one the rules missed — set apart in the table.
  const ruleUrls = new Set(downloads.map((d) => normUrl(d.url)));
  if (mods.length) {
    found.append(el('h3', { text: `Mods the LLM found (${mods.length})` }));
    found.append(llmModsBlock(mods, ruleUrls));
  } else {
    found.append(el('h3', { text: 'Mods the LLM found' }));
    found.append(el('p', { class: 'loading', text: 'No LLM results in the bundle for this thread.' }));
  }

  found.append(el('h3', { text: `Rule-based downloads (${downloads.length})` }));
  found.append(assumedTable(downloads));

  bottom.append(post, found);
  root.append(bottom);
}

// Timestamps arrive as ISO strings; drop the noise for reading.
function stamp(value) {
  if (!value) return null;
  return String(value).replace('T', ' ').replace(/(\.\d+)?Z$/, ' UTC');
}

// D9: thumbnail (strip ext:, Imgur→i.imgur), title, author, game-version chip, views/replies,
// the LLM summary (what TriOS shows), one download button per
// high/medium-confidence download. Falls back to a ~200-char post excerpt only
// when no summary was generated.
function card(idx, detail, downloads, extras) {
  const wrap = el('div', { class: 'card-wrap' });
  const card = el('div', { class: 'mod-card' });

  const thumb = thumbUrl(idx.thumbnailPath);
  // No-referrer so image hosts with hotlink protection (Imgur, in particular)
  // serve the file instead of answering 403 when it's embedded in this page.
  if (thumb) {
    card.append(el('img', {
      class: 'thumb', src: thumb, alt: idx.title || '', referrerpolicy: 'no-referrer',
    }));
  }

  const body = el('div', { class: 'body' });
  body.append(el('div', { class: 'title', text: idx.title || '(untitled)' }));
  body.append(el('div', { class: 'author', text: `by ${idx.author || 'unknown'}` }));

  const chips = el('div', { class: 'meta-chips' });
  if (idx.gameVersion) chips.append(el('span', { class: 'badge badge-primary', text: idx.gameVersion }));
  chips.append(el('span', { class: 'badge badge-dim', text: `${idx.views ?? 0} views` }));
  chips.append(el('span', { class: 'badge badge-dim', text: `${idx.replies ?? 0} replies` }));
  body.append(chips);

  // TriOS shows the generated summary, so the card does too. Prefer the fuller
  // paragraph, then the one-sentence form; only if there is no summary do we
  // fall back to a trimmed slice of the raw post.
  const summary = (extras && extras.summary) || {};
  const summaryText = summary.paragraph || summary.sentence;
  if (summaryText) {
    body.append(el('div', { class: 'excerpt', text: summaryText }));
  } else {
    const excerpt = plainExcerpt(detail && detail.contentHtml, 200);
    if (excerpt) body.append(el('div', { class: 'excerpt excerpt-fallback', text: excerpt }));
  }

  for (const d of downloads) {
    if (d.confidence !== 'high' && d.confidence !== 'medium') continue;
    body.append(el('a', {
      class: 'dl', href: d.directUrl || d.url, target: '_blank',
      text: `Download${d.fileName ? ' · ' + d.fileName : ''}`,
    }));
  }

  card.append(body);
  wrap.append(card);
  return wrap;
}

// Turns a stored thumbnail into a URL an <img> can actually load: drops the
// `ext:` marker, then rewrites Imgur page links to their direct-image form.
function thumbUrl(path) {
  return imgurDirect(stripExt(path));
}

function stripExt(path) {
  if (!path) return null;
  return path.startsWith('ext:') ? path.slice(4) : path;
}

// `imgur.com/<id>` (and `.png`/`m.imgur.com` variants) is an HTML page, not the
// image — the file itself lives on `i.imgur.com`. Rewrite those to the direct
// link, adding `.png` when the link has no extension. Album (`/a/…`) and
// gallery (`/gallery/…`) links have no single image, so they pass through.
function imgurDirect(url) {
  if (!url) return url;
  const m = url.match(/^https?:\/\/(?:www\.|m\.)?imgur\.com\/([A-Za-z0-9]+)(\.[A-Za-z0-9]+)?(?:[?#].*)?$/);
  if (!m) return url;
  return `https://i.imgur.com/${m[1]}${m[2] || '.png'}`;
}

function plainExcerpt(html, max) {
  if (!html) return '';
  const tmp = document.createElement('div');
  tmp.innerHTML = html;
  const text = (tmp.textContent || '').replace(/\s+/g, ' ').trim();
  return text.length > max ? text.slice(0, max) + '…' : text;
}

function stat(label, value) {
  return el('div', { class: 'stat-card' }, [
    el('div', { class: 'label', text: label }),
    el('div', { class: 'value', text: String(value) }),
  ]);
}
