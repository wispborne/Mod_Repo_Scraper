import 'display_name.dart';
import 'models/public_mod.dart';

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

/// The page for [mod], built out of [shell] — the text of `site/index.html`.
///
/// With no shell, or one that has lost its marks, this falls back to a small
/// page that sends the reader to the site's hash address for the same mod. That
/// still works and still carries the preview tags; the only thing lost is the
/// address bar keeping the mod's own address.
String buildModPageHtml(PublicMod mod, {String? shell}) {
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

  return shell.replaceRange(start, end + modPageHeadEnd.length, head);
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
