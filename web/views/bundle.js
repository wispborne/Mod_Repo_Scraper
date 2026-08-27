// #/bundle — forum-data-bundle.json browser (4.4) + TriOS-style card preview (4.5).
//   #/bundle              bundle meta + searchable, paged entries
//   #/bundle/<index>      one bundle entry, with a labeled card approximation
//   #/bundle/changes      what changed between two saved bundles

import {
  api, el, clear, missingPanel, MissingFile, pager, pageSizePreference, go,
  rawJson, hashQuery, buildHash, replaceHash, breadcrumbs,
} from '../lib.js';
import * as manager from '../manager.js';
import { changesPage } from './bundle_compare.js';
import { render as renderHistory } from './topic_history.js';
import {
  postFrame, imageList, linkList, fieldList, fold, assumedTable, llmModsBlock,
  downloadRowFromCandidate, normUrl, topicActionBar, topicStaleness,
  rebuildBundleButton,
} from './extraction_views.js';

const state = { q: '', page: 0, pageSize: pageSizePreference() };

export async function render(root, parts) {
  clear(root);

  // The diff page lives in the sidebar as "Bundle diff".
  if (parts[0] === 'changes') {
    root.append(breadcrumbs([{ label: 'Bundle diff' }]));
    root.append(el('h1', { text: 'Bundle diff' }));
    return changesPage(root);
  }
  if (parts[1] === 'history') {
    return renderHistory(root, parts[0], {
      parent: { label: 'Forum Data Bundle', href: '#/bundle' },
    });
  }
  if (parts.length) return entry(root, parts[0]);

  root.append(breadcrumbs([{ label: 'Forum Data Bundle' }]));
  root.append(el('h1', { text: 'Forum Data Bundle (what TriOS receives)' }));

  // Search and page ride in the URL, so a reload or the back button brings the
  // same list back.
  const query = hashQuery();
  state.q = (query.get('q') || '').trim();
  state.page = Math.max(0, parseInt(query.get('page'), 10) || 0);
  state.pageSize = pageSizePreference();

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

  function syncUrl() {
    replaceHash(buildHash(['bundle'], { q: state.q, page: state.page || '' }));
  }

  async function load() {
    syncUrl();
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

async function entry(root, topicId) {
  return renderThreadPage(root, topicId, {
    parent: { label: 'Forum Data Bundle', href: '#/bundle' },
  });
}

// The one thread page, reached from both Topics and the Forum Data Bundle. It
// shows the working (on-disk) data for the thread — the latest truth — and, when
// the published bundle is behind that, says so and offers to rebuild it.
export async function renderThreadPage(root, topicId, { parent } = {}) {
  clear(root);
  const up = parent || { label: 'Topics', href: '#/topics' };

  const data = await api(`topics/${encodeURIComponent(topicId)}`);
  if (data instanceof MissingFile) {
    root.append(breadcrumbs([up, { label: `Topic ${topicId}` }]));
    return root.append(missingPanel(data));
  }
  if (!data || data.error) {
    root.append(breadcrumbs([up, { label: `Topic ${topicId}` }]));
    root.append(el('p', {
      class: 'loading',
      text: (data && data.error) || 'No data saved for this thread.',
    }));
    return;
  }

  const title = (data.index && data.index.title) || `Topic ${topicId}`;
  root.append(breadcrumbs([up, { label: title }]));

  const status = manager.status() || await manager.refresh();
  const managerOn = !!(status && status.on);

  renderEntry(root, {
    index: data.index || {},
    detail: data.detail,
    downloads: (data.assumedDownloads || []).map(downloadRowFromCandidate),
    llm: data.llm,
    raw: data,
    topicId: Number(topicId),
    managerOn,
    staleness: await topicStaleness(topicId, data.index || {}, data.detail),
    // The history page is reached from whichever list this thread was, so the
    // trail back stays the one the reader came in on.
    historyBase: parent && parent.href === '#/bundle' ? 'bundle' : 'topics',
  });
}

/// The warning shown when the published bundle is behind this thread. Nothing is
/// drawn when the bundle is already up to date.
function stalenessBanner(staleness, managerOn) {
  if (!staleness || staleness.state === 'current') return null;

  let heading;
  let detail;
  switch (staleness.state) {
    case 'stale':
      heading = 'The published bundle is behind this thread.';
      detail = `It was scraped ${stamp(staleness.scrapedAt)}, after the Forum Data `
        + `Bundle was last built ${stamp(staleness.builtAt)}. Rebuild the bundle to `
        + 'publish these changes to TriOS.';
      break;
    case 'absent':
      heading = 'This thread is not in the published bundle yet.';
      detail = 'Its data is saved on disk but has not been published. Rebuild the '
        + 'bundle to include it.';
      break;
    default: // noBundle
      heading = 'No Forum Data Bundle has been published yet.';
      detail = 'This shows the data saved on disk. Rebuild the bundle to publish it '
        + 'to TriOS.';
  }

  const banner = el('div', { class: 'notice-banner' }, [
    el('div', { class: 'notice-text' }, [
      el('strong', { text: heading }),
      el('div', { text: detail }),
    ]),
  ]);
  if (managerOn) banner.append(rebuildBundleButton());
  return banner;
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
  const {
    index: idx, detail, downloads, llm, raw, topicId, managerOn, staleness,
    historyBase,
  } = entry;
  const mods = (llm && llm.mods) || [];

  // Everything below sits in one column with even spacing between blocks, so
  // the page doesn't need each piece to carry its own margins.
  const page = el('div', { class: 'thread' });

  page.append(el('h1', { text: idx.title || `Topic ${topicId}` }));

  // The forum link and the per-topic job buttons share one row.
  const controls = el('div', { class: 'thread-controls' });
  if (idx.topicUrl) {
    controls.append(el('a', {
      class: 'btn', href: idx.topicUrl, target: '_blank', text: 'Open on the forum ↗',
    }));
  }
  controls.append(el('a', {
    class: 'btn',
    href: `#/${historyBase || 'topics'}/${encodeURIComponent(topicId)}/history`,
    text: 'History',
    title: 'Every run that changed this thread.',
  }));
  // A finished job republishes the bundle, so this page shows the new answer
  // after a reload.
  if (managerOn) controls.append(topicActionBar(topicId));
  if (controls.children.length) page.append(controls);

  // When the published bundle is behind this thread, say so and offer to fix it.
  const banner = stalenessBanner(staleness, managerOn);
  if (banner) page.append(banner);

  // The thread and post fields, full width — this is what the page is for.
  const fields = el('div', { class: 'panel' });
  fields.append(el('h2', { text: 'Thread and post fields' }));
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
  page.append(fields);

  // The post itself, beside what was pulled out of it.
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

  // The author's own later posts. Some threads keep every download in a second
  // post, so these are read for downloads and facts the same way the first one
  // is — but they are not the thread's description, which is why they are shown
  // under it rather than joined onto it.
  for (const [i, extra] of (detail?.extraPosts || []).entries()) {
    post.append(el('h3', { text: `The author's post ${i + 2}` }));
    const when = [extra.postDate, extra.lastEditDate && `last edited ${extra.lastEditDate}`]
      .filter(Boolean).join(' · ');
    if (when) post.append(el('p', { class: 'change-note', text: when }));
    if (extra.contentHtml) post.append(postFrame(extra.contentHtml));
    if ((extra.images || []).length) {
      post.append(fold(`Images (${extra.images.length})`, imageList(extra.images)));
    }
    if ((extra.links || []).length) {
      post.append(fold(`Links (${extra.links.length})`, linkList(extra.links)));
    }
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
    // Three cases share this empty state, and they mean different things:
    // the LLM never ran (llm is null), it ran and decided this thread is not a
    // mod release (isMod false), or it ran and simply found nothing to pull out.
    let msg;
    if (!llm) {
      msg = 'The LLM has not run for this thread yet.';
    } else if (llm.isMod === false) {
      msg = 'The LLM read this thread and decided it is not a downloadable mod.';
    } else {
      msg = 'The LLM ran but found no mods to pull out of this post.';
    }
    found.append(el('p', { class: 'loading', text: msg }));
  }

  found.append(el('h3', { text: `Rule-based downloads (${downloads.length})` }));
  found.append(assumedTable(downloads));

  bottom.append(post, found);
  page.append(bottom);

  // The TriOS card preview goes last — a rough look at how TriOS would show this
  // mod, not the working data this page is really about.
  const cardPanel = el('div', { class: 'panel' });
  cardPanel.append(el('h2', { text: 'TriOS card' }));
  cardPanel.append(el('div', { class: 'approx-label', text: 'An approximation — TriOS is the source of truth for how mods display.' }));
  cardPanel.append(card(idx, detail, downloads, primaryExtras(llm)));
  page.append(cardPanel);

  // Everything the tidy layout leaves out, one click away.
  if (raw) page.append(rawJson(raw, 'Show this thread’s raw data (JSON)'));

  root.append(page);
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
