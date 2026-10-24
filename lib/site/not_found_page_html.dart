import 'mod_page_html.dart';

/// The site's not-found page, written at its root. Static hosts (Cloudflare
/// Pages, GitHub Pages, Netlify) answer every missing address with it, status
/// 404, instead of with the front page.
const String notFoundFileName = '404.html';

/// The words the not-found view shows. A taken-down mod looks the same as a
/// mistyped address on purpose. Written exactly as asked for; do not reword.
const String notFoundMessage = 'This mod may have been removed at the request of its owner...or it may never have '
    'existed in the first place. Or something else.';

/// The mark `app.js` looks for to know this document is the not-found page.
const String notFoundMark = '<meta name="starmodder-page" content="not-found">';

/// `404.html`, built out of [shell] (the text of `site/index.html`) the way a
/// mod's page is: only the head region is swapped, so the header, nav, search
/// box, footer, theme and scripts are the site's own.
///
/// The base is `/`, the only absolute base on the site: the host serves this
/// file at whatever address was missing, however many folders deep, and
/// Starmodder is always at the root of its domain.
///
/// Null when [shell] has lost its head marks; [plainNotFoundPage] is the
/// stand-in then.
String? buildNotFoundPageHtml(String shell) {
  final start = shell.indexOf(modPageHeadStart);
  final end = shell.indexOf(modPageHeadEnd);
  if (start < 0 || end < start) return null;

  final head = <String>[
    '<base href="/">',
    '<title>Not found | Starmodder</title>',
    '<meta name="robots" content="noindex">',
    notFoundMark,
  ].join('\n  ');
  return shell.replaceRange(start, end + modPageHeadEnd.length, head);
}

/// A small page with the message and a link to the front page, for when the
/// site's own document cannot be read.
String plainNotFoundPage() => '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="robots" content="noindex">
<title>Not found | Starmodder</title>
</head>
<body>
<h1>Not found</h1>
<p>$notFoundMessage</p>
<p><a href="/">Starmodder</a></p>
</body>
</html>
''';
