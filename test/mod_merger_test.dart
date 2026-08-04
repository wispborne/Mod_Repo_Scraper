import 'package:test/test.dart';
import 'package:mod_repo_scraper/bot/scraper/mod_merger.dart';
import 'package:mod_repo_scraper/bot/scraper/mod_repo_utils.dart';
import 'package:mod_repo_scraper/bot/scraper/scraped_mod.dart';

void main() {
  group('extractForumTopicId', () {
    test('extracts topic ID from standard https URL', () {
      expect(
        ModMerger.extractForumTopicId('https://fractalsoftworks.com/forum/index.php?topic=26122.0'),
        equals('26122'),
      );
    });

    test('extracts topic ID from http URL', () {
      expect(
        ModMerger.extractForumTopicId('http://fractalsoftworks.com/forum/index.php?topic=15122.0'),
        equals('15122'),
      );
    });

    test('extracts topic ID from URL without trailing .0', () {
      expect(
        ModMerger.extractForumTopicId('https://fractalsoftworks.com/forum/index.php?topic=25205'),
        equals('25205'),
      );
    });

    test('extracts topic ID from URL with message anchor', () {
      expect(
        ModMerger.extractForumTopicId('https://fractalsoftworks.com/forum/index.php?topic=27367.msg404012#msg404012'),
        equals('27367'),
      );
    });

    test('returns null for null URL', () {
      expect(ModMerger.extractForumTopicId(null), isNull);
    });

    test('returns null for empty URL', () {
      expect(ModMerger.extractForumTopicId(''), isNull);
    });

    test('returns null for non-forum URL', () {
      expect(
        ModMerger.extractForumTopicId('https://discord.com/channels/12345'),
        isNull,
      );
    });

    test('returns null for URL without topic parameter', () {
      expect(
        ModMerger.extractForumTopicId('https://fractalsoftworks.com/forum/index.php'),
        isNull,
      );
    });
  });

  group('Forum URL normalization in merge', () {
    final merger = ModMerger();

    test('http and https variants of same topic match', () async {
      final mods = [
        const ScrapedMod(
          name: 'AI Flag Tool',
          authorsList: ['Blothorn'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=15122.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'AI Flag Tool',
          authorsList: ['Blothorn'],
          urls: {ModUrlType.Forum: 'http://fractalsoftworks.com/forum/index.php?topic=15122.0'},
          sources: [ModSource.Index],
        ),
      ];

      final result = await merger.merge(mods);
      // Should merge into 1 mod (both are the same)
      expect(result.length, equals(1));
      expect(result.first.name, equals('AI Flag Tool'));
    });

    test('URL with and without trailing .0 for same topic match', () async {
      final mods = [
        const ScrapedMod(
          name: 'Test Mod',
          authorsList: ['Author'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=25205.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'Test Mod',
          authorsList: ['Author'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=25205'},
          sources: [ModSource.Discord],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result.length, equals(1));
    });

    test('URL with message anchor matches same topic', () async {
      final mods = [
        const ScrapedMod(
          name: 'Test Mod',
          authorsList: ['Author'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=27367.msg404012#msg404012'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'Test Mod',
          authorsList: ['Author'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=27367.0'},
          sources: [ModSource.Discord],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result.length, equals(1));
    });

    test('different topic IDs do not match on URL alone', () async {
      final mods = [
        const ScrapedMod(
          name: 'Mod A',
          authorsList: ['Author A'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=11111.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'Mod B',
          authorsList: ['Author B'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=22222.0'},
          sources: [ModSource.Index],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result.length, equals(2));
    });
  });

  group('Name length-ratio guard', () {
    final merger = ModMerger();

    test('Known Skies and Unknown Skies are NOT merged (ratio 0.83)', () async {
      final mods = [
        const ScrapedMod(
          name: 'Known Skies',
          authorsList: ['jamestripleq'],
          urls: {ModUrlType.Discord: 'https://discord.com/channels/1'},
          sources: [ModSource.Discord],
        ),
        const ScrapedMod(
          name: 'Unknown Skies',
          authorsList: ['jamestripleq'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=99999.0'},
          sources: [ModSource.Index],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result.length, equals(2), reason: '"Known Skies" and "Unknown Skies" should be separate mods');
    });

    test('ApproLight and ApproLight Plus are NOT merged (ratio 0.71)', () async {
      final mods = [
        const ScrapedMod(
          name: 'ApproLight',
          authorsList: ['Originem'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=9688.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'ApproLight Plus',
          authorsList: ['Originem'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=18227.0'},
          sources: [ModSource.Index],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result.length, equals(2), reason: '"ApproLight" and "ApproLight Plus" should be separate mods');
    });

    test('minor name typo still merges (ratio > 0.85)', () async {
      final mods = [
        const ScrapedMod(
          name: 'Starsector Mod',
          authorsList: ['TestAuthor'],
          urls: {ModUrlType.Discord: 'https://discord.com/channels/1'},
          sources: [ModSource.Discord],
        ),
        const ScrapedMod(
          name: 'Starsector Mods',
          authorsList: ['TestAuthor'],
          urls: {ModUrlType.Discord: 'https://discord.com/channels/2'},
          sources: [ModSource.Discord],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result.length, equals(1), reason: 'Minor name typo should still merge');
    });

    test('exact same name always merges', () async {
      final mods = [
        const ScrapedMod(
          name: 'LazyLib',
          authorsList: ['LazyWizard'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=5444.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'LazyLib',
          authorsList: ['arkmagius'],
          urls: {ModUrlType.Discord: 'https://discord.com/channels/1'},
          sources: [ModSource.Discord],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result.length, equals(1), reason: 'Exact same name with aliased author should merge');
    });
  });

  group('Dedup safety check', () {
    final merger = ModMerger();

    test('same mod different versions from same source deduplicates normally', () async {
      final mods = [
        const ScrapedMod(
          name: 'Leading Pip',
          authorsList: ['Dark.Revenant'],
          gameVersionReq: '0.97a',
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=7921.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'Leading Pip',
          authorsList: ['Dark.Revenant'],
          gameVersionReq: '0.98a',
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=7921.0'},
          sources: [ModSource.Index],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result.length, equals(1));
      expect(result.first.gameVersionReq, equals('0.98a'));
    });

    test('same thread but unrelated names stay separate', () async {
      // Some authors keep several mods in one forum thread. A shared thread
      // alone must not merge mods whose names have nothing in common.
      final mods = [
        const ScrapedMod(
          name: 'Alpha Mod',
          authorsList: ['SharedAuthor'],
          gameVersionReq: '0.95a',
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=55555.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'Completely Different Name',
          authorsList: ['SharedAuthor'],
          gameVersionReq: '0.98a',
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=55555.0'},
          sources: [ModSource.Index],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result.length, equals(2));
    });

    test('same thread with a version-suffixed name still merges', () async {
      // A Discord post titled "<mod> 1.2.3" linking the mod's thread is the
      // same mod, even though the raw names differ a lot in length.
      final mods = [
        const ScrapedMod(
          name: 'Alpha Mod',
          authorsList: ['AuthorOne'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=55556.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'Alpha Mod 1.2.3 (2026-01-01)',
          authorsList: ['SomeoneElse'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=55556.0'},
          sources: [ModSource.Discord],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result.length, equals(1));
    });
  });

  group('Grouping is transitive and publishes each mod once', () {
    final merger = ModMerger();

    test('old thread, new thread, and Discord post all become one mod', () async {
      // The old thread only matches the new thread (by name and author), and
      // the Discord post only matches the new thread (by forum topic). All
      // three must land in one group — and nothing may appear twice.
      final mods = [
        const ScrapedMod(
          name: 'Chain Mod',
          authorsList: ['OldAuthor'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=11111.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'Chain Mod',
          authorsList: ['OldAuthor, NewAuthor'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=22222.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'Chain Mod v2.0',
          authorsList: ['NewAuthor'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=22222.0'},
          sources: [ModSource.Discord],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result.length, equals(1));
    });

    test('author credit lists match no matter which side is longer', () async {
      // "hqz" must match "hqz, NightKev" whichever entry the merger looks at
      // first — one-way subsequence matching used to make this depend on order.
      for (final ordering in [
        ['hqz, NightKev', 'hqz'],
        ['hqz', 'hqz, NightKev'],
      ]) {
        final mods = [
          ScrapedMod(
            name: 'Ordering Mod',
            authorsList: [ordering[0]],
            urls: const {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=33333.0'},
            sources: const [ModSource.Index],
          ),
          ScrapedMod(
            name: 'Ordering Mod',
            authorsList: [ordering[1]],
            urls: const {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=44444.0'},
            sources: const [ModSource.Index],
          ),
        ];

        final result = await merger.merge(mods);
        expect(result.length, equals(1), reason: 'order: $ordering');
      }
    });

    test('a shared person inside two different author credits matches', () async {
      // "Snrasha, NicoBBQ" and "NicoBBQ, carolinlove" share one person, so
      // two same-named entries are the same mod handed to a new keeper.
      final mods = [
        const ScrapedMod(
          name: 'Handover Mod',
          authorsList: ['Snrasha, NicoBBQ'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=66666.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'Handover Mod',
          authorsList: ['NicoBBQ, carolinlove'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=77777.0'},
          sources: [ModSource.Index],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result.length, equals(1));
    });
  });

  group('Pre-deduplication of input entries', () {
    final merger = ModMerger();

    test('exact duplicate inputs are collapsed before grouping', () async {
      // Simulate "Fleet Journal" appearing 3x from Index with same forum URL
      final mods = [
        const ScrapedMod(
          name: 'Fleet Journal',
          authorsList: ['Ontheheavens'],
          gameVersionReq: '0.97a',
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=26122.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'Fleet Journal',
          authorsList: ['Ontheheavens'],
          gameVersionReq: '0.95.1a',
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=26122.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'Fleet Journal',
          authorsList: ['Ontheheavens'],
          gameVersionReq: '0.97a',
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=26122.0'},
          sources: [ModSource.Index],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result.length, equals(1));
      expect(result.first.name, equals('Fleet Journal'));
    });

    test('same name different sources are NOT deduped', () async {
      final mods = [
        const ScrapedMod(
          name: 'Test Mod',
          authorsList: ['Author'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=11111.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'Test Mod',
          authorsList: ['Author'],
          urls: {ModUrlType.Discord: 'https://discord.com/channels/1'},
          sources: [ModSource.Discord],
        ),
      ];

      final result = await merger.merge(mods);
      // They have different sources, so pre-dedup keeps both.
      // But they merge via name+author match into 1 final mod.
      expect(result.length, equals(1));
      // The merged mod should have both sources.
      expect(result.first.getSources(), containsAll([ModSource.Index, ModSource.Discord]));
    });

    test('keeps entry with more data when deduplicating', () async {
      final mods = [
        const ScrapedMod(
          name: 'Sparse Mod',
          authorsList: ['Author'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=11111.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'Sparse Mod',
          authorsList: ['Author'],
          summary: 'A great mod',
          description: 'This mod does things',
          modVersion: '1.0',
          gameVersionReq: '0.98a',
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=11111.0'},
          sources: [ModSource.Index],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result.length, equals(1));
      // The richer entry should have won the pre-dedup
      expect(result.first.summary, equals('A great mod'));
      expect(result.first.gameVersionReq, equals('0.98a'));
    });
  });

  group('Trigram-indexed candidate generation', () {
    final merger = ModMerger();

    test('mods with similar names are found via trigram index', () async {
      final mods = [
        const ScrapedMod(
          name: 'AI-Retrofits',
          authorsList: ['alaricdragon'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=22261.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'AI-Retrofits V0.10.1',
          authorsList: ['alaricdragon'],
          urls: {ModUrlType.Discord: 'https://discord.com/channels/1'},
          sources: [ModSource.Discord],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result.length, equals(1), reason: 'Same mod with version suffix should merge');
    });

    test('completely unrelated mods stay separate', () async {
      final mods = [
        const ScrapedMod(
          name: 'GraphicsLib',
          authorsList: ['Dark.Revenant'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=10982.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'MagicLib',
          authorsList: ['Tartiflette'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=13718.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'LazyLib',
          authorsList: ['LazyWizard'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=5444.0'},
          sources: [ModSource.Index],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result.length, equals(3), reason: 'Three different libs should stay separate');
    });

    test('mods with short names (< 3 chars) still handled', () async {
      final mods = [
        const ScrapedMod(
          name: 'AB',
          authorsList: ['Author'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=11111.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'AB',
          authorsList: ['Author'],
          urls: {ModUrlType.Discord: 'https://discord.com/channels/1'},
          sources: [ModSource.Discord],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result.length, equals(1), reason: 'Short-named mods should still merge via exact name bucket');
    });

    test('large set of distinct mods stays separate', () async {
      // Use truly distinct names and authors (no shared prefix that collapses after stripping digits).
      final distinctNames = [
        'GraphicsLib',
        'MagicLib',
        'LazyLib',
        'LunaLib',
        'Nexerelin',
        'Interstellar Imperium',
        'Tahlan Shipworks',
        'Diable Avionics',
        'Underworld',
        'SpeedUp',
        'Audio Plus',
        'FleetBuilder',
        'Hyperdrive',
        'Combat Chatter',
        'Planet Search',
        'Starship Legends',
        'Ruthless Sector',
        'Perilous Expanse',
        'Nomadic Survival',
        'New Beginnings',
      ];
      final distinctAuthors = [
        'DarkRevenant',
        'Tartiflette',
        'LazyWizard',
        'LukasZero',
        'Histidine',
        'DarkRevenantTwo',
        'NiaTahl',
        'CaymonJoestar',
        'DarkRevenantThree',
        'DarkRevenantFour',
        'DarkRevenantFive',
        'SNuman',
        'Sundog',
        'HistidineTwo',
        'andylizi',
        'SundogTwo',
        'SundogThree',
        'SundogFour',
        'SundogFive',
        'SundogSix',
      ];
      final mods = List.generate(
          20,
          (i) => ScrapedMod(
                name: distinctNames[i],
                authorsList: [distinctAuthors[i]],
                urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=${10000 + i}.0'},
                sources: [ModSource.Index],
              ));

      final result = await merger.merge(mods);
      expect(result.length, equals(20), reason: 'All distinct mods should remain separate');
    });
  });

  group('stripVersionNoise', () {
    test('version and subtitle', () {
      expect(
        stripVersionNoise('Hazard Mining Incorporated 0.4.0e "Please be fixed Ed."'),
        equals('Hazard Mining Incorporated'),
      );
    });

    test('leading game-version tag', () {
      expect(
        stripVersionNoise('[0.97a] Combat Docking Module v0.0.6'),
        equals('Combat Docking Module'),
      );
    });

    test('leading non-version tag', () {
      expect(
        stripVersionNoise('[WIP] Arcahv Empire'),
        equals('Arcahv Empire'),
      );
    });

    test('v-dot prefix', () {
      expect(
        stripVersionNoise("Caymon's Ship pack v.1.2.4- Full stop to life"),
        equals("Caymon's Ship pack"),
      );
    });

    test('no version', () {
      expect(
        stripVersionNoise('Chatter Expansion Project'),
        equals('Chatter Expansion Project'),
      );
    });

    test('number that is not a version', () {
      expect(
        stripVersionNoise('Warhammer 40000: Banished Imperium 1.0'),
        equals('Warhammer 40000: Banished Imperium'),
      );
    });

    test('empty result falls back to original', () {
      expect(stripVersionNoise('v1.0.0'), equals('v1.0.0'));
    });
  });

  group('stripVersionNoise known weaknesses', () {
    test('version mid-title takes the tail with it', () {
      expect(
        stripVersionNoise('Substance.Abuse 1.1.c - Consumable Alcohol'),
        equals('Substance.Abuse'),
      );
    });

    test('spaced marker survives', () {
      expect(
        stripVersionNoise('Agrean Breakers, ver 3.0'),
        equals('Agrean Breakers, ver'),
      );
    });
  });

  group('Version-stripped name matching', () {
    final merger = ModMerger();

    test('HMI entries merge into one group', () async {
      final mods = [
        const ScrapedMod(
          name: 'Hazard Mining Incorporated',
          authorsList: ['King Alfonzo'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=11111.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'Hazard Mining Incorporated',
          authorsList: ['King Alfonzo'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=22222.0'},
          sources: [ModSource.ModdingSubforum],
        ),
        const ScrapedMod(
          name: 'Hazard Mining Incorporated 0.4.0e "Please be fixed Ed."',
          authorsList: ['King Alfonzo'],
          urls: {ModUrlType.Discord: 'https://discord.com/channels/1'},
          sources: [ModSource.Discord],
        ),
        const ScrapedMod(
          name: 'Hazard Mining Incorporated 0.3.5a "Kalisma Patch"',
          authorsList: ['King Alfonzo'],
          urls: {ModUrlType.Discord: 'https://discord.com/channels/2'},
          sources: [ModSource.Discord],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result.length, equals(1), reason: 'All four HMI entries should merge into one group');
    });

    test('Substance.Abuse regression — scraped names still match', () async {
      final mods = [
        const ScrapedMod(
          name: 'Substance.Abuse - Consumable Alcohol',
          authorsList: ['TobiaF'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=33333.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'Substance.Abuse 1.1.c - Consumable Alcohol',
          authorsList: ['TobiaF'],
          urls: {ModUrlType.Discord: 'https://discord.com/channels/3'},
          sources: [ModSource.Discord],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result.length, equals(1), reason: 'Substance.Abuse pair must still merge on scraped names');
    });

    test('SSMSControllerEx regression — scraped names still match', () async {
      final mods = [
        const ScrapedMod(
          name: 'SSMSControllerEx - Controller Support',
          authorsList: ['Soren'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=44444.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: '[0.98a]SSMSControllerEx v1.1 - Controller support',
          authorsList: ['Harmful Mechanic'],
          urls: {ModUrlType.Discord: 'https://discord.com/channels/4'},
          sources: [ModSource.Discord],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result.length, equals(1), reason: 'SSMSControllerEx pair must still merge on scraped names');
    });

    test("Kon's regression — shared forum thread path still works", () async {
      final mods = [
        const ScrapedMod(
          name: "Kon's Multi-Pack v.6.0.6 - 13th Battlegroup Player Faction",
          authorsList: ['Kon'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=25040.0'},
          sources: [ModSource.ModdingSubforum],
        ),
        const ScrapedMod(
          name: "Kon's Player Faction Bundles",
          authorsList: ['Kon'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=25040.0'},
          sources: [ModSource.Index],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result.length, equals(1), reason: "Kon's mods share a forum thread and related names");
    });

    test('Domain Historical Society — dedup safety check uses stripped reading', () async {
      final mods = [
        const ScrapedMod(
          name: 'Domain Historical Society-0.97 Achi edition (original edition attached below)',
          authorsList: ['Achi'],
          gameVersionReq: '0.97a',
          urls: {ModUrlType.Discord: 'https://discord.com/channels/5'},
          sources: [ModSource.Discord],
        ),
        const ScrapedMod(
          name: 'Domain Historical Society-0.98',
          authorsList: ['Achi'],
          gameVersionReq: '0.98a',
          urls: {ModUrlType.Discord: 'https://discord.com/channels/6'},
          sources: [ModSource.Discord],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result.length, equals(1), reason: 'Should merge and dedup, keeping newer game version');
      expect(result.first.gameVersionReq, equals('0.98a'));
    });
  });

  group('a forum link that points at another mod is dropped', () {
    final merger = ModMerger();

    ScrapedMod? findByName(List<ScrapedMod> mods, String name) =>
        mods.where((mod) => mod.name == name).firstOrNull;

    test('Moci ship pack linking Box Util loses the link', () async {
      final mods = [
        const ScrapedMod(
          name: 'Box Util',
          authorsList: ['Shiozakana & Mycophobia'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=32003.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: '-Moci ship pack first translation-',
          authorsList: ['alfmannerheim'],
          urls: {
            ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=32003.0',
            ModUrlType.Discord: 'https://discord.com/channels/1/2/3',
          },
          sources: [ModSource.Discord],
        ),
      ];

      final result = await merger.merge(mods);

      expect(result.length, equals(2));
      final shipPack = findByName(result, '-Moci ship pack first translation-');
      expect(shipPack, isNotNull);
      expect(shipPack!.getUrls()[ModUrlType.Forum], isNull);
      expect(shipPack.getUrls()[ModUrlType.Discord], isNotNull);
      expect(findByName(result, 'Box Util')?.getUrls()[ModUrlType.Forum], isNotNull);
    });

    test('a download page pointing at the same rejected thread goes too', () async {
      final mods = [
        const ScrapedMod(
          name: 'Box Util',
          authorsList: ['Shiozakana'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=32003.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'Gundam Ship Compilation',
          authorsList: ['alfmannerheim'],
          urls: {
            ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=32003.0',
            ModUrlType.DownloadPage: 'https://fractalsoftworks.com/forum/index.php?topic=32003.0',
          },
          sources: [ModSource.Discord],
        ),
      ];

      final result = await merger.merge(mods);
      final shipPack = findByName(result, 'Gundam Ship Compilation');
      expect(shipPack?.getUrls()[ModUrlType.Forum], isNull);
      expect(shipPack?.getUrls()[ModUrlType.DownloadPage], isNull);
    });

    test('a shared author keeps the link, even with a very different name', () async {
      final mods = [
        const ScrapedMod(
          name: 'Ship and Weapon Pack',
          authorsList: ['DarkRevenant'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=6449.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'SWP',
          authorsList: ['DarkRevenant'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=6449.0'},
          sources: [ModSource.Discord],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result.every((mod) => mod.getUrls()[ModUrlType.Forum] != null), isTrue);
    });

    test('a thread we never scraped is left alone', () async {
      final mods = [
        const ScrapedMod(
          name: 'Some Discord Mod',
          authorsList: ['Somebody'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=99999.0'},
          sources: [ModSource.Discord],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result.single.getUrls()[ModUrlType.Forum], contains('topic=99999'));
    });

    test('Bultach: shared trigrams keep the link, even with a different author', () async {
      final mods = [
        const ScrapedMod(
          name: 'Bultach Coalition',
          authorsList: ['Nerzhull_AI'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=24616.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'Bultach 1.1.7 "Of Humanity."',
          authorsList: ['someoneelse'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=24616.0'},
          sources: [ModSource.Discord],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result.every((mod) => mod.getUrls()[ModUrlType.Forum] != null), isTrue);
    });

    test('Custom Chatter: zero-overlap link to Take No Prisoners is dropped', () async {
      final mods = [
        const ScrapedMod(
          name: 'Take No Prisoners',
          authorsList: ['Kaysaar'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=30039.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'Custom Chatter, a community driven combat chatter addon.',
          authorsList: ['somebody'],
          urls: {
            ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=30039.0',
            ModUrlType.Discord: 'https://discord.com/channels/1/2/3',
          },
          sources: [ModSource.Discord],
        ),
      ];

      final result = await merger.merge(mods);
      final chatter = findByName(result, 'Custom Chatter, a community driven combat chatter addon.');
      expect(chatter?.getUrls()[ModUrlType.Forum], isNull);
    });

    test('SWP initials match Ship and Weapon Pack, link kept', () async {
      final mods = [
        const ScrapedMod(
          name: 'Ship and Weapon Pack',
          authorsList: ['DarkRevenant'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=6449.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'SWP',
          authorsList: ['somebody'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=6449.0'},
          sources: [ModSource.Discord],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result.every((mod) => mod.getUrls()[ModUrlType.Forum] != null), isTrue);
    });

    test('a related name keeps the link', () async {
      final mods = [
        const ScrapedMod(
          name: 'Oculian Armada',
          authorsList: ['Nia'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=12345.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'Oculian Armada AKA Red',
          authorsList: ['SomebodyElse'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=12345.0'},
          sources: [ModSource.Discord],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result.every((mod) => mod.getUrls()[ModUrlType.Forum] != null), isTrue);
    });
  });

  group('tidyAuthorNames', () {
    test('Nexerelin: three spellings of two people become two names', () {
      expect(
        ModRepoUtils.tidyAuthorNames(['Histidine', 'Histidine, Zaphide', 'histidine_my']),
        equals(['Histidine', 'Zaphide']),
      );
    });

    test('keeps the spelling with capitals', () {
      expect(ModRepoUtils.tidyAuthorNames(['Kaysaar', 'kaysaar']), equals(['Kaysaar']));
      expect(ModRepoUtils.tidyAuthorNames(['criowo', 'CriOwO']), equals(['CriOwO']));
    });

    test('drops the digits some people carry on the end of a Discord name', () {
      expect(ModRepoUtils.tidyAuthorNames(['Sundog', 'sundog3161']), equals(['Sundog']));
      expect(ModRepoUtils.tidyAuthorNames(['Dal', 'dal041']), equals(['Dal']));
    });

    test('a name that is mostly digits is not worn down to nothing', () {
      // All three are the same person, so they still fold together — but on
      // spelling, not by having "111164" chopped off and everything matching
      // whatever else starts with an "a".
      expect(
        ModRepoUtils.tidyAuthorNames(['A-111164', 'A111164', 'a111164']),
        equals(['A111164']),
      );
      expect(ModRepoUtils.tidyAuthorNames(['A111164', 'Astarat']), equals(['A111164', 'Astarat']));
    });

    test('ignores leading punctuation', () {
      expect(ModRepoUtils.tidyAuthorNames(['.vicegrip', 'vicegrip']), equals(['vicegrip']));
      expect(ModRepoUtils.tidyAuthorNames(['Astarat', 'astarat.']), equals(['Astarat']));
    });

    test('folds together names listed as aliases', () {
      expect(ModRepoUtils.tidyAuthorNames(['Nes', 'nescom']), equals(['Nes']));
      expect(ModRepoUtils.tidyAuthorNames(['Ed, Nick XR', 'Nick XR', 'nick7884']), equals(['Ed', 'Nick XR']));
    });

    test('finds an alias row even when the name has digits on the end', () {
      // The table lists "hakureireimu"; Discord hands us "hakureireimu6512".
      expect(ModRepoUtils.tidyAuthorNames(['LngA7Gw', 'hakureireimu6512']), equals(['LngA7Gw']));
    });

    test('splits a credit that names several people', () {
      expect(
        ModRepoUtils.tidyAuthorNames(['FluffyRabbit', 'Kentington & FluffyRabbit', 'Kentington, FluffyRabbit']),
        equals(['FluffyRabbit', 'Kentington']),
      );
      expect(
        ModRepoUtils.tidyAuthorNames(['Thule / lechibang / joaonunes']),
        equals(['joaonunes', 'lechibang', 'Thule']),
      );
      expect(ModRepoUtils.tidyAuthorNames(['by IonDragonX & MrDavidhoff']), equals(['IonDragonX', 'MrDavidhoff']));
    });

    test('does not split a name that carries a title', () {
      expect(
        ModRepoUtils.tidyAuthorNames(['Snrasha, the tinkerer', 'Snrasha']),
        equals(['Snrasha']),
      );
    });

    test('leaves a list of different people alone', () {
      expect(
        ModRepoUtils.tidyAuthorNames(['Selkie', 'Dal', 'Starficz']),
        equals(['Dal', 'Selkie', 'Starficz']),
      );
    });

    test('an empty list stays empty', () {
      expect(ModRepoUtils.tidyAuthorNames([]), isEmpty);
    });

    test('the merge tidies the authors of what it publishes', () async {
      final merger = ModMerger();
      final mods = [
        const ScrapedMod(
          name: 'Nexerelin',
          authorsList: ['Histidine, Zaphide'],
          urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=9175.0'},
          sources: [ModSource.Index],
        ),
        const ScrapedMod(
          name: 'Nexerelin',
          authorsList: ['histidine_my'],
          urls: {
            ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=9175.0',
            ModUrlType.Discord: 'https://discord.com/channels/1/2/3',
          },
          sources: [ModSource.Discord],
        ),
      ];

      final result = await merger.merge(mods);
      expect(result, hasLength(1));
      expect(result.first.getAuthors(), equals(['Histidine', 'Zaphide']));
    });
  });
}
