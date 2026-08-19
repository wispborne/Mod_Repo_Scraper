// Home: what the site is in one line, a search box, the kinds of mod, then
// what came out recently.
//
// The release feed is the heart of the page. It is not "threads somebody
// replied to" — it is mods whose version actually moved forward, worked out by
// comparing saved copies of the data over time.

import {
  buildHash, categoryChips, clear, currentGameVersion, el, formatDay, go,
  howLongAgo, modHref, modList, modName, releaseFeed, thumbnail,
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

  // The order the plan asks for: what this is in one line, the search box, the
  // kinds of mod, then the releases. The mods added recently come last —
  // pleasant, but not what anybody came for.
  clear(root);
  root.append(el('div', { class: 'stack' }, [
    front(mods.length),
    browseByKind(mods),
    releasesPanel(releases, byId),
    feedLine(),
    recentlyAdded(mods, currentVersion),
  ]));
}

/// The front of the site: what it is in one line, and a search box.
///
/// A reader arriving here has one of two things in mind — a mod they can name,
/// or no idea yet. The search box answers the first and the chips under it
/// answer the second, so between them they cover everybody who arrives.
function front(total) {
  const box = el('input', {
    type: 'search',
    class: 'search-box',
    placeholder: 'Search for a mod, a person or a kind of mod…',
    'aria-label': 'Search mods',
  });
  const button = el('button', { class: 'btn btn-primary', text: 'Search' });
  const search = () => go(buildHash(['browse'], { q: box.value }));

  box.addEventListener('keydown', (e) => { if (e.key === 'Enter') search(); });
  button.addEventListener('click', search);

  return el('section', { class: 'front' }, [
    el('h1', { text: 'Every Starsector mod, in one place' }),
    el('p', {
      class: 'front-promise',
      text: `All ${total} of them, from the forum, Discord and Nexus Mods, with `
        + 'what each one needs and what came out this week.',
    }),
    el('div', { class: 'search-row' }, [box, button]),
    el('p', {
      class: 'front-hint',
      text: 'Or press / from anywhere on the site.',
    }),
  ]);
}

/// The line offering the release feed. Feed readers are where a lot of modders
/// and server admins actually live, so this is the one way somebody hears about
/// a release without coming back to look. It is on the page whether or not
/// anything has been released yet — that is exactly when subscribing helps.
function feedLine() {
  return el('p', { class: 'feed-note' }, [
    el('span', { text: 'Would rather be told? ' }),
    el('a', { href: 'updates.xml', text: 'Subscribe to the release feed' }),
    el('span', { text: ' in any feed reader.' }),
  ]);
}

/// The categories, as a row of chips, right under the search box. It is the
/// front door for a reader who does not know what they are looking for yet.
function browseByKind(mods) {
  const chips = categoryChips(mods);
  if (!chips) return null;

  return el('section', { class: 'stack' }, [
    el('h2', { class: 'quiet-heading', text: 'Browse by kind' }),
    chips,
  ]);
}

function releasesPanel(releases, byId) {
  const panel = el('div', { class: 'stack' }, [
    el('h2', { class: 'quiet-heading', text: 'Recent releases' }),
  ]);

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
    // A day sits inside "Recent releases", so it is a step down from it. An
    // h2 inside an h2 reads to a screen reader as two things of equal weight.
    panel.append(el('section', { class: 'release-day' }, [
      el('h3', { text: `${formatDay(day)} — ${howLongAgo(day)}` }),
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

/// A short strip of the mods added most recently, at the foot of the page.
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
    el('h2', { class: 'quiet-heading', text: 'Recently added' }),
    strip,
    el('a', { href: buildHash(['browse'], { sort: 'newest' }), text: 'See them all →' }),
  ]);
}
