import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/bot/scraper/qb/llm/extraction_store.dart';
import 'package:mod_repo_scraper/viewer/api.dart';
import 'package:mod_repo_scraper/viewer/data_access.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// `GET /api/attention`: the counts behind the Needs attention panel, each
/// read from a saved file, and left out when its file is missing.
void main() {
  late Directory tmp;
  late String dataDir;
  late String outputsDir;
  late Handler handler;

  void writeJson(String path, Object value) {
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(value));
  }

  Map<String, dynamic> llmAnswer() => {
        'fingerprint': 'f',
        'schemaVersion': LlmExtractionStore.schemaVersion,
        'promptVersion': 1,
        'isMod': true,
        'mods': [],
      };

  void topic(int id, {bool placeholder = false, bool saved = true}) {
    if (!saved) return;
    writeJson(p.join(dataDir, 'mods', '$id', 'detail.json'), {
      'topicId': id,
      'title': 'Topic $id',
      if (placeholder) 'isPlaceholderDetail': true,
    });
  }

  Map<String, dynamic> discordThread(String id) => {
        'threadId': id,
        'name': 'Thread $id',
        'author': 'Someone',
        'url': 'https://discord.com/channels/1/$id/$id',
        'messages': [
          {'id': id, 'content': 'A mod.'},
        ],
      };

  Map<String, dynamic> catalogMod(String id, String name, List<String> authors, List<Map<String, String>> posts) =>
      {'id': id, 'name': name, 'authorsList': authors, 'sourcePosts': posts};

  /// Every file present and nothing that needs attention.
  void writeAllFine() {
    writeJson(p.join(dataDir, 'mods-index.json'), [
      {'topicId': 1, 'title': 'Topic 1', 'author': 'Alice'},
    ]);
    topic(1);
    writeJson(p.join(dataDir, 'llm-extraction-cache.json'), {'1': llmAnswer(), 'discord:900': llmAnswer()});
    writeJson(p.join(dataDir, 'discord-posts.json'), {'900': discordThread('900')});
    writeJson(p.join(dataDir, 'requirement-names-report.json'), {
      'names': [
        {'key': 'lazylib', 'written': 'LazyLib', 'count': 3, 'id': 'lazylib', 'name': 'LazyLib', 'by': 'rule'},
      ],
      'mods': [],
    });
    writeJson(p.join(outputsDir, 'mod-catalog.json'), {
      'items': [
        catalogMod('topic-1', 'Topic 1', ['Alice'], [
          {'kind': 'forum', 'id': '1'},
          {'kind': 'discord', 'id': '900'},
        ]),
      ],
      'collections': [],
      'lastUpdated': '2026-10-22T00:00:00Z',
    });
    writeJson(p.join(tmp.path, 'discord_cache.json'), {
      'items': [
        {
          'urls': {'Discord': 'https://discord.com/channels/1/900/900'},
          'authorsList': ['alice'],
        },
      ],
    });
    writeJson(p.join(dataDir, 'takedowns.json'), {
      'mods': [
        {'id': 'gone-mod', 'name': 'Gone Mod', 'posts': ['forum:7'], 'on': '2026-10-01'},
      ],
      'authors': [],
    });
    writeJson(p.join(dataDir, 'takedown-matches.json'), {
      'builtAt': '2026-10-22T00:00:00Z',
      'matches': [
        {
          'entry': 'gone-mod',
          'mods': [
            {'id': 'gone-mod', 'name': 'Gone Mod'},
          ],
          'collections': [],
          'blockedPosts': ['forum:7'],
        },
      ],
      'removedPosts': ['forum:7'],
    });
    writeJson(p.join(outputsDir, 'site', 'mods.json'), {
      'generatedAt': '2026-10-22T00:00:00Z',
      'mods': [
        {
          'id': 'topic-1',
          'name': 'Topic 1',
          'bestDownload': {'url': 'https://example.com/a.zip'},
        },
      ],
    });
  }

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('viewer_attention');
    dataDir = p.join(tmp.path, 'qb_data');
    outputsDir = p.join(tmp.path, 'outputs');
    Directory(dataDir).createSync(recursive: true);
    Directory(outputsDir).createSync(recursive: true);
    handler = ViewerApi(DataAccess(dataDir: dataDir, outputsDir: outputsDir, rootDir: tmp.path)).router;
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Future<Map<String, dynamic>> attention() async {
    final res = await handler(Request('GET', Uri.parse('http://localhost/attention')));
    expect(res.statusCode, 200);
    return jsonDecode(await res.readAsString()) as Map<String, dynamic>;
  }

  List<String> filesIn(String path) =>
      [for (final f in Directory(path).listSync(recursive: true)) p.relative(f.path, from: path)]..sort();

  test('everything fine: every count is there and 0, and nothing is written', () async {
    writeAllFine();
    final before = filesIn(tmp.path);

    expect(await attention(), {
      'unmatchedDependencyNames': 0,
      'authorPairsToDecide': 0,
      'takedownsExcludedNothing': 0,
      'takedownsReturned': 0,
      'postsWithoutLlmAnswer': 0,
      'modsWithoutDownload': 0,
    });
    expect(filesIn(tmp.path), before);
  });

  test('no files at all: no counts', () async {
    expect(await attention(), isEmpty);
  });

  test('a missing file leaves only its own count out', () async {
    writeAllFine();
    File(p.join(dataDir, 'requirement-names-report.json')).deleteSync();
    File(p.join(outputsDir, 'site', 'mods.json')).deleteSync();

    final body = await attention();
    expect(body.keys, isNot(contains('unmatchedDependencyNames')));
    expect(body.keys, isNot(contains('modsWithoutDownload')));
    expect(body['postsWithoutLlmAnswer'], 0);
    expect(body['authorPairsToDecide'], 0);
  });

  test('a file that cannot be read leaves its count out too', () async {
    writeAllFine();
    File(p.join(dataDir, 'requirement-names-report.json')).writeAsStringSync('{not json');

    final body = await attention();
    expect(body.keys, isNot(contains('unmatchedDependencyNames')));
    expect(body['modsWithoutDownload'], 0);
  });

  test('dependency names that matched no mod', () async {
    writeAllFine();
    writeJson(p.join(dataDir, 'requirement-names-report.json'), {
      'names': [
        {'key': 'lazylib', 'written': 'LazyLib', 'count': 3, 'id': 'lazylib', 'by': 'rule'},
        {'key': 'nex', 'written': 'Nex', 'count': 2, 'by': 'unmatched'},
        {'key': 'graphiclib', 'written': 'GraphicLib', 'count': 1, 'by': 'unmatched'},
        {'key': 'none', 'written': 'Something Else', 'count': 1, 'by': 'hand'},
      ],
    });
    expect((await attention())['unmatchedDependencyNames'], 2);
  });

  test('author pairs to decide, leaving out pairs marked as different people', () async {
    writeAllFine();
    writeJson(p.join(tmp.path, 'discord_cache.json'), {
      'items': [
        {
          'urls': {'Discord': 'https://discord.com/channels/1/900/900'},
          'authorsList': ['bob_on_discord', 'carol'],
        },
      ],
    });
    expect((await attention())['authorPairsToDecide'], 2);

    writeJson(p.join(dataDir, 'author-aliases.json'), {
      'people': [],
      'notSame': [
        ['Alice', 'carol'],
      ],
    });
    expect((await attention())['authorPairsToDecide'], 1);
  });

  test('takedowns that left out nothing, and mods that came back under a new id', () async {
    writeAllFine();
    writeJson(p.join(dataDir, 'takedowns.json'), {
      'mods': [
        {'id': 'gone-mod', 'name': 'Gone Mod', 'posts': ['forum:7'], 'on': '2026-10-01'},
        // Its post is gone: it left out nothing.
        {'id': 'post-gone', 'name': 'Post Gone', 'posts': ['forum:8'], 'on': '2026-10-01'},
        // Its post is still in the catalog under another mod: it came back.
        {'id': 'old-id', 'name': 'Topic One', 'posts': ['forum:1#Topic One'], 'on': '2026-10-01'},
        // Not in the last build yet, so it is not counted.
        {'id': 'just-added', 'name': 'Just Added', 'posts': ['forum:9'], 'on': '2026-10-23'},
      ],
      'authors': [
        {
          'names': ['Nobody'],
          'on': '2026-10-01',
        },
      ],
    });
    Map<String, dynamic> nothing(String entry) =>
        {'entry': entry, 'mods': [], 'collections': [], 'blockedPosts': []};
    writeJson(p.join(dataDir, 'takedown-matches.json'), {
      'builtAt': '2026-10-22T00:00:00Z',
      'matches': [
        {
          'entry': 'gone-mod',
          'mods': [
            {'id': 'gone-mod', 'name': 'Gone Mod'},
          ],
          'collections': [],
          'blockedPosts': ['forum:7'],
        },
        nothing('post-gone'),
        nothing('old-id'),
        nothing('author:Nobody'),
        // An entry since restored is not on the list, so it is not counted.
        nothing('restored'),
      ],
    });

    final body = await attention();
    expect(body['takedownsExcludedNothing'], 2);
    expect(body['takedownsReturned'], 1);
  });

  test('without the catalog, every takedown that left out nothing counts as excluding nothing', () async {
    writeAllFine();
    File(p.join(outputsDir, 'mod-catalog.json')).deleteSync();
    writeJson(p.join(dataDir, 'takedown-matches.json'), {
      'matches': [
        {'entry': 'gone-mod', 'mods': [], 'collections': [], 'blockedPosts': []},
      ],
    });

    final body = await attention();
    expect(body['takedownsExcludedNothing'], 1);
    expect(body.keys, isNot(contains('takedownsReturned')));
    expect(body.keys, isNot(contains('authorPairsToDecide')));
  });

  test('posts with no LLM answer: saved topics that are not placeholders, and Discord threads', () async {
    writeAllFine();
    writeJson(p.join(dataDir, 'mods-index.json'), [
      for (final id in [1, 2, 3, 4]) {'topicId': id, 'title': 'Topic $id', 'author': 'Alice'},
    ]);
    topic(2); // no answer: counts
    topic(3, placeholder: true); // a placeholder is never read
    topic(4, saved: false); // no saved post is never read
    writeJson(p.join(dataDir, 'discord-posts.json'), {'900': discordThread('900'), '901': discordThread('901')});

    expect((await attention())['postsWithoutLlmAnswer'], 2);
  });

  test('mods on the website with no download', () async {
    writeAllFine();
    writeJson(p.join(outputsDir, 'site', 'mods.json'), {
      'generatedAt': '2026-10-22T00:00:00Z',
      'mods': [
        {'id': 'a', 'name': 'A', 'bestDownload': {'url': 'https://example.com/a.zip'}},
        {'id': 'b', 'name': 'B'},
        {'id': 'c', 'name': 'C', 'forumUrl': 'https://fractalsoftworks.com/forum/index.php?topic=3'},
      ],
    });
    expect((await attention())['modsWithoutDownload'], 2);
  });
}
