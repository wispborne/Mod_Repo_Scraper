import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'package:mod_repo_scraper/bot/scraper/qb/download_resolver.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';

void main() {
  late QbDownloadResolver resolver;

  setUp(() {
    final mockClient = MockClient((_) async => http.Response('', 404));
    resolver = QbDownloadResolver(
      client: mockClient,
      dataPath: Directory.systemTemp.path,
    );
  });

  group('Bitbucket URL handling', () {
    test('malformed percent-encoded URL returns candidate with null filename',
        () async {
      final links = [
        LinkRef(
          url:
              'https://bitbucket.org/user/repo/downloads/Mod%252.2.7.zip',
          text: '',
          isExternal: true,
        ),
      ];

      final candidates = await resolver.resolveForTopic(99999, links);
      expect(candidates, hasLength(1));
      expect(candidates[0].archiveFilename, isNull);
      expect(candidates[0].resolvedUrl, contains('bitbucket.org'));
    });

    test('valid percent-encoded URL extracts filename correctly', () async {
      final links = [
        LinkRef(
          url:
              'https://bitbucket.org/user/repo/downloads/My%20Mod%20v1.0.zip',
          text: '',
          isExternal: true,
        ),
      ];

      final candidates = await resolver.resolveForTopic(99998, links);
      expect(candidates, hasLength(1));
      expect(candidates[0].archiveFilename, equals('My Mod v1.0.zip'));
      expect(candidates[0].confidence, equals(DownloadConfidence.high));
    });
  });
}
