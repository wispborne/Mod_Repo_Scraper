import 'mod_page_html.dart';

/// The folder the "How to install mods" page sits in, below the site's root.
/// It is also the page's address, and the router's name for it.
const String guideFolder = 'how-to-install-mods';

/// The file in `site/` holding the guide's words, as an HTML fragment. The page
/// below is built from it, and the popup the top bar opens fetches it, so the
/// words are written once.
const String guideWordsFile = 'how-to-install-mods.html';

const String guideTitle = 'How to install mods';

/// The one line a search engine shows, and Discord shows under a pasted link.
const String guideDescription = 'Learn how to install Starsector mods with '
    'TriOS or manually, check required mods, and turn them on in the launcher.';

/// The guide's own page, at `how-to-install-mods/index.html`, built out of
/// [shell] (the text of `site/index.html`) the same way a mod's page is: the
/// head swapped for the guide's base, title and preview tags, and [words]
/// written into the body so a search engine reads them without running the
/// script.
///
/// Null when [shell] has lost its head marks. Unlike a mod, the guide has no
/// hash address worth redirecting to, so there is no fallback page.
String? buildGuidePageHtml({required String shell, String? words}) {
  final start = shell.indexOf(modPageHeadStart);
  final end = shell.indexOf(modPageHeadEnd);
  if (start < 0 || end < start) return null;

  final head = <String>[
    // One folder up is the site itself.
    '<base href="../">',
    '<title>$guideTitle | Starmodder</title>',
    '<meta name="description" content="$guideDescription">',
    '<meta property="og:type" content="article">',
    '<meta property="og:site_name" content="Starmodder">',
    '<meta property="og:title" content="$guideTitle">',
    '<meta property="og:description" content="$guideDescription">',
    '<meta name="twitter:card" content="summary">',
  ].join('\n  ');

  final page = shell.replaceRange(start, end + modPageHeadEnd.length, head);
  if (words == null) return page;

  final bodyStart = page.indexOf(modPageBodyStart);
  final bodyEnd = page.indexOf(modPageBodyEnd);
  if (bodyStart < 0 || bodyEnd < bodyStart) return page;
  return page.replaceRange(
    bodyStart + modPageBodyStart.length,
    bodyEnd,
    '<article class="stack page-text"><h1>$guideTitle</h1>$words</article>'
        '<div class="loading">Loading…</div>',
  );
}
