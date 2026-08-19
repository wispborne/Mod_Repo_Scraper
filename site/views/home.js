// Home: a search box, the mods added most recently, then what came out recently.
//
// The release feed is the heart of the page. It is not "threads somebody
// replied to" — it is mods whose version actually moved forward, worked out by
// comparing saved copies of the data over time.

import {
  buildHash, clear, currentGameVersion, el, formatDay, go, howLongAgo, modHref,
  modList, modName, releaseFeed, thumbnail,
} from '../lib.js';
import { modCard } from './browse.js';

/// How many recently added mods the strip shows.
const RECENT_COUNT = 8;

export async function render(root) {
  const [list, feed] = await Promise.all([modList(), releaseFeed()]);
  const mods = list.mods || [];
  const releases = feed.releases || [];
  const byId = new Map(mods.map((mod) => [mod.id, mod]));
  const currentVersion = currentGameVersion(mods);

  clear(root);
  root.append(el('div', { class: 'stack' }, [
    searchPanel(mods.length),
    recentlyAdded(mods, currentVersion),
    releasesPanel(releases, byId),
  ]));
}

/// One box with a search field that sends the reader to the browse page.
function searchPanel(total) {
  const box = el('input', {
    type: 'search',
    class: 'search-box',
    placeholder: 'Search for a mod, an author or a category…',
  });
  const button = el('button', { class: 'btn btn-primary', text: 'Search' });
  const search = () => go(buildHash(['browse'], { q: box.value }));

  box.addEventListener('keydown', (e) => { if (e.key === 'Enter') search(); });
  button.addEventListener('click', search);

  return el('div', { class: 'stack' }, [
    el('div', { class: 'page-head' }, [
      el('h1', { text: 'Starsector mods' }),
      el('span', {
        class: 'sub',
        text: `All ${total} of them, from the forum, Discord and Nexus Mods, `
          + 'in one place.',
      }),
    ]),
    el('div', { class: 'search-row' }, [box, button]),
  ]);
}

function releasesPanel(releases, byId) {
  const panel = el('div', { class: 'stack' }, [el('h2', { text: 'Recent releases' })]);

  if (!releases.length) {
    panel.append(el('div', { class: 'notice' }, [
      el('h3', { text: 'No releases yet' }),
      el('p', {
        text: 'Nothing has put out a new version since this started keeping '
          + 'track. New releases turn up here as they happen.',
      }),
    ]));
    return panel;
  }

  for (const [day, ofThatDay] of groupByDay(releases)) {
    const list = el('div', { class: 'release-list' });
    for (const release of ofThatDay) list.append(releaseRow(release, byId));
    panel.append(el('section', { class: 'release-day' }, [
      el('h2', { text: `${formatDay(day)} — ${howLongAgo(day)}` }),
      list,
    ]));
  }
  return panel;
}

/// One release. Where the post gave changelog notes for that version, the row
/// opens to show them as the author wrote them, and says so — a row that opens
/// with nothing to say it does is a row nobody clicks.
function releaseRow(release, byId) {
  const notes = release.changelogNotes;
  const mod = byId.get(release.modId);
  const shownName = mod ? modName(mod) : release.modName;

  const summary = el('summary', {
    title: notes ? 'Read the notes' : null,
  }, [
    notes ? el('span', { class: 'chevron', text: '›', 'aria-hidden': 'true' }) : null,
    thumbnail(mod && mod.imageUrl, 'release-thumb'),
    mod
      ? el('a', { class: 'release-name', href: modHref(release.modId), text: shownName })
      : el('span', { class: 'release-name', text: shownName }),
    el('span', { class: 'badge version', text: release.newVersion }),
    release.oldVersion
      ? el('span', { class: 'release-versions', text: `was ${release.oldVersion}` })
      : null,
    release.gameVersion
      ? el('span', { class: 'badge game', text: release.gameVersion })
      : null,
    notes ? el('span', { class: 'release-read', text: 'Read the notes' }) : null,
  ]);

  const row = el('details', { class: notes ? 'release' : 'release no-notes' }, [summary]);
  if (notes) row.append(el('pre', { class: 'release-notes', text: notes }));
  return row;
}

/// The releases split into days, newest day first. The feed is already in that
/// order, so this only has to group.
function groupByDay(releases) {
  const days = new Map();
  for (const release of releases) {
    if (!days.has(release.seenOn)) days.set(release.seenOn, []);
    days.get(release.seenOn).push(release);
  }
  return [...days.entries()].sort((a, b) => b[0].localeCompare(a[0]));
}

/// A short strip of the mods added most recently, across the top of the page.
/// It is what keeps the page worth reading while the release feed is still
/// filling up.
function recentlyAdded(mods, currentVersion) {
  const newest = mods
    .filter((mod) => mod.addedOn)
    .sort((a, b) => b.addedOn.localeCompare(a.addedOn))
    .slice(0, RECENT_COUNT);

  if (!newest.length) return null;

  const strip = el('div', { class: 'strip' });
  for (const mod of newest) strip.append(modCard(mod, currentVersion));

  return el('section', { class: 'stack' }, [
    el('h2', { text: 'Recently added' }),
    strip,
    el('a', { href: buildHash(['browse'], { sort: 'newest' }), text: 'See them all →' }),
  ]);
}
