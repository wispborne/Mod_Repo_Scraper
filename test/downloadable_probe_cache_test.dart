import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'package:mod_repo_scraper/bot/scraper/qb/downloadable_probe_cache.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('probe_cache_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('probes an ambiguous URL once, then serves the answer from memory',
      () async {
    const url = 'https://ambiguous.example.com/attach';
    var probes = 0;
    final client = MockClient((req) async {
      probes++;
      return http.Response('', 200, headers: {
        'content-disposition': 'attachment; filename="thing.zip"',
      });
    });

    final cache = DownloadableProbeCache(dataPath: tempDir.path);

    final first = await cache.classify(url, client: client);
    final second = await cache.classify(url, client: client);

    expect(first, isTrue);
    expect(second, isTrue);
    expect(probes, 1, reason: 'second call must come from the cache');
  });

  test('obvious downloads never touch the network or the stored cache',
      () async {
    const zipUrl = 'https://cdn.example.com/mod.zip';
    final client = MockClient((req) async {
      fail('Obvious download should short-circuit without a probe');
    });

    final cache = DownloadableProbeCache(dataPath: tempDir.path);

    expect(await cache.classify(zipUrl, client: client), isTrue);

    await cache.saveCache();
    final saved =
        File('${tempDir.path}/link-downloadable-cache.json').readAsStringSync();
    expect(saved, isNot(contains(zipUrl)),
        reason: 'obvious downloads should not bloat the cache');
  });

  test('cached answers survive a save/load round-trip', () async {
    const url = 'https://ambiguous.example.com/page';
    var probes = 0;
    final client = MockClient((req) async {
      probes++;
      return http.Response('<html></html>', 200, headers: {
        'content-type': 'text/html; charset=utf-8',
      });
    });

    final writer = DownloadableProbeCache(dataPath: tempDir.path);
    expect(await writer.classify(url, client: client), isFalse);
    await writer.saveCache();

    // A fresh cache loading the same file should not re-probe.
    final reader = DownloadableProbeCache(dataPath: tempDir.path);
    await reader.loadCache();

    final failClient = MockClient((req) async {
      fail('Loaded cache should answer without probing');
    });
    expect(await reader.classify(url, client: failClient), isFalse);
    expect(probes, 1);
  });
}
