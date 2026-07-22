// #/bundle — forum-data-bundle.json browser (4.4) + TriOS-style card preview (4.5).
//   #/bundle              bundle meta + searchable, paged entries
//   #/bundle/<index>      one bundle entry, with a labeled card approximation

import { api, el, clear, missingPanel, MissingFile, pager, go } from '../lib.js';

const state = { q: '', page: 0, pageSize: 50 };

export async function render(root, parts) {
  clear(root);
  if (parts.length) return entry(root, parts[0]);

  root.append(el('h1', { text: 'Forum Data Bundle (what TriOS receives)' }));

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
    results.append(pager(data.page, data.pageSize, data.total, (p) => { state.page = p; load(); }));
  }
  load();
}

// A single bundle entry lookup reuses the searchable endpoint, filtering by the
// topic's own id so we get its joined index/detail/assumedDownloads back.
async function entry(root, topicId) {
  root.append(el('a', { class: 'back-link', href: '#/bundle', text: '‹ Back to bundle' }));
  const data = await api('bundle/mods', { q: '', pageSize: 500 });
  if (data instanceof MissingFile) return root.append(missingPanel(data));

  const match = (data.items || []).find((r) => String((r.index || {}).topicId) === String(topicId));
  if (!match) {
    // Fall back to the topic detail endpoint for the card fields. In both places
    // the LLM output is a mods list on the topic's `llm` field.
    const td = await api(`topics/${encodeURIComponent(topicId)}`);
    if (td && !td.error) {
      return renderEntry(root, td.index || {}, td.detail, td.assumedDownloads || [], primaryExtras(td.llm));
    }
    root.append(el('p', { class: 'loading', text: 'Entry not found in the bundle.' }));
    return;
  }
  renderEntry(root, match.index || {}, match.detail, match.assumedDownloads || [], primaryExtras(match.llm));
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

function renderEntry(root, idx, detail, assumed, extras) {
  root.append(el('h1', { text: idx.title || `Topic ${idx.topicId}` }));

  root.append(el('div', { class: 'approx-label', text: 'Card preview below is an approximation — TriOS is the source of truth for how mods display.' }));

  const split = el('div', { class: 'split' });

  // Left: the raw bundle fields.
  const left = el('div', { class: 'panel' });
  left.append(el('h2', { text: 'Bundle fields' }));
  const list = el('ul', { class: 'field-list' });
  for (const [label, value] of [
    ['Author', idx.author], ['Game version', idx.gameVersion], ['Category', idx.category],
    ['Replies', idx.replies], ['Views', idx.views], ['Last post', idx.lastPostDate],
    ['Thumbnail', thumbUrl(idx.thumbnailPath)], ['Has detail', detail ? 'yes' : 'no'],
    ['Assumed downloads', assumed.length],
  ]) {
    if (value == null || value === '') continue;
    list.append(el('li', {}, [el('span', { class: 'field-label', text: label }), el('span', { class: 'field-value', text: String(value) })]));
  }
  left.append(list);

  // Right: the card approximation.
  const right = el('div', {});
  right.append(el('h2', { text: 'TriOS card (approximation)' }));
  right.append(card(idx, detail, assumed, extras));

  split.append(left, right);
  root.append(split);
}

// D9: thumbnail (strip ext:, Imgur→i.imgur), title, author, game-version chip, views/replies,
// the LLM summary (what TriOS shows), one download button per
// high/medium-confidence download. Falls back to a ~200-char post excerpt only
// when no summary was generated.
function card(idx, detail, assumed, extras) {
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

  for (const c of assumed) {
    if (c.confidence !== 'high' && c.confidence !== 'medium') continue;
    body.append(el('a', {
      class: 'dl', href: c.resolvedUrl || c.sourceUrl, target: '_blank',
      text: `Download${c.archiveFilename ? ' · ' + c.archiveFilename : ''}`,
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
