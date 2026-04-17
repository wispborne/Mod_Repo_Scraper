import 'package:mod_repo_scraper/bot/scraper/qb/forum_constants.dart';
import 'package:test/test.dart';

void main() {
  group('isLibraryThreadTitle', () {
    test('tab between bracket and digit is accepted (BUG 7 regression)', () {
      expect(ForumConstants.isLibraryThreadTitle('[\t0.98a] Foo'), isTrue);
    });

    test('space between bracket and digit is accepted', () {
      expect(ForumConstants.isLibraryThreadTitle('[ 0.98a] Foo'), isTrue);
    });

    test('no whitespace between bracket and digit is accepted', () {
      expect(ForumConstants.isLibraryThreadTitle('[0.98a] Foo'), isTrue);
    });

    test('bracket followed by non-digit is rejected', () {
      expect(ForumConstants.isLibraryThreadTitle('[WIP] Foo'), isFalse);
    });

    test('empty/null title is rejected', () {
      expect(ForumConstants.isLibraryThreadTitle(''), isFalse);
      expect(ForumConstants.isLibraryThreadTitle(null), isFalse);
    });

    test('leading whitespace before bracket is accepted', () {
      expect(ForumConstants.isLibraryThreadTitle('   [0.98a] Foo'), isTrue);
    });
  });

  group('libraryCategory', () {
    test('is display-cased "Libraries" (C# commit 378df5a parity)', () {
      expect(ForumConstants.libraryCategory, equals('Libraries'));
    });
  });

  group('guessCategoryFromTitle', () {
    test('faction keyword returns "Faction Mods"', () {
      expect(
        ForumConstants.guessCategoryFromTitle('[0.98a] Awesome Faction'),
        equals('Faction Mods'),
      );
    });

    test('portrait keyword returns "Portrait Packs"', () {
      expect(
        ForumConstants.guessCategoryFromTitle('Some Portrait Pack'),
        equals('Portrait Packs'),
      );
    });

    test('flag keyword returns "Flag Packs"', () {
      expect(
        ForumConstants.guessCategoryFromTitle('Cool Flags'),
        equals('Flag Packs'),
      );
    });

    test('no matching keyword returns uncategorizedCategory', () {
      expect(
        ForumConstants.guessCategoryFromTitle('Just Some Random Thing'),
        equals(ForumConstants.uncategorizedCategory),
      );
    });
  });
}
