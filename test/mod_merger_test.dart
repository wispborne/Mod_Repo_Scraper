import 'package:test/test.dart';
import 'package:usc_scraper/bot/scraper/mod_merger.dart';
import 'package:usc_scraper/bot/scraper/scraped_mod.dart';

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

    test('very different names in same group are NOT discarded by dedup', () async {
      // Simulate a case where two very differently named mods end up in a group
      // via forum URL match. The dedup safety should prevent discarding the minority mod.
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
      // Both share a forum URL so they're grouped together.
      // The dedup safety keeps both (names too different to discard either).
      // The merge step still combines them into one entry.
      expect(result.length, equals(1));
      // Both are Index, so the first mod in sorted order ("Alpha Mod") wins priority.
      expect(result.first.name, equals('Alpha Mod'));
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
}
