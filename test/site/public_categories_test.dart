import 'package:mod_repo_scraper/site/public_categories.dart';
import 'package:test/test.dart';

/// The forum and Discord between them name 26 shelves, several of which mean
/// the same thing: "Utility mods", "Standalone Utilities" and "Quality of Life"
/// sat side by side, as did "Other/Misc.", "Miscellaneous Mods" and "Misc.
/// Campaign Mods". A reader browsing by kind had a dropdown of overlapping
/// names. These thirteen are what the site offers instead.
void main() {
  test('every raw name the sources use has a public category', () {
    for (final raw in rawCategoryNames) {
      expect(publicCategoryFor(raw), isNotNull,
          reason: '"$raw" is not in the table');
    }
  });

  test('every public category is one of the thirteen', () {
    for (final raw in rawCategoryNames) {
      expect(publicCategories, contains(publicCategoryFor(raw)));
    }
  });

  test('every one of the thirteen is a category some mod can land on', () {
    final used = {for (final raw in rawCategoryNames) publicCategoryFor(raw)};
    for (final category in publicCategories) {
      expect(used, contains(category),
          reason: '"$category" is offered but nothing maps onto it');
    }
  });

  test('the names that mean the same thing land together', () {
    expect(publicCategoryFor('Utility mods'), 'Utilities');
    expect(publicCategoryFor('Standalone Utilities'), 'Utilities');
    expect(publicCategoryFor('Mod Manager'), 'Utilities');

    expect(publicCategoryFor('Miscellaneous Mods'), 'Everything else');
    expect(publicCategoryFor('Other/Misc.'), 'Everything else');

    expect(publicCategoryFor('Portrait Packs'), 'Portraits and flags');
    expect(publicCategoryFor('Flag Packs'), 'Portraits and flags');
    expect(publicCategoryFor('Portrait/Flag Pack'), 'Portraits and flags');
  });

  test('libraries are their own thing, not lumped in with utilities', () {
    expect(publicCategoryFor('Libraries'), 'Libraries');
  });

  test('"Discord Only" is a source, not a kind of mod, so it has none', () {
    expect(publicCategoryFor('Discord Only'), isNull);
  });

  test('a name nobody has seen before gets nothing rather than a wrong shelf',
      () {
    expect(publicCategoryFor('Something New'), isNull);
  });

  test('the spelling and the spaces around it do not matter', () {
    expect(publicCategoryFor('  faction mods  '), 'Factions');
  });

  test('a mod on several shelves gets each public category once', () {
    expect(
      publicCategoriesFor(const ['Ship Pack', 'Weapon/Fighter Pack', 'Faction Mods']),
      ['Factions', 'Ships and weapons'],
    );
  });

  test('a mod with nothing but "Discord Only" ends up with no category', () {
    expect(publicCategoriesFor(const ['Discord Only']), isEmpty);
  });

  test('the categories come back in the order the site lists them', () {
    expect(
      publicCategoriesFor(const ['Audio/Visual', 'Faction Mods', 'Libraries']),
      ['Factions', 'Libraries', 'Sound and graphics'],
    );
  });
}
