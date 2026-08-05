import 'package:html/parser.dart' as html_parser;
import 'package:mod_repo_scraper/bot/scraper/forum_scraper.dart';
import 'package:test/test.dart';

/// One entry as the forum writes it: [version] **name** by *author*.
String _entry(String version, String name, int topicId, String author) =>
    '<li>[<strong><span class="bbc_color">$version</span></strong>] '
    '<strong><a class="bbc_link" href="https://fractalsoftworks.com/forum/index.php?topic=$topicId.0">$name</a></strong> '
    'by <em><strong>$author</strong></em></li>';

void main() {
  group('mod index categories', () {
    test('each list takes the heading above it', () {
      final doc = html_parser.parse('''
        <div class="inner">
          <strong>Utility mods:</strong><br /><br />
          <ul class="bbc_list">
            ${_entry('0.98a', 'Console Commands', 4106, 'LazyWizard')}
          </ul>
          <br /><br />
          <strong>Faction Mods:</strong><br /><br />
          <ul class="bbc_list">
            ${_entry('0.98a', 'Nexerelin', 9175, 'Histidine')}
          </ul>
        </div>
      ''');

      final mods = ForumScraper.parseModIndex(doc);

      expect(mods.map((mod) => mod.name), ['Console Commands', 'Nexerelin']);
      expect(mods[0].categories, ['Utility mods']);
      expect(mods[1].categories, ['Faction Mods']);
    });

    test('a list of add-ons nested in another list does not become a category of its own', () {
      // The forum writes the inner list as a sibling of the entries, not inside one.
      final doc = html_parser.parse('''
        <div class="inner">
          <strong>Utility mods:</strong><br /><br />
          <ul class="bbc_list">
            ${_entry('0.98a', 'A New Level', 20535, 'Panteradactyl')}
            ${_entry('0.98a', 'Advanced Gunnery Control', 21280, 'DesperatePeter')}
            ${_entry('0.98a', 'Combat Chatter Voice Addon', 35585, 'cimo')}
            <ul class="bbc_list">
              ${_entry('0.98a', 'Additional Console Commands', 30955, 'albinobigfoot')}
            </ul>
          </ul>
        </div>
      ''');

      final mods = ForumScraper.parseModIndex(doc);

      // Every mod, the nested one included, is listed once and under the real heading.
      expect(mods.map((mod) => mod.name), [
        'A New Level',
        'Advanced Gunnery Control',
        'Combat Chatter Voice Addon',
        'Additional Console Commands',
      ]);
      for (final mod in mods) {
        expect(mod.categories, ['Utility mods'], reason: '${mod.name} got the wrong category');
      }
    });

    test('a list of add-ons written inside an entry is also left alone', () {
      final doc = html_parser.parse('''
        <div class="inner">
          <strong>Content Expansions:</strong><br /><br />
          <ul class="bbc_list">
            <li>[<strong><span class="bbc_color">0.98a</span></strong>]
              <strong><a class="bbc_link" href="https://fractalsoftworks.com/forum/index.php?topic=100.0">Big Mod</a></strong>
              by <em><strong>Someone</strong></em>
              <ul class="bbc_list">
                ${_entry('0.98a', 'Big Mod Add-On', 101, 'Someone Else')}
              </ul>
            </li>
          </ul>
        </div>
      ''');

      final mods = ForumScraper.parseModIndex(doc);

      expect(mods.map((mod) => mod.name), ['Big Mod', 'Big Mod Add-On']);
      expect(mods.every((mod) => mod.categories?.single == 'Content Expansions'), isTrue);
    });

    test('a single line break between heading and list still works', () {
      final doc = html_parser.parse('''
        <div class="inner">
          <strong>Mission-only:</strong><br />
          <ul class="bbc_list">
            ${_entry('0.9a', 'Mission Pack', 9221, 'Wyvern')}
          </ul>
        </div>
      ''');

      final mods = ForumScraper.parseModIndex(doc);

      expect(mods.single.categories, ['Mission-only']);
    });

    test('a list with no heading above it is not a list of mods', () {
      // The "how to get your mod added" steps are written as a list, with links in them.
      final doc = html_parser.parse('''
        <div class="inner">
          <span>Would you like to have your mod added to the index?</span><br /><br />
          <ul class="bbc_list">
            <li>Create a mod post in the
              <a class="bbc_link" href="https://fractalsoftworks.com/forum/index.php?board=3.0">modding subforum</a></li>
            <li>PM a
              <a class="bbc_link" href="https://fractalsoftworks.com/forum/index.php?topic=2668.0">moderator</a></li>
          </ul>
        </div>
      ''');

      expect(ForumScraper.parseModIndex(doc), isEmpty);
    });

    test('older posts get the name the index uses today', () {
      // Post 1 is today's index; the posts below it are kept for older game versions.
      final doc = html_parser.parse('''
        <div id="forumposts">
          <div class="post"><div class="inner">
            <strong>Faction Mods:</strong><br /><br />
            <ul class="bbc_list">${_entry('0.98a', 'Nexerelin', 9175, 'Histidine')}</ul>
            <br /><br />
            <strong>Megamods:</strong><br /><br />
            <ul class="bbc_list">${_entry('0.98a', 'Arma Armatura', 16058, 'Nia Tahl')}</ul>
          </div></div>
          <div class="post"><div class="inner">
            <strong>Factions:</strong><br /><br />
            <ul class="bbc_list">${_entry('0.7.2a', 'AI War', 9175, 'Histidine')}</ul>
            <br /><br />
            <strong>Total Conversions:</strong><br /><br />
            <ul class="bbc_list">${_entry('0.7.2a', 'Old Conversion', 500, 'Someone')}</ul>
          </div></div>
        </div>
      ''');

      final categories = {
        for (final mod in ForumScraper.parseModIndex(doc)) mod.name: mod.categories,
      };

      expect(categories['AI War'], ['Faction Mods'], reason: 'Factions is now called Faction Mods');
      expect(categories['Old Conversion'], ['Megamods'], reason: 'Total Conversions is now Megamods');
      expect(categories['Nexerelin'], ['Faction Mods']);
      expect(categories['Arma Armatura'], ['Megamods']);
    });

    test('a name the index still uses is left alone, table or no table', () {
      // "Utility mods" is in the table as an old name for "Standalone Utilities", but the index
      // still has a Utility mods heading of its own, so nothing should be renamed.
      final doc = html_parser.parse('''
        <div id="forumposts">
          <div class="post"><div class="inner">
            <strong>Utility mods:</strong><br /><br />
            <ul class="bbc_list">${_entry('0.98a', 'Console Commands', 4106, 'LazyWizard')}</ul>
            <br /><br />
            <strong>Standalone Utilities:</strong><br /><br />
            <ul class="bbc_list">${_entry('0.98a', 'Starsector Mod Manager', 33787, 'Wisp')}</ul>
          </div></div>
          <div class="post"><div class="inner">
            <strong>Utility mods:</strong><br /><br />
            <ul class="bbc_list">${_entry('0.7.2a', 'Old Utility', 600, 'Someone')}</ul>
          </div></div>
        </div>
      ''');

      final categories = {
        for (final mod in ForumScraper.parseModIndex(doc)) mod.name: mod.categories,
      };

      expect(categories['Console Commands'], ['Utility mods']);
      expect(categories['Old Utility'], ['Utility mods']);
      expect(categories['Starsector Mod Manager'], ['Standalone Utilities']);
    });

    test('an old name the table does not know is kept as it was written', () {
      final doc = html_parser.parse('''
        <div id="forumposts">
          <div class="post"><div class="inner">
            <strong>Faction Mods:</strong><br /><br />
            <ul class="bbc_list">${_entry('0.98a', 'Nexerelin', 9175, 'Histidine')}</ul>
          </div></div>
          <div class="post"><div class="inner">
            <strong>Something We Have Never Seen:</strong><br /><br />
            <ul class="bbc_list">${_entry('0.5a', 'Ancient Mod', 700, 'Someone')}</ul>
          </div></div>
        </div>
      ''');

      final mods = ForumScraper.parseModIndex(doc);
      final ancient = mods.firstWhere((mod) => mod.name == 'Ancient Mod');

      expect(ancient.categories, ['Something We Have Never Seen']);
    });

    test('the heading keeps its wording, minus the trailing colon', () {
      final doc = html_parser.parse('''
        <div class="inner">
          <strong>Portrait Packs::</strong><br /><br />
          <ul class="bbc_list">
            ${_entry('0.98a', 'Some Portraits', 200, 'Artist')}
          </ul>
        </div>
      ''');

      expect(ForumScraper.parseModIndex(doc).single.categories, ['Portrait Packs']);
    });
  });
}
