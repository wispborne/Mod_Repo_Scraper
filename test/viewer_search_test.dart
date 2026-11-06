import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/manager/job.dart';
import 'package:mod_repo_scraper/viewer/api.dart';
import 'package:mod_repo_scraper/viewer/data_access.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// `GET /api/search`: the new viewer's search box. Mods, forum topics and
/// Discord threads are found the way their full lists find them; runs come
/// from the run history when the manager is on.
void main() {
  late Directory tmp;
  late String dataDir;
  late String outputsDir;

  void writeJson(String path, Object value) {
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(value));
  }

  Map<String, dynamic> catalogMod(String id, String name, String author, List<Map<String, dynamic>> posts) => {
        'id': id,
        'name': name,
        'authorsList': [author],
        'sourcePosts': posts,
      };

  Map<String, dynamic> post(String kind, String id) => {'kind': kind, 'id': id, 'foundBy': 'rules'};

  const thread = '1355071745366822950';

  RunRecord run(String id, JobKind kind, {RunState state = RunState.completed}) => RunRecord(
        id: id,
        request: JobRequest(kind: kind),
        state: state,
        startedAt: DateTime.utc(2026, 11, 5, 23),
        logFileName: '$id.log',
      );

  final runs = [
    run('20261105T230000Z-fetchAndUpdate', JobKind.fetchAndUpdate),
    run('20261104T120000Z-rebuildFromSaved', JobKind.rebuildFromSaved, state: RunState.failed),
    run('20261103T120000Z-fetchAndUpdate', JobKind.fetchAndUpdate),
  ];

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('viewer_search');
    dataDir = p.join(tmp.path, 'qb_data');
    outputsDir = p.join(tmp.path, 'outputs');

    writeJson(p.join(dataDir, 'mods-index.json'), [
      {'topicId': 9000, 'title': '[0.98a] Nexerelin v0.12.1', 'author': 'Histidine', 'scrapedAt': '2026-10-01T00:00:00Z'},
      {'topicId': 18011, 'title': 'Industrial.Evolution', 'author': 'SirHartley', 'scrapedAt': '2026-10-01T00:00:00Z'},
      {'topicId': 180, 'title': 'An old thread', 'author': 'Someone', 'scrapedAt': '2026-10-01T00:00:00Z'},
      {'topicId': 181, 'title': '[0.9] Nexer help', 'author': 'Asker', 'scrapedAt': '2026-10-01T00:00:00Z'},
    ]);
    writeJson(p.join(dataDir, 'discord-posts.json'), {
      thread: {
        'threadId': thread,
        'name': 'Nexerelin announcements',
        'author': 'histidine',
        'url': 'https://discord.com/channels/1/$thread',
        'messages': [],
      },
    });
    writeJson(p.join(outputsDir, 'mod-catalog.json'), {
      'items': [
        catalogMod('nexerelin', 'Nexerelin', 'Histidine', [post('forum', '9000'), post('discord', thread)]),
        catalogMod('better-nexerelin-ships', 'Better Nexerelin Ships', 'Someone', [post('forum', '180')]),
        catalogMod('nexerelin-addon', 'Nexerelin Addon', 'Other', []),
        catalogMod('industrial-evolution', 'Industrial.Evolution', 'SirHartley', [post('forum', '18011')]),
        catalogMod('histidines-tweaks', 'Tweaks', 'Histidine', []),
      ],
      'collections': [],
      'movedIds': {},
      'lastUpdated': '2026-10-22T00:00:00.000Z',
    });
    writeJson(p.join(outputsDir, 'site', 'mods.json'), {
      'mods': [
        {'id': 'industrial-evolution', 'name': 'Industrial.Evolution', 'nicknames': ['IndEvo']},
        {'id': 'nexerelin', 'name': 'Nexerelin', 'nicknames': ['Nex']},
      ],
    });
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Handler handlerWith({List<RunRecord>? history}) => ViewerApi(
        DataAccess(dataDir: dataDir, outputsDir: outputsDir, rootDir: tmp.path),
        runs: history == null ? null : () => history,
      ).router;

  Future<Map<String, dynamic>> get(Handler handler, String path) async {
    final res = await handler(Request('GET', Uri.parse('http://localhost/$path')));
    expect(res.statusCode, 200);
    return jsonDecode(await res.readAsString()) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> search(String q, {List<RunRecord>? history, String extra = ''}) =>
      get(handlerWith(history: history), 'search?q=${Uri.encodeQueryComponent(q)}$extra');

  List<String> ids(Map<String, dynamic> group) => [for (final row in group['items'] as List) '${row['id']}'];

  test('answers every group, in the agreed shape', () async {
    final body = await search('nexerelin', history: runs);
    expect(body.keys, ['q', 'mods', 'topics', 'discord', 'runs']);
    expect(body['q'], 'nexerelin');
    expect((body['mods'] as Map)['items'].first, {
      'id': 'nexerelin',
      'name': 'Nexerelin',
      'authors': ['Histidine'],
    });
    expect((body['topics'] as Map)['items'].first, {
      'id': '9000',
      'title': '[0.98a] Nexerelin v0.12.1',
      'author': 'Histidine',
    });
    expect((body['discord'] as Map)['items'].single, {
      'id': thread,
      'title': 'Nexerelin announcements',
      'author': 'histidine',
    });
  });

  test('an exact name first, then names starting with the text, then names containing it', () async {
    final mods = (await search('nexerelin'))['mods'] as Map<String, dynamic>;
    expect(ids(mods), ['nexerelin', 'nexerelin-addon', 'better-nexerelin-ships']);
    expect(mods['total'], 3);

    final start = (await search('nexer'))['mods'] as Map<String, dynamic>;
    expect(ids(start), ['nexerelin', 'nexerelin-addon', 'better-nexerelin-ships']);
  });

  test('a topic whose mod starts with the text comes before a title that only contains it', () async {
    // Forum titles start with the game version, so "Nexerelin" is in the
    // middle of topic 9000's title, but it is the name of the mod it became.
    final topics = (await search('nexer'))['topics'] as Map<String, dynamic>;
    expect(ids(topics), ['9000', '181', '180']);
    expect((topics['items'] as List).first.containsKey('detail'), isFalse, reason: 'the title shows why');
    expect((topics['items'] as List).last['detail'], 'mod: Better Nexerelin Ships');
  });

  test('a nickname finds the mod, with a note saying so', () async {
    final mods = (await search('IndEvo'))['mods'] as Map<String, dynamic>;
    expect(mods['items'], [
      {
        'id': 'industrial-evolution',
        'name': 'Industrial.Evolution',
        'authors': ['SirHartley'],
        'detail': 'also called IndEvo',
      },
    ]);
  });

  test('an author finds their mods, after any mod named like the text', () async {
    final body = await search('Histidine');
    final mods = body['mods'] as Map<String, dynamic>;
    // Both match by author, so they are in name order.
    expect(ids(mods), ['nexerelin', 'histidines-tweaks']);
    expect((mods['items'] as List).first['detail'], 'author: Histidine');
    expect((mods['items'] as List).last['detail'], 'author: Histidine');
    expect(ids(body['topics'] as Map<String, dynamic>), ['9000']);
    expect(ids(body['discord'] as Map<String, dynamic>), [thread]);
  });

  test('no note when the shown name already holds the text', () async {
    final mods = (await search('nex'))['mods'] as Map<String, dynamic>;
    // Nexerelin is exactly its nickname "Nex", and its name shows why.
    expect(ids(mods).first, 'nexerelin');
    expect((mods['items'] as List).first.containsKey('detail'), isFalse);
  });

  test('a post found by the mod it became says so', () async {
    final topics = (await search('Industrial'))['topics'] as Map<String, dynamic>;
    expect(ids(topics), ['18011']);
    final byMod = (await search('Better Nexerelin'))['topics'] as Map<String, dynamic>;
    expect((byMod['items'] as List).single, {
      'id': '180',
      'title': 'An old thread',
      'author': 'Someone',
      'detail': 'mod: Better Nexerelin Ships',
    });
  });

  test('an exact permanent id comes first', () async {
    final mods = (await search('nexerelin-addon'))['mods'] as Map<String, dynamic>;
    expect(ids(mods).first, 'nexerelin-addon');
    expect((mods['items'] as List).first.containsKey('detail'), isFalse);
  });

  test('a topic id puts that topic first, before topics whose id holds it', () async {
    final topics = (await search('180'))['topics'] as Map<String, dynamic>;
    expect(ids(topics), ['180', '18011']);
    expect((topics['items'] as List).last['detail'], 'id: 18011');
  });

  test('a forum or Discord address is searched as the post\'s id', () async {
    final forum = await search('https://fractalsoftworks.com/forum/index.php?topic=18011.0');
    expect(forum['q'], '18011');
    expect(ids(forum['topics'] as Map<String, dynamic>), ['18011']);

    final discord = await search('https://discord.com/channels/187635036525166592/$thread');
    expect(discord['q'], thread);
    expect(ids(discord['discord'] as Map<String, dynamic>), [thread]);
  });

  test('each total is what the full list shows for the same text', () async {
    final handler = handlerWith();
    for (final q in ['nex', 'histidine', 'evolution', '180', 'zzz']) {
      final body = await get(handler, 'search?q=$q');
      final modList = await get(handler, 'mods?pageSize=0&q=$q');
      final topicList = await get(handler, 'posts?pageSize=0&kind=topic&q=$q');
      final threadList = await get(handler, 'posts?pageSize=0&kind=discord&q=$q');
      expect((body['mods'] as Map)['total'], modList['total'], reason: 'mods for "$q"');
      expect((body['topics'] as Map)['total'], topicList['total'], reason: 'topics for "$q"');
      expect((body['discord'] as Map)['total'], threadList['total'], reason: 'threads for "$q"');
    }
  });

  test('limit caps the rows of each kind but not the totals', () async {
    final body = await search('e', extra: '&limit=1');
    expect(body['mods'], {'total': 0, 'items': []}, reason: 'one letter finds nothing');

    final limited = await search('nexerelin', extra: '&limit=1');
    expect(ids(limited['mods'] as Map<String, dynamic>), ['nexerelin']);
    expect((limited['mods'] as Map)['total'], 3);
  });

  test('text shorter than two characters gives empty groups', () async {
    for (final q in ['', ' ', 'n', ' n ']) {
      final body = await search(q, history: runs);
      for (final kind in ['mods', 'topics', 'discord', 'runs']) {
        expect(body[kind], {'total': 0, 'items': []}, reason: '$kind for "$q"');
      }
    }
  });

  test('no matches gives empty groups', () async {
    final body = await search('nothing like this', history: runs);
    for (final kind in ['mods', 'topics', 'discord', 'runs']) {
      expect(body[kind], {'total': 0, 'items': []});
    }
  });

  test('runs are found by id or kind, the exact id first, then newest first', () async {
    final body = await search('fetchAndUpdate', history: runs);
    expect(body['runs'], {
      'total': 2,
      'items': [
        {
          'id': '20261105T230000Z-fetchAndUpdate',
          'kind': 'fetchAndUpdate',
          'state': 'completed',
          'startedAt': '2026-11-05T23:00:00.000Z',
        },
        {
          'id': '20261103T120000Z-fetchAndUpdate',
          'kind': 'fetchAndUpdate',
          'state': 'completed',
          'startedAt': '2026-11-05T23:00:00.000Z',
        },
      ],
    });

    final exact = await search('20261103T120000Z-fetchAndUpdate', history: runs);
    expect(ids(exact['runs'] as Map<String, dynamic>), ['20261103T120000Z-fetchAndUpdate']);

    final day = await search('2026110', history: runs);
    expect(ids(day['runs'] as Map<String, dynamic>), [
      '20261105T230000Z-fetchAndUpdate',
      '20261104T120000Z-rebuildFromSaved',
      '20261103T120000Z-fetchAndUpdate',
    ]);
  });

  test('with the manager off, the runs group is empty and the others still answer', () async {
    final body = await search('fetchAndUpdate');
    expect(body['runs'], {'total': 0, 'items': []});
    final mods = await search('nexer');
    expect((mods['mods'] as Map)['total'], 3);
  });

  test('a taken-down mod says so', () async {
    writeJson(p.join(dataDir, 'takedowns.json'), {
      'mods': [
        {'id': 'gone-nexerelin', 'name': 'Gone Nexerelin', 'posts': [], 'on': '2026-10-01'},
      ],
      'authors': [],
    });
    final mods = (await search('gone'))['mods'] as Map<String, dynamic>;
    expect(mods['items'], [
      {'id': 'gone-nexerelin', 'name': 'Gone Nexerelin', 'authors': [], 'takenDown': true},
    ]);
  });

  test('with no catalog or saved posts, every group is empty', () async {
    Directory(outputsDir).deleteSync(recursive: true);
    Directory(dataDir).deleteSync(recursive: true);
    final body = await search('nexerelin');
    for (final kind in ['mods', 'topics', 'discord', 'runs']) {
      expect(body[kind], {'total': 0, 'items': []});
    }
  });

  test('only reads', () async {
    List<String> files() => [
          for (final f in tmp.listSync(recursive: true))
            if (f is File) '${f.path} ${f.lengthSync()} ${f.lastModifiedSync().millisecondsSinceEpoch}',
        ]..sort();
    final before = files();
    await search('nexerelin', history: runs);
    await search('https://fractalsoftworks.com/forum/index.php?topic=18011.0', history: runs);
    expect(files(), before);
  });
}
