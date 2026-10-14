import 'dart:io';

import 'package:mod_repo_scraper/site/mod_page_html.dart';
import 'package:mod_repo_scraper/site/models/public_mod.dart';
import 'package:mod_repo_scraper/site/models/public_mod_detail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A mod's page is the site's own document with one region of its head swapped
/// for that mod's base, title and preview tags. That page is the mod's address:
/// the site's links point at it, and a reader who copies it gets a link Discord
/// and a search engine can fetch and read.
void main() {
  /// A stand-in for `site/index.html`: the marks, and enough of the shape to
  /// tell that the rest of the document survives.
  const shell = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <!--page-head-->
  <title>Starmodder 4: Starsector mods</title>
  <meta name="description" content="Starsector mods.">
  <!--/page-head-->
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <header class="site-header">Starmodder</header>
  <main id="app"><!--page-body--><div class="loading">Loading…</div><!--/page-body--></main>
  <script type="module" src="app.js"></script>
</body>
</html>
''';

  PublicMod modOf({
    String id = 'nexerelin',
    String name = '[0.98a] Nexerelin v0.12.2',
    String? displayName = 'Nexerelin',
    List<String> authors = const ['Histidine'],
    String? summary = 'Adds diplomacy, invasions and a 4X layer.',
    String? imageUrl = 'https://i.imgur.com/shot.png',
    String? gameVersion = '0.98a',
  }) =>
      PublicMod(
        id: id,
        name: name,
        displayName: displayName,
        authors: authors,
        summary: summary,
        imageUrl: imageUrl,
        gameVersion: gameVersion,
      );

  group('built from the site\'s own document', () {
    test('the page is named for the mod, not for the site', () {
      final html = buildModPageHtml(modOf(), shell: shell);

      expect(html, contains('<title>Nexerelin | Starmodder</title>'));
      expect(html, contains('property="og:title" content="Nexerelin"'));
      expect(html, isNot(contains('Starmodder 4: Starsector mods')));
    });

    test('it is the whole site, so a reader lands on a working page', () {
      final html = buildModPageHtml(modOf(), shell: shell);

      expect(html, contains('<header class="site-header">Starmodder</header>'));
      expect(html, contains('<main id="app">'));
      expect(html, contains('<script type="module" src="app.js"></script>'));
      expect(html, contains('<link rel="stylesheet" href="style.css">'));
    });

    test('its base points back at the site, two folders up', () {
      final html = buildModPageHtml(modOf(), shell: shell);

      // The page sits at mods/<id>/index.html, so everything relative in it —
      // the stylesheet, the scripts, every data file — is two levels up.
      expect(html, contains('<base href="../../">'));

      // And it has to come before the first relative address on the page, or
      // the browser has already resolved that one against the wrong folder.
      expect(html.indexOf('<base href="../../">'),
          lessThan(html.indexOf('href="style.css"')));
    });

    test('it carries the mod\'s own picture, so a shared link shows one', () {
      expect(
          buildModPageHtml(modOf(), shell: shell),
          contains(
              'property="og:image" content="https://i.imgur.com/shot.png"'));
    });

    test('a mod with no picture simply has none', () {
      expect(buildModPageHtml(modOf(imageUrl: null), shell: shell),
          isNot(contains('og:image')));
    });

    test('the description is the summary where there is one', () {
      final html = buildModPageHtml(modOf(), shell: shell);
      const summary = 'Adds diplomacy, invasions and a 4X layer.';
      expect(html, contains('<meta name="description" content="$summary">'));
      expect(html,
          contains('<meta property="og:description" content="$summary">'));
      expect(html, isNot(contains('content="Starsector mods."')));
    });

    test('a mod with no summary still says something useful', () {
      final html = buildModPageHtml(modOf(summary: null), shell: shell);
      expect(html, contains('Histidine'));
      expect(html, contains('0.98a'));
    });

    test('nothing in it can break out of the page', () {
      final html = buildModPageHtml(
          modOf(
            displayName: 'Ships & "Guns" <script>alert(1)</script>',
            summary: 'A & B < C',
          ),
          shell: shell);

      expect(html, isNot(contains('<script>alert(1)</script>')));
      expect(html, contains('Ships &amp; &quot;Guns&quot;'));
      expect(html, contains('A &amp; B &lt; C'));
    });

    test('a picture that is not a web address is left off', () {
      expect(
          buildModPageHtml(modOf(imageUrl: 'javascript:alert(1)'),
              shell: shell),
          isNot(contains('og:image')));
    });

    test('it does not send the reader anywhere: it is already the page', () {
      final html = buildModPageHtml(modOf(), shell: shell);
      expect(html, isNot(contains('location.replace')));
      expect(html, isNot(contains('#/mods/nexerelin')));
    });

    test('it does not tell a search engine some other page is the real one',
        () {
      // This address is the mod's own now, so there is no other page to name.
      expect(buildModPageHtml(modOf(), shell: shell),
          isNot(contains('rel="canonical"')));
    });
  });

  group('the mod\'s words are in the page before its script runs', () {
    // A search engine that reads the file without running the script would
    // otherwise find nothing but "Loading…".
    PublicModDetail detailOf(
      PublicMod mod, {
      String? description = 'Diplomacy and invasions.',
      bool descriptionIsGenerated = false,
    }) =>
        PublicModDetail(
          generatedAt: DateTime.utc(2026, 10, 13),
          listing: mod,
          description: description,
          descriptionIsGenerated: descriptionIsGenerated,
          descriptionIsForumPost: true,
          forumUrl: 'https://fractalsoftworks.com/forum/index.php?topic=9175.0',
        );

    String bodyOf(String html) => html.substring(
        html.indexOf(modPageBodyStart), html.indexOf(modPageBodyEnd));

    test('the name, the authors, the summary and the post are written in', () {
      final mod = modOf();
      final body =
          bodyOf(buildModPageHtml(mod, shell: shell, detail: detailOf(mod)));

      expect(body, contains('<h1>Nexerelin</h1>'));
      expect(body, contains('A Starsector mod by Histidine.'));
      expect(body, contains('For Starsector 0.98a.'));
      expect(body, contains('Adds diplomacy, invasions and a 4X layer.'));
      expect(body, contains('<p>Diplomacy and invasions.</p>'));
      expect(body, contains('topic=9175.0'));
      expect(body, isNot(contains('Loading…')));
    });

    test('a mod it needs links to that mod\'s page', () {
      final mod = PublicMod(
        id: 'nexerelin',
        name: 'Nexerelin',
        needs: [
          PublicNeededMod(name: 'LazyLib', id: 'lazylib'),
          PublicNeededMod(name: 'Some Other Lib'),
        ],
      );
      final body =
          bodyOf(buildModPageHtml(mod, shell: shell, detail: detailOf(mod)));

      expect(body, contains('<a href="mods/lazylib/">LazyLib</a>'));
      expect(body, contains('<li>Some Other Lib</li>'));
    });

    test('no AI words, even for the moment before the script runs', () {
      // A reader who chose "Never" must not see them at all.
      final mod = PublicMod(
        id: 'x',
        name: 'X',
        summary: 'An AI summary.',
        summaryIsGenerated: true,
      );
      final body = bodyOf(buildModPageHtml(mod,
          shell: shell,
          detail: detailOf(mod,
              description: 'An AI paragraph.', descriptionIsGenerated: true)));

      expect(body, isNot(contains('An AI summary.')));
      expect(body, isNot(contains('An AI paragraph.')));
    });

    test('only the start of the post goes in, in whole paragraphs', () {
      // The whole post is on the page the script draws; the file only needs
      // the author's opening words.
      final first = 'a' * 300;
      final second = 'b' * 150;
      final third = 'c' * 100;
      final mod = modOf();
      final body = bodyOf(buildModPageHtml(mod,
          shell: shell,
          detail: detailOf(mod,
              description: '$first\n\n$second\nline two\n\n$third')));

      expect(body, contains('<p>$first</p>'));
      expect(body, contains('<p>$second<br>line two</p>'));
      expect(body, isNot(contains(third)));
    });

    test('a first paragraph that is too long is cut at a space', () {
      final words = List.filled(200, 'word').join(' ');
      final opening = postOpening(words);

      expect(opening, hasLength(1));
      expect(opening.single, endsWith('word…'));
      expect(opening.single.length, lessThanOrEqualTo(postOpeningLength + 1));
    });

    test('the post goes in as plain text, so it carries no pictures', () {
      // A reader who turned pictures off was promised nothing is fetched.
      final mod = modOf();
      final body = bodyOf(buildModPageHtml(mod,
          shell: shell, detail: detailOf(mod, description: 'A <b> & <img>')));

      expect(body, contains('A &lt;b&gt; &amp; &lt;img&gt;'));
      expect(body, isNot(contains('<img')));
    });

    test('without the mod\'s detail, the body is left as it was', () {
      expect(bodyOf(buildModPageHtml(modOf(), shell: shell)),
          contains('Loading…'));
    });

    test('a document with no body marks still gets its head swapped', () {
      final mod = modOf();
      final html = buildModPageHtml(mod,
          shell: shell
              .replaceAll(modPageBodyStart, '')
              .replaceAll(modPageBodyEnd, ''),
          detail: detailOf(mod));
      expect(html, contains('<title>Nexerelin | Starmodder</title>'));
      expect(html, isNot(contains('<h1>')));
    });
  });

  group('with no document to build from', () {
    // The site's own files are copied in beside the data; a copy that is
    // missing or has lost its marks is a log line, not a failed run. Each mod
    // then gets a small page that still previews and still reaches the mod.
    test('it falls back to a page that sends the reader to the mod', () {
      final html = buildModPageHtml(modOf());

      expect(html, contains('<title>Nexerelin | Starmodder</title>'));
      expect(html, contains('property="og:image"'));
      expect(html, contains('../../#/mods/nexerelin'));
    });

    test('somebody with no scripts still gets a link rather than a blank page',
        () {
      expect(buildModPageHtml(modOf()),
          contains('<a href="../../#/mods/nexerelin">'));
    });

    test('a document that has lost its marks falls back the same way', () {
      final html =
          buildModPageHtml(modOf(), shell: '<html><head></head></html>');
      expect(html, contains('../../#/mods/nexerelin'));
    });
  });

  test('the site\'s own document really carries the marks', () {
    // The two halves of this are in different languages and different folders,
    // so nothing but a test keeps them in step. Lose the marks and every mod
    // silently drops back to the small redirecting page.
    final real = File(p.join('site', 'index.html')).readAsStringSync();

    expect(real, contains(modPageHeadStart));
    expect(real, contains(modPageHeadEnd));
    expect(
        real.indexOf(modPageHeadStart), lessThan(real.indexOf(modPageHeadEnd)));
    expect(
        real.indexOf(modPageBodyStart), lessThan(real.indexOf(modPageBodyEnd)));
    expect(real.indexOf('<main id="app"'),
        lessThan(real.indexOf(modPageBodyStart)));

    // The base lands where the first mark is, and a base has to come before the
    // first relative address on the page.
    final firstRelative =
        RegExp('(href|src)="(?!https?:|//|#)').firstMatch(real)?.start;
    expect(firstRelative, isNotNull);
    expect(real.indexOf(modPageHeadStart), lessThan(firstRelative!));
  });
}
