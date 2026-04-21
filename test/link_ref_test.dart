import 'package:test/test.dart';

import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';

void main() {
  setUpAll(() {
    LinkRefMapper.ensureInitialized();
  });

  group('LinkRef JSON round-trip', () {
    test('serializes and deserializes with isDownloadable = true', () {
      final original = LinkRef(
        url: 'https://example.com/mod.zip',
        text: 'Download',
        isExternal: true,
        isDownloadable: true,
      );

      final json = original.toJson();
      final decoded = LinkRefMapper.fromJson(json);

      expect(decoded.url, equals(original.url));
      expect(decoded.text, equals(original.text));
      expect(decoded.isExternal, equals(original.isExternal));
      expect(decoded.isDownloadable, equals(original.isDownloadable));
    });

    test('deserializes legacy JSON without isDownloadable key → defaults false',
        () {
      const legacyJson = '{'
          '"url":"https://example.com/page",'
          '"text":"Info",'
          '"isExternal":true'
          '}';

      final decoded = LinkRefMapper.fromJson(legacyJson);

      expect(decoded.url, equals('https://example.com/page'));
      expect(decoded.text, equals('Info'));
      expect(decoded.isExternal, isTrue);
      expect(decoded.isDownloadable, isFalse);
    });
  });

  group('LinkRef.toString()', () {
    test('contains all field labels including isDownloadable', () {
      final link = LinkRef(
        url: 'u',
        text: 't',
        isExternal: true,
        isDownloadable: true,
      );

      final str = link.toString();
      expect(str, contains('url'));
      expect(str, contains('text'));
      expect(str, contains('isExternal'));
      expect(str, contains('isDownloadable'));
    });

    test(
        'existing fields appear in original order, isDownloadable appended last',
        () {
      final link = LinkRef(
        url: 'u',
        text: 't',
        isExternal: true,
        isDownloadable: true,
      );

      final str = link.toString();
      final urlIdx = str.indexOf('url');
      final textIdx = str.indexOf('text');
      final externalIdx = str.indexOf('isExternal');
      final downloadableIdx = str.indexOf('isDownloadable');

      expect(urlIdx, greaterThanOrEqualTo(0));
      expect(textIdx, greaterThan(urlIdx));
      expect(externalIdx, greaterThan(textIdx));
      expect(downloadableIdx, greaterThan(externalIdx));
    });

    test(
        'toString of downloadable link includes "isDownloadable: true"',
        () {
      final link = LinkRef(
        url: 'https://example.com/mod.zip',
        isDownloadable: true,
      );
      expect(link.toString(), contains('isDownloadable: true'));
    });
  });
}
