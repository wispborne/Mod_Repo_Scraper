import 'package:mod_repo_scraper/site/mod_id_store.dart';
import 'package:mod_repo_scraper/site/mod_name_match.dart';
import 'package:test/test.dart';

void main() {
  group('matchableName', () {
    test('takes the version off the end', () {
      expect(matchableName('Useful.Tithes 1.0.a'), 'useful.tithes');
      expect(matchableName('Big Pilum Energy 1.0.d'), 'big pilum energy');
    });

    test('cuts at a version in the middle, subtitle and all', () {
      // The one that made a separate matcher necessary: the merge writes the
      // version in the middle and hangs a subtitle behind it.
      expect(
        matchableName('Disco.Balls 1.1.c - More Lamp Colour Options'),
        'disco.balls',
      );
    });

    test('drops the bracketed game version at the front', () {
      expect(matchableName('[0.98a] Nexerelin v0.12.2'), 'nexerelin');
      expect(matchableName('[0.98a][WIP] Starship Legends'), 'starship legends');
    });

    test('drops a bare "Mod" on the end, on both sides alike', () {
      // A title ending "Mod" says nothing about which mod, so it comes off —
      // and because it comes off both names being compared, a mod written
      // "Combat Chatter Mod" one place and "Combat Chatter" the other still
      // reads as one mod.
      expect(matchableName('Combat Chatter Mod'), 'combat chatter');
      expect(modNamesMatch('Combat Chatter Mod', 'Combat Chatter'), isTrue);
    });

    test('drops a bracketed version and a trailing "Mod"', () {
      expect(
        matchableName('[0.98a] Red - the Oculian Armada (0.10.2-RC4) Mod'),
        'red - the oculian armada',
      );
    });

    test('leaves a name that is not a version alone', () {
      // "Ship Pack 2" is a name, not a version. Cutting there would lose it.
      expect(matchableName('Ship Pack 2'), 'ship pack 2');
      expect(matchableName('Lost.Sector'), 'lost.sector');
    });

    test('falls back to the name when it is all decoration', () {
      expect(matchableName('[0.98a]'), '[0.98a]');
    });
  });

  group('modNamesMatch', () {
    test('a merged name and the LLM name for the same mod agree', () {
      // Every one of these is a real pair off topic 34161. Under
      // ModIdStore.cleanName none of them matched, so all four would have been
      // published a second time.
      expect(modNamesMatch('Useful.Tithes 1.0.a', 'Useful.Tithes'), isTrue);
      expect(modNamesMatch('Big Pilum Energy 1.0.d', 'Big Pilum Energy'), isTrue);
      expect(
        modNamesMatch('Disco.Balls 1.1.c - More Lamp Colour Options', 'Disco.Balls'),
        isTrue,
      );
    });

    test('a mod the thread also holds does not match', () {
      expect(modNamesMatch('Useful.Tithes 1.0.a', 'Lost.Sector'), isFalse);
      expect(modNamesMatch('Big Pilum Energy 1.0.d', 'Disco.Balls'), isFalse);
    });

    test('punctuation and capitals do not keep two names apart', () {
      expect(modNamesMatch('Useful.Tithes', 'Useful Tithes'), isTrue);
      expect(modNamesMatch('LOST_SECTOR', 'Lost.Sector'), isTrue);
    });

    test('two plainly different mods stay different', () {
      expect(modNamesMatch('Nexerelin', 'Industrial.Evolution'), isFalse);
      expect(modNamesMatch('LazyLib', 'MagicLib'), isFalse);
    });

    test('it is keener than the id name, which must not change', () {
      // Why this file exists. cleanName is what ids are filed under, so it can
      // never be made keener; these two have to be told apart there and read as
      // one mod here.
      expect(
        ModIdStore.cleanName('Useful.Tithes 1.0.a'),
        isNot(ModIdStore.cleanName('Useful.Tithes')),
      );
      expect(modNamesMatch('Useful.Tithes 1.0.a', 'Useful.Tithes'), isTrue);
    });
  });
}
