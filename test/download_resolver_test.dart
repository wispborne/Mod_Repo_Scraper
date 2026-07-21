import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'package:mod_repo_scraper/bot/scraper/qb/download_resolver.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/downloadable_probe_cache.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/url_normalizer.dart';

void main() {
  late QbDownloadResolver resolver;

  // Each test gets its own empty folder, so no test can read or write
  // another test's cache files.
  String freshDir() =>
      Directory.systemTemp.createTempSync('qb_resolver_test').path;

  setUp(() {
    final mockClient = MockClient((_) async => http.Response('', 404));
    resolver = QbDownloadResolver(
      client: mockClient,
      dataPath: freshDir(),
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

  group('GitHub URL handling', () {
    test('releases/download/{tag}/{file} is a high-confidence direct asset',
        () async {
      final links = [
        LinkRef(
          url: 'https://github.com/user/repo/releases/download/v1.2/MyMod.zip',
          text: '',
          isExternal: true,
        ),
      ];

      final candidates = await resolver.resolveForTopic(99997, links);
      expect(candidates, hasLength(1));
      expect(candidates[0].confidence, equals(DownloadConfidence.high));
      expect(candidates[0].requiresManualStep, isFalse);
      expect(candidates[0].archiveFilename, equals('MyMod.zip'));
    });

    test('releases/latest/download/{file} is a high-confidence direct asset',
        () async {
      final links = [
        LinkRef(
          url:
              'https://github.com/Starficz/scy-nation/releases/latest/download/ScyNation.zip',
          text: '',
          isExternal: true,
        ),
      ];

      final candidates = await resolver.resolveForTopic(99996, links);
      expect(candidates, hasLength(1));
      expect(candidates[0].confidence, equals(DownloadConfidence.high));
      expect(candidates[0].requiresManualStep, isFalse);
      expect(candidates[0].archiveFilename, equals('ScyNation.zip'));
      expect(candidates[0].resolvedUrl, equals(links[0].url));
    });
  });

  group('Google Drive URL handling', () {
    test('folder link is low confidence and needs a manual step', () async {
      final links = [
        LinkRef(
          url: 'https://drive.google.com/drive/folders/abc123XYZ',
          text: '',
          isExternal: true,
        ),
      ];

      final candidates = await resolver.resolveForTopic(99995, links);
      expect(candidates, hasLength(1));
      expect(candidates[0].confidence, equals(DownloadConfidence.low));
      expect(candidates[0].requiresManualStep, isTrue);
      expect(candidates[0].resolvedUrl, equals(links[0].url));
    });

    test('open?id= link is rewritten to the direct-download form', () async {
      final links = [
        LinkRef(
          url: 'https://drive.google.com/open?id=abc123XYZ',
          text: '',
          isExternal: true,
        ),
      ];

      final candidates = await resolver.resolveForTopic(99994, links);
      expect(candidates, hasLength(1));
      expect(
        candidates[0].resolvedUrl,
        equals('https://drive.google.com/uc?export=download&id=abc123XYZ'),
      );
      expect(candidates[0].requiresManualStep, isFalse);
    });

    test('open?id= link that redirects to a folder needs a manual step',
        () async {
      final redirecting = MockClient((_) async => http.Response('', 302,
          headers: {
            'location': 'https://drive.google.com/drive/folders/abc123XYZ'
          }));
      final r = QbDownloadResolver(
        client: redirecting,
        dataPath: freshDir(),
      );

      final links = [
        LinkRef(
          url: 'https://drive.google.com/open?id=abc123XYZ',
          text: '',
          isExternal: true,
        ),
      ];

      final candidates = await r.resolveForTopic(99993, links);
      expect(candidates, hasLength(1));
      expect(candidates[0].confidence, equals(DownloadConfidence.low));
      expect(candidates[0].requiresManualStep, isTrue);
      expect(
        candidates[0].resolvedUrl,
        equals('https://drive.google.com/drive/folders/abc123XYZ'),
      );
    });
  });

  group('Unknown host fallback probe', () {
    test('unknown host that serves a file is a medium-confidence direct download',
        () async {
      final probed = MockClient((_) async => http.Response('', 200, headers: {
            'content-disposition': 'attachment; filename="Mod.zip"',
          }));
      final r = QbDownloadResolver(
        client: probed,
        dataPath: freshDir(),
      );

      final links = [
        LinkRef(
          url: 'https://cdn.example.com/download/12345',
          text: '',
          isExternal: true,
        ),
      ];

      final candidates = await r.resolveForTopic(91001, links);
      expect(candidates, hasLength(1));
      expect(candidates[0].confidence, equals(DownloadConfidence.medium));
      expect(candidates[0].requiresManualStep, isFalse);
      expect(candidates[0].resolvedUrl, equals(links[0].url));
    });

    test('unknown host that serves a web page is not a download', () async {
      final probed = MockClient((_) async => http.Response('<html></html>', 200,
          headers: {'content-type': 'text/html; charset=utf-8'}));
      final r = QbDownloadResolver(
        client: probed,
        dataPath: freshDir(),
      );

      final links = [
        LinkRef(
          url: 'https://example.com/some-page',
          text: '',
          isExternal: true,
        ),
      ];

      final candidates = await r.resolveForTopic(91002, links);
      expect(candidates, isEmpty);
    });

    test('archive URL on an unknown host resolves without any network call',
        () async {
      final noNetwork = MockClient((_) async {
        fail('an obvious archive URL should not be probed over the network');
      });
      final r = QbDownloadResolver(
        client: noNetwork,
        dataPath: freshDir(),
      );

      final links = [
        LinkRef(
          url: 'https://files.example.com/MyMod.zip',
          text: '',
          isExternal: true,
        ),
      ];

      final candidates = await r.resolveForTopic(91003, links);
      expect(candidates, hasLength(1));
      expect(candidates[0].confidence, equals(DownloadConfidence.medium));
      expect(candidates[0].requiresManualStep, isFalse);
      expect(candidates[0].archiveFilename, equals('MyMod.zip'));
    });

    test('a shared cache probes an unknown host only once across topics',
        () async {
      var probes = 0;
      final counting = MockClient((_) async {
        probes++;
        return http.Response('', 200, headers: {
          'content-disposition': 'attachment; filename="Mod.zip"',
        });
      });
      final dir = freshDir();
      final cache = DownloadableProbeCache(dataPath: dir);
      final r = QbDownloadResolver(
        client: counting,
        dataPath: dir,
        probeCache: cache,
      );

      final link = LinkRef(
        url: 'https://cdn.example.com/download/777',
        text: '',
        isExternal: true,
      );

      // Same link, two different topics — the second should reuse the answer.
      await r.resolveForTopic(92001, [link]);
      await r.resolveForTopic(92002, [link]);

      expect(probes, equals(1));
    });

    test('the same link asked about twice at once only makes one request',
        () async {
      var probes = 0;
      final counting = MockClient((_) async {
        probes++;
        return http.Response('', 200, headers: {
          'content-disposition': 'attachment; filename="Mod.zip"',
        });
      });
      final cache = DownloadableProbeCache(dataPath: freshDir());

      // Fire both checks before either finishes.
      final results = await Future.wait([
        cache.classify('https://cdn.example.com/download/1', client: counting),
        cache.classify('https://cdn.example.com/download/1', client: counting),
      ]);

      expect(results, equals([true, true]));
      expect(probes, equals(1));
    });
  });

  group('Cache entries from an older version', () {
    test('are kept, flagged for a redo, and upgraded when redone', () async {
      final dir = freshDir();
      // Write a cache file the way an older version (schema 2) would have.
      File('$dir/assumed-downloads-cache.json').writeAsStringSync(jsonEncode({
        '12345': {
          'fingerprint': 'https://example.com/OldMod.zip',
          'schemaVersion': 2,
          'candidates': [
            {
              'sourceUrl': 'https://example.com/OldMod.zip',
              'resolvedUrl': 'https://example.com/OldMod.zip',
              'archiveFilename': 'OldMod.zip',
              'confidence': 'medium',
              'requiresManualStep': false,
            }
          ],
        },
      }));

      final r = QbDownloadResolver(
        client: MockClient((_) async => http.Response('', 404)),
        dataPath: dir,
      );
      await r.loadCache();

      // The old answer still shows up (the bundle needs it)...
      expect(r.getCachedCandidates(12345), hasLength(1));
      // ...but the topic is flagged as needing a redo.
      expect(r.outdatedTopicIds, contains(12345));

      // Redoing it brings the entry up to date and clears the flag.
      final candidates = await r.resolveForTopic(12345, [
        LinkRef(
          url: 'https://example.com/OldMod.zip',
          text: '',
          isExternal: true,
        ),
      ]);
      expect(candidates, hasLength(1));
      expect(r.outdatedTopicIds, isEmpty);
    });
  });

  group('UrlNormalizer Google Drive helpers', () {
    test('isGoogleDriveFolder spots folder links', () {
      expect(
        UrlNormalizer.isGoogleDriveFolder(
            'https://drive.google.com/drive/folders/abc123'),
        isTrue,
      );
      expect(
        UrlNormalizer.isGoogleDriveFolder(
            'https://drive.google.com/drive/u/0/folders/abc123'),
        isTrue,
      );
      expect(
        UrlNormalizer.isGoogleDriveFolder(
            'https://drive.google.com/folderview?id=abc123'),
        isTrue,
      );
      expect(
        UrlNormalizer.isGoogleDriveFolder(
            'https://drive.google.com/file/d/abc123/view'),
        isFalse,
      );
      expect(
        UrlNormalizer.isGoogleDriveFolder('https://example.com/folders/x'),
        isFalse,
      );
    });

    test('normalizeDownloadUrl rewrites open?id= links', () {
      expect(
        UrlNormalizer.normalizeDownloadUrl(
            'https://drive.google.com/open?id=abc123'),
        equals('https://drive.google.com/uc?export=download&id=abc123'),
      );
    });

    test('normalizeDownloadUrl leaves uc?export=download links alone', () {
      const url = 'https://drive.google.com/uc?export=download&id=abc123';
      expect(UrlNormalizer.normalizeDownloadUrl(url), equals(url));
    });
  });
}
