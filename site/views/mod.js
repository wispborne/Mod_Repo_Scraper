// One mod's own page, at an address built from its permanent id. The id never
// changes, so this address holds even when the mod's thread is renamed by its
// next release.
//
// A part the mod has nothing for is left out entirely rather than drawn empty,
// so a thin page reads as deliberate instead of broken.

import {
  aiSummariesOn, breadcrumbs, clear, currentGameVersion, el, errorPanel,
  formatDay, joinNames, modDetail, modHref, modList, modName, picture,
  PROBLEM_REPORT_BASE, sourceName, versionStanding, versionStandingNote,
} from '../lib.js';

/// Plain names for the support links, keyed by the type the scraper works out.
const SUPPORT_NAMES = {
  patreon: 'Patreon',
  kofi: 'Ko-fi',
  paypal: 'PayPal',
  buymeacoffee: 'Buy Me a Coffee',
  liberapay: 'Liberapay',
  subscribestar: 'SubscribeStar',
  boosty: 'Boosty',
  opencollective: 'Open Collective',
  githubsponsors: 'GitHub Sponsors',
  other: 'Support the author',
};

export async function render(root, parts) {
  const id = parts[0];
  if (!id) {
    clear(root).append(errorPanel(new Error('No mod was named in the address.')));
    return;
  }

  let detail;
  try {
    detail = await modDetail(id);
  } catch {
    clear(root).append(el('div', { class: 'notice' }, [
      el('h3', { text: 'No such mod' }),
      el('p', { text: `There is no mod at "${id}". It may have been taken down, `
        + 'or the link may be wrong.' }),
      el('p', {}, [el('a', { href: '#/browse', text: 'Browse every mod →' })]),
    ]));
    return;
  }

  const mod = detail.listing || {};
  const shownName = modName(mod);
  document.title = `${shownName} — Starmodder`;

  // Only so the game-version badge can say whether this is the current release.
  // The list is already loaded, so it costs nothing; if it will not load, the
  // badge simply says nothing extra.
  let currentVersion = null;
  try {
    currentVersion = currentGameVersion((await modList()).mods || []);
  } catch {
    currentVersion = null;
  }

  clear(root);
  root.append(breadcrumbs([
    { label: 'Browse mods', href: '#/browse' },
    { label: shownName },
  ]));
  root.append(el('div', { class: 'stack' }, [
    header(mod, shownName, currentVersion),
    needsLine(mod),
    downloads(detail),
    description(detail),
    gallery(detail),
    changelog(detail),
    releases(detail),
    addons(detail),
    facts(detail),
    olderVersions(detail),
    reportProblem(detail, shownName),
  ]));
}

function header(mod, shownName, currentVersion) {
  const meta = el('div', { class: 'mod-meta' });
  if (mod.modVersion) meta.append(el('span', { class: 'badge version', text: mod.modVersion }));
  if (mod.gameVersion) {
    meta.append(el('span', {
      class: `badge game ${versionStanding(mod, currentVersion) || ''}`.trim(),
      text: `For Starsector ${mod.gameVersion}`,
      title: versionStandingNote(versionStanding(mod, currentVersion)),
    }));
  }
  if (mod.isWorkInProgress) meta.append(el('span', { class: 'badge wip', text: 'Work in progress' }));
  if (mod.saveCompatible === true) {
    meta.append(el('span', { class: 'badge save-ok', text: 'Can be added to an existing save' }));
  } else if (mod.saveCompatible === false) {
    meta.append(el('span', { class: 'badge save-no', text: 'Needs a new game' }));
  }

  const authors = el('div', { class: 'card-authors' });
  (mod.authors || []).forEach((name, i) => {
    if (i) authors.append(document.createTextNode(', '));
    authors.append(el('a', { href: `#/authors/${encodeURIComponent(name)}`, text: name }));
  });

  return el('div', { class: 'page-head' }, [
    el('h1', { text: shownName }),
    // The thread's own title, where it says more than the name does.
    shownName === mod.name
      ? null
      : el('span', { class: 'sub thread-title', text: mod.name }),
    (mod.authors || []).length ? authors : null,
    meta,
  ]);
}

/// What this mod will not run without, right under the header.
///
/// Nearly every Starsector mod needs LazyLib, MagicLib, GraphicsLib or
/// Nexerelin, and finding that out after the download — from a crash on
/// startup — is the oldest annoyance in Starsector modding. Each one we have a
/// page for is a link; the rest are still named.
function needsLine(mod) {
  const needs = mod.needs || [];
  if (!needs.length) return null;

  // The names sit in one span of their own, so the commas stay against the
  // name in front of them rather than being spaced out as flex children.
  const names = el('span', { class: 'needs-list' });
  needs.forEach((needed, i) => {
    if (i) names.append(document.createTextNode(', '));
    names.append(needed.id
      ? el('a', { class: 'needed', href: modHref(needed.id), text: needed.name })
      : el('span', { class: 'needed unknown', text: needed.name,
          title: 'This site has no page for that one.' }));
  });

  return el('div', { class: 'needs-line' }, [
    el('span', { class: 'needs-label', text: 'Needs' }),
    names,
  ]);
}

function downloads(detail) {
  const list = detail.downloads || [];
  if (!list.length) return null;

  const box = el('div', { class: 'download-list' });
  for (const download of list) box.append(downloadRow(download));
  return el('section', { class: 'panel' }, [
    el('h2', { text: 'Download' }),
    box,
    detail.generatedAt
      ? el('p', {
          class: 'checked-on',
          text: `Last checked ${formatDay(detail.generatedAt)}.`,
          title: "When these links were last read off the mod's post.",
        })
      : null,
  ]);
}

function downloadRow(download) {
  const label = download.kind === 'mirror' ? 'Mirror'
    : download.kind === 'trios' ? 'Install with TriOS'
      : 'Download';
  return el('div', { class: 'download' }, [
    el('a', {
      class: 'btn btn-primary',
      href: download.directUrl || download.url,
      rel: 'noopener nofollow',
      target: '_blank',
      text: label,
    }),
    download.fileName ? el('span', { class: 'file', text: download.fileName }) : null,
    download.host ? el('span', { class: 'badge', text: download.host }) : null,
    download.needsAnotherStep
      ? el('span', {
          class: 'badge', text: 'Needs another click',
          title: "The host's own page opens first; the file comes after that.",
        })
      : null,
  ]);
}

/// The description, and the AI note when the words were written rather than
/// copied. With AI summaries off, an AI-written description is left out
/// altogether — no gap, no placeholder.
function description(detail) {
  const formatted = detail.descriptionHtml;
  const text = detail.description;
  if (!formatted && !text) return null;
  if (detail.descriptionIsGenerated && !aiSummariesOn()) return null;

  // The formatted description is built by the scraper from a short list of safe
  // tags — no scripts, no styles, nothing that loads from another host — so it
  // is put into the page as it arrives. Anything else is shown as plain words.
  const body = formatted
    ? el('div', {
        class: detail.descriptionIsGenerated ? 'prose generated' : 'prose',
        html: formatted,
      })
    : el('div', {
        class: detail.descriptionIsGenerated ? 'prose plain generated' : 'prose plain',
        text,
      });

  return el('section', { class: 'panel' }, [
    el('h2', { text: 'About this mod' }),
    body,
    detail.descriptionIsGenerated
      ? el('p', {
          class: 'ai-note',
          text: 'Written by an AI from the mod\'s post, not copied from it.',
        })
      : null,
  ]);
}

function gallery(detail) {
  const images = detail.gallery || [];
  if (!images.length) return null;

  // A picture that will not load takes its link with it, so the grid holds no
  // empty boxes to click on.
  const grid = el('div', { class: 'gallery' });
  for (const image of images) {
    const link = el('a', { href: image.url, target: '_blank', rel: 'noopener' });
    link.append(picture(image.url, {
      alt: image.caption || '',
      title: image.caption || null,
      whenBroken: () => link.remove(),
    }));
    grid.append(link);
  }
  return el('section', { class: 'panel' }, [
    el('h2', { text: 'Screenshots' }), grid,
  ]);
}

function changelog(detail) {
  const entries = Object.entries(detail.changelog || {});
  if (!entries.length && !detail.changelogUrl) return null;

  const box = el('div', {});
  entries.forEach(([version, notes], i) => {
    box.append(el('details', { class: 'changelog-entry', open: i === 0 ? '' : null }, [
      el('summary', { text: version }),
      el('pre', { text: notes }),
    ]));
  });
  if (detail.changelogUrl) {
    box.append(el('p', {}, [
      el('a', {
        href: detail.changelogUrl, target: '_blank', rel: 'noopener nofollow',
        text: 'The full changelog →',
      }),
    ]));
  }
  return el('section', { class: 'panel' }, [
    el('h2', { text: 'Changelog' }), box,
  ]);
}

function releases(detail) {
  const list = detail.releases || [];
  if (!list.length) return null;

  const rows = el('div', { class: 'release-list' });
  for (const release of list) {
    rows.append(el('details', { class: release.changelogNotes ? 'release' : 'release no-notes' }, [
      el('summary', {}, [
        el('span', { class: 'badge version', text: release.newVersion }),
        el('span', {
          class: 'release-versions',
          text: release.oldVersion
            ? `from ${release.oldVersion} on ${formatDay(release.seenOn)}`
            : formatDay(release.seenOn),
        }),
      ]),
      release.changelogNotes
        ? el('pre', { class: 'release-notes', text: release.changelogNotes })
        : null,
    ]));
  }
  return el('section', { class: 'panel' }, [
    el('h2', { text: 'Release history' }), rows,
  ]);
}

function addons(detail) {
  const list = detail.addons || [];
  if (!list.length) return null;

  const box = el('div', { class: 'stack' });
  for (const addon of list) {
    box.append(el('div', {}, [
      el('h3', { text: addon.name }),
      addon.requires
        ? el('div', { class: 'card-authors', text: `Needs ${addon.requires}` })
        : null,
      el('div', { class: 'download-list' }, (addon.downloads || []).map(downloadRow)),
    ]));
  }
  return el('section', { class: 'panel' }, [
    el('h2', { text: 'Add-ons on the same thread' }), box,
  ]);
}

/// The links out, the license and the support links. The whole box is left out
/// when the mod has none of them.
function facts(detail) {
  const rows = [];
  const link = (label, url, text) => {
    if (!url) return;
    rows.push([label, el('a', {
      href: url, target: '_blank', rel: 'noopener nofollow', text: text || url,
    })]);
  };

  link('Forum thread', detail.forumUrl, 'On the Starsector forum');
  link('Discord', detail.discordUrl, 'On Discord');
  link('Nexus Mods', detail.nexusUrl, 'On Nexus Mods');
  link('Source code', detail.sourceCodeUrl);
  if (detail.license) rows.push(['License', el('span', { text: detail.license })]);
  if (detail.saveCompatibilityText) {
    rows.push(['Save compatibility',
      el('span', { text: detail.saveCompatibilityText })]);
  }
  const listing = detail.listing || {};
  if ((listing.categories || []).length) {
    rows.push(['Category', el('span', { text: joinNames(listing.categories) })]);
  }
  // What each source actually called it, which is not always what the site
  // does. Left out when it says nothing the line above did not.
  const raw = detail.rawCategories || [];
  if (raw.length && joinNames(raw) !== joinNames(listing.categories || [])) {
    rows.push(['Filed under', el('span', {
      class: 'dim', text: joinNames(raw),
      title: 'The shelves the forum and Discord file this mod under.',
    })]);
  }
  if ((listing.sources || []).length) {
    rows.push(['Found on',
      el('span', { text: joinNames(listing.sources.map(sourceName)) })]);
  }

  const support = detail.supportLinks || [];
  if (support.length) {
    const links = el('span', { class: 'link-list' });
    for (const one of support) {
      links.append(el('a', {
        href: one.url, target: '_blank', rel: 'noopener nofollow',
        text: SUPPORT_NAMES[one.type] || SUPPORT_NAMES.other,
      }));
    }
    rows.push(['Support the author', links]);
  }

  if (!rows.length) return null;

  const facts = el('dl', { class: 'fact-list' });
  for (const [label, value] of rows) {
    facts.append(el('dt', { text: label }), el('dd', {}, [value]));
  }
  return el('section', { class: 'panel' }, [
    el('h2', { text: 'Details' }), facts,
  ]);
}

/// Older threads for the same mod. There are none yet — matching an old thread
/// to the mod it became is a separate job — so this box stays out of the way
/// until there are.
function olderVersions(detail) {
  const list = detail.olderVersions || [];
  if (!list.length) return null;

  const rows = el('div', { class: 'mod-rows' });
  for (const older of list) {
    rows.append(el('a', {
      class: 'mod-row', href: older.url, target: '_blank', rel: 'noopener nofollow',
    }, [
      el('div', { class: 'row-main' }, [
        el('div', { class: 'row-title', text: older.title }),
        el('div', {
          class: 'row-sub',
          text: [older.modVersion, older.gameVersion].filter(Boolean).join(' · '),
        }),
      ]),
    ]));
  }
  return el('section', { class: 'panel' }, [
    el('h2', { text: 'Older versions' }), rows,
  ]);
}

/// A line at the foot of every mod page for saying something here is wrong.
///
/// Everything on this page was read off somebody else's post by a machine, so
/// some of it will be wrong. A mod author who wants an entry fixed, or a mod
/// taken down, needs one obvious place to say so — and the message arrives
/// naming the mod, so nobody has to work out which page it was about.
function reportProblem(detail, shownName) {
  const mod = detail.listing || {};
  const params = new URLSearchParams({
    title: `Wrong data for ${shownName}`,
    body: `Mod page: ${location.origin}${location.pathname}#/mods/${mod.id}\n`
      + `Mod id: ${mod.id}\n\n`
      + 'What is wrong:\n',
  });

  return el('p', { class: 'report-problem' }, [
    el('a', {
      href: `${PROBLEM_REPORT_BASE}?${params}`,
      target: '_blank',
      rel: 'noopener nofollow',
      text: 'Something wrong on this page?',
    }),
    el('span', { text: ' — this is collected automatically, so tell us and it '
      + 'gets fixed.' }),
  ]);
}
