import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/manager/bundle_snapshot_store.dart';
import 'package:mod_repo_scraper/viewer/api.dart';
import 'package:mod_repo_scraper/viewer/data_access.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// `GET /api/mods`, `GET /api/mods/<id>` and `GET /api/mods/<id>/history`: the
/// mods of the last build, one mod with where its facts came from, and the
/// saved runs in which it changed.
void main() {
  late Directory tmp;
  late String dataDir;
  late String outputsDir;
  late Handler handler;

  const builtAt = '2026-10-22T00:00:00.000Z';

  void writeJson(String path, Object value) {
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(value));
  }

  Map<String, dynamic> post(String kind, String id, {String? llmName, String foundBy = 'rules'}) => {
        'kind': kind,
        'id': id,
        if (llmName != null) 'llmModName': llmName,
        'foundBy': foundBy,
      };

  // Alpha is a forum topic and a Discord thread; Beta is one forum topic.
  final alphaForum = post('forum', '1', llmName: 'Alpha');
  final alphaDiscord = post('discord', '900', llmName: 'Alpha', foundBy: 'llm');
  final betaForum = post('forum', '2');

  Map<String, dynamic> scraped(String name, {String author = 'Someone'}) => {
        'name': name,
        'authorsList': [author],
      };

  Map<String, dynamic> mergeDebug({List<List<Map<String, dynamic>>>? outputs}) => {
        'groups': [
          {
            'groupIndex': 0,
            'members': [scraped('Alpha'), scraped('Alpha 1.3')],
            'matchEntries': [
              {
                'outerMod': scraped('Alpha'),
                'innerMod': scraped('Alpha 1.3'),
                'reasons': ['nameAndAuthor', 'forumUrl'],
              },
            ],
            'memberSourcePosts': [
              [alphaForum],
              [alphaDiscord],
            ],
          },
          {
            'groupIndex': 1,
            'members': [scraped('Beta')],
            'matchEntries': [],
            'memberSourcePosts': [
              [betaForum],
            ],
          },
        ],
        'finalOutput': [scraped('Alpha'), scraped('Beta')],
        'finalSourcePosts': outputs ??
            [
              [alphaForum, alphaDiscord],
              [betaForum],
            ],
      };

  void writeFactSources({String at = builtAt}) => writeJson(p.join(dataDir, 'fact-sources.json'), {
        'builtAt': at,
        'mods': {
          'alpha': {
            'modVersion': {'kind': 'discord', 'id': '900', 'llmName': 'Alpha'},
            'license': {'kind': 'forum', 'id': '1', 'llmName': 'Alpha'},
            'downloads': 'rules',
            'nicknames': 'merged',
          },
        },
        'mergedFrom': {
          'alpha': {
            'nicknames': [
              {'kind': 'forum', 'id': '1', 'llmName': 'Alpha'},
              {'kind': 'discord', 'id': '900', 'llmName': 'Alpha'},
            ],
          },
        },
      });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('viewer_mods');
    dataDir = p.join(tmp.path, 'qb_data');
    outputsDir = p.join(tmp.path, 'outputs');

    writeJson(p.join(dataDir, 'mods-index.json'), [
      {'topicId': 1, 'title': 'Alpha Thread', 'author': 'Someone', 'scrapedAt': '2026-10-01T00:00:00Z'},
      {'topicId': 2, 'title': 'Beta Thread', 'author': 'Other', 'scrapedAt': '2026-10-01T00:00:00Z'},
      {'topicId': 3, 'title': 'A Collection Thread', 'author': 'Other', 'scrapedAt': '2026-10-01T00:00:00Z'},
    ]);
    writeJson(p.join(dataDir, 'discord-posts.json'), {
      '900': {
        'threadId': '900',
        'name': 'Alpha on Discord',
        'author': 'someone',
        'url': 'https://discord.com/channels/1/900/900',
        'messages': [],
      },
    });
    writeJson(p.join(outputsDir, 'mod-catalog.json'), {
      'items': [
        {
          'id': 'alpha',
          ...scraped('Alpha'),
          'sourcePosts': [alphaForum, alphaDiscord],
        },
        {
          'id': 'beta',
          ...scraped('Beta', author: 'Other'),
          'sourcePosts': [betaForum],
        },
      ],
      'collections': [
        {
          'id': 'a-collection',
          'name': 'A Collection',
          'sourcePost': {'kind': 'forum', 'id': '3'},
          'modIds': ['alpha', 'beta'],
        },
      ],
      'movedIds': {'old-alpha': 'alpha'},
      'lastUpdated': builtAt,
    });
    writeJson(p.join(outputsDir, 'site', 'mods.json'), {
      'mods': [
        {
          'id': 'alpha',
          'name': 'Alpha',
          'displayName': 'Alpha!',
          'nicknames': ['ALF'],
          'sources': ['forum', 'discord'],
          'modVersion': '1.3',
          'usesAi': false,
          'bestDownload': {'url': 'https://e/a.zip', 'kind': 'zip', 'needsAnotherStep': false},
        },
        {'id': 'beta', 'name': 'Beta', 'sources': ['forum']},
      ],
    });
    writeJson(p.join(outputsDir, 'site', 'mods', 'alpha.json'), {
      'listing': {
        'id': 'alpha',
        'name': 'Alpha',
        'modVersion': '1.3',
        'nicknames': ['ALF'],
        'needs': [
          {'name': 'LazyLib', 'id': 'lazylib'},
          {'name': 'Mystery Lib'},
          {'name': 'GraphicsLib', 'via': 'MagicLib'},
        ],
      },
      'license': 'MIT',
      'downloads': [
        {'url': 'https://e/a.zip', 'kind': 'zip', 'label': 'Download', 'needsAnotherStep': false},
      ],
      'optionalNeeds': [
        {'name': 'Optional Thing'},
        {'name': 'mystery lib'},
      ],
    });
    writeJson(p.join(outputsDir, 'site', 'mods', 'a-collection.json'), {
      'collection': {'id': 'a-collection', 'name': 'A Collection', 'mods': []},
    });
    writeJson(p.join(outputsDir, 'site', 'conflicts.json'), {
      'mods': [
        {
          'modId': 'alpha',
          'modName': 'Alpha',
          'conflicts': [
            {'name': 'Beta', 'id': 'beta', 'quote': 'Breaks with Beta', 'kind': 'technical'},
          ],
        },
      ],
    });
    writeJson(p.join(dataDir, 'takedowns.json'), {
      'mods': [
        {'id': 'gone-mod', 'name': 'Gone Mod', 'posts': ['discord:777'], 'on': '2026-10-01'},
      ],
      'authors': [],
    });
    writeJson(p.join(dataDir, 'takedown-matches.json'), {
      'builtAt': builtAt,
      'matches': [
        {
          'entry': 'gone-mod',
          'mods': [
            {'id': 'gone-mod', 'name': 'Gone Mod'},
          ],
          'collections': [],
          'blockedPosts': ['discord:777#Gone Mod'],
        },
      ],
      'removedPosts': ['discord:777'],
    });
    writeJson(p.join(tmp.path, 'merge-debug.json'), mergeDebug());
    writeFactSources();

    handler = ViewerApi(DataAccess(dataDir: dataDir, outputsDir: outputsDir, rootDir: tmp.path)).router;
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Future<(int, Map<String, dynamic>)> get(String path) async {
    final res = await handler(Request('GET', Uri.parse('http://localhost/$path')));
    return (res.statusCode, jsonDecode(await res.readAsString()) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> mods([String query = '']) async {
    final (status, body) = await get('mods?pageSize=0&$query');
    expect(status, 200);
    return body;
  }

  List<String> ids(Map<String, dynamic> body) => [for (final row in body['items'] as List) '${row['id']}'];

  Future<Map<String, dynamic>> modAt(String id) async {
    final (status, body) = await get('mods/$id');
    expect(status, 200);
    return body;
  }

  group('GET /api/mods', () {
    test('lists every catalog mod and every taken-down mod', () async {
      final body = await mods();
      expect(ids(body), ['alpha', 'beta', 'gone-mod']);
      expect(body['counts'], {'total': 3, 'noDownload': 1, 'takenDown': 1, 'conflicts': 1, 'aiStated': 1});
    });

    test('each row carries what the list shows', () async {
      final rows = {for (final row in (await mods())['items'] as List) row['id']: row};
      expect(rows['alpha'], {
        'id': 'alpha',
        'name': 'Alpha',
        'displayName': 'Alpha!',
        'authors': ['Someone'],
        'sources': ['forum', 'discord'],
        'gameVersion': null,
        'modVersion': '1.3',
        'hasDownload': true,
        'takenDown': false,
        'conflicts': 1,
        'usesAi': false,
      });
      expect(rows['gone-mod']!['takenDown'], isTrue);
      expect(rows['gone-mod']!['sources'], ['discord']);
    });

    test('searches names, nicknames, authors and ids', () async {
      expect(ids(await mods('q=alf')), ['alpha']);
      expect(ids(await mods('q=other')), ['beta']);
      expect(ids(await mods('q=gone-')), ['gone-mod']);
    });

    test('filters', () async {
      expect(ids(await mods('filters=noDownload')), ['beta']);
      expect(ids(await mods('filters=takenDown')), ['gone-mod']);
      expect(ids(await mods('filters=conflicts')), ['alpha']);
      expect(ids(await mods('filters=aiStated')), ['alpha']);
    });

    test('sorts and pages', () async {
      expect(ids(await mods('sort=name&dir=desc')), ['gone-mod', 'beta', 'alpha']);
      final (_, page) = await get('mods?pageSize=1&page=1');
      expect(ids(page), ['beta']);
      expect(page['total'], 3);
    });

    test('a page past the end gives the last page, however big the number', () async {
      for (final asked in ['3', '200000000000000000', '9223372036854775807']) {
        final (status, page) = await get('mods?pageSize=1&page=$asked');
        expect(status, 200, reason: 'page=$asked');
        expect(ids(page), ['gone-mod'], reason: 'page=$asked');
        expect(page['page'], 2, reason: 'page=$asked');
      }
      final (_, first) = await get('mods?pageSize=2&page=-4');
      expect(ids(first), ['alpha', 'beta']);
      expect(first['page'], 0);
    });

    test('says what to run when there is no catalog', () async {
      File(p.join(outputsDir, 'mod-catalog.json')).deleteSync();
      final (status, body) = await get('mods');
      expect(status, 200);
      expect(body['missing'], isTrue);
    });
  });

  group('GET /api/mods/<id>', () {
    test('a mod: its records, posts, facts, old ids and unmatched needs', () async {
      final body = await modAt('alpha');
      expect(body['kind'], 'mod');
      expect((body['catalog'] as Map)['name'], 'Alpha');
      expect((body['site'] as Map)['license'], 'MIT');
      expect(body['starmodderUrl'], 'https://starmodder.wispborne.com/mods/alpha/');
      expect(body['oldIds'], ['old-alpha']);
      expect(body['unmatchedNeeds'], [
        {'name': 'Mystery Lib', 'key': 'mysterylib'},
        {'name': 'Optional Thing', 'key': 'optionalthing'},
      ]);
      expect(body.containsKey('takedown'), isFalse);
      expect(body['sourcePosts'], [
        {
          'kind': 'forum',
          'id': '1',
          'title': 'Alpha Thread',
          'postKind': 'topic',
          'llmName': 'Alpha',
          'foundBy': 'rules',
          'joinedBy': 'first',
        },
        {
          'kind': 'discord',
          'id': '900',
          'title': 'Alpha on Discord',
          'postKind': 'discord',
          'llmName': 'Alpha',
          'foundBy': 'llm',
          'joinedBy': 'forumLink',
        },
      ]);
    });

    test('says where each fact came from, with the value Starmodder shows', () async {
      final body = await modAt('alpha');
      expect(body['factsStatus'], 'current');
      final facts = body['facts'] as Map;
      expect(facts['modVersion'], {
        'value': '1.3',
        'source': {'kind': 'discord', 'id': '900', 'llmName': 'Alpha'},
      });
      expect(facts['license'], {
        'value': 'MIT',
        'source': {'kind': 'forum', 'id': '1', 'llmName': 'Alpha'},
      });
      expect((facts['downloads'] as Map)['source'], 'rules');
      expect(facts['nicknames'], {
        'value': ['ALF'],
        'source': 'merged',
        'from': [
          {'kind': 'forum', 'id': '1', 'llmName': 'Alpha'},
          {'kind': 'discord', 'id': '900', 'llmName': 'Alpha'},
        ],
      });
    });

    test('fact sources saved for another build are not used', () async {
      writeFactSources(at: '2026-10-01T00:00:00.000Z');
      final body = await modAt('alpha');
      expect(body['factsStatus'], 'otherBuild');
      expect(body['facts'], isEmpty);
    });

    test('with no fact sources saved, it says so', () async {
      File(p.join(dataDir, 'fact-sources.json')).deleteSync();
      final body = await modAt('alpha');
      expect(body['factsStatus'], 'missing');
      expect(body['facts'], isEmpty);
    });

    test('how a post joined is left out when the merge data is from another build', () async {
      writeJson(p.join(tmp.path, 'merge-debug.json'), mergeDebug(outputs: [
        [alphaForum],
        [betaForum],
      ]));
      final body = await modAt('alpha');
      for (final post in body['sourcePosts'] as List) {
        expect((post as Map).containsKey('joinedBy'), isFalse);
      }
      // Beta's posts are the same in both, so its answer is still read.
      expect(((await modAt('beta'))['sourcePosts'] as List).single['joinedBy'], 'first');
    });

    void writeMergeSnapshot(String runId, Map<String, dynamic> debug, {required DateTime fileTime}) {
      File(p.join(dataDir, 'merges', '$runId.json.gz'))
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(gzip.encode(utf8.encode(jsonEncode(debug))))
        ..setLastModifiedSync(fileTime);
    }

    // A merge from another build: alpha's Discord post is not in it.
    Map<String, dynamic> otherBuild() => mergeDebug(outputs: [
          [alphaForum],
          [betaForum],
        ]);

    test('how a post joined comes from the merge snapshot when merge-debug.json is gone', () async {
      File(p.join(tmp.path, 'merge-debug.json')).deleteSync();
      // Saved before the save time was recorded: the run started before the
      // catalog was built, and the file was written after.
      writeMergeSnapshot('20261021T235900Z-mergeModRepo', mergeDebug(), fileTime: DateTime.utc(2026, 10, 22, 0, 1));
      // An older build's, written before the catalog, and the next run's,
      // started after it. Neither is this build's.
      writeMergeSnapshot('20261021T120000Z-mergeModRepo', otherBuild(), fileTime: DateTime.utc(2026, 10, 21, 12, 1));
      writeMergeSnapshot('20261022T060000Z-mergeModRepo', otherBuild(), fileTime: DateTime.utc(2026, 10, 22, 6, 1));
      final body = await modAt('alpha');
      expect([for (final post in body['sourcePosts'] as List) post['joinedBy']], ['first', 'forumLink']);
    });

    test('a merge snapshot with a recorded save time is found by it', () async {
      File(p.join(tmp.path, 'merge-debug.json')).deleteSync();
      // The file times say nothing here (a copied folder): the recorded times
      // decide.
      final copied = DateTime.utc(2026, 11, 1);
      writeMergeSnapshot('20261021T235900Z-mergeModRepo', mergeDebug(), fileTime: copied);
      writeMergeSnapshot('20261021T235950Z-fullRun', otherBuild(), fileTime: copied);
      writeJson(p.join(dataDir, 'merges', 'merge-counts.json'), {
        '20261021T235900Z-mergeModRepo': {'savedAt': '2026-10-22T00:00:05.000Z'},
        // Started before the catalog too, but saved before it was built.
        '20261021T235950Z-fullRun': {'savedAt': '2026-10-21T23:59:58.000Z'},
      });
      final body = await modAt('alpha');
      expect([for (final post in body['sourcePosts'] as List) post['joinedBy']], ['first', 'forumLink']);
    });

    test('a shared id says so in joinedBy', () async {
      final debug = mergeDebug();
      ((debug['groups'] as List).first['matchEntries'] as List).first['reasons'] = ['nameAndAuthor', 'forumUrl', 'sameId'];
      writeJson(p.join(tmp.path, 'merge-debug.json'), debug);
      final body = await modAt('alpha');
      expect((body['sourcePosts'] as List)[1]['joinedBy'], 'sameId');
    });

    test('an old id answers moved, naming the mod it leads to', () async {
      expect(await modAt('old-alpha'), {
        'id': 'old-alpha',
        'kind': 'moved',
        'movedTo': 'alpha',
        'movedToName': 'Alpha',
      });
    });

    test("a Collection's id answers as a Collection", () async {
      final body = await modAt('a-collection');
      expect(body['kind'], 'collection');
      expect(body['collection'], {
        'id': 'a-collection',
        'name': 'A Collection',
        'sourcePost': {'kind': 'forum', 'id': '3', 'title': 'A Collection Thread', 'postKind': 'topic'},
        'mods': [
          {'id': 'alpha', 'name': 'Alpha', 'displayName': 'Alpha!'},
          {'id': 'beta', 'name': 'Beta'},
        ],
      });
      expect((body['site'] as Map)['collection'], isNotNull);
    });

    test('a taken-down mod answers takenDown, with its entry', () async {
      final body = await modAt('gone-mod');
      expect(body['kind'], 'takenDown');
      expect(body['name'], 'Gone Mod');
      expect((body['takedown'] as Map)['status'], 'takenDown');
      expect((body['takedown'] as Map)['entryKind'], 'mod');
      expect((body['takedown'] as Map).containsKey('author'), isFalse);
      expect(((body['takedown'] as Map)['entry'] as Map)['on'], '2026-10-01');
      expect(body['sourcePosts'], [
        {'kind': 'discord', 'id': '777', 'title': '', 'postKind': 'discord'},
      ]);
    });

    test('a mod an author entry took down says so, naming the person', () async {
      writeJson(p.join(dataDir, 'takedowns.json'), {
        'mods': [],
        'authors': [
          {
            'names': ['Tidal', 'tidal5590'],
            'on': '2026-10-02',
          },
        ],
      });
      writeJson(p.join(dataDir, 'takedown-matches.json'), {
        'builtAt': builtAt,
        'matches': [
          {
            'entry': 'author:tidal',
            'mods': [
              {'id': 'tidal-mod', 'name': 'Tidal Mod'},
            ],
            'collections': [],
            'blockedPosts': [],
          },
        ],
        'removedPosts': [],
      });
      final body = await modAt('tidal-mod');
      expect(body['kind'], 'takenDown');
      final takedown = body['takedown'] as Map;
      expect(takedown['entryKind'], 'author');
      expect(takedown['author'], 'Tidal');
      expect((takedown['entry'] as Map)['on'], '2026-10-02');
    });

    test('a mod back under a new id carries the takedown entry', () async {
      writeJson(p.join(dataDir, 'takedowns.json'), {
        'mods': [
          {'id': 'old-beta', 'name': 'Beta', 'posts': ['forum:2'], 'on': '2026-10-01'},
        ],
        'authors': [],
      });
      final body = await modAt('beta');
      expect(body['takedown'], {
        'status': 'returnedUnderNewId',
        'entries': [
          {'id': 'old-beta', 'name': 'Beta', 'posts': ['forum:2'], 'on': '2026-10-01'},
        ],
      });
    });

    test('an unknown id answers unknown', () async {
      expect(await modAt('no-such-mod'), {'id': 'no-such-mod', 'kind': 'unknown'});
    });

    test('an id that is not a file name reads no file', () async {
      final body = await modAt('..%2Fmods');
      expect(body['kind'], 'unknown');
    });
  });

  group('GET /api/mods/<id>/history', () {
    var minute = 0;

    /// A saved bundle in which topic 1 has Alpha and Gamma, and maybe the
    /// Discord thread.
    Future<void> saveBundle(String runId,
        {String alphaVersion = '1.0', String gammaVersion = '1.0', bool withDiscord = false}) async {
      Map<String, dynamic> llmMod(String name, String version) => {
            'name': name,
            'downloads': [],
            'extras': {'version': version},
          };
      final file = await BundleSnapshotStore(dataDir).save(runId, {
        'updatedAt': '2026-10-01T00:00:00Z',
        'index': [
          {
            'topicId': 1,
            'title': 'Alpha Thread',
            'author': 'Someone',
            'llm': {
              'mods': [llmMod('Alpha', alphaVersion), llmMod('Gamma', gammaVersion)],
            },
          },
        ],
        'details': {
          '1': {'topicId': 1, 'contentHtml': '<p>Alpha</p>'},
        },
        'assumedDownloads': {},
        'discordThreads': [
          if (withDiscord)
            {
              'threadId': '900',
              'name': 'Alpha on Discord',
              'url': '',
              'mods': [llmMod('Alpha', alphaVersion)],
            },
        ],
      });
      file.setLastModifiedSync(DateTime.utc(2026, 10, 1).add(Duration(minutes: ++minute)));
    }

    void saveMerge(String runId, String name) {
      final debug = mergeDebug();
      (debug['finalOutput'] as List)[0] = scraped(name);
      File(p.join(dataDir, 'merges', '$runId.json.gz'))
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(gzip.encode(utf8.encode(jsonEncode(debug))))
        ..setLastModifiedSync(DateTime.utc(2026, 10, 1).add(Duration(minutes: ++minute)));
    }

    Future<Map<String, dynamic>> historyOf(String id) async {
      final (status, body) = await get('mods/$id/history');
      expect(status, 200);
      return body;
    }

    test("lists the runs in which the mod's own record changed, newest first", () async {
      await saveBundle('r1');
      await saveBundle('r2', gammaVersion: '2.0'); // Only Gamma, the other mod on the topic.
      await saveBundle('r3', alphaVersion: '1.1', gammaVersion: '2.0');
      await saveBundle('r4', alphaVersion: '1.1', gammaVersion: '2.0', withDiscord: true);

      final history = await historyOf('alpha');
      final entries = (history['entries'] as List).cast<Map<String, dynamic>>();
      expect([for (final e in entries) e['runId']], ['r4', 'r3']);
      expect(entries[1]['source'], 'bundle');
      expect(entries[1]['kind'], 'changed');
      expect(entries[1]['fields'], ['LLM facts']);
      expect((entries[1]['diff'] as List).single['post'], {'kind': 'forum', 'id': '1', 'llmName': 'Alpha'});
      expect(entries[0]['fields'], ['source post']);
      expect((entries[0]['diff'] as List).single['post'], {'kind': 'discord', 'id': '900', 'llmName': 'Alpha'});
      expect(history['bundleSnapshots'], containsPair('read', 4));
    });

    test('takes in the merges, matched by the mod\'s posts', () async {
      saveMerge('m1', 'Alpha');
      saveMerge('m2', 'Alpha Renamed');

      final entries = ((await historyOf('alpha'))['entries'] as List).cast<Map<String, dynamic>>();
      expect(entries, hasLength(1));
      expect(entries.single['runId'], 'm2');
      expect(entries.single['source'], 'merge');
      expect(entries.single['fields'], ['name']);
      expect((entries.single['diff'] as List).single, {'field': 'name', 'before': 'Alpha', 'after': 'Alpha Renamed'});
    });

    test('a new snapshot is picked up', () async {
      await saveBundle('r1');
      expect((await historyOf('alpha'))['entries'], isEmpty);
      await saveBundle('r2', alphaVersion: '2.0');
      expect([for (final e in (await historyOf('alpha'))['entries'] as List) e['runId']], ['r2']);
    });

    test('an unknown id has no history', () async {
      await saveBundle('r1');
      final history = await historyOf('no-such-mod');
      expect(history['kind'], 'unknown');
      expect(history['entries'], isEmpty);
    });
  });
}
