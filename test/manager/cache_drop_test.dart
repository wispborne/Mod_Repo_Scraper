import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/download_resolver.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/downloadable_probe_cache.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/extraction_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/post_extraction.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A GitHub asset link resolves with no network calls at all, which keeps these
/// tests about the dropping rather than about link resolution.
LinkRef assetLink(String name) => LinkRef(
      url: 'https://github.com/someone/$name/releases/download/v1/$name.zip',
      text: name,
      isExternal: true,
    );

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cache-drop-test');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test('dropping one topic leaves the other topic untouched', () async {
    final resolver = QbDownloadResolver(
      client: MockClient((_) async => http.Response('', 404)),
      dataPath: dir.path,
    );
    await resolver.resolveForTopic(123, [assetLink('one')]);
    await resolver.resolveForTopic(456, [assetLink('two')]);
    await resolver.saveCache();

    final file = File(p.join(dir.path, 'assumed-downloads-cache.json'));
    final before =
        (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)['456'];

    resolver.dropTopics([123]);
    await resolver.saveCache();

    final after =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(after.containsKey('123'), isFalse);
    expect(jsonEncode(after['456']), jsonEncode(before));
    expect(resolver.getCachedCandidates(456), isNotNull);
    expect(resolver.getCachedCandidates(123), isNull);
  });

  test('dropping downloads does not touch the LLM results', () async {
    final resolver = QbDownloadResolver(
      client: MockClient((_) async => http.Response('', 404)),
      dataPath: dir.path,
    );
    await resolver.resolveForTopic(123, [assetLink('one')]);
    await resolver.saveCache();

    final llmStore = LlmExtractionStore(dir.path);
    await llmStore.put(123, entryFor('one'));
    await llmStore.flush();
    final llmFile = File(p.join(dir.path, 'llm-extraction-cache.json'));
    final llmBefore = llmFile.readAsStringSync();

    resolver.dropTopics([123]);
    await resolver.saveCache();

    expect(llmFile.readAsStringSync(), llmBefore);
  });

  test('dropping LLM results for one topic leaves the other alone', () async {
    final store = LlmExtractionStore(dir.path);
    await store.put(123, entryFor('one'));
    await store.put(456, entryFor('two'));
    await store.flush();

    final file = File(p.join(dir.path, 'llm-extraction-cache.json'));
    final before =
        (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)['456'];

    store.dropTopics([123]);
    await store.flush();

    final after = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(after.containsKey('123'), isFalse);
    expect(jsonEncode(after['456']), jsonEncode(before));
    expect(store.get(456), isNotNull);
    expect(store.get(123), isNull);
  });

  test('dropping LLM results does not touch the download answers', () async {
    final resolver = QbDownloadResolver(
      client: MockClient((_) async => http.Response('', 404)),
      dataPath: dir.path,
    );
    await resolver.resolveForTopic(123, [assetLink('one')]);
    await resolver.saveCache();
    final downloadsFile =
        File(p.join(dir.path, 'assumed-downloads-cache.json'));
    final downloadsBefore = downloadsFile.readAsStringSync();

    final store = LlmExtractionStore(dir.path);
    await store.put(123, entryFor('one'));
    await store.flush();
    store.dropTopics([123]);
    await store.flush();

    expect(downloadsFile.readAsStringSync(), downloadsBefore);
  });

  test('dropping a link makes the probe ask the host again', () async {
    var asks = 0;
    final client = MockClient((_) async {
      asks++;
      return http.Response('', 200,
          headers: {'content-type': 'application/octet-stream'});
    });
    final cache = DownloadableProbeCache(dataPath: dir.path);
    const url = 'https://example.com/files/thing';

    expect(await cache.classify(url, client: client), isTrue);
    expect(await cache.classify(url, client: client), isTrue);
    expect(asks, 1, reason: 'the saved answer is reused');

    cache.dropUrls([url]);
    expect(await cache.classify(url, client: client), isTrue);
    expect(asks, 2);
  });
}

LlmStoreEntry entryFor(String name) => LlmStoreEntry(
      fingerprint: 'fingerprint-$name',
      schemaVersion: LlmExtractionStore.schemaVersion,
      promptVersion: 1,
      mods: [LlmMod(name: name, role: 'main', downloads: const [])],
    );
