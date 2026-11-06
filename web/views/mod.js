// One mod (#/mods/<id>), from `GET /api/mods/<id>`: the header, what
// Starmodder shows, where each fact came from, the source posts, the history
// and the raw data. A Collection's id draws the Collection page; an old id
// draws the mod it leads to with a note; a taken-down or unknown id says so.
// While the manager is on, the toolbar has the per-post jobs for all the
// mod's posts and Take down, and the page offers "These are the same person"
// and "Match this to a mod", which add pending changes.

import { el, api, breadcrumbs, rawJson, showDialog, noticeDialog } from '../lib.js';
import { pageLayout, sidePanel, statusMark } from '../frame.js';
import { icon } from '../icons.js';
import { subscribe, status } from '../status.js';
import { buildHash } from '../routes.js';
import { POST_JOBS, postJobCount, postJobRequest } from '../jobs.js';
import { confirmAndStart } from '../actions.js';
import { addPending, isPending, onPendingChange, pendingItems, removePending } from '../pending.js';
import { pendingPanel } from '../pending_view.js';
import { looseKey, openModPicker } from '../mod_picker.js';
import { previewAndAdd } from './takedowns.js';
import {
  badge, section, emptyLine, outLink, fold, fieldList, when,
} from '../post_parts.js';
import {
  diffTable, changedFieldsLine, changedFieldsTitle, expandAllButton, jobWord, isImported,
} from '../diff_parts.js';
import {
  starmodderPage, starmodderFile, modHref, webAddress, postHref, postKindWords, postFallbackName, postJobKeys,
  foundByWords, joinedByWords, factSource, fieldName, shortValue, saveAnswerWords, distinctNames,
  sameAuthorLabel, matchLabel,
} from '../mod_words.js';

/// The sentence the other pages use when jobs are off.
function managerOffText(s) {
  if (s && s.offline) return 'The server could not be reached. Jobs cannot be started.';
  return `${(s && s.reason) || 'Job management is disabled on this server.'} Start the viewer with a readable `
    + 'config.properties file (or specify it with --config) and omit --no-manager to enable jobs.';
}

export async function render({ content, parts, toolbar, onLeave }) {
  const id = parts[0] || '';
  const crumbs = el('div');
  const main = el('div', { class: 'pp-page md-page' }, [crumbs, emptyLine('Loading…')]);
  const offSlot = el('div');
  const picturesSlot = el('div');
  content.append(pageLayout(main, [pendingPanel(), offSlot, picturesSlot]));
  const gone = () => !main.isConnected;

  const drawCrumbs = (label) => crumbs.replaceChildren(breadcrumbs([
    { label: 'Mods', href: '#/mods' },
    { label },
  ]));
  drawCrumbs(id);

  let answer = await readMod(id);
  if (gone()) return;

  // No catalog has been built yet: say so, with the server's hint.
  if (answer.missing) {
    main.replaceChildren(crumbs, el('div', { class: 'pp-missing' }, [
      el('p', { text: `No catalog yet. ${answer.hint || ''}`.trim() }),
    ]));
    return;
  }

  // An old id: draw the mod it leads to, with a note naming the old id.
  let movedFrom = null;
  if (answer.kind === 'moved' && answer.movedTo) {
    movedFrom = id;
    const target = await readMod(answer.movedTo);
    if (gone()) return;
    if (target.kind === 'unknown' || target.error) {
      drawCrumbs(id);
      main.replaceChildren(crumbs, el('div', { class: 'md-note' }, [
        el('p', {}, [
          el('code', { text: id }), ' is an old id. It leads to ',
          el('a', { href: modHref(answer.movedTo), text: answer.movedTo }), ', which could not be loaded.',
        ]),
        target.error ? el('p', { class: 'error-text', text: target.error }) : null,
      ]), el('div', { class: 'raw-slot' }, [rawJson(answer, 'Raw mod data (JSON)')]));
      return;
    }
    answer = target;
  }

  const ctx = { answer, movedFrom, on: null, toolbar, offSlot, refreshers: [], gone };

  switch (answer.kind) {
    case 'collection':
      drawCrumbs(collectionName(answer));
      main.replaceChildren(crumbs, ...collectionPage(ctx));
      break;
    case 'takenDown':
      drawCrumbs(answer.name || answer.id || id);
      main.replaceChildren(crumbs, ...takenDownPage(ctx, id));
      break;
    case 'mod':
      drawCrumbs(modName(answer));
      main.replaceChildren(crumbs, ...modPage(ctx));
      picturesSlot.replaceChildren(...picturesPanel(answer));
      loadHistory(ctx);
      break;
    default:
      drawCrumbs(id);
      main.replaceChildren(crumbs, ...unknownPage(answer, id));
  }

  // The toolbar's buttons and the correction buttons follow the manager
  // going on or off, and the pending list changing.
  const redraw = () => {
    if (gone()) return;
    drawActions(ctx);
    for (const fn of ctx.refreshers) fn();
  };
  onLeave(onPendingChange(redraw));
  onLeave(subscribe((s) => {
    if (!!s.on === ctx.on) return;
    ctx.on = !!s.on;
    redraw();
  }));
}

/// The server's answer for one id. A refusal comes back as `{ error }`.
async function readMod(id) {
  try {
    return await api(`mods/${encodeURIComponent(id)}`);
  } catch (err) {
    return { kind: 'unknown', id, error: err.message };
  }
}

function listingOf(answer) {
  return (answer.site && answer.site.listing) || {};
}

function modName(answer) {
  const listing = listingOf(answer);
  const catalog = answer.catalog || {};
  return listing.displayName || listing.name || catalog.name || answer.id;
}

function collectionName(answer) {
  return (answer.collection && answer.collection.name) || (answer.catalog && answer.catalog.name) || answer.name || answer.id;
}

// --- The toolbar ---

function drawActions(ctx) {
  const { answer, on, toolbar, offSlot } = ctx;
  const buttons = [];
  if (on && answer.kind === 'mod') {
    const keys = postJobKeys(answer.sourcePosts || (answer.catalog && answer.catalog.sourcePosts));
    for (const job of POST_JOBS) {
      const n = postJobCount(job.kind, keys);
      // Say how many a topics-only job acts on when the mod has Discord threads too.
      const partial = job.topicsOnly && n > 0 && n < keys.length;
      buttons.push(el('button', {
        type: 'button',
        class: 'button',
        disabled: n === 0,
        title: job.topicsOnly && !n ? 'Works on forum topics only. This mod has none.' : `Runs on this mod's ${n === 1 ? 'post' : `${n} posts`}.`,
        onclick: () => startJob(postJobRequest(job.kind, keys)),
      }, [job.label, partial ? el('span', { class: 'choice', text: ` ${n} of ${keys.length}` }) : null]));
    }
  }
  if (on && (answer.kind === 'mod' || answer.kind === 'collection')) {
    buttons.push(el('button', {
      type: 'button',
      class: 'button danger',
      text: 'Take down',
      title: answer.kind === 'collection'
        ? 'Remove this Collection page from Starmodder. The mods it lists stay published.'
        : 'Leave this mod out of everything we publish, at its owner\'s request.',
      onclick: () => previewAndAdd({ modId: answer.id }),
    }));
  }
  toolbar.actions.replaceChildren(...buttons);
  offSlot.replaceChildren(...(on === false ? [sidePanel({
    name: 'Viewing only',
    body: el('p', { class: 'pp-side-note', text: managerOffText(status()) }),
  })] : []));
}

/// Starts a job after its confirm dialog, then opens its run.
async function startJob(request) {
  const record = await confirmAndStart(request);
  if (record && record.id) location.hash = `#/runs/${encodeURIComponent(record.id)}`;
}

// --- A mod ---

function modPage(ctx) {
  const { answer } = ctx;
  const site = answer.site || null;
  const historySlot = el('div');
  ctx.historySlot = historySlot;
  return [
    modHead(ctx),
    el('div', { class: 'pp-sections' }, [
      section('What Starmodder shows', null, site ? siteFields(ctx, site) : [
        emptyLine('Starmodder has no file for this mod. Run Rebuild from saved to build the website.'),
      ]),
      factsSection(answer.facts, answer.factsStatus),
      postsSection(answer.sourcePosts || (answer.catalog && answer.catalog.sourcePosts) || []),
      historySlot,
    ]),
    el('div', { class: 'raw-slot' }, [rawJson(answer, 'Raw mod data (JSON)')]),
  ];
}

/// Name, id, authors, links, old ids and takedown status.
function modHead(ctx) {
  const { answer, movedFrom } = ctx;
  const listing = listingOf(answer);
  const catalog = answer.catalog || {};
  const name = modName(answer);
  const authors = distinctNames(listing.authors || catalog.authorsList || []);

  const authorSlot = el('span', { class: 'md-authors' });
  const drawAuthors = () => {
    const button = ctx.on && authors.length >= 2 ? sameAuthorButton(authors) : null;
    authorSlot.replaceChildren(...[
      authors.length ? el('span', { class: 'pp-meta-text', text: `by ${authors.join(', ')}` }) : null,
      button,
    ].filter(Boolean));
  };
  drawAuthors();
  ctx.refreshers.push(drawAuthors);

  const meta = [el('span', { class: 'chip id', text: answer.id }), authorSlot];
  if (listing.isTool) meta.push(badge('tool'));
  if (listing.isWorkInProgress) meta.push(badge('work in progress', 'warn'));

  const head = el('header', { class: 'pp-head' }, [
    movedFrom ? movedNote(movedFrom, answer.id) : null,
    el('h2', { class: 'pp-title', text: name }),
    el('div', { class: 'pp-meta' }, meta),
    el('div', { class: 'pp-head-links' }, [
      outLink(answer.starmodderUrl || starmodderPage(answer.id), 'Open on Starmodder ↗'),
      outLink(answer.publishedFileUrl || starmodderFile(answer.id), 'Published file ↗'),
    ]),
  ]);
  const oldIds = (answer.oldIds || []).filter((old) => old !== movedFrom);
  if (oldIds.length || movedFrom) {
    const all = movedFrom ? [movedFrom, ...oldIds] : oldIds;
    head.append(el('p', { class: 'md-line' }, [
      el('span', { class: 'dim', text: all.length === 1 ? 'Old id that leads here: ' : 'Old ids that lead here: ' }),
      ...all.flatMap((old, i) => [i ? ', ' : null, el('code', { class: 'md-old-id', text: old })]),
    ]));
  }
  const statusLine = el('p', { class: 'md-line md-status' });
  const drawStatus = () => statusLine.replaceChildren(...takedownStatus(answer));
  drawStatus();
  ctx.refreshers.push(drawStatus);
  head.append(statusLine);
  return head;
}

function movedNote(oldId, newId) {
  return el('div', { class: 'md-note' }, [
    icon('chevron-right', 14),
    el('span', {}, [
      'You opened ', el('code', { text: oldId }), ', an old id. It now leads to ',
      el('code', { text: newId }), '.',
    ]),
  ]);
}

/// Published, taken down, or a takedown pending, with a mark.
function takedownStatus(answer) {
  const td = answer.takedown;
  if (td && td.status === 'returnedUnderNewId') {
    // The Takedowns page's warning, for the same case.
    const names = (td.entries || []).map((e) => e.id || e.name).filter(Boolean);
    return [statusMark('warning'), el('span', {}, [
      `Published, but a takedown entry${names.length ? ` (${names.join(', ')})` : ''} lists its posts. `
        + 'It may be back under a new id. ',
      el('a', { href: '#/takedowns', text: 'Takedowns' }),
    ])];
  }
  if (td) {
    const entry = td.entry || {};
    const on = entry.on ? ` on ${String(entry.on).slice(0, 10)}` : '';
    return [statusMark('failed'), el('span', {}, [
      `Taken down${on}. Left out of everything we publish. `,
      el('a', { href: '#/takedowns', text: 'Takedowns' }),
    ])];
  }
  if (isPending({ kind: 'takeDownMod', modId: answer.id })) {
    return [statusMark('warning'), el('span', { text: 'Takedown pending. Nothing is written until the pending changes are saved.' })];
  }
  return [statusMark('done'), el('span', { text: 'Published. Not on the takedown list.' })];
}

/// The pictures Starmodder can show on the mod's card: the forum post's, and
/// the Discord post's when it differs.
function picturesPanel(answer) {
  const listing = listingOf(answer);
  const pictures = [
    ['Forum post', webAddress(listing.imageUrl)],
    ['Discord post', webAddress(listing.announcementImageUrl)],
  ].filter(([, url]) => url);
  if (!pictures.length) return [];
  return [sidePanel({
    name: 'Card picture',
    body: el('div', { class: 'md-pictures' }, pictures.map(([label, url]) => el('figure', { class: 'md-picture' }, [
      el('a', { href: url, target: '_blank', rel: 'noopener' }, [
        el('img', { src: url, alt: `${label} picture`, loading: 'lazy', referrerpolicy: 'no-referrer' }),
      ]),
      el('figcaption', { text: label }),
    ]))),
  })];
}

// --- What Starmodder shows ---

const CONFLICT_WORDS = {
  technical: 'Incompatible (Technical)',
  gameplay: 'Incompatible (Gameplay)',
  withNotes: 'Compatible, with notes',
  other: 'Other',
};

function siteFields(ctx, site) {
  const { answer } = ctx;
  const listing = site.listing || {};
  // Each unmatched name's key from the server, by its loose spelling.
  const unmatchedList = unmatchedNeedsOf(answer);
  const unmatched = new Map(unmatchedList.map((need) => [looseKey(need.name), need.key]));
  const shownNeeds = new Set();

  const needChips = (list) => el('span', { class: 'md-chips' }, list.map((need) => {
    shownNeeds.add(looseKey(need.name));
    if (need.id) {
      return el('a', { class: 'chip md-need', href: modHref(need.id), title: need.via ? `Required by ${need.via}.` : null, text: need.name });
    }
    const loose = looseKey(need.name);
    return unmatchedNeed(ctx, need.name, unmatched.has(loose), unmatched.get(loose));
  }));

  const download = listing.bestDownload;
  const save = (answerWord, text) => {
    if (!text) return null;
    const word = saveAnswerWords(answerWord);
    return word ? `${word} — ${text}` : text;
  };

  const rows = [
    ['Name', listing.displayName || listing.name],
    ['Thread title', listing.displayName && listing.name !== listing.displayName ? listing.name : null],
    ['Authors', (listing.authors || []).join(', ')],
    ['Other names', otherNamesText(listing.otherAuthorNames)],
    ['Also called', (listing.nicknames || []).join(', ')],
    ['Summary', listing.summary ? `${listing.summary}${listing.summaryIsGenerated ? ' (AI)' : ''}` : null],
    ['AI summary', listing.aiSummary && listing.aiSummary !== listing.summary ? listing.aiSummary : null],
    ['Categories', (listing.categories || []).join(', ')],
    ['Original categories', (site.rawCategories || []).join(', ')],
    ['Game version', listing.gameVersion],
    ['Mod version', listing.modVersion],
    ['Picture', listing.imageUrl, listing.imageUrl ? outLink(listing.imageUrl, listing.imageUrl) : null],
    ['Discord picture', listing.announcementImageUrl, listing.announcementImageUrl
      ? outLink(listing.announcementImageUrl, listing.announcementImageUrl) : null],
    ['Main download', download && download.url, download ? el('span', {}, [
      badge(download.kind || 'direct', download.kind === 'trios' ? 'strong' : ''), ' ',
      outLink(download.url, download.url),
      download.needsAnotherStep ? el('span', { class: 'dim', text: ' (opens the host’s page)' }) : null,
    ]) : null],
    ['Downloads', (site.downloads || []).length ? null : 'None', (site.downloads || []).length ? downloadList(site.downloads) : null],
    ['Requires', null, (listing.needs || []).length ? needChips(listing.needs) : null],
    ['Optional', null, (site.optionalNeeds || []).length ? needChips(site.optionalNeeds) : null],
    ['Conflicts', null, (site.conflicts || []).length ? conflictList(site.conflicts) : null],
    ['Adding to a save', save(site.canAdd, site.saveCompatibilityText)],
    ['Updating', save(site.canUpdate, site.updateCompatibilityText)],
    ['Removing from a save', save(site.canRemove, site.removalCompatibilityText)],
    ['AI use', aiUseText(site.aiUse)],
    ['Source code', site.sourceCodeUrl, site.sourceCodeUrl ? outLink(site.sourceCodeUrl, site.sourceCodeUrl) : null],
    ['License', site.license],
    ['Support the author', null, (site.supportLinks || []).length ? el('span', { class: 'md-chips' }, site.supportLinks.map(
      (s) => outLink(s.url, s.label || s.type || s.url),
    )) : null],
    ['Forum thread', site.forumUrl, site.forumUrl ? outLink(site.forumUrl, site.forumUrl) : null],
    ['Discord post', site.discordUrl, site.discordUrl ? outLink(site.discordUrl, site.discordUrl) : null],
    ['Full changelog', site.changelogUrl, site.changelogUrl ? outLink(site.changelogUrl, site.changelogUrl) : null],
    ['Added', listing.addedOn],
    ['Last edited', listing.editedOn],
    ['Last release', listing.lastReleaseDate ? String(listing.lastReleaseDate).slice(0, 10) : null],
    ['Releases', (site.releases || []).length
      ? site.releases.map((r) => `${r.newVersion}${r.seenOn ? ` (${r.seenOn})` : ''}`).join(', ') : null],
    ['Same name', null, (site.sameNameMods || []).length
      ? el('span', { class: 'md-chips' }, site.sameNameMods.map(sameNameChip)) : null],
    ['Add-ons', null, (site.addons || []).length ? el('span', { class: 'md-chips' }, site.addons.map(
      (a) => (a.id ? el('a', { class: 'chip', href: modHref(a.id), text: a.name || a.id }) : el('span', { class: 'chip', text: a.name || '' })),
    )) : null],
    ['Gallery', (site.gallery || []).length ? `${site.gallery.length} picture${site.gallery.length === 1 ? '' : 's'}` : null],
  ];

  // Requirements the build could not match that no list above shows.
  const leftOver = unmatchedList.filter((need) => !shownNeeds.has(looseKey(need.name)));
  const children = [fieldList(rows)];
  if (leftOver.length) {
    children.push(fieldList([['Not matched', null, el('span', { class: 'md-chips' },
      leftOver.map((need) => unmatchedNeed(ctx, need.name, true, need.key)))]]));
  }

  const descriptionText = site.description || '';
  if (descriptionText) {
    const heading = site.descriptionIsForumPost ? 'Forum post' : 'About this mod';
    const label = `${heading}${site.descriptionIsGenerated ? ' (AI)' : ''}: ${descriptionText.length} characters`;
    children.push(fold(label, el('pre', { class: 'pp-pre pp-message', text: descriptionText })));
  }
  if (site.aiDescription) {
    children.push(fold('AI description', el('p', { class: 'md-fold-text', text: site.aiDescription })));
  }
  return children;
}

/// Links to the mod's page here, or to its forum thread in a new tab.
function sameNameChip(m) {
  const title = m.title || m.id || m.url || '';
  if (m.id) return el('a', { class: 'chip', href: modHref(m.id), text: title });
  if (m.url) return outLink(m.url, `${title} ↗`, { class: 'chip', title: 'Open on the forum' });
  return el('span', { class: 'chip', text: title });
}

function otherNamesText(map) {
  const parts = Object.entries(map || {})
    .filter(([, names]) => (names || []).length)
    .map(([name, names]) => `${name}: ${names.join(', ')}`);
  return parts.length ? parts.join('; ') : null;
}

function downloadList(downloads) {
  return el('ul', { class: 'md-list' }, downloads.map((d) => el('li', {}, [
    badge(d.kind || 'direct', d.kind === 'trios' ? 'strong' : ''), ' ',
    outLink(d.url, d.label ? `${d.label}${d.host ? ` · ${d.host}` : ''}` : d.url),
    d.needsAnotherStep ? el('span', { class: 'dim', text: ' (opens the host’s page)' }) : null,
  ])));
}

function conflictList(conflicts) {
  return el('ul', { class: 'md-list' }, conflicts.map((c) => el('li', {}, [
    c.id ? el('a', { href: modHref(c.id), text: c.name }) : el('strong', { text: c.name }),
    c.kind ? el('span', { class: 'dim', text: ` · ${CONFLICT_WORDS[c.kind] || c.kind}` }) : null,
    c.fromOtherMod ? el('span', { class: 'dim', text: ' · from the other mod’s post' }) : null,
    c.quote ? el('div', { class: 'md-quote', text: `“${c.quote}”` }) : null,
  ])));
}

/// The author's statement about AI use, in the old thread page's words.
function aiUseText(aiUse) {
  if (!aiUse) return 'Not checked yet';
  if (aiUse.usesAi == null) return 'Not stated in the post';
  const uses = (aiUse.uses || []).map((use) => {
    const notes = [use.how, use.extent, use.optional ? 'optional' : null].filter(Boolean);
    return notes.length ? `${use.area} (${notes.join(', ')})` : use.area;
  });
  if (!aiUse.usesAi) return 'No';
  return uses.length ? `Yes — ${uses.join(' · ')}` : 'Yes';
}

// --- Corrections ---

/// "These are the same person": pick two of the credited names.
function sameAuthorButton(authors) {
  return el('button', {
    type: 'button',
    class: 'button md-small',
    text: 'These are the same person',
    title: 'Pick two of these names that belong to one person.',
    onclick: () => pickSamePerson(authors),
  });
}

function pickSamePerson(authors) {
  const boxes = authors.map((name) => {
    const box = el('input', { type: 'checkbox', value: name });
    // With only two names, both are the answer.
    box.checked = authors.length === 2;
    return box;
  });
  const add = el('button', { type: 'button', class: 'button primary', text: 'Add' });
  const cancel = el('button', { type: 'button', class: 'button', text: 'Cancel' });
  const preview = el('p', { class: 'dn-hint' });
  const picked = () => boxes.filter((b) => b.checked).map((b) => b.value);
  const sync = () => {
    const names = picked();
    add.disabled = names.length !== 2;
    preview.textContent = names.length === 2 ? sameAuthorLabel(names[0], names[1]) : 'Tick two names.';
  };
  boxes.forEach((b) => b.addEventListener('change', sync));
  const box = el('dialog', { class: 'dialog dn-dialog' }, [
    el('div', { class: 'dn-eyebrow', text: 'Author aliases' }),
    el('h2', { text: 'Which two names are the same person?' }),
    el('div', { class: 'md-names' }, authors.map((name, i) => el('label', { class: 'check' }, [boxes[i], name]))),
    preview,
    el('p', {
      class: 'dn-hint dn-pending-note',
      text: 'This is added to the pending changes. Nothing is written until you save them.',
    }),
    el('div', { class: 'dialog-buttons' }, [cancel, add]),
  ]);
  const shut = showDialog(box, async (value) => {
    if (!value) return;
    const [a, b] = value;
    const added = addPending({ kind: 'sameAuthor', label: sameAuthorLabel(a, b), correction: { kind: 'sameAuthor', names: [a, b] } });
    if (!added) await noticeDialog('Already pending', 'This change is already pending.');
  });
  add.addEventListener('click', () => shut(picked()));
  cancel.addEventListener('click', () => shut(null));
  sync();
  (authors.length === 2 ? add : boxes[0]).focus();
}

/// The server's unmatched requirement names as `{ name, key }`. An answer
/// from an older server lists plain names, with no key.
function unmatchedNeedsOf(answer) {
  return (answer.unmatchedNeeds || []).map((need) => (typeof need === 'string'
    ? { name: need, key: null }
    : { name: String(need.name || ''), key: need.key || null })).filter((need) => need.name);
}

/// A requirement the build could not match: its name, then "Match this to a
/// mod" while the manager is on, or the pending match with Undo. `key` is the
/// server's key for the name; a pending match is found by it, or by the loose
/// spelling when either side has no key.
function unmatchedNeed(ctx, written, unmatched, key = null) {
  const slot = el('span', { class: 'md-need-slot' });
  const draw = () => {
    const pending = pendingItems().filter((i) => i.correction.kind === 'matchRequirement'
      && (i.key && key ? i.key === key : looseKey(i.correction.written) === looseKey(written)));
    const parts = [el('span', {
      class: `chip md-need${unmatched ? ' warn' : ''}`,
      title: unmatched ? 'The last build could not match this name to one of our mods.' : null,
      text: written,
    })];
    if (pending.length) {
      parts.push(el('span', { class: 'tag dn-tag-pending', title: pending[pending.length - 1].label, text: 'Match pending' }));
      parts.push(el('button', {
        type: 'button',
        class: 'button quiet md-small',
        text: 'Undo',
        title: 'Remove this change from the pending changes.',
        onclick: () => { for (const item of pending) removePending(item.id); },
      }));
    } else if (unmatched && ctx.on) {
      parts.push(el('button', {
        type: 'button',
        class: 'button md-small',
        text: 'Match this to a mod',
        title: 'Pick the mod this name means.',
        onclick: () => matchNeed(ctx, written, key),
      }));
    }
    slot.replaceChildren(...parts);
  };
  draw();
  ctx.refreshers.push(() => { if (slot.isConnected) draw(); });
  return slot;
}

/// Opens the mod picker over the mods of the last website build.
async function matchNeed(ctx, written, key) {
  if (!ctx.pickerMods) {
    ctx.pickerMods = api('requirement-names')
      .then((body) => ((body && body.report && body.report.mods) || []))
      .catch(() => []);
  }
  const mods = await ctx.pickerMods;
  openModPicker({
    written,
    facts: `Written in the post of ${modName(ctx.answer)}. The last build could not match it to one of our mods.`,
    mods,
    onPick: (mod) => addPending({
      kind: 'matchRequirement',
      label: matchLabel(written, mod.name),
      correction: { kind: 'matchRequirement', written, modId: mod.id },
      key: key || undefined,
    }),
  });
}

// --- Where each fact came from ---

function factsSection(facts, factsStatus) {
  const entries = Object.entries(facts || {});
  if (!entries.length) {
    let text = 'Run Rebuild from saved to see where each fact came from.';
    if (factsStatus === 'otherBuild') {
      text = 'These are from an older build. Run Rebuild from saved to update them.';
    } else if (factsStatus === 'current') {
      text = 'The last build recorded no fact sources for this mod.';
    }
    return section('Where each fact came from', null, [emptyLine(text)]);
  }
  const rows = entries.map(([field, fact]) => {
    const value = fact && typeof fact === 'object' && 'value' in fact ? fact.value : fact;
    const source = factSource(fact && fact.source);
    let from;
    if (!source) from = el('span', { class: 'dim', text: 'Not recorded' });
    else {
      // A fact put together from several answers names each post behind it.
      const several = ((fact && (fact.from || fact.mergedFrom)) || []).map(factSource).filter(Boolean);
      from = el('span', { class: 'md-from' }, [
        source.href ? el('a', { href: source.href, text: source.text }) : el('span', { text: source.text }),
        source.llmName ? el('span', { class: 'dim', text: ` · LLM answer "${source.llmName}"` }) : null,
        source.href && !source.llmName ? el('span', { class: 'dim', text: ' · the post itself' }) : null,
        several.length ? el('ul', { class: 'md-list md-from-list' }, several.map((s) => el('li', {}, [
          s.href ? el('a', { href: s.href, text: s.text }) : s.text,
          s.llmName ? el('span', { class: 'dim', text: ` · LLM answer "${s.llmName}"` }) : null,
        ]))) : null,
      ]);
    }
    return el('tr', {}, [
      el('td', { class: 'md-field', text: fieldName(field) }),
      el('td', { class: 'md-value', title: typeof value === 'string' && value.length > 160 ? value : null, text: shortValue(value) }),
      el('td', { class: 'md-source' }, [from]),
    ]);
  });
  return section('Where each fact came from', entries.length, [
    el('div', { class: 'table-wrap pp-table-wrap' }, [el('table', { class: 'table md-table' }, [
      el('thead', {}, el('tr', {}, ['Fact', 'Value', 'Came from'].map((h) => el('th', { text: h })))),
      el('tbody', {}, rows),
    ])]),
  ]);
}

// --- Source posts ---

function postsSection(posts) {
  if (!posts.length) return section('Source posts', 0, [emptyLine('The catalog lists no source posts for this mod.')]);
  const anyJoined = posts.some((p) => p.joinedBy);
  const rows = posts.map((post) => {
    const href = postHref(post);
    const title = post.title || postFallbackName(post);
    return el('tr', {}, [
      el('td', { class: 'md-post' }, [
        href ? el('a', { href, text: title }) : el('span', { text: title }),
        // The kind and id, under a title. A post with no title is already named by them.
        post.title ? el('span', { class: 'md-post-kind', text: `${postKindWords(post.kind)} ${post.id}` }) : null,
      ]),
      el('td', { class: 'md-llm', text: post.llmName || post.llmModName || '—' }),
      el('td', { text: foundByWords(post.foundBy) || '—' }),
      anyJoined ? el('td', { text: joinedByWords(post.joinedBy) || '—' }) : null,
    ]);
  });
  const children = [el('div', { class: 'table-wrap pp-table-wrap' }, [el('table', { class: 'table md-table md-posts' }, [
    el('thead', {}, el('tr', {}, ['Post', 'LLM name', 'How it was found', anyJoined ? 'How it joined' : null]
      .filter(Boolean).map((h) => el('th', { text: h })))),
    el('tbody', {}, rows),
  ])])];
  if (!anyJoined && posts.length > 1) {
    children.push(el('p', { class: 'pp-source-line', text: 'The build did not save how each post joined. Run Rebuild from saved to record it.' }));
  }
  return section('Source posts', posts.length, children);
}

// --- History ---

async function loadHistory(ctx) {
  const slot = ctx.historySlot;
  slot.replaceChildren(section('History', null, [emptyLine('Loading… Reading every saved snapshot can take a minute.')]));
  let history;
  try {
    history = await api(`mods/${encodeURIComponent(ctx.answer.id)}/history`);
  } catch (err) {
    if (ctx.gone()) return;
    slot.replaceChildren(section('History', null, [el('p', { class: 'error-text', text: err.message })]));
    return;
  }
  if (ctx.gone()) return;
  const entries = Array.isArray(history) ? history : ((history && (history.entries || history.items)) || []);
  const name = modName(ctx.answer);
  const log = el('div', { class: 'ph-log md-history' });
  const forumPost = (ctx.answer.sourcePosts || []).find((p) => p && p.kind === 'forum');
  const forumTopic = forumPost ? forumPost.id : null;
  for (const entry of entries) log.append(historyEntry(entry, name, forumTopic));
  if (!entries.length) {
    log.append(el('div', { class: 'ph-entry' }, [
      el('div', { class: 'ph-rail' }, el('span', { class: 'ph-dot dim' })),
      el('div', { class: 'ph-body' }, [el('p', { class: 'pp-source-line', text: 'No changes in saved snapshots.' })]),
    ]));
  }
  const tail = historyTail(history);
  if (tail) log.append(tail);
  const body = [];
  if (entries.length) body.push(el('div', { class: 'md-history-bar' }, [expandAllButton(log, 'details.ph-card')]));
  body.push(log);
  const sec = section('History', entries.length, body);
  slot.replaceChildren(sec);
}

/// The end of the history: how far back the saved snapshots reach.
function historyTail(history) {
  if (!history || Array.isArray(history)) return null;
  const lines = [];
  for (const [what, walk] of [['mod details', history.bundleSnapshots], ['catalog', history.mergeSnapshots]]) {
    if (!walk) continue;
    const from = when(walk.oldestSavedAt);
    const total = walk.total || 0;
    const read = walk.read || 0;
    const kept = `${total} saved ${what} snapshot${total === 1 ? '' : 's'}`;
    lines.push(from ? `${kept}, from ${from}. Earlier snapshots are unavailable.` : `${kept}.`);
    if (read < total) lines.push(`${total - read} of the ${what} snapshots could not be read and were skipped.`);
  }
  if (!lines.length) return null;
  return el('div', { class: 'ph-entry ph-tail' }, [
    el('div', { class: 'ph-rail' }, el('span', { class: 'ph-cap' })),
    el('div', { class: 'ph-body' }, lines.map((text) => el('p', { class: 'pp-source-line', text }))),
  ]);
}

const KIND_WORDS = { changed: ['changed', 'warn'], first: ['first seen', 'good'], gone: ['removed', 'bad'] };

/// One saved run in which the mod changed. When collapsed, it lists the
/// changed fields. When expanded, it shows their changes.
function historyEntry(entry, name, forumTopic) {
  const changes = entry.diff || entry.changes || [];
  const fieldNames = (entry.fields || []).length ? entry.fields : changes.map((c) => c.field).filter(Boolean);
  const named = fieldNames.map((field) => ({ field }));
  const [word, tone] = KIND_WORDS[entry.kind] || KIND_WORDS.changed;
  const card = el('details', { class: 'ph-card' });
  card.append(el('summary', {}, [
    badge(word, tone),
    el('span', { class: 'ph-name', text: when(entry.at || entry.savedAt) || entry.runId }),
    el('span', { class: 'ph-job', text: [jobWord(entry.runId), sourceWord(entry.source)].filter(Boolean).join(' · ') }),
    el('span', { class: 'ph-chev', 'aria-hidden': 'true' }, [icon('chevron-right', 14)]),
    // After the chevron, so it wraps to its own line under the date.
    named.length ? el('span', { class: 'ph-hint', text: changedFieldsLine(named), title: changedFieldsTitle(named) }) : null,
  ]));

  const body = el('div', { class: 'ph-card-body' });
  const links = el('div', { class: 'ph-actions' });
  if (isImported(entry.runId)) {
    body.append(el('p', { class: 'pp-source-line', text: 'Imported from the published repo’s Git history. No local run record.' }));
  } else {
    links.append(el('a', { href: `#/runs/${encodeURIComponent(entry.runId)}`, text: 'View run' }));
  }
  if (entry.kind !== 'first') {
    links.append(el('a', { href: changesHref(entry, name, forumTopic), text: 'View changes' }));
  }
  body.append(links);
  if (entry.kind === 'first') body.append(el('p', { class: 'pp-source-line', text: 'First saved snapshot containing this mod.' }));
  if (entry.kind === 'gone') body.append(el('p', { class: 'pp-source-line', text: 'This mod was removed.' }));
  if (changes.length) body.append(diffTable(changes));
  card.append(body);

  return el('div', { class: 'ph-entry' }, [
    el('div', { class: 'ph-rail' }, el('span', { class: 'ph-dot' })),
    el('div', { class: 'ph-body' }, [card]),
  ]);
}

/// What changed for this entry's run: the Mods tab for a catalog snapshot,
/// the Facts tab for a mod details one, searched for the mod's name. The rows
/// for its forum topics start open.
function changesHref(entry, name, forumTopic) {
  const merge = entry.source === 'merge';
  const topics = merge
    ? [forumTopic].filter(Boolean)
    : (entry.diff || []).map((c) => c.post).filter((p) => p && p.kind === 'forum').map((p) => p.id);
  return buildHash(['changes'], {
    tab: merge ? 'mods' : 'facts',
    b: entry.runId,
    q: name,
    open: [...new Set(topics)].map((id) => `topic:${id}`).join(';'),
  });
}

/// Which kind of saved snapshot an entry came from.
function sourceWord(source) {
  if (source === 'merge') return 'catalog';
  if (source === 'bundle') return 'mod details';
  return '';
}

// --- A Collection ---

function collectionPage(ctx) {
  const { answer } = ctx;
  const catalog = answer.collection || answer.catalog || {};
  const post = catalog.sourcePost || (answer.sourcePosts || [])[0] || null;
  const href = post ? postHref(post) : null;
  const postTitle = (post && post.title) || (post ? postFallbackName(post) : '');
  const modIds = catalog.modIds || (catalog.mods || []).map((m) => m.id);

  const modsSlot = el('div', {}, [emptyLine('Loading…')]);
  collectionMods(catalog, modIds).then((rows) => {
    if (ctx.gone()) return;
    modsSlot.replaceChildren(rows.length
      ? el('ul', { class: 'md-collection' }, rows.map((m) => el('li', {}, [
        el('a', { href: modHref(m.id), text: m.displayName || m.name || m.id }),
        el('code', { class: 'ml-id', text: m.id }),
      ])))
      : emptyLine('This Collection lists no mods.'));
  });

  return [
    el('header', { class: 'pp-head' }, [
      ctx.movedFrom ? movedNote(ctx.movedFrom, answer.id) : null,
      el('h2', { class: 'pp-title', text: collectionName(answer) }),
      el('div', { class: 'pp-meta' }, [badge('Collection', 'strong'), el('span', { class: 'chip id', text: answer.id })]),
      el('p', { class: 'md-line dim', text: 'This page lists the mods from the post. Each mod has its own page.' }),
      (answer.oldIds || []).length ? el('p', { class: 'md-line' }, [
        el('span', { class: 'dim', text: answer.oldIds.length === 1 ? 'Old id that leads here: ' : 'Old ids that lead here: ' }),
        ...answer.oldIds.flatMap((old, i) => [i ? ', ' : null, el('code', { class: 'md-old-id', text: old })]),
      ]) : null,
      el('div', { class: 'pp-head-links' }, [
        outLink(starmodderPage(answer.id), 'Open on Starmodder ↗'),
        outLink(starmodderFile(answer.id), 'Published file ↗'),
      ]),
    ]),
    el('div', { class: 'pp-sections' }, [
      section('Source post', null, [post
        ? el('p', {}, [
          href ? el('a', { href, text: postTitle }) : el('span', { text: postTitle }),
          el('span', { class: 'dim', text: ` · ${postKindWords(post.kind)} ${post.id}` }),
        ])
        : emptyLine('The catalog names no source post for this Collection.')]),
      section('Mods', modIds.length, [modsSlot]),
    ]),
    el('div', { class: 'raw-slot' }, [rawJson(answer, 'Raw Collection data (JSON)')]),
  ];
}

/// The Collection's mods with their names: from the answer when it has them,
/// otherwise from the Mods list.
async function collectionMods(collection, ids) {
  const given = collection.mods;
  if (Array.isArray(given) && given.length && typeof given[0] === 'object') return given;
  if (!ids.length) return [];
  let names = new Map();
  try {
    const list = await api('mods', { pageSize: 0 });
    names = new Map((list.items || []).map((m) => [m.id, m.displayName || m.name]));
  } catch {
    // The ids alone still link to each mod.
  }
  return ids.map((id) => ({ id, name: names.get(id) || id }));
}

// --- Taken down and unknown ---

function takenDownPage(ctx, id) {
  const { answer } = ctx;
  const td = answer.takedown || {};
  const entry = td.entry || {};
  const name = answer.name || entry.name || answer.id || id;
  const posts = answer.sourcePosts || [];
  return [
    el('header', { class: 'pp-head' }, [
      el('h2', { class: 'pp-title', text: name }),
      el('div', { class: 'pp-meta' }, [badge('taken down', 'bad'), el('span', { class: 'chip id', text: answer.id || id })]),
      el('p', { class: 'md-line md-status' }, takedownStatus({ ...answer, takedown: answer.takedown || {} })),
    ]),
    el('div', { class: 'pp-sections' }, [
      section('Takedown', null, [
        fieldList([
          ['Taken down on', entry.on ? String(entry.on).slice(0, 10) : null],
          ['Taken down by', takenDownBy(td)],
          ['Blocked posts', null, posts.length ? el('ul', { class: 'md-list' }, posts.map((post) => {
            const href = postHref(post);
            const title = post.title || postFallbackName(post);
            return el('li', {}, [
              href ? el('a', { href, text: title }) : title,
              post.llmName ? el('span', { class: 'dim', text: ` · "${post.llmName}"` }) : null,
            ]);
          })) : null],
        ]),
        el('p', {}, ['Restore it on the ', el('a', { href: '#/takedowns', text: 'Takedowns' }), ' page.']),
      ]),
    ]),
    el('div', { class: 'raw-slot' }, [rawJson(answer, 'Raw mod data (JSON)')]),
  ];
}

/// Which takedown entry left the mod out: its own mod entry, or an author
/// entry naming the person.
function takenDownBy(td) {
  if (td.entryKind === 'author') return td.author ? `Author takedown: ${td.author}` : 'Author takedown';
  if (td.entryKind === 'mod') return 'Mod takedown';
  return null;
}

function unknownPage(answer, id) {
  return [
    el('div', { class: 'pp-missing' }, [
      el('p', { class: answer.error ? 'error-text' : null, text: answer.error || `There is no mod with the id "${id}" in the last build.` }),
      el('p', {}, ['Search for it on the ', el('a', { href: `#/mods?q=${encodeURIComponent(id)}`, text: 'Mods' }), ' page.']),
    ]),
  ];
}

