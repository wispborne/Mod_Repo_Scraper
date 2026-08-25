import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_summary.dart';
import 'package:mod_repo_scraper/manager/bundle_snapshot_store.dart';
import 'package:mod_repo_scraper/viewer/api.dart';
import 'package:mod_repo_scraper/viewer/data_access.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Watching a run while it is still going.
///
/// A run publishes its bundle at the end but writes what it scrapes and what it
/// pays the LLM for as it goes, so the difference between the last published
/// bundle and the data on disk is what the run has done so far. These pin that
/// the two sides are built alike — same shape, same keep/drop rule, same
/// fingerprint — because a difference in how they are built would read as a
/// change the run never made.
void main() {
  late Directory dir;
  late String dataDir;
  late ViewerApi api;
  late DataAccess data;
  late BundleSnapshotStore snapshots;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('working_bundle');
    dataDir = p.join(dir.path, 'data');
    Directory(dataDir).createSync(recursive: true);
    snapshots = BundleSnapshotStore(dataDir);
    data = DataAccess(
      dataDir: dataDir,
      outputsDir: p.join(dir.path, 'outputs'),
      rootDir: dir.path,
    );
    api = ViewerApi(data);
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  QbModSummary summary(int topicId, {String? title}) => QbModSummary(
        topicId: topicId,
        title: title ?? '[0.98a] Mod $topicId 1.0',
        author: 'Someone',
        category: 'ships',
        inModIndex: true,
        lastPostDate: 'July 01, 2026, 10:00:00 AM',
        scrapedAt: DateTime.utc(2026, 7, 1),
      );

  QbModDetail detail(int topicId, {String post = '<p>A mod.</p>'}) =>
      QbModDetail(
        topicId: topicId,
        title: 'Mod $topicId',
        author: 'Someone',
        contentHtml: post,
        scrapedAt: DateTime.utc(2026, 7, 1),
      );

  /// Writes the working data a run leaves behind as it goes.
  void writeWorking(List<QbModSummary> index, Map<int, QbModDetail> details,
      {Map<String, dynamic> llm = const {}}) {
    File(p.join(dataDir, 'mods-index.json')).writeAsStringSync(
        jsonEncode([for (final s in index) s.toMap()]));
    for (final entry in details.entries) {
      final folder = Directory(p.join(dataDir, 'mods', '${entry.key}'));
      folder.createSync(recursive: true);
      File(p.join(folder.path, 'detail.json'))
          .writeAsStringSync(jsonEncode(entry.value.toMap()));
    }
    if (llm.isNotEmpty) {
      File(p.join(dataDir, 'llm-extraction-cache.json'))
          .writeAsStringSync(jsonEncode(llm));
    }
  }

  /// A bundle snapshot standing for what was published before the run started.
  Future<void> publish(String runId, List<QbModSummary> index,
          Map<int, QbModDetail> details) =>
      // Saving does the trimming — handing it an already-trimmed bundle would
      // fingerprint a post that is no longer there and leave every topic
      // reading as "the post text was read for the first time".
      snapshots.save(runId, {
        'updatedAt': '2026-07-01T00:00:00Z',
        'index': [for (final s in index) s.toMap()],
        'details': {
          for (final e in details.entries) '${e.key}': e.value.toMap(),
        },
        'assumedDownloads': <String, dynamic>{},
      });

  Future<Map<String, dynamic>> get(String path) async {
    final res =
        await api.router(Request('GET', Uri.parse('http://localhost/$path')));
    return jsonDecode(await res.readAsString()) as Map<String, dynamic>;
  }

  test('nothing scraped yet means no side to compare against', () async {
    final body = await get('bundle/runs');
    expect(body['working'], isNull);
  });

  test('the data on disk is offered as a side, with what is in it', () async {
    writeWorking([summary(1), summary(2)], {1: detail(1), 2: detail(2)});

    final body = await get('bundle/runs');
    final working = body['working'] as Map<String, dynamic>;
    expect(working['id'], 'working');
    expect(working['indexCount'], 2);
    expect(working['updatedAt'], isNotNull);
  });

  test('a topic scraped since the last publish shows up as changed', () async {
    await publish('20260701T100000Z-fullRun', [summary(1), summary(2)],
        {1: detail(1), 2: detail(2)});
    // The run has re-scraped topic 2 and not yet published anything.
    writeWorking([summary(1), summary(2)],
        {1: detail(1), 2: detail(2, post: '<p>Now with more guns.</p>')});

    final body = await get('bundle/compare?b=working');
    expect(body['a'], '20260701T100000Z-fullRun');
    expect(body['b'], 'working');
    expect(body['changedCount'], 1);
    expect(body['sameCount'], 1);

    final changed = (body['items'] as List).cast<Map<String, dynamic>>().single;
    expect(changed['name'], '[0.98a] Mod 2 1.0');
    expect((changed['changes'] as List).single['field'], 'post text');
  });

  test('a topic the run has not touched is not reported as changed', () async {
    await publish('20260701T100000Z-fullRun', [summary(1)], {1: detail(1)});
    writeWorking([summary(1)], {1: detail(1)});

    final body = await get('bundle/compare?b=working');
    expect(body['changedCount'], 0,
        reason: 'the two sides must be built alike, or every topic would look '
            'changed the moment a run started');
    expect(body['addedCount'], 0);
    expect(body['goneCount'], 0);
    expect(body['sameCount'], 1);
  });

  test('a thread the LLM calls a non-mod is dropped from both sides', () async {
    // No game-version tag in the title, and the LLM says it is not a mod: the
    // publisher drops it, so the data-on-disk side must drop it too or it would
    // read as removed for as long as the run lasted.
    final chatter = summary(3, title: 'What is everyone playing?');
    await publish('20260701T100000Z-fullRun', [summary(1)], {1: detail(1)});
    writeWorking([summary(1), chatter], {1: detail(1), 3: detail(3)}, llm: {
      '3': {
        'fingerprint': 'abc',
        'schemaVersion': 1,
        'promptVersion': 1,
        'isMod': false,
        'mods': <dynamic>[],
      },
    });

    final body = await get('bundle/compare?b=working');
    expect(body['addedCount'], 0);
    expect(body['changedCount'], 0);
  });

  test('the data on disk cannot be the older side', () async {
    writeWorking([summary(1)], {1: detail(1)});
    final res = await api.router(Request(
        'GET',
        Uri.parse(
            'http://localhost/bundle/compare?a=working&b=20260701T100000Z-fullRun')));
    expect(res.statusCode, 404);
    expect(await res.readAsString(), contains('always the newer'));
  });

  test('with nothing published yet it says so rather than falling over',
      () async {
    writeWorking([summary(1)], {1: detail(1)});
    final body = await get('bundle/compare?b=working');
    expect(body['missing'], isNotNull, reason: 'a missing-file envelope');
    expect(jsonEncode(body), contains('No bundle has been saved yet'));
  });

  test('the answer carries no post text and no whole snapshot', () async {
    await publish('20260701T100000Z-fullRun', [summary(1)], {1: detail(1)});
    writeWorking(
        [summary(1)], {1: detail(1, post: '<p>Secret words nobody kept.</p>')});

    final body = await get('bundle/compare?b=working');
    expect(jsonEncode(body), isNot(contains('Secret words')));
  });
}
