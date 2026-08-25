import 'display_name.dart';
import 'models/public_mod.dart';

/// A small page of its own for each mod, at `mods/<id>/index.html`.
///
/// The site itself lives behind `#/mods/<id>`, and a hash is never sent to a
/// server — so every link anyone shared showed the same title and no picture in
/// Discord, and a search engine saw one page standing for nine hundred mods.
///
/// This is the fix, and it is deliberately the smallest one that works: a plain
/// file per mod carrying that mod's title, description and picture, one line of
/// visible words, and a script that sends a person straight on to the real
/// page. Any static web server serves it. Nothing here needs Cloudflare, a
/// redirect rule, or a server that can read the address.
///
/// There is no `canonical` link on purpose. The only address this page could
/// name is the site's own with a fragment on the end, and a search engine drops
/// the fragment — so every one of the nine hundred pages would end up declaring
/// the front page as the real one, which is exactly the state these pages exist
/// to end.

/// The little page for [mod].
String buildModPageHtml(PublicMod mod) {
  final name = mod.displayName ?? displayName(mod.name);
  final page = '../../#/mods/${Uri.encodeComponent(mod.id)}';
  final about = _describe(mod, name);
  final picture = _webPicture(mod.imageUrl);

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
  if (!lower.startsWith('http://') && !lower.startsWith('https://')) return null;
  return trimmed;
}

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _attribute(String value) => _escape(value).replaceAll('"', '&quot;');
