import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/manager/bundle_snapshot_store.dart';
import 'package:mod_repo_scraper/viewer/api.dart';
import 'package:mod_repo_scraper/viewer/bundle_views.dart';
import 'package:mod_repo_scraper/viewer/data_access.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// One saved bundle holding one topic, in the shape a snapshot really has —
/// the post text swapped for a fingerprint, as `BundleSnapshotStore` does when
/// it saves one.
Map<String, dynamic> snapshotOf(Map<String, dynamic> topic) =>
    BundleSnapshotStore.withoutPostText({
      'updatedAt': '2026-07-22T12:00:00Z',
      'index': [
        {
          'topicId': topic['id'],
          'title': topic['title'] ?? 'A Mod',
          'author': topic['author'] ?? 'Someone',
          'category': 'ships',
          'lastPostDate': topic['lastPost'] ?? 'July 01, 2026, 10:00:00 AM',
          'isWip': false,
          'inModIndex': true,
          'sourceBoard': 8,
          'replies': topic['replies'] ?? 10,
          'views': topic['views'] ?? 100,
          'scrapedAt': topic['scrapedAt'] ?? '2026-07-01T00:00:00Z',
          'llm': topic['llm'],
        },
      ],
      'details': {
        '${topic['id']}': {
          'topicId': topic['id'],
          'contentHtml': topic['post'] ?? '<p>A mod.</p>',
          'images': <dynamic>[],
          'links': topic['links'],
        },
      },
      'assumedDownloads': {
        // A plain list, which is the shape a real bundle has.
        if (topic['downloads'] != null) '${topic['id']}': topic['downloads'],
      },
    });

/// A bundle with no topics in it at all.
Map<String, dynamic> emptySnapshot() => BundleSnapshotStore.withoutPostText({
      'updatedAt': '2026-07-22T12:00:00Z',
      'index': <dynamic>[],
      'details': <String, dynamic>{},
      'assumedDownloads': <String, dynamic>{},
    });

void main() {
  var day = 0;

  /// A snapshot in the walk. Each one is saved a day after the last, so the
  /// order is never in doubt.
  HistorySnapshot at(String runId, Map<String, dynamic>? bundle) =>
      HistorySnapshot(
        runId,
        DateTime.utc(2026, 7, 1 + day++),
        () => bundle,
      );

  setUp(() => day = 0);

  Map<String, dynamic> historyOf(List<HistorySnapshot> snapshots) =>
      topicHistory(topicId: 1, snapshots: snapshots);

  List<Map<String, dynamic>> entriesOf(Map<String, dynamic> history) =>
      (history['entries'] as List).cast<Map<String, dynamic>>();

  group('which runs make an entry', () {
    test('a changed field makes an entry naming the run', () {
      final history = historyOf([
        at('r1', snapshotOf({'id': 1, 'title': 'Alpha'})),
        at('r2', snapshotOf({'id': 1, 'title': 'Alpha Renamed'})),
      ]);

      final entries = entriesOf(history);
      expect(entries, hasLength(1));
      expect(entries.first['runId'], 'r2');
      expect(entries.first['kind'], 'changed');
      expect((entries.first['changes'] as List).map((c) => c['field']),
          contains('title'));
    });

    test('a run that changed nothing makes no entry', () {
      final history = historyOf([
        at('r1', snapshotOf({'id': 1})),
        at('r2', snapshotOf({'id': 1})),
        at('r3', snapshotOf({'id': 1})),
      ]);

      expect(entriesOf(history), isEmpty);
      expect(history['snapshotsRead'], 3);
    });

    test('fields that move on their own make no entry', () {
      final history = historyOf([
        at('r1',
            snapshotOf({'id': 1, 'scrapedAt': '2026-07-01T00:00:00Z', 'replies': 10, 'views': 100})),
        at('r2',
            snapshotOf({'id': 1, 'scrapedAt': '2026-07-22T00:00:00Z', 'replies': 11, 'views': 250})),
      ]);

      expect(entriesOf(history), isEmpty,
          reason: 'a re-scrape that only moved the scrape time, the reply '
              'count and the view count did not change the mod');
    });

    test('a topic in none of the bundles is told apart from a quiet one', () {
      final never = historyOf([
        at('r1', emptySnapshot()),
        at('r2', emptySnapshot()),
      ]);
      expect(never['everInBundle'], isFalse);
      expect(entriesOf(never), isEmpty);

      final quiet = historyOf([
        at('r3', snapshotOf({'id': 1})),
        at('r4', snapshotOf({'id': 1})),
      ]);
      expect(quiet['everInBundle'], isTrue);
      expect(entriesOf(quiet), isEmpty);
    });

    test('the oldest bundle kept is where history starts, not an event', () {
      final history = historyOf([
        at('r1', snapshotOf({'id': 1})),
      ]);

      expect(entriesOf(history), isEmpty);
      expect(history['oldestRunId'], 'r1');
      expect(history['oldestSavedAt'], '2026-07-01T00:00:00.000Z');
    });

    test('entries come back newest first', () {
      final history = historyOf([
        at('r1', snapshotOf({'id': 1, 'title': 'One'})),
        at('r2', snapshotOf({'id': 1, 'title': 'Two'})),
        at('r3', snapshotOf({'id': 1, 'title': 'Three'})),
      ]);

      expect(entriesOf(history).map((e) => e['runId']), ['r3', 'r2']);
    });
  });

  group('entering and leaving the bundle', () {
    test('a topic first seen in a later run says so', () {
      final history = historyOf([
        at('r1', emptySnapshot()),
        at('r2', snapshotOf({'id': 1})),
      ]);

      final entries = entriesOf(history);
      expect(entries, hasLength(1));
      expect(entries.first['kind'], 'first');
      expect(entries.first['runId'], 'r2');
    });

    test('a topic dropped from the bundle says so', () {
      final history = historyOf([
        at('r1', snapshotOf({'id': 1})),
        at('r2', emptySnapshot()),
      ]);

      final entries = entriesOf(history);
      expect(entries, hasLength(1));
      expect(entries.first['kind'], 'gone');
      expect(entries.first['runId'], 'r2');
    });

    test('the title is remembered even after the topic is dropped', () {
      final history = historyOf([
        at('r1', snapshotOf({'id': 1, 'title': 'Alpha'})),
        at('r2', emptySnapshot()),
      ]);

      expect(history['title'], 'Alpha');
    });
  });

  group('a snapshot that cannot be read', () {
    test('is skipped, and its neighbours are compared across the gap', () {
      final history = historyOf([
        at('r1', snapshotOf({'id': 1, 'title': 'Alpha'})),
        at('r2', null),
        at('r3', snapshotOf({'id': 1, 'title': 'Omega'})),
      ]);

      final entries = entriesOf(history);
      expect(entries, hasLength(1));
      expect(entries.first['runId'], 'r3');
      expect(history['snapshotsRead'], 2);
      expect(history['snapshotsTotal'], 3);
    });

    test('does not become the start of history', () {
      final history = historyOf([
        at('r1', null),
        at('r2', snapshotOf({'id': 1})),
      ]);

      expect(history['oldestRunId'], 'r2');
      expect(history['snapshotsRead'], 1);
    });
  });

  group('the post text', () {
    test('is reported as changed, without the words', () {
      final history = historyOf([
        at('r1', snapshotOf({'id': 1, 'post': '<p>Version 1.</p>'})),
        at('r2', snapshotOf({'id': 1, 'post': '<p>Version 2, more guns.</p>'})),
      ]);

      final change = (entriesOf(history).first['changes'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((c) => c['field'] == 'post text');
      expect(change['note'], contains('post text changed'));
      expect(change.containsKey('before'), isFalse);
      expect(change.containsKey('after'), isFalse);
    });
  });

  group('downloads, item by item', () {
    Map<String, dynamic> download(String url,
            {String? file, String? resolved, String? confidence}) =>
        {
          'originalUrl': url,
          'resolvedDirectUrl': resolved ?? url,
          'fileName': file ?? 'mod.zip',
          'sourceHost': 'example.com',
          'confidence': confidence ?? 'high',
          'requiresManualStep': false,
        };

    List<Map<String, dynamic>> itemsOf(Map<String, dynamic> history) =>
        ((entriesOf(history).first['changes'] as List)
                .cast<Map<String, dynamic>>()
                .firstWhere((c) => c['field'] == 'downloads')['items'] as List)
            .cast<Map<String, dynamic>>();

    test('a new link is one added row, and the rest stay quiet', () {
      final history = historyOf([
        at('r1', snapshotOf({
          'id': 1,
          'downloads': [download('http://a/one.zip', file: 'one.zip')],
        })),
        at('r2', snapshotOf({
          'id': 1,
          'downloads': [
            download('http://a/one.zip', file: 'one.zip'),
            download('http://a/two.zip', file: 'two.zip'),
          ],
        })),
      ]);

      final items = itemsOf(history);
      expect(items, hasLength(1));
      expect(items.first['change'], 'added');
      expect(items.first['label'], 'two.zip');
    });

    test('a dropped link is one removed row', () {
      final history = historyOf([
        at('r1', snapshotOf({
          'id': 1,
          'downloads': [
            download('http://a/one.zip', file: 'one.zip'),
            download('http://a/two.zip', file: 'two.zip'),
          ],
        })),
        at('r2', snapshotOf({
          'id': 1,
          'downloads': [download('http://a/one.zip', file: 'one.zip')],
        })),
      ]);

      final items = itemsOf(history);
      expect(items, hasLength(1));
      expect(items.first['change'], 'removed');
      expect(items.first['label'], 'two.zip');
    });

    test('the same link resolving differently shows only what moved', () {
      final history = historyOf([
        at('r1', snapshotOf({
          'id': 1,
          'downloads': [
            download('http://a/one.zip', resolved: 'http://cdn/old.zip')
          ],
        })),
        at('r2', snapshotOf({
          'id': 1,
          'downloads': [
            download('http://a/one.zip', resolved: 'http://cdn/new.zip')
          ],
        })),
      ]);

      final items = itemsOf(history);
      expect(items, hasLength(1));
      expect(items.first['change'], 'changed');

      final parts = (items.first['parts'] as List).cast<Map<String, dynamic>>();
      expect(parts, hasLength(1));
      expect(parts.first['name'], 'resolved link');
      expect(parts.first['before'], 'http://cdn/old.zip');
      expect(parts.first['after'], 'http://cdn/new.zip');
    });

    test('the two whole lists are not sent as well', () {
      final history = historyOf([
        at('r1', snapshotOf({
          'id': 1,
          'downloads': [download('http://a/one.zip')],
        })),
        at('r2', snapshotOf({
          'id': 1,
          'downloads': [download('http://a/two.zip')],
        })),
      ]);

      final change = (entriesOf(history).first['changes'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((c) => c['field'] == 'downloads');
      expect(change.containsKey('before'), isFalse);
      expect(change.containsKey('after'), isFalse);
    });
  });

  group('LLM facts, mod by mod', () {
    Map<String, dynamic> llm(List<Map<String, dynamic>> mods) => {'mods': mods};

    List<Map<String, dynamic>> itemsOf(Map<String, dynamic> history) =>
        ((entriesOf(history).first['changes'] as List)
                .cast<Map<String, dynamic>>()
                .firstWhere((c) => c['field'] == 'LLM facts')['items'] as List)
            .cast<Map<String, dynamic>>();

    test('a version that moved reads as old and new', () {
      final history = historyOf([
        at('r1', snapshotOf({
          'id': 1,
          'llm': llm([
            {
              'name': 'A Mod',
              'role': 'main',
              'extras': {'version': '0.7'},
            }
          ]),
        })),
        at('r2', snapshotOf({
          'id': 1,
          'llm': llm([
            {
              'name': 'A Mod',
              'role': 'main',
              'extras': {'version': '0.8'},
            }
          ]),
        })),
      ]);

      final items = itemsOf(history);
      expect(items, hasLength(1));
      expect(items.first['label'], 'A Mod');
      final parts = (items.first['parts'] as List).cast<Map<String, dynamic>>();
      expect(parts, hasLength(1));
      expect(parts.first['name'], 'version');
      expect(parts.first['before'], '0.7');
      expect(parts.first['after'], '0.8');
    });

    test('the summary is compared a piece at a time', () {
      final history = historyOf([
        at('r1', snapshotOf({
          'id': 1,
          'llm': llm([
            {
              'name': 'A Mod',
              'extras': {
                'summary': {'sentence': 'Adds ships.', 'paragraph': 'Long.'}
              },
            }
          ]),
        })),
        at('r2', snapshotOf({
          'id': 1,
          'llm': llm([
            {
              'name': 'A Mod',
              'extras': {
                'summary': {'sentence': 'Adds pirates.', 'paragraph': 'Long.'}
              },
            }
          ]),
        })),
      ]);

      final parts =
          (itemsOf(history).first['parts'] as List).cast<Map<String, dynamic>>();
      expect(parts, hasLength(1));
      expect(parts.first['name'], 'summary — one line');
      expect(parts.first['after'], 'Adds pirates.');
    });

    test('a mod the LLM found for the first time is one added row', () {
      final history = historyOf([
        at('r1', snapshotOf({
          'id': 1,
          'llm': llm([
            {'name': 'A Mod'}
          ]),
        })),
        at('r2', snapshotOf({
          'id': 1,
          'llm': llm([
            {'name': 'A Mod'},
            {'name': 'A Patch'},
          ]),
        })),
      ]);

      final items = itemsOf(history);
      expect(items, hasLength(1));
      expect(items.first['change'], 'added');
      expect(items.first['label'], 'A Patch');
    });

    test("a download inside a mod is reported under that mod", () {
      final history = historyOf([
        at('r1', snapshotOf({
          'id': 1,
          'llm': llm([
            {'name': 'A Mod', 'downloads': <dynamic>[]}
          ]),
        })),
        at('r2', snapshotOf({
          'id': 1,
          'llm': llm([
            {
              'name': 'A Mod',
              'downloads': [
                {'url': 'http://a/mod.zip', 'fileName': 'mod.zip'}
              ],
            }
          ]),
        })),
      ]);

      final items = itemsOf(history);
      expect(items, hasLength(1));
      expect(items.first['change'], 'changed');
      final inner = (items.first['items'] as List).cast<Map<String, dynamic>>();
      expect(inner, hasLength(1));
      expect(inner.first['change'], 'added');
      expect(inner.first['label'], 'mod.zip');
    });
  });

  group('served over the API', () {
    late Directory dir;
    late ViewerApi api;
    late DataAccess data;
    late BundleSnapshotStore store;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('topic_history');
      store = BundleSnapshotStore(p.join(dir.path, 'data'));
      data = DataAccess(
        dataDir: p.join(dir.path, 'data'),
        outputsDir: p.join(dir.path, 'outputs'),
        rootDir: dir.path,
      );
      api = ViewerApi(data);
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    Future<Map<String, dynamic>> get(String path) async {
      final res =
          await api.router(Request('GET', Uri.parse('http://localhost/$path')));
      return jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    }

    /// Saves a snapshot the way a run does. The store strips the post text.
    Future<void> save(String runId, Map<String, dynamic> topic) => store.save(
        runId,
        {
          'updatedAt': '2026-07-22T12:00:00Z',
          'index': [
            {
              'topicId': topic['id'],
              'title': topic['title'] ?? 'A Mod',
              'author': 'Someone',
              'lastPostDate': 'July 01, 2026, 10:00:00 AM',
              'isWip': false,
              'inModIndex': true,
              'sourceBoard': 8,
              'scrapedAt': topic['scrapedAt'] ?? '2026-07-01T00:00:00Z',
            },
          ],
          'details': {
            '${topic['id']}': {
              'topicId': topic['id'],
              'contentHtml': topic['post'] ?? '<p>A mod.</p>',
              'images': <dynamic>[],
            },
          },
          'assumedDownloads': <String, dynamic>{},
        });

    test('a topic that changed comes back newest first, with the counts',
        () async {
      await save('20260720T100000Z-fullRun', {'id': 1, 'title': 'Alpha'});
      await save('20260721T100000Z-fullRun', {'id': 1, 'title': 'Beta'});
      await save('20260722T100000Z-fullRun', {'id': 1, 'title': 'Gamma'});

      final body = await get('topics/1/history');
      expect((body['entries'] as List).map((e) => e['runId']),
          ['20260722T100000Z-fullRun', '20260721T100000Z-fullRun']);
      expect(body['snapshotsRead'], 3);
      expect(body['snapshotsTotal'], 3);
      expect(body['oldestRunId'], '20260720T100000Z-fullRun');
      expect(body['title'], 'Gamma');
    });

    test('a topic that never changed comes back with nothing to show',
        () async {
      await save('20260720T100000Z-fullRun', {'id': 1});
      await save('20260722T100000Z-fullRun', {'id': 1});

      final body = await get('topics/1/history');
      expect(body['entries'], isEmpty);
      expect(body['snapshotsRead'], 2,
          reason: 'the page says how many it checked, so an empty history '
              'reads as an answer rather than a shrug');
    });

    test('a new snapshot shows up on the next ask', () async {
      await save('20260720T100000Z-fullRun', {'id': 1, 'title': 'Alpha'});
      await save('20260721T100000Z-fullRun', {'id': 1, 'title': 'Beta'});

      final first = await get('topics/1/history');
      expect(first['entries'], hasLength(1));

      await save('20260722T100000Z-fullRun', {'id': 1, 'title': 'Gamma'});

      final second = await get('topics/1/history');
      expect(second['entries'], hasLength(2));
      expect((second['entries'] as List).first['runId'],
          '20260722T100000Z-fullRun');
    });

    test('working out a history leaves the compare page its two snapshots',
        () async {
      for (var i = 0; i < 6; i++) {
        await save('2026072${i}T100000Z-fullRun', {'id': 1, 'title': 'Mod $i'});
      }

      await get('bundle/compare'
          '?a=20260720T100000Z-fullRun&b=20260721T100000Z-fullRun');
      final beingCompared = data.heldSnapshots;
      expect(beingCompared, hasLength(2));

      await get('topics/1/history');
      expect(data.heldSnapshots, beingCompared,
          reason: 'the history walk reads every snapshot, so it must not go '
              'through the small holding pen');
    });

    test('no post text and no whole snapshot go to the browser', () async {
      await save('20260720T100000Z-fullRun',
          {'id': 1, 'post': '<p>secret post text</p>'});
      await save('20260722T100000Z-fullRun',
          {'id': 1, 'post': '<p>a different secret</p>'});

      final body = jsonEncode(await get('topics/1/history'));
      expect(body, isNot(contains('secret')));
      expect(body, isNot(contains('contentHtml')));
    });

    test('with no bundles saved at all it says so in plain words', () async {
      final body = await get('topics/1/history');
      expect(body['missing'], isTrue);
      expect(body['hint'], contains('No bundles have been saved yet'));
    });

    test('a topic id that is not a number is refused', () async {
      final body = await get('topics/not-a-number/history');
      expect(body['error'], contains('must be an integer'));
    });
  });
}
