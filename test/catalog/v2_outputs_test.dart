import 'dart:convert';
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
import 'package:mod_repo_scraper/bot/scraper/scraped_mod.dart';
import 'package:mod_repo_scraper/catalog/catalog_step.dart';
import 'package:mod_repo_scraper/catalog/discord_posts.dart';
import 'package:mod_repo_scraper/catalog/takedowns.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The words of the Discord message, which must never be published.
const _messageText = 'Only-in-the-message: Fresh Mod is out, grab it below';

void main() {
  late Directory dir;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('v2_outputs');
    final store = JsonDataStore(dir.path);
    await store.saveIndex([QbModSummary(topicId: 1, title: '[0.98a] Forum Mod 1.0', author: 'Someone')]);
    await store.saveDetail(QbModDetail(topicId: 1, title: '[0.98a] Forum Mod 1.0', contentHtml: '<p>Forum Mod</p>'));

    await DiscordPostsFile.write(File(p.join(dir.path, DiscordPostsFile.fileName)), {
      '900': DiscordThreadPost(
        threadId: '900',
        name: 'Fresh Mod 1.2',
        author: 'Author',
        url: 'https://discord.com/channels/1/900/900',
        messages: [DiscordOpeningMessage(id: '900', content: '$_messageText https://e/fresh.zip')],
      ),
    });

    final llm = LlmExtractionStore(dir.path, flushEveryN: 1000);
    await llm.putKey(
      'discord:900',
      LlmStoreEntry(
        fingerprint: 'x',
        schemaVersion: LlmExtractionStore.schemaVersion,
        promptVersion: 1,
        model: 'some-model',
        endpoint: 'http://localhost:8080/v1/chat/completions',
        mods: [
          LlmMod(name: 'Fresh Mod', downloads: [LlmDownload(url: 'https://e/fresh.zip', confidence: 'high')]),
        ],
      ),
    );
    await llm.flush();

    File(p.join(dir.path, 'discord_cache.json')).writeAsStringSync(ScrapedMods(items: const [
      ScrapedMod(
        name: 'Fresh Mod 1.2',
        authorsList: ['Author'],
        sources: [ModSource.Discord],
        urls: {ModUrlType.Discord: 'https://discord.com/channels/1/900/900'},
      ),
    ]).toJson());
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<String> publishBundle() async {
    final llm = LlmExtractionStore(dir.path);
    await llm.load();
    final publisher = BundlePublisher(
      store: JsonDataStore(dir.path),
      resolver: QbDownloadResolver(client: MockClient((_) async => http.Response('', 404)), dataPath: dir.path),
      outputPath: p.join(dir.path, 'outputs'),
      llmStore: llm,
    );
    await publisher.writeLocal(await publisher.createBundle());
    return File(p.join(dir.path, 'outputs', BundlePublisher.detailsFileName)).readAsStringSync();
  }

  test("the mod details carry the Discord thread's answer and none of its words", () async {
    final json = await publishBundle();
    final threads = (jsonDecode(json) as Map)['discordThreads'] as List;

    final thread = threads.single as Map;
    expect(thread['threadId'], '900');
    expect(thread['name'], 'Fresh Mod 1.2');
    expect((thread['mods'] as List).single['name'], 'Fresh Mod');

    expect(json, isNot(contains('Only-in-the-message')));
    expect(jsonEncode(thread), isNot(contains('confidence')));
    expect(json, isNot(contains('some-model')), reason: 'which model answered is never published');
    expect(json, isNot(contains('localhost:8080')));
  });

  test('the old bundle never carries the Discord answers', () async {
    await publishBundle();
    final old = File(p.join(dir.path, 'outputs', 'forum-data-bundle.json')).readAsStringSync();
    expect((jsonDecode(old) as Map).containsKey('discordThreads'), isFalse);
  });

  test('a thread whose mod was taken down is left out of the details file; the forum topic stays', () async {
    const TakedownList(mods: [
      ModTakedown(id: 'fresh-mod-1-2', name: 'Fresh Mod 1.2', posts: ['discord:900'], on: '2026-10-22'),
    ]).write(dir.path);
    final catalog = (await CatalogStep(
      qbDataPath: dir.path,
      sourceCachePath: dir.path,
      outputPath: p.join(dir.path, 'outputs'),
    ).run())!;
    expect(catalog.mods.map((m) => m.mod.name), ['Forum Mod']);
    expect(catalog.takedownReport.removedThreadIds, {'900'});

    final llm = LlmExtractionStore(dir.path);
    await llm.load();
    final publisher = BundlePublisher(
      store: JsonDataStore(dir.path),
      resolver: QbDownloadResolver(client: MockClient((_) async => http.Response('', 404)), dataPath: dir.path),
      outputPath: p.join(dir.path, 'outputs'),
      llmStore: llm,
    );
    await publisher.writeLocal(await publisher.createBundle(
      leaveOutTopics: catalog.takedownReport.removedTopicIds,
      leaveOutThreads: catalog.takedownReport.removedThreadIds,
    ));
    final details = jsonDecode(File(p.join(dir.path, 'outputs', BundlePublisher.detailsFileName)).readAsStringSync()) as Map;
    expect(details['discordThreads'], isEmpty);
    expect((details['details'] as Map).keys, ['1']);
    expect(File(p.join(dir.path, TakedownList.matchesFileName)).existsSync(), isTrue);
  });

  test('a topic whose mod was taken down is left out of both bundles', () async {
    const TakedownList(authors: [AuthorTakedown(names: ['Someone'], on: '2026-10-22')]).write(dir.path);
    final catalog = (await CatalogStep(
      qbDataPath: dir.path,
      sourceCachePath: dir.path,
      outputPath: p.join(dir.path, 'outputs'),
    ).run())!;
    expect(catalog.takedownReport.removedTopicIds, {1});

    final publisher = BundlePublisher(
      store: JsonDataStore(dir.path),
      resolver: QbDownloadResolver(client: MockClient((_) async => http.Response('', 404)), dataPath: dir.path),
      outputPath: p.join(dir.path, 'outputs'),
    );
    await publisher.writeLocal(await publisher.createBundle(leaveOutTopics: catalog.takedownReport.removedTopicIds));
    for (final name in ['forum-data-bundle.json', BundlePublisher.detailsFileName]) {
      final bundle = jsonDecode(File(p.join(dir.path, 'outputs', name)).readAsStringSync()) as Map;
      expect(bundle['index'], isEmpty, reason: name);
      expect(bundle['details'], isEmpty, reason: name);
    }
  });

  test('neither new file holds a local path, a run id, a token or message text', () async {
    final bundle = await publishBundle();
    final catalog = (await CatalogStep(
      qbDataPath: dir.path,
      sourceCachePath: dir.path,
      outputPath: p.join(dir.path, 'outputs'),
    ).run())!;
    final catalogJson = File(p.join(dir.path, 'outputs', 'mod-catalog.json')).readAsStringSync();
    expect(catalog.mods.map((m) => m.mod.name), containsAll(['Forum Mod', 'Fresh Mod 1.2']));

    for (final json in [bundle, catalogJson]) {
      final escapedPath = jsonEncode(dir.path);
      expect(json, isNot(contains(escapedPath.substring(1, escapedPath.length - 1))));
      expect(json, isNot(contains('Only-in-the-message')));
      expect(json, isNot(contains(RegExp(r'\d{8}T\d{6}Z'))), reason: 'no run id');
      expect(json.toLowerCase(), isNot(contains('token')));
    }
  });
}
