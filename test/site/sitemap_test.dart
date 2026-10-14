import 'package:mod_repo_scraper/site/models/public_mod.dart';
import 'package:mod_repo_scraper/site/sitemap.dart';
import 'package:test/test.dart';

/// The sitemap lists every mod's page by its whole address, so a search engine
/// finds every mod without running the site's script.
void main() {
  PublicModList listOf(List<PublicMod> mods) =>
      PublicModList(generatedAt: DateTime.utc(2026, 10, 13), mods: mods);

  test('the front page and every mod page are listed by whole address', () {
    final xml = buildSitemapXml(listOf([
      PublicMod(id: 'nexerelin', name: 'Nexerelin'),
      PublicMod(id: 'industrial-evolution', name: 'Industrial.Evolution'),
    ]));

    expect(xml, contains('<loc>https://starmodder.wispborne.com/</loc>'));
    expect(
        xml,
        contains(
            '<loc>https://starmodder.wispborne.com/mods/nexerelin/</loc>'));
    expect(
        xml,
        contains('<loc>https://starmodder.wispborne.com/mods/'
            'industrial-evolution/</loc>'));
  });

  test('a mod carries the later of its last release and its last thread post',
      () {
    final xml = buildSitemapXml(listOf([
      PublicMod(
        id: 'a',
        name: 'A',
        lastReleaseDate: DateTime.utc(2026, 9, 1),
        threadLastPostOn: '2026-10-02',
      ),
      PublicMod(
        id: 'b',
        name: 'B',
        lastReleaseDate: DateTime.utc(2026, 9, 30),
        threadLastPostOn: '2026-01-02',
      ),
      PublicMod(id: 'c', name: 'C'),
    ]));

    expect(xml, contains('mods/a/</loc><lastmod>2026-10-02</lastmod>'));
    expect(xml, contains('mods/b/</loc><lastmod>2026-09-30</lastmod>'));
    expect(xml, contains('mods/c/</loc></url>'));
  });

  test('robots.txt lets everything be read and names the sitemap', () {
    final robots = buildRobotsTxt();
    expect(robots, contains('Allow: /'));
    expect(robots,
        contains('Sitemap: https://starmodder.wispborne.com/sitemap.xml'));
  });
}
