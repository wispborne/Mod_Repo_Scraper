// One mod's own page, at an address built from its permanent id. The id never
// changes, so this address holds even when the mod's thread is renamed by its
// next release.
//
// A part the mod has nothing for is left out entirely rather than drawn empty,
// so a thin page reads as deliberate instead of broken.

import {
  aiOnModPages, aiSparkle, aiSummaryNote, aiSummaryOf,
  clear,
  currentGameVersion, DATA_BASE, downloadButton, el, errorPanel, expandAllButton, formatDay,
  favoriteToggle, formatMoment, imageUrlOf, inlinePictures, joinNames,
  setAiOnModPages, setInlinePictures, summaryToShow,
  modDetail, modHref, modList, modName, MOD_VERSION_NOTE,
  NO_DESCRIPTION, pageIcon, picture, showPicture, sourceName, summaryTitle,
  versionStanding, versionStandingNote,
} from '../lib.js';
import { address } from '../address.js';
import { modCard } from './browse.js';

const RELATED_COUNT = 6;

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
};

/// What a support link's button says. A site with a name of its own (Patreon,
/// Ko-fi…) is called by it, the same on every mod. Any other is called by the
/// words the model gave it, or failing those by its host — never by one shared
/// word, or a mod with three such links shows three identical buttons.
function supportName(link) {
  if (SUPPORT_NAMES[link.type]) return SUPPORT_NAMES[link.type];
  if (link.label) return link.label;
  try {
    return new URL(link.url).host.replace(/^www\./, '');
  } catch {
    return 'Donate';
  }
}

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
  document.title = `${shownName} | Starmodder`;

  // The list is also what the two "more like this" strips at the foot are
  // built from. A page that will not load it still draws everything else.
  let everyMod = [];
  try {
    everyMod = (await modList()).mods || [];
  } catch {
    everyMod = [];
  }
  const currentVersion = currentGameVersion(everyMod);

  clear(root);
  // A small link back rather than the full breadcrumb trail every other page
  // carries: the nav bar already says where Home and Browse are, and the
  // room is worth more to the cards at the side.
  root.append(el('a', { class: 'back-link', href: '#/browse', text: '‹ Browse mods' }));

  // CSS places download buttons before the post on narrow screens.
  root.append(el('div', { class: 'stack' }, [
    modHeader(mod, detail, shownName, currentVersion),
    el('div', { class: 'mod-layout' }, [
      el('div', { class: 'mod-main stack' }, [
        sameNameMods(detail),
        tabs(id, [
          { label: 'Description', parts: [aiSummary(detail, mod), description(detail)] },
          { label: 'Gallery', count: (detail.gallery || []).length, parts: [gallery(detail)] },
          // The author's changelog and the releases this site noticed are one
          // question — what changed, and when — so they share a tab.
          { label: 'Recent Updates', parts: [changelog(detail), releases(detail)] },
          { label: 'Add-ons', count: (detail.addons || []).length, parts: [addons(detail)] },
        ]),
      ]),
      // One column that stays in view while the post is read. On a narrow
      // screen it stands aside (`display: contents`) so its two parts can sit
      // either side of the mod.
      el('div', { class: 'mod-aside' }, [
        el('aside', { class: 'mod-side-top' }, [howToGetIt(mod, detail)]),
        el('aside', { class: 'mod-side stack' }, [
          compatibility(detail, currentVersion),
          linksOut(detail),
          facts(detail),
          downloads(detail),
        ]),
      ]),
    ]),
    moreByTheAuthor(mod, everyMod, currentVersion),
    similarMods(mod, everyMod, currentVersion),
    rawInfo(detail, id),
  ]));
}

/// The mod's sections as tabs. A tab with nothing in it is not drawn, and a mod
/// with only one has no tab row at all.
///
/// The open tab is kept in the address as a plain hash after the mod's own
/// path — `mods/<id>/#gallery` — so a link can open a mod on a tab. On a mod's
/// page the route is read from the path alone, so the hash names no page. The
/// first tab is the page as it opens and writes no hash. A move between tabs
/// replaces the address rather than adding to the history, so Back leaves the
/// mod instead of stepping back through its tabs.
///
/// Each tab is a real link to that address, so it can be copied or opened in a
/// new tab. A plain click is kept on this page: the site's link handling would
/// otherwise read `#gallery` on the site's root as a page called "gallery".
function tabs(modId, list) {
  const shown = list
    .map((tab) => ({ ...tab, parts: tab.parts.filter(Boolean), key: tabKey(tab.label) }))
    .filter((tab) => tab.parts.length);
  if (!shown.length) return null;
  if (shown.length === 1) return el('div', { class: 'stack' }, shown[0].parts);

  const addressOf = (tab) => (tab === shown[0]
    ? modHref(modId)
    : `${modHref(modId)}#${tab.key}`);

  const bar = el('div', { class: 'mod-tabs', role: 'tablist' });
  const holder = el('div', { class: 'stack' });
  const links = shown.map((tab) => {
    const link = el('a', {
      class: 'mod-tab', role: 'tab', href: addressOf(tab),
    }, [
      tab.label,
      tab.count ? el('span', { class: 'mod-tab-count', text: String(tab.count) }) : null,
    ]);
    link.addEventListener('click', (e) => {
      if (e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
      e.preventDefault();
      open(tab);
      address().replace(addressOf(tab));
    });
    bar.append(link);
    return link;
  });
  const open = (tab) => {
    shown.forEach((one, i) => {
      links[i].classList.toggle('on', one === tab);
      links[i].setAttribute('aria-selected', String(one === tab));
    });
    holder.replaceChildren(...tab.parts);
  };

  // A hash that names no tab here, or a tab this mod has nothing in, opens
  // the first one.
  const asked = location.hash.replace(/^#/, '');
  open(shown.find((tab) => tab.key === asked) || shown[0]);
  return el('div', { class: 'stack' }, [bar, holder]);
}

/// A tab's name as it is written in the address: "Recent Updates" is
/// `recent-updates`.
function tabKey(label) {
  return label.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}

function modHeader(mod, detail, shownName, currentVersion) {
  const chips = el('div', { class: 'mod-meta' });
  if (mod.gameVersion) {
    chips.append(el('span', {
      class: `badge game ${versionStanding(mod, currentVersion) || ''}`.trim(),
      text: `For Starsector ${mod.gameVersion}`,
      title: versionStandingNote(versionStanding(mod, currentVersion)),
    }));
  }
  if (mod.modVersion) {
    chips.append(el('span', {
      class: 'badge version', text: mod.modVersion, title: MOD_VERSION_NOTE,
    }));
  }
  if (mod.isWorkInProgress) chips.append(el('span', { class: 'badge wip', text: 'Work in progress' }));
  if (mod.isTool) {
    chips.append(el('span', {
      class: 'badge tool', text: 'Tool',
      title: 'A separate program, such as a launcher or mod editor.',
    }));
  }
  for (const category of mod.categories || []) {
    chips.append(el('span', { class: 'badge', text: category }));
  }

  const byline = el('div', { class: 'mod-byline' });
  if ((mod.authors || []).length) {
    const authors = el('span', { class: 'mod-authors' }, ['by ']);
    mod.authors.forEach((name, i) => {
      if (i) authors.append(document.createTextNode(', '));
      authors.append(el('a', { href: `#/authors/${encodeURIComponent(name)}`, text: name }));
    });
    byline.append(authors);
  }
  byline.append(chips);

  return el('div', { class: 'mod-head' }, [
    headPicture(mod),
    el('div', { class: 'mod-head-words' }, [
      el('h1', { text: shownName }),
      // The thread's own title, where it says more than the name does.
      shownName === mod.name
        ? null
        : el('span', { class: 'sub thread-title' }, [
          'Original title: ',
          el('i', { text: mod.name }),
        ]),
      partOfThreadLine(mod),
      el('div', { class: 'mod-summary-slot' }, [headSummary(mod)]),
      byline,
    ]),
  ]);
}

function headSummary(mod) {
  let summary = summaryToShow(mod);
  if (summary?.generated && aiOnModPages() === 'hide') {
    summary = !mod.summaryIsGenerated && mod.summary
      ? { text: mod.summary, generated: false }
      : null;
  }
  if (!summary) return null;
  return el('p', {
    class: 'mod-summary',
    title: summaryTitle(summary),
  }, [summary.generated ? aiSparkle(summary.text) : null,
    summary.generated ? ' ' : null, summary.text]);
}

function headPicture(mod) {
  const url = imageUrlOf(mod);
  if (!url) return null;
  const box = el('button', {
    class: 'mod-head-picture', type: 'button', title: 'Open the picture',
  });
  box.append(picture(url, { alt: '', whenBroken: () => box.remove() }));
  box.addEventListener('click', () => showPicture([{ url, caption: null }], 0));
  return box;
}

function partOfThreadLine(mod) {
  if (!mod.partOfThreadTitle) return null;
  const line = el('div', { class: 'sub part-of' }, [
    document.createTextNode('Part of '),
  ]);
  line.append(mod.forumUrl
    ? el('a', {
        href: mod.forumUrl, target: '_blank', rel: 'noopener nofollow',
        text: mod.partOfThreadTitle,
        title: 'A forum thread with several mods, including this one.',
      })
    : el('span', { text: mod.partOfThreadTitle }));
  line.append(document.createTextNode(', a thread with several mods.'));
  return line;
}

// Adapt a full download to the shared button’s compact download shape.
function bestOf(download) {
  return {
    url: download.directUrl || download.url,
    kind: download.kind,
    // A TriOS link is never counted as needing another step: opening it is the
    // point of it. The same rule the builder sorts by.
    needsAnotherStep: download.kind !== 'trios' && Boolean(download.needsAnotherStep),
  };
}

const PLACES = [
  { field: 'forumUrl', alone: 'Get it from the forum thread', also: 'Forum' },
  { field: 'discordUrl', alone: 'Get it from Discord', also: 'Discord' },
];

// Downloads are already sorted by the builder. Offer a plain download
// below a TriOS link for readers who do not use TriOS.
function howToGetIt(mod, detail) {
  const list = detail.downloads || [];
  const first = list[0];
  const card = el('section', { class: 'panel side-card get-it' });
  // When the links were last read from the post, on hover over the download
  // buttons rather than a line of its own.
  const checked = detail.generatedAt
    ? `Links last checked ${formatMoment(detail.generatedAt)}`
    : null;

  if (first) {
    const main = downloadButton(
      { ...mod, bestDownload: bestOf(first), downloadCount: 1 },
      { big: true },
    );
    main.classList.add('btn-solid');
    if (checked) main.title = checked;
    card.append(main);
  }

  // Everything but the main button shares one row of smaller buttons, so the
  // card stays short.
  const row = el('div', { class: 'get-it-row' });
  const plain = first?.kind === 'trios' ? list.find((d) => d.kind !== 'trios') : null;
  if (plain) row.append(plainDownloadButton(plain, checked));
  const place = PLACES.find((p) => detail[p.field]);
  if (place) {
    const icon = pageIcon(place.field);
    const button = el('a', {
      class: `btn btn-with-icon${first ? '' : ' btn-big'}`,
      href: detail[place.field],
      rel: 'noopener nofollow',
      target: '_blank',
    }, [
      icon
        ? el('span', { class: 'original-page-icon', html: icon, 'aria-hidden': 'true' })
        : null,
      el('span', { text: first ? place.also : place.alone }),
    ]);
    if (first) {
      row.append(button);
    } else {
      button.classList.add('btn-solid');
      card.append(button);
    }
  }
  const favorite = favoriteToggle(mod, { wide: true });
  favorite.classList.remove('btn-big');
  row.append(favorite);
  card.append(row);

  // The source code and the support links share one quiet line at the foot.
  // `append` writes a missing value out as the word "null", so a mod with
  // neither must add nothing at all.
  const source = sourceCodeLink(detail);
  const support = supportLinks(detail);
  if (source || support) {
    card.append(el('div', { class: 'card-foot-line' }, [source, support]));
  }
  return card;
}

/// Plain names for the places a mod's code is kept, by host.
const CODE_HOSTS = {
  'github.com': 'GitHub',
  'gitlab.com': 'GitLab',
  'bitbucket.org': 'Bitbucket',
  'codeberg.org': 'Codeberg',
  'sourceforge.net': 'SourceForge',
};

/// A small link to the mod's code, at the foot of the download card. Sharing
/// the code is a gift to other modders — they can learn from it, fix it, and
/// keep it alive after the author moves on — so it sits beside the download
/// rather than down in the list of links, but quietly: a note in the author's
/// favour, not another button competing with the download.
function sourceCodeLink(detail) {
  const url = detail.sourceCodeUrl;
  if (!url) return null;
  let host = '';
  try {
    host = new URL(url).host.replace(/^www\./, '');
  } catch {
    return null;
  }
  return el('a', {
    class: 'source-link',
    href: url, target: '_blank', rel: 'noopener nofollow',
    title: `The mod's source code, on ${CODE_HOSTS[host] || host}`,
  }, [
    el('span', { class: 'original-page-icon', html: CODE_ICON, 'aria-hidden': 'true' }),
    'Source code',
  ]);
}

function plainDownloadButton(download, checked) {
  const extension = /\.(zip|7z|rar|jar|tar\.gz|exe)$/i.exec(download.fileName || '');
  const label = download.needsAnotherStep ? 'Download page'
    : extension ? `Download .${extension[1].toLowerCase()}` : 'Download';
  return el('a', {
    class: 'btn btn-with-icon',
    href: download.directUrl || download.url,
    rel: 'noopener nofollow',
    target: '_blank',
    title: [download.fileName, checked].filter(Boolean).join('\n') || null,
  }, [
    el('span', { class: 'original-page-icon', html: DOWNLOAD_ICON, 'aria-hidden': 'true' }),
    el('span', { text: label }),
  ]);
}

// Tabler download icon.
const DOWNLOAD_ICON = '<svg viewBox="0 0 24 24" width="1em" height="1em" fill="none" '
  + 'stroke="currentColor" stroke-width="2" stroke-linecap="round" '
  + 'stroke-linejoin="round" focusable="false" aria-hidden="true">'
  + '<path d="M4 17v2a2 2 0 0 0 2 2h12a2 2 0 0 0 2 -2v-2"/>'
  + '<path d="M7 11l5 5l5 -5"/><path d="M12 4l0 12"/></svg>';

/// Where readers can support the author, as one line at the foot of the
/// download card: near the moment a reader decides the mod is worth having,
/// without a card of its own or competing with the download itself.
function supportLinks(detail) {
  const support = detail.supportLinks || [];
  if (!support.length) return null;

  return el('span', { class: 'support-row' }, [
    el('span', { class: 'support-label', text: 'Support' }),
    el('span', { class: 'support-links' }, support.map((one) => el('a', {
      href: one.url,
      target: '_blank',
      rel: 'noopener nofollow',
      text: supportName(one),
      title: one.url,
    }))),
  ]);
}

function downloads(detail) {
  const list = detail.downloads || [];
  if (!list.length) return null;

  const box = el('div', { class: 'side-downloads' });
  for (const download of list) box.append(downloadRow(download));
  return el('section', { class: 'panel side-card' }, [
    el('h2', { class: 'side-heading', text: list.length === 1 ? 'Download' : 'All downloads' }),
    box,
    detail.changelogUrl
      ? el('a', {
          class: 'side-more',
          href: detail.changelogUrl, target: '_blank', rel: 'noopener nofollow',
          text: 'Full changelog →',
        })
      : null,
  ]);
}

function downloadRow(download) {
  const label = download.kind === 'trios' ? 'Install with TriOS'
    : download.fileName || (download.kind === 'mirror' ? 'Mirror' : 'Download');
  return el('div', { class: 'download' }, [
    el('a', {
      class: 'download-name',
      href: download.directUrl || download.url,
      rel: 'noopener nofollow',
      target: '_blank',
      text: label,
      title: download.needsAnotherStep
        ? "Opens the download page rather than the file."
        : (download.kind === 'mirror' ? 'A mirror of the main download.' : null),
    }),
    download.host ? el('span', { class: 'badge', text: download.host }) : null,
  ]);
}

// Author text only; generated descriptions are shown by aiSummary.
function description(detail, { collapsed = false } = {}) {
  const generated = Boolean(detail.descriptionIsGenerated);
  const formatted = generated ? null : detail.descriptionHtml;
  const text = generated ? null : detail.description;
  const own = Boolean(formatted || text);

  if (!own) {
    return el('section', { class: 'panel' }, [
      el('h2', { text: 'About this mod' }),
      el('p', { class: 'no-description', text: NO_DESCRIPTION }),
    ]);
  }

  // descriptionHtml is sanitized by the builder; plain descriptions use textContent.
  const body = formatted
    ? postBody(formatted)
    : el('div', { class: 'prose plain', text });
  continuedOnTheForum(body, detail.forumUrl);

  const clip = el('div', { class: `prose-clip${collapsed ? ' clipped' : ''}` }, [body]);
  const fold = el('button', {
    class: 'link-button pictures-switch',
    type: 'button',
    text: collapsed ? 'Show full description' : 'Collapse',
    'aria-expanded': String(!collapsed),
  });
  fold.addEventListener('click', () => {
    collapsed = !collapsed;
    clip.classList.toggle('clipped', collapsed);
    fold.textContent = collapsed ? 'Show full description' : 'Collapse';
    fold.setAttribute('aria-expanded', String(!collapsed));
  });
  // Images can change the post height after it is attached.
  const settle = () => {
    if (!clip.isConnected) return;
    const preview = parseFloat(getComputedStyle(body).fontSize) * PREVIEW_LINES;
    fold.hidden = body.offsetHeight <= preview + 1;
  };
  if (typeof ResizeObserver !== 'undefined') new ResizeObserver(settle).observe(body);
  setTimeout(settle, 0);

  const section = el('section', { class: 'panel' }, [
    el('div', { class: 'section-head' }, [
      el('h2', { text: 'About this mod' }),
      el('span', { class: 'description-switches' }, [
        formatted && /<img\s/i.test(formatted)
          ? picturesSwitch(() => section.replaceWith(description(detail, { collapsed })))
          : null,
        fold,
      ]),
    ]),
    clip,
  ]);
  return section;
}

// Keep in step with `.prose-clip.clipped` in style.css.
const PREVIEW_LINES = 14;

/// A post too long to publish whole ends with a "…" paragraph (the builder's
/// cap, `maxDescriptionLength`). That is turned into a link to the thread, so
/// the reader is told where the rest is rather than left at a dot-dot-dot.
function continuedOnTheForum(body, forumUrl) {
  const last = body.lastElementChild;
  if (!forumUrl || !last || last.tagName !== 'P' || last.textContent.trim() !== '…') return;
  last.replaceChildren(el('a', {
    href: forumUrl, target: '_blank', rel: 'noopener nofollow',
    text: 'Continued on the forum →',
  }));
}

function picturesSwitch(redraw) {
  const on = inlinePictures() !== 'off';
  const button = el('button', {
    class: 'link-button pictures-switch',
    type: 'button',
    text: on ? 'Hide pictures' : 'Show pictures',
    title: 'Applies to all mod descriptions. Also available in Settings.',
  });
  button.addEventListener('click', () => {
    setInlinePictures(on ? 'off' : 'on');
    redraw();
  });
  return button;
}

// Parse in a template so hidden pictures do not start downloading.
// Preserve image-only links as text when removing their pictures.
function postBody(html) {
  const template = document.createElement('template');
  template.innerHTML = html;
  const content = template.content;
  const showPictures = inlinePictures() !== 'off';

  // The pictures the viewer steps through, in the order the post has them.
  const viewable = [];
  const open = (image) => showPicture(viewable, viewable.indexOf(image));

  for (const video of [...content.querySelectorAll('a.video-link')]) {
    youTubePreview(video, showPictures);
  }

  for (const img of [...content.querySelectorAll('img')]) {
    // A video's thumbnail was seen to above.
    if (img.closest('a.video-link')) continue;
    const image = {
      url: img.getAttribute('src'),
      caption: img.getAttribute('alt') || null,
    };
    const link = img.closest('a');
    const onlyContentOfLink = Boolean(link)
      && link.textContent.trim() === ''
      && link.querySelectorAll('img').length === 1;

    // What is left of a picture inside a link once the picture is gone.
    const linkWords = () => document.createTextNode(link.getAttribute('href'));

    if (!showPictures) {
      if (link) {
        if (onlyContentOfLink) img.replaceWith(linkWords());
        else img.remove();
        continue;
      }
      viewable.push(image);
      const stand = el('button', {
        class: 'link-button inline-picture-link',
        type: 'button',
        text: 'picture',
        title: image.caption || 'Open this picture',
      });
      stand.addEventListener('click', () => open(image));
      img.replaceWith(stand);
      continue;
    }

    img.addEventListener('error', () => {
      const gone = viewable.indexOf(image);
      if (gone >= 0) viewable.splice(gone, 1);
      if (onlyContentOfLink) img.replaceWith(linkWords());
      else img.remove();
    });
    if (!link) {
      viewable.push(image);
      img.classList.add('inline-picture');
      img.addEventListener('click', () => open(image));
    }
  }

  const body = el('div', { class: 'prose' });
  body.append(content);
  return body;
}

// Load the YouTube player only on an unmodified click.
function youTubePreview(link, showPictures) {
  const thumb = link.querySelector('img');
  const asWords = () => {
    link.classList.add('as-words');
    link.replaceChildren('▶ Video on YouTube');
  };
  if (!showPictures || !thumb) {
    asWords();
    return;
  }
  thumb.addEventListener('error', asWords);

  let id = null;
  try {
    id = new URL(link.getAttribute('href')).searchParams.get('v');
  } catch {
    // Not an address; it stays a plain link.
  }
  if (!id || !/^[A-Za-z0-9_-]{11}$/.test(id)) return;

  link.addEventListener('click', (e) => {
    if (e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
    if (link.classList.contains('as-words')) return;
    e.preventDefault();
    // The player sits in the same 16:9 box the thumbnail did, so the page
    // does not move. YouTube refuses to play in a frame that sends no
    // referrer at all, so this one sends the site's address and nothing more.
    const player = el('iframe', {
      class: 'video-player',
      src: `https://www.youtube-nocookie.com/embed/${id}?autoplay=1`,
      title: 'YouTube video',
      allow: 'autoplay; encrypted-media; picture-in-picture; fullscreen',
      allowfullscreen: '',
      referrerpolicy: 'strict-origin-when-cross-origin',
    });
    link.replaceWith(player);
  });
}

function aiSummary(detail, mod) {
  const words = aiSummaryOf({
    aiSummary: detail.aiDescription,
    summary: detail.description,
    summaryIsGenerated: Boolean(detail.descriptionIsGenerated),
  });
  if (!words) return null;

  const shown = aiOnModPages() !== 'hide';
  let section = null;
  const flip = () => {
    setAiOnModPages(shown ? 'hide' : 'show');
    section.replaceWith(aiSummary(detail, mod));
    // The line under the name follows the same choice.
    const slot = document.querySelector('.mod-summary-slot');
    if (slot) slot.replaceChildren(...[headSummary(mod)].filter(Boolean));
  };
  const toggle = el('button', {
    class: 'link-button ai-switch',
    type: 'button',
    text: shown ? 'Hide AI summaries' : 'Show AI summary',
    title: 'Applies to all mod pages.',
  });
  toggle.addEventListener('click', flip);

  if (!shown) {
    section = el('p', { class: 'ai-hidden-row' }, [
      aiSparkle(), ' ', toggle,
    ]);
    return section;
  }

  section = el('div', { class: 'panel' }, [
    el('div', {
      class: 'summary-block',
      title: summaryTitle({ text: words, generated: true }),
    }, [
      el('div', { class: 'prose plain' }, [
        el('p', {}, [aiSparkle(words), ' ', words]),
      ]),
      el('div', { class: 'ai-foot' }, [aiSummaryNote(), toggle]),
    ]),
  ]);
  return section;
}

function gallery(detail) {
  const images = detail.gallery || [];
  if (!images.length) return null;

  // Buttons, badges and small icons are published too, but kept out of the
  // way behind a button, so the section reads as screenshots first.
  const smallCount = images.filter((image) => image.small).length;
  let showSmall = false;

  // Exclude failed and hidden images from the viewer.
  const broken = new Set();
  const showing = () => images.filter((image) =>
    !broken.has(image) && (showSmall || !image.small));
  const grid = el('div', { class: 'gallery' });
  const buttons = new Map();
  images.forEach((image) => {
    const button = el('button', {
      class: 'shot',
      title: image.caption || 'Open screenshot',
    });
    button.hidden = Boolean(image.small);
    button.append(picture(image.url, {
      alt: image.caption || '',
      whenBroken: () => {
        button.remove();
        broken.add(image);
      },
    }));
    button.addEventListener('click', () => {
      const list = showing();
      showPicture(list, list.indexOf(image));
    });
    buttons.set(image, button);
    grid.append(button);
  });

  let toggle = null;
  if (smallCount) {
    toggle = el('button', {
      class: 'link-button small-pictures-toggle', type: 'button',
    });
    const label = () => {
      toggle.textContent = showSmall
        ? 'Hide small pictures'
        : `Show ${smallCount} small ${smallCount === 1 ? 'picture' : 'pictures'}`;
      toggle.setAttribute('aria-expanded', String(showSmall));
    };
    label();
    toggle.addEventListener('click', () => {
      showSmall = !showSmall;
      for (const [image, button] of buttons) {
        if (image.small) button.hidden = !showSmall;
      }
      label();
    });
  }

  return el('section', { class: 'panel' }, [
    el('h2', { text: 'Screenshots' }),
    grid,
    toggle ? el('p', { class: 'small-pictures-row' }, [toggle]) : null,
  ]);
}

/// A section whose entries fold, with a button beside its heading that opens
/// or closes every one of them. The button works on this section alone, and is
/// left out when nothing in it folds.
function foldingPanel(heading, body, foldSelector) {
  return el('section', { class: 'panel' }, [
    el('div', { class: 'section-head' }, [
      el('h2', { text: heading }),
      expandAllButton(body, foldSelector),
    ]),
    body,
  ]);
}

function changelog(detail) {
  const entries = Object.entries(detail.changelog || {});
  const changelogUrl = (detail.downloads || []).length ? null : detail.changelogUrl;
  if (!entries.length && !changelogUrl) return null;

  const box = el('div', {});
  entries.forEach(([version, notes], i) => {
    box.append(el('details', { class: 'changelog-entry', open: i === 0 ? '' : null }, [
      el('summary', { text: version }),
      el('pre', { text: notes }),
    ]));
  });
  if (changelogUrl) {
    box.append(el('p', {}, [
      el('a', {
        href: changelogUrl, target: '_blank', rel: 'noopener nofollow',
        text: 'Full changelog →',
      }),
    ]));
  }
  return foldingPanel('Recent Updates', box, 'details.changelog-entry');
}

function releases(detail) {
  const list = detail.releases || [];
  if (!list.length) return null;

  const rows = el('div', { class: 'release-list' });
  for (const release of list) {
    rows.append(el('details', { class: release.changelogNotes ? 'release' : 'release no-notes' }, [
      el('summary', {}, [
        // The same arrow Home's release rows carry; a row with no notes has
        // none and is pushed along to line up with the rest.
        release.changelogNotes
          ? el('span', { class: 'chevron', text: '›', 'aria-hidden': 'true' })
          : null,
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
  return foldingPanel('Release history', rows, 'details.release:not(.no-notes)');
}

function addons(detail) {
  const list = detail.addons || [];
  if (!list.length) return null;

  const versions = list.filter((a) => a.role === 'variant');
  const extras = list.filter((a) => a.role !== 'variant');

  return el('div', { class: 'stack' }, [
    addonBox(extras, 'Add-ons on the same thread'),
    addonBox(versions, 'Other versions of this mod'),
  ]);
}

function addonBox(list, heading) {
  if (!list.length) return null;

  const box = el('div', { class: 'stack' });
  for (const addon of list) {
    box.append(el('div', {}, [
      el('h3', { text: addon.name }),
      addon.requires
        ? el('div', { class: 'card-authors', text: `Requires ${addon.requires}` })
        : null,
      el('div', { class: 'download-list' }, (addon.downloads || []).map(downloadRow)),
    ]));
  }
  return el('section', { class: 'panel' }, [
    el('h2', { text: heading }),
    box,
  ]);
}

/// The chip beside each save question. "Maybe" is the author saying it
/// depends: the words under it say on what.
const SAVE_ANSWERS = {
  yes: ['save-ok', 'Yes'],
  no: ['save-no', 'No'],
  depends: ['', 'Maybe'],
  unknown: ['save-unknown', 'Unknown'],
};

// Show unanswered add/remove questions as Unknown. Show update only
// when the author supplied text.
function saves(detail) {
  const questions = [
    ['Add mid-game?', detail.saveCompatibilityText, detail.canAdd, true],
    ['Update mid-game?', detail.updateCompatibilityText, detail.canUpdate, false],
    ['Remove from game?', detail.removalCompatibilityText, detail.canRemove, true],
  ];
  if (!questions.some(([, words]) => words)) return null;

  const authors = joinNames((detail.listing || {}).authors || []);
  const quoted = new Set();
  const rows = el('div', { class: 'save-lines' });
  for (const [question, words, answer, alwaysAsked] of questions) {
    if (!words && !alwaysAsked) continue;
    const shown = words ? answer : 'unknown';
    const chip = SAVE_ANSWERS[shown];
    // Where the model copied the same words into two fields, they are quoted
    // on the first row only.
    const quote = words && !quoted.has(words)
      ? el('q', {
          class: 'save-words',
          text: chip ? withoutLeadingAnswer(words, shown) : words,
          title: authors ? `${authors}, in the mod's forum thread` : null,
        })
      : null;
    if (words) quoted.add(words);
    rows.append(el('div', { class: 'save-line' }, [
      el('div', { class: 'save-ask' }, [
        el('span', { class: 'save-question', text: question }),
        chip
          ? el('span', { class: `badge ${chip[0]}`.trim(), text: chip[1] })
          : null,
      ]),
      quote,
    ]));
  }

  return rows;
}

function withoutLeadingAnswer(words, answer) {
  if (answer !== 'yes' && answer !== 'no') return words;
  const rest = words.replace(new RegExp(`^${answer}\\b[\\s.,!:;\u2014-]*`, 'i'), '');
  if (!rest || rest === words) return words;
  return rest[0].toUpperCase() + rest.slice(1);
}

function sideFact(label, value, { beside = false } = {}) {
  return el('div', { class: `side-fact${beside ? ' beside' : ''}` }, [
    el('span', { class: 'side-label', text: label }),
    el('div', { class: 'side-value' }, [value]),
  ]);
}

function sideCard(heading, rows) {
  const kept = rows.filter(Boolean);
  if (!kept.length) return null;
  return el('section', { class: 'panel side-card' }, [
    el('h2', { class: 'side-heading', text: heading }),
    el('div', { class: 'side-facts' }, kept),
  ]);
}

function compatibility(detail, currentVersion) {
  const listing = detail.listing || {};
  const needs = (listing.needs || []).length
    ? sideFact('Requires', el('div', { class: 'needs-chips' }, listing.needs.map((needed) =>
      needed.id
        ? el('a', { class: 'chip needed', href: modHref(needed.id), text: needed.name })
        : el('span', {
            class: 'chip needed unknown', text: needed.name,
            title: 'No page available for this requirement.',
          }))))
    : null;
  const saveRows = saves(detail);
  return sideCard('Compatibility', [
    listing.gameVersion
      ? sideFact('Game version', el('span', {
          text: `Starsector ${listing.gameVersion}`,
          title: versionStandingNote(versionStanding(listing, currentVersion)),
        }), { beside: true })
      : null,
    needs,
    saveRows ? el('div', { class: 'side-fact' }, [saveRows]) : null,
  ]);
}

function linksOut(detail) {
  const links = [
    ['Forum thread', detail.forumUrl, 'forumUrl'],
    ['Discord', detail.discordUrl, 'discordUrl'],
  ].filter(([, url]) => url);
  if (!links.length) return null;
  return el('section', { class: 'panel side-card' }, [
    el('h2', { class: 'side-heading', text: 'Links' }),
    el('div', { class: 'side-link-list' }, links.map(([text, url, field]) => {
      const icon = field ? pageIcon(field) : CODE_ICON;
      return el('a', {
        href: url, target: '_blank', rel: 'noopener nofollow', title: url,
      }, [
        icon ? el('span', { class: 'original-page-icon', html: icon, 'aria-hidden': 'true' }) : null,
        el('span', { text }),
      ]);
    })),
  ]);
}

// Tabler code icon.
const CODE_ICON = '<svg viewBox="0 0 24 24" width="1em" height="1em" fill="none" '
  + 'stroke="currentColor" stroke-width="2" stroke-linecap="round" '
  + 'stroke-linejoin="round" focusable="false" aria-hidden="true">'
  + '<path d="M7 8l-4 4l4 4"/><path d="M17 8l4 4l-4 4"/><path d="M14 4l-4 16"/></svg>';

function facts(detail) {
  const listing = detail.listing || {};
  // What each source actually called it, which is not always what the site
  // does. Left out when it says nothing the categories line did not.
  const raw = detail.rawCategories || [];
  const rawDiffers = raw.length && joinNames(raw) !== joinNames(listing.categories || []);
  const day = (label, value, title) => (value
    ? sideFact(label, el('span', { text: formatDay(value), title }), { beside: true })
    : null);
  return sideCard('Details', [
    listing.modVersion
      ? sideFact('Mod version', el('span', { text: listing.modVersion, title: MOD_VERSION_NOTE }),
        { beside: true })
      : null,
    (listing.categories || []).length
      ? sideFact('Category', el('span', { text: joinNames(listing.categories) }))
      : null,
    rawDiffers
      ? sideFact('Original categories', el('span', {
          class: 'dim', text: joinNames(raw),
          title: 'Categories from the forum or Discord.',
        }))
      : null,
    detail.license ? sideFact('License', el('span', { text: detail.license })) : null,
    day('Added', listing.addedOn,
      'When the forum thread was posted, or the mod was first seen on Discord.'),
    day('Last release', listing.lastReleaseDate,
      'When this site last noticed a new version.'),
    day('Thread last posted', listing.threadLastPostOn || detail.threadLastPostOn, null),
    (listing.sources || []).length
      ? sideFact('Found on', el('span', { text: joinNames(listing.sources.map(sourceName)) }),
        { beside: true })
      : null,
  ]);
}

// Same-name entries may be older threads, forks, or unrelated mods.
function sameNameMods(detail) {
  const others = detail.sameNameMods || [];
  if (!others.length) return null;

  const rows = el('div', { class: 'mod-rows' });
  for (const other of others) {
    const metadata = [
      (other.authors || []).length ? `by ${joinNames(other.authors)}` : null,
      other.threadLastPostOn
        ? `thread last posted ${formatDay(other.threadLastPostOn)}`
        : null,
      other.gameVersion ? `for Starsector ${other.gameVersion}` : null,
      other.modVersion ? `version ${other.modVersion}` : null,
    ].filter(Boolean);

    // A page here where we have one, and the forum thread where we do not.
    const inner = other.id
      ? el('a', { class: 'row-inner', href: modHref(other.id) })
      : el('a', {
          class: 'row-inner', href: other.url,
          target: '_blank', rel: 'noopener nofollow',
        });
    inner.append(el('div', { class: 'row-main' }, [
      el('div', { class: 'row-title', text: other.title }),
      metadata.length
        ? el('div', { class: 'row-sub', text: metadata.join(' · ') })
        : null,
    ]));
    rows.append(el('div', { class: 'mod-row' }, [inner]));
  }

  const many = others.length > 1;
  return el('section', { class: 'panel name-share' }, [
    el('h3', { text: `${many ? 'Other mods have' : 'Another mod has'} the same name` }),
    el('p', {
      class: 'sub',
      text: `${many ? 'Each' : 'It'} may be an older thread for this mod, a fork `
        + 'of it, or a different mod altogether.',
    }),
    rows,
  ]);
}

function moreByTheAuthor(mod, everyMod, currentVersion) {
  const people = new Set((mod.authors || []).map((a) => a.toLowerCase()));
  if (!people.size) return null;

  const theirs = everyMod.filter((other) => other.id !== mod.id
    && (other.authors || []).some((a) => people.has(a.toLowerCase())));
  if (!theirs.length) return null;

  const who = (mod.authors || []).length === 1 ? mod.authors[0] : 'these authors';
  return el('section', { class: 'stack' }, [
    el('h2', { text: `More by ${who}` }),
    strip(theirs, currentVersion),
  ]);
}

function similarMods(mod, everyMod, currentVersion) {
  const shelves = new Set(mod.categories || []);
  if (!shelves.size) return null;

  const people = new Set((mod.authors || []).map((a) => a.toLowerCase()));
  const shared = (other) =>
    (other.categories || []).filter((c) => shelves.has(c)).length;
  const alike = everyMod.filter((other) => other.id !== mod.id
    // Not this person's own mods — those have their own strip above.
    && !(other.authors || []).some((a) => people.has(a.toLowerCase()))
    && shared(other) > 0);
  if (!alike.length) return null;

  // Stable sorting preserves release order within each category count.
  const ranked = newestFirst(alike).sort((a, b) => shared(b) - shared(a));

  return el('section', { class: 'stack' }, [
    el('h2', { text: 'Similar mods' }),
    strip(ranked, currentVersion, { alreadyOrdered: true }),
  ]);
}

function strip(mods, currentVersion, { alreadyOrdered = false } = {}) {
  const row = el('div', { class: 'strip' });
  const inOrder = alreadyOrdered ? mods : newestFirst(mods);
  for (const mod of inOrder.slice(0, RELATED_COUNT)) {
    row.append(modCard(mod, currentVersion));
  }
  return row;
}

// Build the diagnostic view only when first opened.
function rawInfo(detail, id) {
  const fold = el('details', { class: 'raw-info' }, [
    el('summary', { text: 'See raw info' }),
  ]);
  let built = false;
  fold.addEventListener('toggle', () => {
    if (built || !fold.open) return;
    built = true;
    fold.append(rawInfoBody(detail, id));
  });
  return fold;
}

function rawInfoBody(detail, id) {
  const file = `mods/${encodeURIComponent(id)}.json`;
  const copy = el('button', { class: 'btn', text: 'Copy as JSON' });
  copy.addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(JSON.stringify(detail, null, 2));
      copy.textContent = 'Copied';
    } catch {
      copy.textContent = 'Could not copy';
    }
    setTimeout(() => { copy.textContent = 'Copy as JSON'; }, 2000);
  });

  return el('div', { class: 'panel raw-info-body' }, [
    el('div', { class: 'raw-info-tools' }, [
      copy,
      el('a', {
        class: 'btn', href: DATA_BASE + file, target: '_blank', rel: 'noopener',
        text: 'Open the file',
        title: `The published file this is read from: ${file}`,
      }),
    ]),
    el('div', { class: 'raw-tree' }, [rawValue(detail)]),
  ]);
}

// Render raw HTML strings as text.
function rawValue(value) {
  if (value === null || value === undefined) {
    return el('span', { class: 'raw-none', text: 'nothing' });
  }
  if (Array.isArray(value)) {
    if (!value.length) return el('span', { class: 'raw-none', text: 'empty list' });
    const rows = el('div', { class: 'raw-branch' });
    value.forEach((entry, i) => {
      rows.append(el('span', { class: 'raw-name', text: `${i + 1}.` }),
        el('div', { class: 'raw-cell' }, [rawValue(entry)]));
    });
    return rows;
  }
  if (typeof value === 'object') {
    const keys = Object.keys(value);
    if (!keys.length) return el('span', { class: 'raw-none', text: 'empty' });
    const rows = el('div', { class: 'raw-branch' });
    for (const key of keys) {
      rows.append(el('span', { class: 'raw-name', text: key }),
        el('div', { class: 'raw-cell' }, [rawValue(value[key])]));
    }
    return rows;
  }
  if (typeof value === 'string') {
    if (value.length > 160 || value.includes('\n') || value.includes('<')) {
      return el('pre', { class: 'raw-text', text: value });
    }
    if (/^https?:\/\//.test(value)) {
      return el('a', {
        href: value, target: '_blank', rel: 'noopener nofollow', text: value,
      });
    }
  }
  return el('span', { text: String(value) });
}

// Undated releases sort last.
function newestFirst(mods) {
  return [...mods].sort((a, b) => {
    const left = a.lastReleaseDate || '';
    const right = b.lastReleaseDate || '';
    if (left === right) return modName(a).localeCompare(modName(b));
    if (!left) return 1;
    if (!right) return -1;
    return right.localeCompare(left);
  });
}
