import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/bundle_publisher.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/download_resolver.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/json_data_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/extraction_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_summary.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/post_extraction.dart';
import 'package:test/test.dart';

Future<JsonDataStore> _seedStore({
  required String dataPath,
  required QbModSummary summary,
  required QbModDetail detail,
}) async {
  final store = JsonDataStore(dataPath);
  await store.saveIndex([summary]);
  await store.saveDetail(detail);
  return store;
}

Future<JsonDataStore> _seedStoreMany({
  required String dataPath,
  required List<QbModSummary> summaries,
  required List<QbModDetail> details,
}) async {
  final store = JsonDataStore(dataPath);
  await store.saveIndex(summaries);
  for (final d in details) {
    await store.saveDetail(d);
  }
  return store;
}

Future<BundlePublisher> _makePublisherWith({
  required String dataPath,
  required JsonDataStore store,
  Map<int, List<DownloadCandidate>> ruleCandidates = const {},
  LlmExtractionStore? llmStore,
}) async {
  final mockClient = MockClient((_) async => http.Response('', 404));
  final resolver = QbDownloadResolver(
    client: mockClient,
    dataPath: dataPath,
  );
  ruleCandidates.forEach(resolver.importCandidates);
  return BundlePublisher(
    store: store,
    resolver: resolver,
    outputPath: dataPath,
    llmStore: llmStore,
  );
}

/// A minimal LLM store entry at the current schema version.
LlmStoreEntry _llmEntry({List<LlmMod> mods = const [], bool isMod = true}) =>
    LlmStoreEntry(
      fingerprint: 'fp',
      schemaVersion: LlmExtractionStore.schemaVersion,
      promptVersion: 1,
      mods: mods,
      isMod: isMod,
    );

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bundle_publisher_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test(
      'null detail.category is backfilled from summary.category (BUG 2 regression)',
      () async {
    final summary = QbModSummary(
      topicId: 1000,
      title: 'Test Mod',
      category: 'Faction Mods',
      inModIndex: true,
    );
    final detail = QbModDetail(
      topicId: 1000,
      title: 'Test Mod',
      // category intentionally null
    );

    final store = await _seedStore(
      dataPath: tempDir.path,
      summary: summary,
      detail: detail,
    );
    final publisher =
        await _makePublisherWith(dataPath: tempDir.path, store: store);

    final bundle = await publisher.createBundle();

    expect(bundle.details['1000']?.category, equals('Faction Mods'));
  });

  test(
      'non-null detail.category is NOT overwritten by summary.category',
      () async {
    final summary = QbModSummary(
      topicId: 1001,
      title: 'Test Mod',
      category: 'Summary Category',
      inModIndex: true,
    );
    final detail = QbModDetail(
      topicId: 1001,
      title: 'Test Mod',
      category: 'Detail Category',
    );

    final store = await _seedStore(
      dataPath: tempDir.path,
      summary: summary,
      detail: detail,
    );
    final publisher =
        await _makePublisherWith(dataPath: tempDir.path, store: store);

    final bundle = await publisher.createBundle();

    expect(bundle.details['1001']?.category, equals('Detail Category'));
  });

  group('LLM output on the index item', () {
    QbModSummary summary(int id) =>
        QbModSummary(topicId: id, title: 'Mod $id', inModIndex: true);
    QbModDetail detail(int id) => QbModDetail(topicId: id, title: 'Mod $id');

    test(
        'assumedDownloads stays rules-only and the index item carries the mods list',
        () async {
      final store = await _seedStore(
        dataPath: tempDir.path,
        summary: summary(2000),
        detail: detail(2000),
      );

      final llmStore = LlmExtractionStore(tempDir.path);
      await llmStore.put(
        2000,
        _llmEntry(mods: [
          LlmMod(
            name: 'Mod 2000',
            role: LlmModRole.main,
            downloads: [
              LlmDownload(
                url: 'https://host/llm.zip',
                label: 'dl',
                kind: LlmDownloadKind.direct,
                sourceHost: 'host',
              ),
            ],
            extras: LlmExtras(version: '1.2.3'),
          ),
        ]),
      );

      final publisher = await _makePublisherWith(
        dataPath: tempDir.path,
        store: store,
        ruleCandidates: {
          2000: [
            DownloadCandidate(
              sourceUrl: 'https://host/rules.zip',
              resolvedUrl: 'https://host/rules.zip',
              confidence: DownloadConfidence.high,
            ),
          ],
        },
        llmStore: llmStore,
      );

      final bundle = await publisher.createBundle();

      // Rules-only list: just the rule-based link, untouched by the LLM.
      final assumed = bundle.assumedDownloads['2000']!;
      expect(assumed.single.originalUrl, 'https://host/rules.zip');

      // The LLM output lives on the index item as its `llm` field, a mods list.
      final idx = bundle.index.firstWhere((s) => s.topicId == 2000);
      final mods = idx.llm!.mods;
      expect(mods.single.name, 'Mod 2000');
      expect(mods.single.downloads.single.url, 'https://host/llm.zip');
      expect(mods.single.extras!.version, '1.2.3');

      // There is no top-level `llm` map on the bundle any more.
      expect(bundle.toMap().containsKey('llm'), isFalse);
    });

    test('the llm field is absent when the LLM feature is off', () async {
      final store = await _seedStore(
        dataPath: tempDir.path,
        summary: summary(2001),
        detail: detail(2001),
      );

      final publisher = await _makePublisherWith(
        dataPath: tempDir.path,
        store: store,
        ruleCandidates: {
          2001: [
            DownloadCandidate(
              sourceUrl: 'https://host/rules.zip',
              resolvedUrl: 'https://host/rules.zip',
            ),
          ],
        },
        // llmStore omitted → feature off.
      );

      final bundle = await publisher.createBundle();

      expect(bundle.index.single.llm, isNull);
      expect(bundle.assumedDownloads['2001']?.single.originalUrl,
          'https://host/rules.zip');
    });

    test('a thread that produced nothing gets no llm field', () async {
      final store = await _seedStore(
        dataPath: tempDir.path,
        summary: summary(2002),
        detail: detail(2002),
      );

      final llmStore = LlmExtractionStore(tempDir.path);
      // An empty result (no mods) should be skipped entirely.
      await llmStore.put(2002, _llmEntry());

      final publisher = await _makePublisherWith(
        dataPath: tempDir.path,
        store: store,
        llmStore: llmStore,
      );

      final bundle = await publisher.createBundle();

      expect(bundle.index.single.llm, isNull);
    });
  });

  group('non-mod drop filter', () {
    QbModSummary summary(int id, String title) =>
        QbModSummary(topicId: id, title: title, inModIndex: true);
    QbModDetail detail(int id, String title) =>
        QbModDetail(topicId: id, title: title);

    test(
        'drops a thread the LLM calls non-mod when the title has no version tag',
        () async {
      final store = await _seedStoreMany(
        dataPath: tempDir.path,
        summaries: [summary(3000, 'Just a discussion thread')],
        details: [detail(3000, 'Just a discussion thread')],
      );
      final llmStore = LlmExtractionStore(tempDir.path);
      await llmStore.put(3000, _llmEntry(isMod: false));

      final publisher = await _makePublisherWith(
        dataPath: tempDir.path,
        store: store,
        ruleCandidates: {
          3000: [
            DownloadCandidate(
              sourceUrl: 'https://host/x.zip',
              resolvedUrl: 'https://host/x.zip',
            ),
          ],
        },
        llmStore: llmStore,
      );

      final bundle = await publisher.createBundle();

      // Dropped from the index, details, and the rules-only layer alike.
      expect(bundle.index.where((s) => s.topicId == 3000), isEmpty);
      expect(bundle.details.containsKey('3000'), isFalse);
      expect(bundle.assumedDownloads.containsKey('3000'), isFalse);
    });

    test('keeps a non-mod thread when its title has a game-version tag',
        () async {
      final store = await _seedStoreMany(
        dataPath: tempDir.path,
        summaries: [summary(3001, '[0.98a] Borderline Thread')],
        details: [detail(3001, '[0.98a] Borderline Thread')],
      );
      final llmStore = LlmExtractionStore(tempDir.path);
      await llmStore.put(3001, _llmEntry(isMod: false));

      final publisher = await _makePublisherWith(
        dataPath: tempDir.path,
        store: store,
        llmStore: llmStore,
      );

      final bundle = await publisher.createBundle();

      expect(bundle.index.map((s) => s.topicId), contains(3001));
    });

    test('keeps an untagged thread when the LLM calls it a mod', () async {
      final store = await _seedStoreMany(
        dataPath: tempDir.path,
        summaries: [summary(3002, 'Untagged Mod')],
        details: [detail(3002, 'Untagged Mod')],
      );
      final llmStore = LlmExtractionStore(tempDir.path);
      await llmStore.put(
        3002,
        _llmEntry(isMod: true, mods: [
          LlmMod(
            name: 'Untagged Mod',
            role: LlmModRole.main,
            downloads: [
              LlmDownload(url: 'https://host/u.zip', sourceHost: 'host'),
            ],
          ),
        ]),
      );

      final publisher = await _makePublisherWith(
        dataPath: tempDir.path,
        store: store,
        llmStore: llmStore,
      );

      final bundle = await publisher.createBundle();

      expect(bundle.index.map((s) => s.topicId), contains(3002));
    });

    test('keeps an untagged thread when the LLM feature is off', () async {
      final store = await _seedStoreMany(
        dataPath: tempDir.path,
        summaries: [summary(3003, 'Untagged, no LLM judgment')],
        details: [detail(3003, 'Untagged, no LLM judgment')],
      );

      final publisher = await _makePublisherWith(
        dataPath: tempDir.path,
        store: store,
        // llmStore omitted → no judgment, so nothing is dropped.
      );

      final bundle = await publisher.createBundle();

      expect(bundle.index.map((s) => s.topicId), contains(3003));
    });
  });
}
