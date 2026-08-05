import 'package:mod_repo_scraper/bot/scraper/category_aliases.dart';
import 'package:test/test.dart';

void main() {
  group('tidyCategoryNames', () {
    test('a Discord tag becomes the forum wording', () {
      expect(tidyCategoryNames(['Faction']), ['Faction Mods']);
      expect(tidyCategoryNames(['Utility']), ['Utility mods']);
      expect(tidyCategoryNames(['Library']), ['Libraries']);
      expect(tidyCategoryNames(['Megamod']), ['Megamods']);
    });

    test('a mod on both sources says each category once', () {
      expect(tidyCategoryNames(['Faction', 'Faction Mods']), ['Faction Mods']);
      expect(tidyCategoryNames(['Faction Mods', 'Faction']), ['Faction Mods']);
      expect(tidyCategoryNames(['Megamod', 'Megamods']), ['Megamods']);
    });

    test("Discord's own shelves are left alone", () {
      // These say what a mod does, and the forum has no heading to fold them into.
      const discordOnly = [
        'Ship Pack',
        'Weapon/Fighter Pack',
        'Misc. Campaign Mods',
        'Other/Misc.',
        'Quality of Life',
        'Exploration',
        'Audio/Visual',
        'Modular Hullmods',
        'Quests and Bars',
        'Colonies',
        'Skills and Abilities',
        'Officers',
        'Portrait/Flag Pack',
        'Discord Only',
        // Close to a forum heading, but not close enough to fold in.
        'Total Conversion',
        'Mod Manager',
      ];

      expect(tidyCategoryNames(discordOnly), discordOnly);
    });

    test('forum headings are left alone', () {
      const forumHeadings = [
        'Faction Mods',
        'Utility mods',
        'Miscellaneous Mods',
        'Content Expansions',
        'Portrait Packs',
        'Libraries',
        'Megamods',
        'Feature overhauls',
        'Flag Packs',
        'Standalone Utilities',
      ];

      expect(tidyCategoryNames(forumHeadings), forumHeadings);
    });

    test('the order categories were found in is kept', () {
      expect(
        tidyCategoryNames(['Ship Pack', 'Faction', 'Exploration', 'Faction Mods']),
        ['Ship Pack', 'Faction Mods', 'Exploration'],
      );
    });

    test('capitals and stray spaces do not stop a match', () {
      expect(tidyCategoryNames([' faction ']), ['Faction Mods']);
      expect(tidyCategoryNames(['MEGAMOD']), ['Megamods']);
    });

    test('an empty list stays empty', () {
      expect(tidyCategoryNames([]), isEmpty);
    });

    test('every answer in the table is spelled the way the forum spells it', () {
      // A typo here would invent a heading the mod index does not have.
      const forumHeadings = {
        'Faction Mods',
        'Utility mods',
        'Miscellaneous Mods',
        'Content Expansions',
        'Portrait Packs',
        'Libraries',
        'Megamods',
        'Feature overhauls',
        'Flag Packs',
        'Standalone Utilities',
      };

      for (final entry in discordCategoryAliases.entries) {
        expect(forumHeadings, contains(entry.value),
            reason: "'${entry.key}' maps to '${entry.value}', which is not a mod index heading");
      }
    });
  });
}
