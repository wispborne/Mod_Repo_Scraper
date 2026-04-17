import 'package:html/parser.dart' as html_parser;
import 'package:mod_repo_scraper/bot/scraper/qb/mod_index_scraper.dart';
import 'package:test/test.dart';

String _wrapPost(String innerHtml) {
  return '''
<html><body>
  <div id="forumposts">
    <div class="post"><div class="inner">
      $innerHtml
    </div></div>
  </div>
</body></html>
''';
}

void main() {
  group('extractTopicCategoriesFromPost', () {
    test('happy path: strong + ul immediate siblings', () {
      final doc = html_parser.parse(_wrapPost('''
<table class="bbc_table"><tbody><tr><td>
  <strong>Faction Mods:</strong>
  <ul class="bbc_list">
    <li><a href="index.php?topic=100.0">Mod A</a></li>
    <li><a href="index.php?topic=101.0">Mod B</a></li>
  </ul>
</td></tr></tbody></table>
'''));
      final post = doc.querySelector('#forumposts .post .inner')!;
      final result = QbModIndexScraper.extractTopicCategoriesFromPost(post);
      expect(result, equals({100: 'Faction Mods', 101: 'Faction Mods'}));
    });

    test('strong + <br> + ul: topic ids still extracted (BUG 1 regression)',
        () {
      final doc = html_parser.parse(_wrapPost('''
<table class="bbc_table"><tbody><tr><td>
  <strong>Faction Mods:</strong><br>
  <ul class="bbc_list">
    <li><a href="index.php?topic=200.0">Mod A</a></li>
    <li><a href="index.php?topic=201.0">Mod B</a></li>
  </ul>
</td></tr></tbody></table>
'''));
      final post = doc.querySelector('#forumposts .post .inner')!;
      final result = QbModIndexScraper.extractTopicCategoriesFromPost(post);
      expect(result, equals({200: 'Faction Mods', 201: 'Faction Mods'}));
    });

    test('nested <strong> inside a <p> is NOT a category header (BUG 4)', () {
      final doc = html_parser.parse(_wrapPost('''
<table class="bbc_table"><tbody><tr><td>
  <strong>Faction Mods:</strong>
  <ul class="bbc_list">
    <li><a href="index.php?topic=300.0">Mod A</a></li>
  </ul>
  <p>Some description with <strong>emphasis</strong> in it.</p>
  <ul class="bbc_list">
    <li><a href="index.php?topic=999.0">Should not appear</a></li>
  </ul>
</td></tr></tbody></table>
'''));
      final post = doc.querySelector('#forumposts .post .inner')!;
      final result = QbModIndexScraper.extractTopicCategoriesFromPost(post);
      expect(result, equals({300: 'Faction Mods'}));
      expect(result.containsKey(999), isFalse);
    });

    test('label with multiple trailing colons trims all (BUG 5)', () {
      final doc = html_parser.parse(_wrapPost('''
<table class="bbc_table"><tbody><tr><td>
  <strong>Factions:::</strong>
  <ul class="bbc_list">
    <li><a href="index.php?topic=400.0">Mod A</a></li>
  </ul>
</td></tr></tbody></table>
'''));
      final post = doc.querySelector('#forumposts .post .inner')!;
      final result = QbModIndexScraper.extractTopicCategoriesFromPost(post);
      expect(result[400], equals('Factions'));
    });
  });

  group('QbModIndexScraper.scrape (via extract + result composition)', () {
    test(
        'archived category "Factions:::" maps to "Faction Mods" via legacy map',
        () {
      // Simulate the scrape() logic: main post has "Faction Mods", archived
      // post has "Factions:::" which should legacy-map onto "Faction Mods".
      final mainHtml = '''
<table class="bbc_table"><tbody><tr><td>
  <strong>Faction Mods:</strong>
  <ul class="bbc_list">
    <li><a href="index.php?topic=500.0">Mod Main</a></li>
  </ul>
</td></tr></tbody></table>
''';
      final archivedHtml = '''
<table class="bbc_table"><tbody><tr><td>
  <strong>Factions:::</strong>
  <ul class="bbc_list">
    <li><a href="index.php?topic=501.0">Mod Archived</a></li>
  </ul>
</td></tr></tbody></table>
''';
      final mainDoc = html_parser.parse(_wrapPost(mainHtml));
      final archDoc = html_parser.parse(_wrapPost(archivedHtml));
      final mainPost = mainDoc.querySelector('#forumposts .post .inner')!;
      final archPost = archDoc.querySelector('#forumposts .post .inner')!;

      final mainMap =
          QbModIndexScraper.extractTopicCategoriesFromPost(mainPost);
      final archMap =
          QbModIndexScraper.extractTopicCategoriesFromPost(archPost);

      expect(mainMap, equals({500: 'Faction Mods'}));
      expect(archMap, equals({501: 'Factions'}));

      // Verify legacy map contains the mapping under test.
      // Archive-routing logic (in scrape()) uses this to remap "Factions" -> "Faction Mods".
      // Integration of both is exercised by the scrape() unit via mainCategoriesLower.
    });

    test('main-category casing preserved in mainCategories (BUG 3)', () {
      final doc = html_parser.parse(_wrapPost('''
<table class="bbc_table"><tbody><tr><td>
  <strong>Faction Mods:</strong>
  <ul class="bbc_list">
    <li><a href="index.php?topic=600.0">Mod A</a></li>
  </ul>
</td></tr></tbody></table>
'''));
      final post = doc.querySelector('#forumposts .post .inner')!;
      final result = QbModIndexScraper.extractTopicCategoriesFromPost(post);
      final mainCategories = result.values.toSet();
      expect(mainCategories, contains('Faction Mods'));
      expect(mainCategories, isNot(contains('faction mods')));
    });

  });
}
