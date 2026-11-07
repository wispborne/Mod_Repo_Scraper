import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/bot/scraper/qb/llm/extraction_store.dart';
import 'package:mod_repo_scraper/viewer/api.dart';
import 'package:mod_repo_scraper/viewer/data_access.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// `GET /api/posts` and `GET /api/posts/outcome`: forum topics and Discord
/// threads in one list, and what the last build made of each.
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

  Map<String, dynamic> llmAnswer({List<String> downloads = const []}) => {
        'fingerprint': 'f',
        'schemaVersion': LlmExtractionStore.schemaVersion,
        'promptVersion': 1,
        'isMod': true,
        'mods': [
          {
            'name': 'Some Mod',
            'downloads': [for (final url in downloads) {'url': url, 'confidence': 'high'}],
          },
        ],
      };

  Map<String, dynamic> summary(int id, String title, {String scrapedAt = '2026-10-01T00:00:00Z'}) => {
        'topicId': id,
        'title': title,
        'author': 'Author $id',
        'lastPostDate': 'October 0$id, 2026, 10:00:00 AM',
        'scrapedAt': scrapedAt,
      };

  void detail(int id, {bool placeholder = false}) => writeJson(p.join(dataDir, 'mods', '$id', 'detail.json'), {
        'topicId': id,
        'title': 'Topic $id',
        if (placeholder) 'isPlaceholderDetail': true,
      });

  Map<String, dynamic> thread(String id, String name) => {
        'threadId': id,
        'name': name,
        'author': 'someone',
        'url': 'https://discord.com/channels/1/$id/$id',
        'messages': [
          {'id': id, 'content': 'A mod.', 'timestamp': '2026-09-15T12:00:00.000Z'},
        ],
      };

  Map<String, dynamic> catalogMod(String id, String name, List<Map<String, String>> posts) =>
      {'id': id, 'name': name, 'authorsList': ['Someone'], 'sourcePosts': posts};

  void writeLeftOut({String at = builtAt}) => writeJson(p.join(dataDir, 'catalog-left-out.json'), {
        'builtAt': at,
        'topics': {'3': 'notModNoDownload'},
        'pointers': {'forum:5#Alpha': 'forum:1'},
      });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('viewer_posts');
    dataDir = p.join(tmp.path, 'qb_data');
    outputsDir = p.join(tmp.path, 'outputs');

    // 1 became two mods, 2 is a Collection, 3 was left out, 4 was taken down,
    // 5 only points to topic 1, 6 is a placeholder scraped after the build.
    writeJson(p.join(dataDir, 'mods-index.json'), [
      summary(1, 'Two Mods Thread'),
      summary(2, 'A Collection'),
      summary(3, 'A Question'),
      summary(4, 'Gone'),
      summary(5, 'A List Of Links'),
      summary(6, 'Placeholder', scrapedAt: '2026-11-01T00:00:00Z'),
    ]);
    for (final id in [1, 2, 3, 4, 5]) {
      detail(id);
    }
    detail(6, placeholder: true);
    writeJson(p.join(dataDir, 'llm-extraction-cache.json'), {
      '1': llmAnswer(downloads: ['https://example.com/a.zip']),
      'discord:900': llmAnswer(downloads: ['https://example.com/e.zip']),
    });
    writeJson(p.join(dataDir, 'assumed-downloads-cache.json'), {
      '1': {
        'candidates': [
          {'sourceUrl': 'http://example.com/a.zip/', 'resolvedUrl': 'http://example.com/a.zip', 'confidence': 'high'},
        ],
      },
      '2': {
        'candidates': [
          {'sourceUrl': 'https://example.com/c.zip', 'resolvedUrl': 'https://example.com/c.zip', 'confidence': 'high'},
        ],
      },
    });
    writeJson(p.join(dataDir, 'discord-posts.json'), {
      '900': thread('900', 'Echo Mod 1.0'),
      '901': thread('901', 'Brand New Thread'),
    });
    writeJson(p.join(outputsDir, 'mod-catalog.json'), {
      'items': [
        catalogMod('alpha', 'Alpha', [
          {'kind': 'forum', 'id': '1', 'llmModName': 'Alpha'},
        ]),
        catalogMod('beta', 'Beta', [
          {'kind': 'forum', 'id': '1', 'llmModName': 'Beta'},
        ]),
        catalogMod('charlie', 'Charlie', [
          {'kind': 'forum', 'id': '2', 'llmModName': 'Charlie'},
        ]),
        catalogMod('delta', 'Delta', [
          {'kind': 'forum', 'id': '2', 'llmModName': 'Delta'},
        ]),
        catalogMod('echo', 'Echo', [
          {'kind': 'discord', 'id': '900'},
        ]),
      ],
      'collections': [
        {
          'id': 'a-collection',
          'name': 'A Collection',
          'sourcePost': {'kind': 'forum', 'id': '2'},
          'modIds': ['charlie', 'delta'],
        },
      ],
      'lastUpdated': builtAt,
    });
    writeJson(p.join(dataDir, 'takedown-matches.json'), {
      'builtAt': builtAt,
      'matches': [],
      'removedPosts': ['forum:4'],
    });
    writeLeftOut();

    handler = ViewerApi(DataAccess(dataDir: dataDir, outputsDir: outputsDir, rootDir: tmp.path)).router;
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Future<(int, Map<String, dynamic>)> get(String path) async {
    final res = await handler(Request('GET', Uri.parse('http://localhost/$path')));
    return (res.statusCode, jsonDecode(await res.readAsString()) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> posts([String query = '']) async {
    final (status, body) = await get('posts?pageSize=0&$query');
    expect(status, 200);
    return body;
  }

  List<String> keys(Map<String, dynamic> body) =>
      [for (final row in body['items'] as List) '${row['kind']}:${row['id']}'];

  Future<Map<String, dynamic>> outcome(String kind, String id) async {
    final (status, body) = await get('posts/outcome?kind=$kind&id=$id');
    expect(status, 200);
    return body;
  }

  group('GET /api/posts', () {
    test('lists forum topics and Discord threads together', () async {
      final body = await posts();
      expect(body['total'], 8);
      expect(keys(body).toSet(), {
        for (final id in [1, 2, 3, 4, 5, 6]) 'topic:$id',
        'discord:900',
        'discord:901',
      });
    });

    test('each row carries what the list shows', () async {
      final rows = {for (final row in (await posts())['items'] as List) '${row['kind']}:${row['id']}': row};
      expect(rows['topic:1'], {
        'kind': 'topic',
        'id': '1',
        'title': 'Two Mods Thread',
        'author': 'Author 1',
        'lastPostDate': '2026-10-01T10:00:00.000',
        // The rules and the LLM found the same file.
        'downloads': 1,
        'downloadCounts': {'rules': 1, 'llm': 1},
        'hasLlmAnswer': true,
        'isPlaceholder': false,
        'outcome': 'mods',
        'line': '2 mods: Alpha and Beta.',
        'modCount': 2,
      });
      expect(rows['discord:900']!['title'], 'Echo Mod 1.0');
      expect(rows['discord:900']!['lastPostDate'], '2026-09-15T12:00:00.000Z');
      expect(rows['discord:900']!['downloads'], 1);
      expect(rows['topic:6']!['isPlaceholder'], true);
    });

    test('the counts are over every post, whatever the filter', () async {
      final all = await posts();
      final filtered = await posts('filters=noDownload&kind=discord&q=zzz');
      expect(filtered['counts'], all['counts']);
      expect(all['counts'], {
        // 3, 4, 5, 6 and thread 901.
        'noDownload': 5,
        // Placeholder 6 is never sent to the LLM, so it is not counted.
        'noLlmAnswer': 5,
        'placeholder': 1,
      });
    });

    test('each filter narrows the list', () async {
      expect(keys(await posts('filters=noDownload')).toSet(),
          {'topic:3', 'topic:4', 'topic:5', 'topic:6', 'discord:901'});
      expect(keys(await posts('filters=noLlmAnswer')).toSet(),
          {'topic:2', 'topic:3', 'topic:4', 'topic:5', 'discord:901'});
      expect(keys(await posts('filters=placeholder')), ['topic:6']);
      expect(keys(await posts('filters=leftOut')), ['topic:3']);
      expect(keys(await posts('filters=takenDown')), ['topic:4']);
      expect(keys(await posts('filters=collection')), ['topic:2']);
      expect(keys(await posts('filters=noDownload,leftOut')), ['topic:3']);
    });

    test('kind, search and sort', () async {
      expect(keys(await posts('kind=discord')).toSet(), {'discord:900', 'discord:901'});
      expect(keys(await posts('kind=topic')).length, 6);
      // A post is found by the names of the mods it became.
      expect(keys(await posts('q=beta')), ['topic:1']);
      expect(keys(await posts('q=author 3')), ['topic:3']);
      expect(keys(await posts('q=901')), ['discord:901']);
      expect(keys(await posts('sort=mods')).take(2).toSet(), {'topic:1', 'topic:2'});
      expect(keys(await posts('sort=title&dir=asc')).first, 'topic:2');
      // Newest last post first by default.
      expect(keys(await posts()).first, 'topic:6');
    });

    test('pages like the other lists', () async {
      final (_, body) = await get('posts?pageSize=3&page=1');
      expect(body['total'], 8);
      expect(body['page'], 1);
      expect(body['pageSize'], 3);
      expect((body['items'] as List).length, 3);
    });

    test("the forum's 'Today at' is read against the day the topic was scraped", () async {
      writeJson(p.join(dataDir, 'mods-index.json'), [
        {...summary(1, 'Late'), 'lastPostDate': 'Today at 10:05:53 PM', 'scrapedAt': '2026-11-05T07:39:14Z'},
        {...summary(2, 'Early'), 'lastPostDate': 'Today at 01:00:00 AM', 'scrapedAt': '2026-11-05T07:39:14Z'},
        {...summary(3, 'Before'), 'lastPostDate': 'Yesterday at 09:00:00 AM', 'scrapedAt': '2026-11-05T07:39:14Z'},
      ]);
      final dates = {
        for (final row in (await posts('kind=topic'))['items'] as List) row['id']: row['lastPostDate'],
      };
      // The forum's clock is behind UTC, so 10 PM "today" was the day before,
      // and so was 9 AM "today"; 9 AM "yesterday" is the day before that.
      expect(dates, {'1': '2026-11-04T22:05:53.000', '2': '2026-11-05T01:00:00.000', '3': '2026-11-03T09:00:00.000'});
    });

    test("'Yesterday at' is always one day before 'Today at' the same time", () async {
      const scrapedAt = '2026-11-05T03:00:00Z';
      writeJson(p.join(dataDir, 'mods-index.json'), [
        {...summary(1, 'Today late'), 'lastPostDate': 'Today at 08:00:00 PM', 'scrapedAt': scrapedAt},
        {...summary(2, 'Yesterday late'), 'lastPostDate': 'Yesterday at 08:00:00 PM', 'scrapedAt': scrapedAt},
        {...summary(3, 'Today early'), 'lastPostDate': 'Today at 02:00:00 AM', 'scrapedAt': scrapedAt},
        {...summary(4, 'Yesterday early'), 'lastPostDate': 'Yesterday at 02:00:00 AM', 'scrapedAt': scrapedAt},
      ]);
      final body = await posts('kind=topic');
      final dates = {for (final row in body['items'] as List) row['id']: row['lastPostDate']};
      // At 03:00 UTC, 8 PM "today" on the forum was on 4 November, so 8 PM
      // "yesterday" was on 3 November, not on the same day as "today".
      expect(dates, {
        '1': '2026-11-04T20:00:00.000',
        '2': '2026-11-03T20:00:00.000',
        '3': '2026-11-05T02:00:00.000',
        '4': '2026-11-04T02:00:00.000',
      });
      expect(keys(body), ['topic:3', 'topic:1', 'topic:4', 'topic:2']);
    });

    test('forum and Discord times sort the same way in every time zone', () async {
      // The forum's clock has no time zone; it is compared as if it were UTC,
      // like the Discord times. Read as the computer's own time instead, the
      // forum topic would move above or below both threads with the zone.
      writeJson(p.join(dataDir, 'mods-index.json'), [
        {...summary(1, 'Forum'), 'lastPostDate': 'October 01, 2026, 10:00:00 AM'},
      ]);
      Map<String, dynamic> at(String id, String time) => {
            ...thread(id, 'Thread $id'),
            'messages': [
              {'id': id, 'content': 'A mod.', 'timestamp': time},
            ],
          };
      writeJson(p.join(dataDir, 'discord-posts.json'), {
        '900': at('900', '2026-10-01T09:30:00.000Z'),
        '901': at('901', '2026-10-01T10:30:00.000Z'),
      });
      writeJson(p.join(dataDir, 'llm-extraction-cache.json'), {});
      expect(keys(await posts()), ['discord:901', 'topic:1', 'discord:900']);
      expect(keys(await posts('dir=asc')), ['discord:900', 'topic:1', 'discord:901']);
    });

    test('with no saved posts at all, says which file is missing', () async {
      File(p.join(dataDir, 'mods-index.json')).deleteSync();
      File(p.join(dataDir, 'discord-posts.json')).deleteSync();
      final (_, body) = await get('posts');
      expect(body['missing'], true);
    });
  });

  group('GET /api/posts/outcome', () {
    test('a post that became several mods', () async {
      expect(await outcome('topic', '1'), {
        'kind': 'topic',
        'id': '1',
        'outcome': 'mods',
        'line': '2 mods: Alpha and Beta.',
        'mods': [
          {'id': 'alpha', 'name': 'Alpha'},
          {'id': 'beta', 'name': 'Beta'},
        ],
        'builtAt': builtAt,
      });
      expect((await outcome('discord', '900'))['line'], '1 mod: Echo.');
    });

    test('a Collection', () async {
      final body = await outcome('topic', '2');
      expect(body['outcome'], 'collection');
      expect(body['line'], 'Collection: 2 mods.');
      expect(body['collection'], {'id': 'a-collection', 'name': 'A Collection'});
      expect(body['mods'], hasLength(2));
    });

    test('left out, with the reason the build saved', () async {
      final body = await outcome('topic', '3');
      expect(body['outcome'], 'leftOut');
      expect(body['line'], 'Not in catalog.');
      expect(body['reason'], 'Marked as not a mod. No download found.');
    });

    test('taken down', () async {
      final body = await outcome('topic', '4');
      expect(body['outcome'], 'takenDown');
      expect(body['line'], 'Taken down.');
    });

    test('a post whose mod only points to a topic of its own', () async {
      final body = await outcome('topic', '5');
      expect(body['outcome'], 'pointsTo');
      expect(body['line'], 'See topic 1 for Alpha.');
      expect(body['pointsTo'], {'kind': 'topic', 'id': '1', 'modId': 'alpha', 'modName': 'Alpha'});
      expect(body['pointsToAll'], [
        {'kind': 'topic', 'id': '1', 'modId': 'alpha', 'modName': 'Alpha'},
      ]);
    });

    test('a post that points to several topics lists each of them', () async {
      writeJson(p.join(dataDir, 'catalog-left-out.json'), {
        'builtAt': builtAt,
        'topics': {'3': 'notModNoDownload'},
        'pointers': {'forum:5#Alpha': 'forum:1', 'forum:5#Echo': 'forum:7', 'forum:5#Beta': 'forum:1'},
      });
      final body = await outcome('topic', '5');
      expect(body['outcome'], 'pointsTo');
      expect(body['line'], 'See 2 other topics.');
      expect(body['pointsToAll'], [
        {'kind': 'topic', 'id': '1', 'modId': 'alpha', 'modName': 'Alpha'},
        {'kind': 'topic', 'id': '7'},
        {'kind': 'topic', 'id': '1', 'modId': 'beta', 'modName': 'Beta'},
      ]);
    });

    test('a post the last build never saw', () async {
      for (final (kind, id) in [('topic', '6'), ('topic', '99999'), ('discord', '901')]) {
        final body = await outcome(kind, id);
        expect(body['outcome'], 'notInBuild', reason: '$kind $id');
        expect(body['line'], 'Not in last build.');
        expect(body['mods'], isEmpty);
      }
    });

    test('reasons saved by another build are not used', () async {
      writeLeftOut(at: '2026-10-01T00:00:00.000Z');
      final body = await outcome('topic', '3');
      expect(body['outcome'], 'leftOut');
      expect(body['line'], 'Not in catalog.');
      expect(body.containsKey('reason'), isFalse);
      // Scraped after the build, so the build cannot have seen it.
      expect((await outcome('topic', '6'))['outcome'], 'notInBuild');
    });

    test('with no catalog, nothing is in a build', () async {
      File(p.join(outputsDir, 'mod-catalog.json')).deleteSync();
      final body = await outcome('topic', '1');
      expect(body['outcome'], 'notInBuild');
      expect(body['line'], 'No catalog built yet.');
    });

    test('a kind it does not know, or no id, is refused', () async {
      expect((await get('posts/outcome?kind=nexus&id=1')).$1, 400);
      expect((await get('posts/outcome?kind=topic')).$1, 400);
    });

    test('a new build is read without restarting', () async {
      expect((await outcome('topic', '3'))['outcome'], 'leftOut');
      final catalog = File(p.join(outputsDir, 'mod-catalog.json'));
      final map = jsonDecode(catalog.readAsStringSync()) as Map<String, dynamic>;
      (map['items'] as List).add(catalogMod('question', 'Question Mod', [
        {'kind': 'forum', 'id': '3'},
      ]));
      catalog.writeAsStringSync(jsonEncode(map));
      catalog.setLastModifiedSync(DateTime.now().add(const Duration(seconds: 5)));
      expect((await outcome('topic', '3'))['line'], '1 mod: Question Mod.');
    });
  });

  test('both routes only read', () async {
    List<String> files() =>
        [for (final f in tmp.listSync(recursive: true)) '${f.path}:${f is File ? f.lengthSync() : 0}']..sort();
    final before = files();
    await posts();
    await outcome('topic', '1');
    expect(files(), before);
  });
}
