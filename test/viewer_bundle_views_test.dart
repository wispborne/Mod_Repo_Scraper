import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/manager/bundle_snapshot_store.dart';
import 'package:mod_repo_scraper/viewer/api.dart';
import 'package:mod_repo_scraper/viewer/data_access.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late ViewerApi api;
  late BundleSnapshotStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('bundle_compare');
    store = BundleSnapshotStore(p.join(dir.path, 'data'));
    api = ViewerApi(DataAccess(
      dataDir: p.join(dir.path, 'data'),
      outputsDir: p.join(dir.path, 'outputs'),
      rootDir: dir.path,
    ));
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  /// One topic as the bundle holds it, split across the three parts.
  Map<String, dynamic> bundle(List<Map<String, dynamic>> topics) => {
        'updatedAt': '2026-07-22T12:00:00Z',
        'meta': {'version': 1},
        'index': [
          for (final t in topics)
            {
              'topicId': t['id'],
              'title': t['title'] ?? 'Mod ${t['id']}',
              'author': t['author'] ?? 'Someone',
              'category': 'ships',
              'lastPostDate': t['lastPost'] ?? 'July 01, 2026, 10:00:00 AM',
              'isWip': t['isWip'] ?? false,
              'inModIndex': true,
              'sourceBoard': 8,
              'scrapedAt': t['scrapedAt'] ?? '2026-07-01T00:00:00Z',
              'llm': t['llm'],
            },
        ],
        'details': {
          for (final t in topics)
            '${t['id']}': {
              'topicId': t['id'],
              'contentHtml': t['post'] ?? '<p>A mod.</p>',
              'images': t['images'] ?? <dynamic>[],
            },
        },
        'assumedDownloads': {
          for (final t in topics)
            // A plain list, which is the shape a real bundle has.
            if (t['downloads'] != null) '${t['id']}': t['downloads'],
        },
      };

  Future<Map<String, dynamic>> get(String path) async {
    final res = await api.router(
        Request('GET', Uri.parse('http://localhost/$path')));
    return jsonDecode(await res.readAsString()) as Map<String, dynamic>;
  }

  Future<void> save(String id, Map<String, dynamic> data) =>
      store.save(id, data);

  test('the saved bundles are listed newest first', () async {
    await save('20260720T100000Z-fullRun', bundle([
      {'id': 1}
    ]));
    await save('20260722T100000Z-fullRun', bundle([
      {'id': 1},
      {'id': 2}
    ]));

    final body = await get('bundle/runs');
    expect((body['items'] as List).map((r) => r['id']),
        ['20260722T100000Z-fullRun', '20260720T100000Z-fullRun']);
    expect((body['items'] as List).first['indexCount'], 2);
  });

  group('what changed', () {
    test('a topic added, a topic gone, a topic changed', () async {
      await save('20260720T100000Z-fullRun', bundle([
        {'id': 1, 'title': 'Alpha'},
        {'id': 2, 'title': 'Beta'},
      ]));
      await save('20260722T100000Z-fullRun', bundle([
        {'id': 1, 'title': 'Alpha Renamed'},
        {'id': 3, 'title': 'Gamma'},
      ]));

      final body = await get(
          'bundle/compare?a=20260720T100000Z-fullRun&b=20260722T100000Z-fullRun');
      expect(body['addedCount'], 1);
      expect(body['goneCount'], 1);
      expect(body['changedCount'], 1);
      expect(body['sameCount'], 0);

      final rows = (body['items'] as List).cast<Map<String, dynamic>>();
      final added = rows.firstWhere((r) => r['kind'] == 'added');
      expect(added['name'], 'Gamma');
      final gone = rows.firstWhere((r) => r['kind'] == 'gone');
      expect(gone['name'], 'Beta');
      final changed = rows.firstWhere((r) => r['kind'] == 'changed');
      expect(changed['name'], 'Alpha Renamed');
      expect(
          (changed['changes'] as List).map((c) => c['field']), contains('title'));
    });

    test('comparing a bundle with itself finds no differences', () async {
      await save('20260722T100000Z-fullRun', bundle([
        {'id': 1},
        {'id': 2}
      ]));

      final body = await get(
          'bundle/compare?a=20260722T100000Z-fullRun&b=20260722T100000Z-fullRun');
      expect(body['addedCount'], 0);
      expect(body['goneCount'], 0);
      expect(body['changedCount'], 0);
      expect(body['sameCount'], 2);
      expect(body['items'], isEmpty);
    });

    test('a re-scrape that only moved the scrape time counts as unchanged',
        () async {
      await save('20260720T100000Z-fullRun', bundle([
        {'id': 1, 'scrapedAt': '2026-07-01T00:00:00Z'}
      ]));
      await save('20260722T100000Z-fullRun', bundle([
        {'id': 1, 'scrapedAt': '2026-07-22T00:00:00Z'}
      ]));

      final body = await get(
          'bundle/compare?a=20260720T100000Z-fullRun&b=20260722T100000Z-fullRun');
      expect(body['sameCount'], 1);
      expect(body['changedCount'], 0);
    });

    test('a changed post says so in words, without the old text', () async {
      await save('20260720T100000Z-fullRun', bundle([
        {'id': 1, 'post': '<p>Version 1.</p>'}
      ]));
      await save('20260722T100000Z-fullRun', bundle([
        {'id': 1, 'post': '<p>Version 2, now with more guns.</p>'}
      ]));

      final body = await get(
          'bundle/compare?a=20260720T100000Z-fullRun&b=20260722T100000Z-fullRun');
      expect(body['changedCount'], 1);
      final change = ((body['items'] as List).first['changes'] as List)
          .firstWhere((c) => c['field'] == 'post text');
      expect(change['note'], contains('post text changed'));
      expect(change.containsKey('before'), isFalse,
          reason: 'the old post text is not kept, so it must not be shown');
      final whole = jsonEncode(body);
      expect(whole, isNot(contains('more guns')));
      expect(whole, isNot(contains('Version 1')));
    });

    test('new LLM facts show up as a change', () async {
      await save('20260720T100000Z-fullRun', bundle([
        {'id': 1}
      ]));
      await save('20260722T100000Z-fullRun', bundle([
        {
          'id': 1,
          'llm': {
            'mods': [
              {'name': 'A Mod', 'version': '1.0'}
            ]
          }
        }
      ]));

      final body = await get(
          'bundle/compare?a=20260720T100000Z-fullRun&b=20260722T100000Z-fullRun');
      expect(body['changedCount'], 1);
      expect(((body['items'] as List).first['changes'] as List)
          .map((c) => c['field']), contains('LLM facts'));
    });

    test('only the download that moved is listed, not all of them', () async {
      List<Map<String, dynamic>> downloads(String second) => [
            {'originalUrl': 'https://a.example/one.zip', 'fileName': 'one.zip'},
            {'originalUrl': 'https://b.example/two.zip', 'fileName': second},
            {'originalUrl': 'https://c.example/three.zip', 'fileName': 'three.zip'},
          ];

      await save('20260720T100000Z-fullRun', bundle([
        {'id': 1, 'downloads': downloads('two.zip')}
      ]));
      await save('20260722T100000Z-fullRun', bundle([
        {'id': 1, 'downloads': downloads('two-fixed.zip')}
      ]));

      final body = await get(
          'bundle/compare?a=20260720T100000Z-fullRun&b=20260722T100000Z-fullRun');
      final change = ((body['items'] as List).first['changes'] as List)
          .cast<Map<String, dynamic>>()
          .single;
      expect(change['field'], 'downloads');
      // The whole list on both sides is what this used to show.
      expect(change.containsKey('before'), isFalse);

      final items = (change['items'] as List).cast<Map<String, dynamic>>();
      expect(items, hasLength(1));
      expect(items.single['label'], 'two-fixed.zip');
      expect((items.single['parts'] as List).single['name'], 'file name');
    });

    test('the differences can be searched and filtered', () async {
      await save('20260720T100000Z-fullRun', bundle([
        {'id': 1, 'title': 'Alpha', 'author': 'Ada'},
        {'id': 2, 'title': 'Beta', 'author': 'Bob'},
      ]));
      await save('20260722T100000Z-fullRun', bundle([
        {'id': 3, 'title': 'Gamma', 'author': 'Ada'},
      ]));

      final searched = await get('bundle/compare'
          '?a=20260720T100000Z-fullRun&b=20260722T100000Z-fullRun&q=ada');
      expect((searched['items'] as List).map((r) => r['name']), ['Gamma', 'Alpha']);

      final onlyGone = await get('bundle/compare'
          '?a=20260720T100000Z-fullRun&b=20260722T100000Z-fullRun&kind=gone');
      expect((onlyGone['items'] as List).map((r) => r['name']),
          ['Alpha', 'Beta']);
    });
  });

  group('what did this run change', () {
    test('naming only the newer side compares it with the one before',
        () async {
      await save('20260720T100000Z-fullRun', bundle([
        {'id': 1, 'title': 'Alpha'}
      ]));
      await save('20260722T100000Z-fullRun', bundle([
        {'id': 1, 'title': 'Alpha'},
        {'id': 2, 'title': 'Beta'},
      ]));

      final body = await get('bundle/compare?b=20260722T100000Z-fullRun');
      expect(body['a'], '20260720T100000Z-fullRun');
      expect(body['addedCount'], 1);
    });

    test('the oldest bundle kept has nothing before it', () async {
      await save('20260722T100000Z-fullRun', bundle([
        {'id': 1}
      ]));

      final body = await get('bundle/compare?b=20260722T100000Z-fullRun');
      expect(body['missing'], isTrue);
      expect(body['hint'], contains('oldest'));
    });

    test('a bundle that is no longer kept says so', () async {
      await save('20260722T100000Z-fullRun', bundle([
        {'id': 1}
      ]));

      final body = await get(
          'bundle/compare?a=20260101T000000Z-fullRun&b=20260722T100000Z-fullRun');
      expect(body['missing'], isTrue);
      expect(body['hint'], contains('no longer kept'));
    });

    test('naming no bundle at all is refused in plain words', () async {
      final body = await get('bundle/compare');
      expect(body['error'], contains('Name two bundles'));
    });
  });

  test('no bundle endpoint hands over a whole snapshot', () async {
    await save('20260720T100000Z-fullRun', bundle([
      {'id': 1, 'post': '<p>secret post text</p>'}
    ]));
    await save('20260722T100000Z-fullRun', bundle([
      {'id': 1, 'post': '<p>secret post text</p>'}
    ]));

    for (final path in [
      'bundle/runs',
      'bundle/compare?a=20260720T100000Z-fullRun&b=20260722T100000Z-fullRun',
    ]) {
      final body = jsonEncode(await get(path));
      expect(body, isNot(contains('secret post text')));
      expect(body, isNot(contains('contentHtml')));
    }
  });
}
