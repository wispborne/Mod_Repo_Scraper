import 'dart:io';

import 'package:mod_repo_scraper/viewer/site_version.dart';
import 'package:test/test.dart';

void main() {
  group('SiteVersion.parseDescribed', () {
    test('sitting exactly on a tag', () {
      expect(
        SiteVersion.parseDescribed('3.4.2-0-g4150078'),
        equals({'tag': '3.4.2', 'commitsSince': 0, 'described': '3.4.2-0-g4150078'}),
      );
    });

    test('some commits past a tag', () {
      expect(
        SiteVersion.parseDescribed('3.4.2-3-g4150078'),
        equals({'tag': '3.4.2', 'commitsSince': 3, 'described': '3.4.2-3-g4150078'}),
      );
    });

    test('a tag with dashes of its own keeps them', () {
      expect(
        SiteVersion.parseDescribed('1.0-beta-2-gabc1234'),
        equals({'tag': '1.0-beta', 'commitsSince': 2, 'described': '1.0-beta-2-gabc1234'}),
      );
    });

    test('anything else is passed on whole', () {
      expect(
        SiteVersion.parseDescribed('something-odd'),
        equals({'tag': 'something-odd', 'commitsSince': 0, 'described': 'something-odd'}),
      );
    });
  });

  group('SiteVersion.read', () {
    test('a folder that is not a git checkout has nothing to say', () {
      final folder = Directory.systemTemp.createTempSync('site_version_test');
      addTearDown(() => folder.deleteSync(recursive: true));

      expect(SiteVersion(folder.path).read(), isNull);
    });

    test('this checkout reports its tag', () {
      final version = SiteVersion(Directory.current.path).read();
      // Skipped where the tests run from a copy with no tags — a shallow CI
      // clone, say. The point is that a real checkout answers sensibly.
      if (version == null) return;

      expect(version['tag'], isA<String>());
      expect(version['tag'], isNotEmpty);
      expect(version['commitsSince'], isA<int>());
    });
  });
}
