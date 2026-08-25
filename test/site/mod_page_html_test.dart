import 'package:mod_repo_scraper/site/mod_page_html.dart';
import 'package:mod_repo_scraper/site/models/public_mod.dart';
import 'package:test/test.dart';

/// Every page of the site lives behind `#/mods/<id>`, so every link anyone
/// shared showed the same title and no picture in Discord, and a search engine
/// saw one page for 900 mods. These little pages fix that: one per mod, with
/// its own title and picture, and a line of script that sends a person on to
/// the real page.
void main() {
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

  test('the page is named for the mod, not for the site', () {
    final html = buildModPageHtml(modOf());

    expect(html, contains('<title>Nexerelin | Starmodder</title>'));
    expect(html, contains('property="og:title" content="Nexerelin"'));
  });

  test('it carries the mod\'s own picture, so a shared link shows one', () {
    expect(buildModPageHtml(modOf()),
        contains('property="og:image" content="https://i.imgur.com/shot.png"'));
  });

  test('a mod with no picture simply has none', () {
    expect(buildModPageHtml(modOf(imageUrl: null)), isNot(contains('og:image')));
  });

  test('the description is the summary where there is one', () {
    final html = buildModPageHtml(modOf());
    expect(html, contains('Adds diplomacy, invasions and a 4X layer.'));
  });

  test('a mod with no summary still says something useful', () {
    final html = buildModPageHtml(modOf(summary: null));
    expect(html, contains('Histidine'));
    expect(html, contains('0.98a'));
  });

  test('it sends a reader on to the real page', () {
    final html = buildModPageHtml(modOf());

    // Two levels up, because this page sits at mods/<id>/index.html.
    expect(html, contains('../../#/mods/nexerelin'));
  });

  test('somebody with no scripts still gets a link rather than a blank page',
      () {
    final html = buildModPageHtml(modOf());
    expect(html, contains('<a href="../../#/mods/nexerelin">'));
  });

  test('nothing in it can break out of the page', () {
    final html = buildModPageHtml(modOf(
      displayName: 'Ships & "Guns" <script>alert(1)</script>',
      summary: 'A & B < C',
    ));

    expect(html, isNot(contains('<script>alert(1)</script>')));
    expect(html, contains('Ships &amp; &quot;Guns&quot;'));
    expect(html, contains('A &amp; B &lt; C'));
  });

  test('a picture that is not a web address is left off', () {
    expect(buildModPageHtml(modOf(imageUrl: 'javascript:alert(1)')),
        isNot(contains('og:image')));
  });

  test('it does not tell a search engine some other page is the real one', () {
    // The only address it could name is the front page with a fragment on the
    // end, and a search engine drops the fragment — so naming one would undo
    // the whole point of these pages.
    expect(buildModPageHtml(modOf()), isNot(contains('rel="canonical"')));
  });
}
