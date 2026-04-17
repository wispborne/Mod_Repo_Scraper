import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/bundle_publisher.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/download_resolver.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/json_data_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_summary.dart';
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

Future<BundlePublisher> _makePublisherWith({
  required String dataPath,
  required JsonDataStore store,
}) async {
  final mockClient = MockClient((_) async => http.Response('', 404));
  final resolver = QbDownloadResolver(
    client: mockClient,
    dataPath: dataPath,
  );
  return BundlePublisher(
    store: store,
    resolver: resolver,
    dataPath: dataPath,
  );
}

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

}
