// One source post: a forum topic (#/posts/topic/<id>) or a Discord thread
// (#/posts/discord/<id>). It says what the last build made of the post, then
// shows the LLM's mods, the rules' downloads, the pictures, the post itself
// in a sandboxed frame, and the raw data. The job buttons and Take down sit
// in the toolbar while the manager is on.

import { el, api, breadcrumbs, rawJson, showDialog } from '../lib.js';
import { pageLayout, sidePanel, statusMark } from '../frame.js';
import { subscribe, status } from '../status.js';
import { pendingPanel } from '../pending_view.js';
import { previewAndAdd } from './takedowns.js';
import {
  badge, section, subhead, emptyLine, outLink, fold, fieldList, when, postFrame, linkList,
  imageList, discordImage, downloadRowFromCandidate, normUrl, assumedTable, llmModsBlock,
  llmSourceLine, topicJobButtons, discordJobButtons, topicStaleness, stalenessBanner,
} from '../post_parts.js';

const KINDS = { topic: 'Forum topic', discord: 'Discord thread' };

/// The sentence the other pages use when jobs are off.
function managerOffText(s) {
  if (s && s.offline) return 'The server could not be reached. Jobs cannot be started.';
  return `${(s && s.reason) || 'Job management is disabled on this server.'} Start the viewer with a readable `
    + 'config.properties file (or specify it with --config) and omit --no-manager to enable jobs.';
}

export async function render({ content, parts, toolbar, onLeave }) {
  const kind = parts[0];
  const id = parts[1] || '';
  const crumbs = el('div');
  const main = el('div', { class: 'pp-page' }, [crumbs, emptyLine('Loading…')]);
  const offSlot = el('div');
  const factsSlot = el('div');
  content.append(pageLayout(main, [pendingPanel(), offSlot, factsSlot]));
  // True once the reader has moved to another page while this one loaded.
  const gone = () => !main.isConnected;

  const drawCrumbs = (title) => crumbs.replaceChildren(breadcrumbs([
    { label: 'Source posts', href: '#/posts' },
    { label: title },
  ]));

  if (!KINDS[kind] || !id) {
    drawCrumbs('Not found');
    main.replaceChildren(crumbs, el('p', { class: 'error-text', text: `There is no source post at #/posts/${parts.join('/')}.` }));
    return;
  }

  const key = `${kind === 'topic' ? 'forum' : 'discord'}:${id}`;
  const fallbackTitle = kind === 'topic' ? `Topic ${id}` : `Discord thread ${id}`;
  drawCrumbs(fallbackTitle);

  // Fetch the outcome, takedown preview and post at the same time.
  const outcomeLine = el('p', { class: 'pp-outcome', 'aria-live': 'polite' });
  const outcome = api('posts/outcome', { kind, id }).catch(() => null);
  const takedownMods = api('takedowns/preview', { post: key })
    .then((body) => (body && Array.isArray(body.mods) ? body.mods : []))
    .catch(() => []);

  let body;
  try {
    body = await api(kind === 'topic' ? `topics/${encodeURIComponent(id)}` : `discord/${encodeURIComponent(id)}`);
  } catch {
    body = null;
  }
  if (gone()) return;

  const title = kind === 'topic'
    ? (body && body.index && body.index.title) || fallbackTitle
    : (body && body.thread && body.thread.name) || fallbackTitle;
  drawCrumbs(title);

  const head = el('header', { class: 'pp-head' }, [
    el('h2', { class: 'pp-title', text: title }),
    el('div', { class: 'pp-meta' }, metaChips(kind, id, body)),
    outcomeLine,
  ]);
  const links = el('div', { class: 'pp-head-links' }, headLinks(kind, id, body));
  if (links.children.length) head.append(links);

  const page = [crumbs, head];
  if (!body) {
    page.push(el('div', { class: 'pp-sections' }, [
      kind === 'topic'
        ? emptyLine('No data saved for this thread.')
        : el('div', { class: 'pp-missing' }, [
          el('p', { text: 'Could not load this Discord thread.' }),
          el('p', { class: 'dim', text: 'If it has not been saved yet, run Fetch and update with Discord selected.' }),
        ]),
    ]));
  }
  const bannerSlot = el('div');
  if (body) {
    page.push(bannerSlot);
    page.push(el('div', { class: 'pp-sections' }, kind === 'topic' ? topicSections(body) : discordSections(body)));
    factsSlot.replaceChildren(...(kind === 'topic' ? topicFacts(body) : discordFacts(body)));
    page.push(el('div', { class: 'raw-slot' }, [rawJson(body, 'Raw thread data (JSON)')]));
  }
  main.replaceChildren(...page);

  outcome.then((answer) => drawOutcome(outcomeLine, answer));

  // Job buttons and Take down, only while the manager is on. Take down is
  // added once the catalog says which mods come from this post.
  let on = null;
  let mods = [];
  const drawActions = () => {
    const buttons = [];
    if (on && body) buttons.push(...(kind === 'topic' ? topicJobButtons(Number(id)) : discordJobButtons(id)));
    if (on && mods.length) buttons.push(takeDownButton(mods));
    toolbar.actions.replaceChildren(...buttons);
    offSlot.replaceChildren(...(on ? [] : [sidePanel({
      name: 'Viewing only',
      body: el('p', { class: 'pp-side-note', text: managerOffText(status()) }),
    })]));
  };
  onLeave(subscribe((s) => {
    if (!!s.on === on) return;
    on = !!s.on;
    drawActions();
  }));
  takedownMods.then((found) => {
    if (gone() || !found.length) return;
    mods = found;
    if (on) drawActions();
  });

  if (body && kind === 'topic') {
    const staleness = await topicStaleness(id, body.index || {}, body.detail);
    if (gone()) return;
    // The warning and its Rebuild button follow the manager going on or off.
    let bannerOn = null;
    onLeave(subscribe((s) => {
      if (!!s.on === bannerOn) return;
      bannerOn = !!s.on;
      bannerSlot.replaceChildren(...[stalenessBanner(staleness, bannerOn)].filter(Boolean));
    }));
  }
}

// --- The head of the page ---

function metaChips(kind, id, body) {
  const chips = [badge(KINDS[kind], 'strong'), el('span', { class: 'chip id', text: id })];
  if (kind === 'topic' && body) {
    const idx = body.index || {};
    if (idx.author) chips.push(el('span', { class: 'pp-meta-text', text: `by ${idx.author}` }));
    if (idx.gameVersion) chips.push(el('span', { class: 'chip', text: idx.gameVersion }));
    if (body.detail && body.detail.isPlaceholderDetail) chips.push(badge('placeholder', 'warn'));
  } else if (body && body.thread && body.thread.author) {
    chips.push(el('span', { class: 'pp-meta-text', text: `by ${body.thread.author}` }));
  }
  return chips;
}

function headLinks(kind, id, body) {
  const links = [];
  if (kind === 'topic') {
    const url = body && body.index && body.index.topicUrl;
    if (url) links.push(outLink(url, 'Open on the forum ↗'));
    links.push(el('a', {
      href: `#/posts/topic/${encodeURIComponent(id)}/history`,
      text: 'History',
      title: 'Every run that changed this thread.',
    }));
  } else if (body && body.thread && body.thread.url) {
    links.push(outLink(body.thread.url, 'Open on Discord ↗'));
  }
  return links;
}

const OUTCOME_MARKS = {
  mods: 'done', collection: 'done', leftOut: 'warning', pointsTo: 'idle', takenDown: 'failed', notInBuild: 'warning',
};

/// The one line saying what the last build made of the post. The server
/// writes the line; mod names and the post it points to become links. The
/// line names at most five mods and no Collection, so a second line links the
/// Collection page and every mod the line left out. Nothing is shown when the
/// server has no answer.
function drawOutcome(node, answer) {
  if (!answer || !answer.line) return;
  const modTargets = [];
  for (const mod of answer.mods || []) {
    if (mod && mod.id) modTargets.push({ text: mod.name || mod.id, href: `#/mods/${encodeURIComponent(mod.id)}` });
  }
  const targets = [...modTargets];
  const c = answer.collection;
  const collectionTarget = c && c.id
    ? { text: c.name || c.id, href: `#/mods/${encodeURIComponent(c.id)}` } : null;
  if (collectionTarget) targets.push(collectionTarget);
  const to = answer.pointsTo;
  if (to && to.id != null) {
    const postKind = to.kind === 'discord' ? 'discord' : 'topic';
    const href = `#/posts/${postKind}/${encodeURIComponent(to.id)}`;
    targets.push({ text: `${postKind === 'topic' ? 'topic' : 'thread'} ${to.id}`, href });
    if (to.modName && to.modId) targets.push({ text: to.modName, href: `#/mods/${encodeURIComponent(to.modId)}` });
  }
  const { parts, unused } = linkedText(answer.line, targets);
  const more = [];
  if (collectionTarget && unused.includes(collectionTarget)) {
    more.push(el('span', { class: 'dim', text: 'Collection page: ' }), el('a', { href: collectionTarget.href, text: collectionTarget.text }));
  }
  if (modTargets.some((t) => unused.includes(t))) {
    if (more.length) more.push(el('span', { class: 'dim', text: ' · ' }));
    more.push(el('span', { class: 'dim', text: modTargets.length === 1 ? 'Mod: ' : 'Mods: ' }));
    modTargets.forEach((t, i) => {
      if (i) more.push(', ');
      more.push(el('a', { href: t.href, text: t.text }));
    });
  }
  // The line sits beside its mark, so the links go under it in the same box.
  node.replaceChildren(
    statusMark(OUTCOME_MARKS[answer.outcome] || 'idle'),
    el('span', {}, [
      el('span', {}, parts),
      more.length ? el('span', { class: 'pp-outcome-links', style: 'display: block' }, more) : null,
    ]),
  );
}

/// `text` with the first appearance of each target's words made a link, and
/// the targets that did not appear in it. Longer names are matched first, so
/// "Lost.Sector Extended" is not cut short by "Lost.Sector".
function linkedText(text, targets) {
  const out = [];
  let rest = String(text);
  const left = [...targets].sort((a, b) => b.text.length - a.text.length);
  for (;;) {
    let best = null;
    for (const t of left) {
      const at = rest.indexOf(t.text);
      if (at >= 0 && (!best || at < best.at)) best = { at, t };
    }
    if (!best) break;
    if (best.at) out.push(rest.slice(0, best.at));
    out.push(el('a', { href: best.t.href, text: best.t.text }));
    rest = rest.slice(best.at + best.t.text.length);
    left.splice(left.indexOf(best.t), 1);
  }
  if (rest) out.push(rest);
  return { parts: out, unused: left };
}

// --- Take down ---

/// Take down: one mod goes straight to its preview; several ask which first.
function takeDownButton(mods) {
  return el('button', {
    type: 'button',
    class: 'button danger',
    text: 'Take down',
    title: 'Leave a mod from this post out of everything we publish, at its owner\'s request.',
    onclick: async () => {
      const modId = mods.length === 1 ? mods[0].id : await pickMod(mods);
      if (modId) await previewAndAdd({ modId });
    },
  });
}

/// Asks which of the post's mods to take down. Resolves the id, or null.
function pickMod(mods) {
  return new Promise((resolve) => {
    const cancel = el('button', { type: 'button', class: 'button', text: 'Cancel' });
    const rows = mods.map((mod) => el('button', { type: 'button', class: 'pp-pick-row' }, [
      el('span', { class: 'td-row-text' }, [
        el('span', { class: 'td-row-name', text: mod.name }),
        el('code', { class: 'td-id', text: mod.id }),
      ]),
      el('span', { class: 'pp-pick-arrow', 'aria-hidden': 'true', text: '›' }),
    ]));
    const box = el('dialog', { class: 'dialog td-dialog' }, [
      el('div', { class: 'td-eyebrow', text: 'Take down a mod' }),
      el('h2', { text: 'Which mod?' }),
      el('p', { text: `The catalog lists ${mods.length} mods from this post. Choose the one to take down.` }),
      el('div', { class: 'td-rows pp-pick' }, rows),
      el('div', { class: 'dialog-buttons' }, [cancel]),
    ]);
    const shut = showDialog(box, (value) => resolve(value || null));
    rows.forEach((row, i) => row.addEventListener('click', () => shut(mods[i].id)));
    cancel.addEventListener('click', () => shut(null));
    cancel.focus();
  });
}

// --- A forum topic ---

function topicSections(data) {
  const detail = data.detail || null;
  const llm = data.llm || null;
  const downloads = (data.assumedDownloads || []).map(downloadRowFromCandidate);
  return [
    extractedSection(llm, downloads),
    picturesSection(detail, data.discordThreads || [], data.pictureCaptions || {}),
    forumPostSection(detail),
  ];
}

/// What the LLM and the download rules pulled out of the post.
function extractedSection(llm, downloads, { emptyLlm } = {}) {
  const mods = (llm && llm.mods) || [];
  // A download the LLM lists whose address the rules did not find is marked
  // as one the rules missed.
  const ruleUrls = new Set(downloads.map((d) => normUrl(d.url)));
  const children = [subhead(`Mods found by LLM${mods.length ? ` (${mods.length})` : ''}`)];
  if (mods.length) {
    children.push(llmModsBlock(mods, ruleUrls));
  } else if (!llm) {
    children.push(emptyLine(emptyLlm || 'No LLM results saved for this thread.'));
  } else if (llm.isMod === false) {
    children.push(emptyLine('The LLM classified this thread as not a downloadable mod.'));
  } else {
    children.push(emptyLine('The LLM returned no mods for this thread.'));
  }
  if (llm) children.push(llmSourceLine(llm));
  children.push(subhead(`Rule-based downloads (${downloads.length})`), assumedTable(downloads));
  return section('Extracted data', null, children);
}

/// The thread's and the first post's facts, as side panels.
function topicFacts(data) {
  const idx = data.index || {};
  const detail = data.detail || null;
  const thumb = thumbUrl(idx.thumbnailPath);
  const thread = fieldList([
    ['Topic ID', idx.topicId],
    ['Author', idx.author],
    ['Game version', idx.gameVersion],
    ['Category', idx.category],
    ['Replies', idx.replies],
    ['Views', idx.views],
    ['Created', idx.createdDate],
    ['Last post', idx.lastPostDate],
    ['Last post by', idx.lastPostBy],
    ['In mod index', idx.inModIndex == null ? null : (idx.inModIndex ? 'yes' : 'no')],
    ['Archived mod index', idx.isArchivedModIndex ? 'yes' : null],
    ['Mod index lines', (idx.indexLines || []).length
      ? idx.indexLines.map((l) => [l.name, l.author ? `by ${l.author}` : null,
        l.gameVersion ? `[${l.gameVersion}]` : null, `in ${l.category}`]
        .filter(Boolean).join(' ')).join('; ')
      : null],
    ['Work in progress', idx.isWip ? 'yes' : null],
    ['Source board', idx.sourceBoard],
    ['Scraped at', when(idx.scrapedAt)],
    ['Thumbnail', thumb, thumb ? outLink(thumb, thumb) : null],
  ]);

  let post;
  if (detail) {
    // Fields shared with the thread are shown only when the post differs.
    const differs = (v, threadValue) => (v && v !== threadValue ? v : null);
    post = fieldList([
      ['Title', differs(detail.title, idx.title)],
      ['Author', differs(detail.author, idx.author)],
      ['Game version', differs(detail.gameVersion, idx.gameVersion)],
      ['Category', differs(detail.category, idx.category)],
      ['Author title', detail.authorTitle],
      ['Author post count', detail.authorPostCount],
      ['Author avatar', detail.authorAvatarPath],
      ['Posted', detail.postDate],
      ['Last edited', detail.lastEditDate],
      ['Placeholder', detail.isPlaceholderDetail ? 'yes' : null],
      ['Scraped at', when(detail.scrapedAt)],
    ]);
  } else {
    post = emptyLine('No post saved for this thread.');
  }
  return [
    sidePanel({ name: 'Thread', body: el('div', { class: 'pp-side-body' }, [thread]) }),
    sidePanel({ name: 'First post', body: el('div', { class: 'pp-side-body' }, [post]) }),
  ];
}

/// Every picture from the author's posts and the joined Discord threads, one
/// group per post.
function picturesSection(detail, discordThreads, captions) {
  const groups = [];
  if (detail && (detail.images || []).length) {
    groups.push([subhead(`First post (${detail.images.length})`), detail.images]);
  }
  for (const [i, extra] of ((detail && detail.extraPosts) || []).entries()) {
    if ((extra.images || []).length) {
      groups.push([subhead(`Author’s post ${i + 2} (${extra.images.length})`), extra.images]);
    }
  }
  for (const thread of discordThreads) {
    const images = (thread.images || []).map(discordImage);
    groups.push([subhead('Discord thread: ', [
      el('a', { href: `#/posts/discord/${encodeURIComponent(thread.threadId)}`, text: thread.name || thread.threadId }),
      ` (${images.length})`,
    ]), images]);
  }
  const count = groups.reduce((n, [, images]) => n + images.length, 0);
  const children = [];
  if (!groups.length) children.push(emptyLine('No pictures saved for this thread.'));
  for (const [heading, images] of groups) {
    children.push(heading, images.length ? imageList(images, captions) : emptyLine('No pictures in this thread.'));
  }
  return section('Images', count, children);
}

/// The author's opening run as the forum showed it, with each post's links.
function forumPostSection(detail) {
  const children = [];
  if (detail && detail.contentHtml) children.push(postFrame(detail.contentHtml));
  else children.push(emptyLine('No post text saved for this thread.'));
  if (detail && (detail.links || []).length) {
    children.push(fold(`Links (${detail.links.length})`, linkList(detail.links)));
  }
  // Later posts by the author add downloads and facts, but not the description.
  for (const [i, extra] of ((detail && detail.extraPosts) || []).entries()) {
    children.push(subhead(`Author’s post ${i + 2}`));
    const dates = [extra.postDate, extra.lastEditDate && `last edited ${extra.lastEditDate}`]
      .filter(Boolean).join(' · ');
    if (dates) children.push(el('p', { class: 'pp-source-line', text: dates }));
    if (extra.contentHtml) children.push(postFrame(extra.contentHtml));
    if ((extra.links || []).length) {
      children.push(fold(`Links (${extra.links.length})`, linkList(extra.links)));
    }
  }
  return section('Forum post', null, children);
}

/// Turns a stored thumbnail into an address an <img> can load: drops the
/// `ext:` mark, then rewrites Imgur page links to the picture itself.
function thumbUrl(path) {
  if (!path) return null;
  const url = path.startsWith('ext:') ? path.slice(4) : path;
  // Album (`/a/…`) and gallery (`/gallery/…`) links have no single picture.
  const m = url.match(/^https?:\/\/(?:www\.|m\.)?imgur\.com\/([A-Za-z0-9]+)(\.[A-Za-z0-9]+)?(?:[?#].*)?$/);
  return m ? `https://i.imgur.com/${m[1]}${m[2] || '.png'}` : url;
}

// --- A Discord thread ---

/// The thread's facts, as a side panel.
function discordFacts(body) {
  const thread = body.thread;
  if (!thread) return [];
  const topic = String(thread.forumUrl || '').match(/[?&]topic=(\d+)/);
  return [sidePanel({ name: 'Thread', body: el('div', { class: 'pp-side-body' }, [fieldList([
    ['Thread id', body.threadId || thread.threadId],
    ['Author', thread.author],
    ['Link', thread.url, thread.url ? outLink(thread.url, thread.url) : null],
    ['Forum link', thread.forumUrl, thread.forumUrl ? outLink(thread.forumUrl, thread.forumUrl) : null],
    ['Forum topic', null, topic ? el('a', { href: `#/posts/topic/${topic[1]}`, text: `Topic ${topic[1]}` }) : null],
  ])]) })];
}

function discordSections(body) {
  const thread = body.thread || null;
  const llm = body.llm || null;
  const downloads = (body.ruleDownloads || []).map(downloadRowFromCandidate);
  const sections = [];

  const extracted = extractedSection(llm, downloads, {
    emptyLlm: 'No LLM results saved. Run LLM catch-up to extract mod details from this thread.',
  });
  if (llm) {
    // What only a Discord answer records, ahead of the mods.
    extracted.querySelector('.pp-section-body').prepend(fieldList([
      ['Is a mod release', llm.isMod ? 'yes' : 'no'],
      ['Prompt version', llm.promptVersion],
    ]));
  }
  sections.push(extracted);

  if (thread) {
    sections.push(messagesSection(thread, body.pictureCaptions || {}));
  } else {
    sections.push(section('Messages', null, [
      emptyLine('Only LLM results are available. The saved thread is missing from discord-posts.json.'),
    ]));
  }
  return sections;
}

/// The author's opening messages as the Discord scrape saved them, each with
/// its pictures and attached files.
function messagesSection(thread, captions) {
  const messages = thread.messages || [];
  const children = [];
  for (const message of messages) {
    const edited = message.editedTimestamp ? ` · edited ${String(message.editedTimestamp).slice(0, 10)}` : '';
    children.push(subhead(`${(message.timestamp || '').slice(0, 10) || 'Message'}${edited}`));
    children.push(el('pre', { class: 'pp-pre pp-message', text: message.content || '(no text)' }));
    const images = (message.images || []).map(discordImage);
    if (images.length) children.push(imageList(images, captions));
    // Files attached to the message. Their addresses stop working about a
    // day after the Discord scrape, so an old one may not open.
    const files = message.files || [];
    if (files.length) {
      children.push(el('ul', { class: 'pp-files' }, files.map((file) => el('li', {}, [
        'Attached file: ',
        outLink(file.url, file.filename || file.url),
        file.size ? ` (${Math.round(file.size / 1024)} KB)` : '',
      ]))));
    }
  }
  if (!messages.length) children.push(emptyLine('No messages saved for this thread.'));
  return section('The author’s opening messages', messages.length, children);
}
