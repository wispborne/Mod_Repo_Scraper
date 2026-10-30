import 'display_name.dart';
import 'models/public_mod.dart';
import 'models/public_mod_detail.dart';
import 'sitemap.dart';

/// A mod's own page, at `mods/<id>/index.html`.
///
/// Every mod has a real page of its own on disk, and that is the mod's address:
/// the site's links point at it, the address bar shows it, and a reader who
/// copies it gets a link that Discord and a search engine can fetch and read.
/// Before this, the whole site lived behind `#/mods/<id>`, and a hash is never
/// sent to a server — so every shared link showed the same title and no
/// picture, and a search engine saw one page standing for nine hundred mods.
///
/// The page is the site's own front document with one region of its head
/// swapped: this mod's `<base>`, title, description and preview tags in place
/// of the site's own. So the header, the settings box, the footer and the
/// scripts are written once, in `site/index.html`, and a mod's page can never
/// drift from the rest of the site.
///
/// The `<base>` is what lets the document sit two folders down and still find
/// everything: its stylesheet, its scripts and the data files all resolve back
/// beside the front document. It is also why the swapped region is the first
/// thing in the head — a `<base>` has to come before the first relative address
/// on the page.
///
/// There is no `canonical` link on purpose. The address this page has *is* the
/// canonical one now, and saying so adds nothing.

/// The two marks in `site/index.html` around the region that changes from page
/// to page. Both are in that file; a copy without them is not one this can
/// build a mod's page from.
const String modPageHeadStart = '<!--page-head-->';
const String modPageHeadEnd = '<!--/page-head-->';

/// The two marks inside `<main>` around what the page shows before its script
/// has run. A mod's page puts the mod's own words there, so a search engine
/// that reads the file without running the script still finds them. The
/// script empties `<main>` as it starts, so a reader only ever sees the page
/// the script draws.
const String modPageBodyStart = '<!--page-body-->';
const String modPageBodyEnd = '<!--/page-body-->';

/// The page for [mod], built out of [shell] — the text of `site/index.html`.
///
/// With no shell, or one that has lost its marks, this falls back to a small
/// page that sends the reader to the site's hash address for the same mod. That
/// still works and still carries the preview tags; the only thing lost is the
/// address bar keeping the mod's own address.
///
/// With [detail], the mod's name, summary, links and forum post are also
/// written into the page's body, between the body marks. A shell without
/// those marks still gets its head swapped; only the body is left alone.
String buildModPageHtml(
  PublicMod mod, {
  String? shell,
  PublicModDetail? detail,
}) {
  final name = mod.displayName ?? displayName(mod.name);
  final about = _describe(mod, name);
  final picture = _webPicture(mod.imageUrl);

  final head = _head(name: name, about: about, picture: picture);
  if (shell == null) return _redirectingPage(mod, name, about, picture);

  final start = shell.indexOf(modPageHeadStart);
  final end = shell.indexOf(modPageHeadEnd);
  if (start < 0 || end < start) {
    return _redirectingPage(mod, name, about, picture);
  }

  final page = shell.replaceRange(start, end + modPageHeadEnd.length, head);
  if (detail == null) return page;

  final bodyStart = page.indexOf(modPageBodyStart);
  final bodyEnd = page.indexOf(modPageBodyEnd);
  if (bodyStart < 0 || bodyEnd < bodyStart) return page;
  return page.replaceRange(
    bodyStart + modPageBodyStart.length,
    bodyEnd,
    _bodyText(mod, detail, name),
  );
}

/// The page at a Collection's old address, built out of [shell] the same way a
/// mod's page is: the head swapped for the Collection's name and preview tags,
/// and the body listing its mods, each linked to its own page.
String buildCollectionPageHtml({
  required String id,
  required String name,
  required List<PublicMod> mods,
  String? threadUrl,
  String? shell,
}) {
  final names = [for (final mod in mods) mod.displayName ?? displayName(mod.name)];
  final about = names.isEmpty
      ? 'A post that held several Starsector mods.'
      : '${names.length} Starsector mods posted together: ${names.join(', ')}.';
  String? picture;
  for (final mod in mods) {
    picture ??= _webPicture(mod.imageUrl);
  }

  final redirect = '../../#/mods/${Uri.encodeComponent(id)}';
  final head = _head(name: name, about: about, picture: picture);
  final start = shell?.indexOf(modPageHeadStart) ?? -1;
  final end = shell?.indexOf(modPageHeadEnd) ?? -1;
  if (shell == null || start < 0 || end < start) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>${_escape(name)} | Starmodder</title>
<meta name="description" content="${_attribute(about)}">
</head>
<body>
<h1>${_escape(name)}</h1>
<p>${_escape(about)}</p>
<p><a href="$redirect">Open it on Starmodder</a></p>
<script>location.replace('$redirect');</script>
</body>
</html>
''';
  }

  final page = shell.replaceRange(start, end + modPageHeadEnd.length, head);
  final bodyStart = page.indexOf(modPageBodyStart);
  final bodyEnd = page.indexOf(modPageBodyEnd);
  if (bodyStart < 0 || bodyEnd < bodyStart) return page;

  final out = StringBuffer()..write('<article class="stack page-text">');
  out.write('<h1>${_escape(name)}</h1>');
  out.write('<p>${_escape(about)}</p><ul>');
  for (final (index, mod) in mods.indexed) {
    out.write('<li><a href="mods/${Uri.encodeComponent(mod.id)}/">${_escape(names[index])}</a></li>');
  }
  out.write('</ul>');
  final link = threadUrl == null ? null : _link(threadUrl, 'Forum thread');
  if (link != null) out.write('<p>$link</p>');
  out.write('</article><div class="loading">Loading…</div>');
  return page.replaceRange(bodyStart + modPageBodyStart.length, bodyEnd, out.toString());
}

/// What the page holds before its script runs: the mod's name, who made it,
/// the author's own summary, the links that get it, what it needs, and the
/// start of the author's forum post.
///
/// Only the author's own words go in. An AI summary or paragraph is left out,
/// because a reader who chose "Never" for AI summaries must not see one, even
/// for the moment before the script takes over. The post goes in as plain
/// text, so it carries no pictures: a picture in the file starts downloading
/// at once, and a reader who turned pictures off was promised nothing would be
/// fetched.
///
/// Every address here is relative to the page's `<base>`, which is the site
/// itself, so a link to another mod is `mods/<id>/`.
String _bodyText(PublicMod mod, PublicModDetail detail, String name) {
  final out = StringBuffer()..write('<article class="stack page-text">');
  out.write('<h1>${_escape(name)}</h1>');

  final facts = <String>[
    if (mod.authors.isNotEmpty)
      'A Starsector mod by ${_escape(mod.authors.join(', '))}.'
    else
      'A Starsector mod.',
    if (mod.gameVersion != null) 'For Starsector ${_escape(mod.gameVersion!)}.',
    if (mod.modVersion != null) 'Version ${_escape(mod.modVersion!)}.',
  ];
  out.write('<p>${facts.join(' ')}</p>');

  final summary = mod.summary?.trim();
  if (summary != null && summary.isNotEmpty && !mod.summaryIsGenerated) {
    out.write('<p>${_escape(summary)}</p>');
  }

  final links = <String?>[
    if (mod.bestDownload != null)
      _link(mod.bestDownload!.url, _downloadWords(mod.bestDownload!)),
    if (detail.forumUrl != null) _link(detail.forumUrl!, 'Forum thread'),
    if (detail.discordUrl != null) _link(detail.discordUrl!, 'Discord post'),
    if (detail.sourceCodeUrl != null)
      _link(detail.sourceCodeUrl!, 'Source code'),
  ].whereType<String>().toList();
  if (links.isNotEmpty) out.write('<p>${links.join(' · ')}</p>');

  for (final (heading, mods) in [
    ('Requires', mod.needs),
    ('Optional', detail.optionalNeeds ?? const <PublicNeededMod>[]),
  ]) {
    if (mods.isEmpty) continue;
    out.write('<h2>$heading</h2><ul>');
    for (final needed in mods) {
      final words = _escape(needed.name);
      final via =
          needed.via == null ? '' : ' (required by ${_escape(needed.via!)})';
      out.write(needed.id == null
          ? '<li>$words$via</li>'
          : '<li><a href="mods/${Uri.encodeComponent(needed.id!)}/">'
              '$words</a>$via</li>');
    }
    out.write('</ul>');
  }

  final post = detail.descriptionIsGenerated ? null : detail.description;
  final opening = post == null ? const <String>[] : postOpening(post);
  if (opening.isNotEmpty) {
    final heading =
        detail.descriptionIsForumPost ? 'Forum post' : 'About this mod';
    out.write('<h2>$heading</h2>');
    for (final paragraph in opening) {
      out.write('<p>${_escape(paragraph).replaceAll('\n', '<br>')}</p>');
    }
  }

  // Where scripts run, the stylesheet hides the words above and shows this
  // until the script has drawn the page.
  out.write('</article><div class="loading">Loading…</div>');
  return out.toString();
}

/// The words for the mod's first download, matching what its button says.
String _downloadWords(PublicBestDownload download) {
  if (download.kind == 'trios') return 'Install with TriOS';
  return download.needsAnotherStep ? 'Download page' : 'Download';
}

/// A link out, or null when the address is not a web address.
String? _link(String url, String words) {
  final address = _webPicture(url);
  if (address == null) return null;
  return '<a href="${_attribute(address)}" rel="nofollow noopener">'
      '${_escape(words)}</a>';
}

/// How much of the post a mod's page file carries, in characters. Enough for
/// the author's opening description, which is where the words people search
/// for usually are. The whole post is on the page the script draws.
const int postOpeningLength = 500;

/// The first paragraphs of [post], the plain-text post, up to
/// [postOpeningLength] characters. Whole paragraphs only, except when the
/// first one is already too long: then it is cut at the last space before the
/// limit and ends with "…".
List<String> postOpening(String post) {
  final paragraphs = post
      .split(RegExp(r'\n\s*\n'))
      .map((paragraph) => paragraph.trim())
      .where((paragraph) => paragraph.isNotEmpty);

  final kept = <String>[];
  var length = 0;
  for (final paragraph in paragraphs) {
    if (length + paragraph.length <= postOpeningLength) {
      kept.add(paragraph);
      length += paragraph.length;
      continue;
    }
    if (kept.isEmpty) {
      final cut = paragraph.lastIndexOf(' ', postOpeningLength);
      final end = cut > 0 ? cut : postOpeningLength;
      kept.add('${paragraph.substring(0, end).trimRight()}…');
    }
    break;
  }
  return kept;
}

/// The head region this mod's page carries in place of the site's own.
String _head({
  required String name,
  required String about,
  required String? picture,
}) {
  final lines = <String>[
    // Two folders up is the site itself, where every script, style and data
    // file this page asks for actually lives.
    '<base href="../../">',
    '<title>${_escape(name)} | Starmodder</title>',
    '<meta name="description" content="${_attribute(about)}">',
    '<meta property="og:type" content="article">',
    '<meta property="og:site_name" content="Starmodder">',
    '<meta property="og:title" content="${_attribute(name)}">',
    '<meta property="og:description" content="${_attribute(about)}">',
    if (picture != null)
      '<meta property="og:image" content="${_attribute(picture)}">',
    '<meta name="twitter:card" '
        'content="${picture == null ? 'summary' : 'summary_large_image'}">',
  ];
  return lines.join('\n  ');
}

/// The page at an old address whose mod was joined into [to]. It sends the
/// reader straight on to [to]'s own page, keeping the reader's `?data=…` and
/// a tab picked after the address. It carries [to]'s preview tags, so an old
/// link shared in Discord still shows the mod, and names [to]'s page as the
/// real one so a search engine files the two as one.
String buildMovedPageHtml({required PublicMod to}) {
  final name = to.displayName ?? displayName(to.name);
  final about = _describe(to, name);
  final picture = _webPicture(to.imageUrl);
  final id = Uri.encodeComponent(to.id);
  final page = '../$id/';
  return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="referrer" content="no-referrer">
<title>${_escape(name)} | Starmodder</title>
<link rel="canonical" href="${siteAddress}mods/$id/">
<meta http-equiv="refresh" content="0; url=$page">
<meta name="description" content="${_attribute(about)}">
<meta property="og:type" content="article">
<meta property="og:site_name" content="Starmodder">
<meta property="og:title" content="${_attribute(name)}">
<meta property="og:description" content="${_attribute(about)}">
${picture == null ? '' : '<meta property="og:image" content="${_attribute(picture)}">\n'}<meta name="twitter:card" content="${picture == null ? 'summary' : 'summary_large_image'}">
<script>location.replace('$page' + location.search + (location.hash.indexOf('#/') === 0 ? '' : location.hash));</script>
</head>
<body>
<p>This mod's page has moved: <a href="$page">${_escape(name)} on Starmodder</a>.</p>
</body>
</html>
''';
}

/// The stand-in for when the site's own document cannot be read: the preview
/// tags, one line of visible words, and a script sending a reader on to the
/// site's hash address for this mod.
String _redirectingPage(
  PublicMod mod,
  String name,
  String about,
  String? picture,
) {
  final page = '../../#/mods/${Uri.encodeComponent(mod.id)}';
  return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="referrer" content="no-referrer">
<title>${_escape(name)} | Starmodder</title>
<meta name="description" content="${_attribute(about)}">
<meta property="og:type" content="article">
<meta property="og:site_name" content="Starmodder">
<meta property="og:title" content="${_attribute(name)}">
<meta property="og:description" content="${_attribute(about)}">
${picture == null ? '' : '<meta property="og:image" content="${_attribute(picture)}">\n'}<meta name="twitter:card" content="${picture == null ? 'summary' : 'summary_large_image'}">
</head>
<body>
<h1>${_escape(name)}</h1>
<p>${_escape(about)}</p>
<p><a href="$page">Open ${_escape(name)} on Starmodder</a></p>
<script>location.replace('$page');</script>
</body>
</html>
''';
}

/// One line about the mod, for the page's description and its only paragraph.
/// The summary where there is one; failing that, who made it and what it is
/// for, which is at least true of every mod.
String _describe(PublicMod mod, String name) {
  final summary = mod.summary?.trim();
  if (summary != null && summary.isNotEmpty) return summary;

  final parts = <String>[];
  if (mod.authors.isNotEmpty) parts.add('By ${mod.authors.join(', ')}.');
  if (mod.gameVersion != null) parts.add('For Starsector ${mod.gameVersion}.');
  parts.add('A Starsector mod, on Starmodder.');
  return parts.join(' ');
}

/// The picture, but only when it is a web address. Anything else has no place
/// in a tag that another site will go and fetch.
String? _webPicture(String? url) {
  final trimmed = url?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final lower = trimmed.toLowerCase();
  if (!lower.startsWith('http://') && !lower.startsWith('https://'))
    return null;
  return trimmed;
}

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _attribute(String value) => _escape(value).replaceAll('"', '&quot;');
