import 'dart:io';

import 'package:mod_repo_scraper/site/guide_page_html.dart';
import 'package:mod_repo_scraper/site/models/public_mod.dart';
import 'package:mod_repo_scraper/site/sitemap.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The "How to install mods" page is the site's own document with its head
/// swapped and the guide's words in its body, the same way a mod's page is
/// built.
void main() {
  const shell = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <!--page-head-->
  <base href="./">
  <title>Starmodder 4: Starsector mods</title>
  <!--/page-head-->
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <main id="app"><!--page-body--><div class="loading">Loading…</div><!--/page-body--></main>
</body>
</html>
''';

  test('the head is swapped for the guide, one folder down', () {
    final page = buildGuidePageHtml(shell: shell)!;
    expect(page, contains('<base href="../">'));
    expect(page, contains('<title>How to install mods | Starmodder</title>'));
    expect(page, contains('og:description'));
    expect(page, isNot(contains('Starmodder 4: Starsector mods')));
    expect(page, contains('<link rel="stylesheet" href="style.css">'));
  });

  test('the words go in the body, where a search engine reads them', () {
    final page = buildGuidePageHtml(shell: shell, words: '<p>Unzip it.</p>')!;
    expect(page, contains('<h1>How to install mods</h1><p>Unzip it.</p>'));
    expect(page, contains('<div class="loading">Loading…</div>'));
  });

  test('a shell without its marks gives no page', () {
    expect(buildGuidePageHtml(shell: '<html></html>'), isNull);
  });

  test('the sitemap lists the guide', () {
    final xml = buildSitemapXml(PublicModList(generatedAt: DateTime.utc(2026), mods: const []));
    expect(xml, contains('<loc>https://starmodder.wispborne.com/how-to-install-mods/</loc>'));
  });

  test("the real site has the guide's words, and its links are ones the site serves", () {
    final words = File(p.join('site', guideWordsFile)).readAsStringSync();
    expect(words, contains('href="mods/trios-launcher-mod-manager-toolkit/"'));
    expect(words, contains('topic=25974'));
    expect(words, isNot(contains('<h1')));
  });
}
