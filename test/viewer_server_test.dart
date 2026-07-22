import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/viewer/api.dart';
import 'package:mod_repo_scraper/viewer/data_access.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Drives the viewer API handlers against on-disk fixtures, so the tests cover
/// the real join, filter predicates (D6), allowlist (D7), and mtime cache (D4).
void main() {
  late Directory tmp;
  late String dataDir;
  late String outputsDir;
  late ViewerApi api;
  late Handler handler;

  // Calls a GET endpoint and returns the decoded JSON body.
  Future<Map<String, dynamic>> get(String path) async {
    final res =
        await handler(Request('GET', Uri.parse('http://localhost/$path')));
    return jsonDecode(await res.readAsString()) as Map<String, dynamic>;
  }

  Future<int> status(String path) async {
    final res =
        await handler(Request('GET', Uri.parse('http://localhost/$path')));
    return res.statusCode;
  }

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('viewer_test_');
    dataDir = '${tmp.path}/new_data';
    outputsDir = '${tmp.path}/outputs';
    Directory(dataDir).createSync(recursive: true);
    Directory(outputsDir).createSync(recursive: true);

    _writeIndex(dataDir);
    _writeLlmCache(dataDir);
    _writeAssumedCache(dataDir);
    _writePlaceholderDetail(dataDir);
    _writeBundle(outputsDir);

    final data = DataAccess(
      dataDir: dataDir,
      outputsDir: outputsDir,
      rootDir: tmp.path,
    );
    api = ViewerApi(data);
    handler = api.router;
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('topic list joins index + caches + placeholder set', () async {
    final body = await get('topics?pageSize=100');
    expect(body['total'], 5);
    final byId = {
      for (final row in body['items'] as List) row['topicId'] as int: row,
    };
    expect(byId.keys, containsAll([100, 200, 300, 400, 500]));
    // Download counts come through the join.
    expect((byId[100]!['downloadCounts'] as Map)['rules'], 1);
    expect((byId[300]!['downloadCounts'] as Map)['llmMissed'], 1);
    expect((byId[300]!['downloadCounts'] as Map)['mods'], 2);
  });

  group('D6 filter predicates', () {
    Future<Set<int>> idsFor(String filter) async {
      final body = await get('topics?pageSize=100&filters=$filter');
      return {
        for (final row in body['items'] as List) row['topicId'] as int,
      };
    }

    test('noDownload', () async {
      // 200 has no caches at all; 500 has neither an assumed nor an LLM entry.
      expect(await idsFor('noDownload'), {200, 500});
    });
    test('lowConfidenceOnly', () async {
      expect(await idsFor('lowConfidenceOnly'), {400});
    });
    test('llmOnlyDownloads', () async {
      expect(await idsFor('llmOnlyDownloads'), {300});
    });
    test('multiMod', () async {
      expect(await idsFor('multiMod'), {300});
    });
    test('placeholderDetail', () async {
      expect(await idsFor('placeholderDetail'), {500});
    });
    test('missingGameVersion', () async {
      expect(await idsFor('missingGameVersion'), {500});
    });
    test('wip', () async {
      expect(await idsFor('wip'), {100});
    });
    test('noLlmExtraction', () async {
      expect(await idsFor('noLlmExtraction'), {200, 500});
    });
    test('multiple filters are ANDed', () async {
      final body =
          await get('topics?pageSize=100&filters=missingGameVersion,placeholderDetail');
      expect((body['items'] as List).length, 1);
      expect((body['items'] as List).first['topicId'], 500);
    });
  });

  test('text search matches title or author', () async {
    final byTitle = await get('topics?q=alpha');
    expect((byTitle['items'] as List).length, 1);
    expect((byTitle['items'] as List).first['topicId'], 100);
  });

  test('text search matches the thread id', () async {
    final byId = await get('topics?q=400');
    expect((byId['items'] as List).single['topicId'], 400);
  });

  test('string-keyed caches join to int topic ids', () async {
    // Topic 400's low-confidence entries live under the string keys "400" in
    // both cache files; the join must still find them.
    final body = await get('topics?filters=lowConfidenceOnly&pageSize=100');
    expect((body['items'] as List).single['topicId'], 400);
  });

  test('bundle mods returns the rules base and the per-mod llm output',
      () async {
    final body = await get('bundle/mods');
    final entry = (body['items'] as List).single as Map<String, dynamic>;

    // Rules-only base: the assumed downloads.
    final assumed = entry['assumedDownloads'] as List;
    expect(assumed.single['confidence'], 'high');

    // The LLM output is a mods list carried on the index item's `llm` field.
    final llm = entry['llm'] as Map<String, dynamic>;
    final mods = llm['mods'] as List;
    final mod = mods.single as Map<String, dynamic>;
    expect((mod['downloads'] as List).single['kind'], 'direct');
    expect((mod['extras'] as Map)['version'], '1.0.0');
  });

  test('missing file yields the missing envelope, not a crash', () async {
    final body = await get('merge/summary');
    expect(body['missing'], isTrue);
    expect(body['file'], 'merge-debug');
    expect(body['hint'], isNotNull);
  });

  group('allowlist (D7)', () {
    test('known id serves a slice', () async {
      final body = await get('files/mods-index?offset=0&length=10');
      expect(body['totalSize'], greaterThan(0));
      expect((body['content'] as String).isNotEmpty, isTrue);
    });
    test('unknown id is 404', () async {
      expect(await status('files/config'), 404);
    });
    test('no path-based access', () async {
      // A traversal-looking id is just an unknown allowlist id → 404, never a
      // file read.
      expect(await status('files/..%2f..%2fconfig.properties'), 404);
    });
  });

  test('mtime cache invalidates when the file changes', () async {
    expect((await get('topics?pageSize=100'))['total'], 5);

    // Append a sixth topic and bump the file's mtime forward.
    final indexFile = File('$dataDir/mods-index.json');
    final list = jsonDecode(indexFile.readAsStringSync()) as List;
    list.add(_indexRow(600, 'Sixth', 'Zed', '0.98a'));
    indexFile.writeAsStringSync(jsonEncode(list));
    indexFile.setLastModifiedSync(
        DateTime.now().add(const Duration(seconds: 5)));

    expect((await get('topics?pageSize=100'))['total'], 6);
  });
}

// --- Fixtures ---

Map<String, dynamic> _indexRow(
    int id, String title, String author, String? gameVersion,
    {bool isWip = false}) {
  return {
    'topicId': id,
    'title': title,
    'category': 'Mods',
    'inModIndex': true,
    'isArchivedModIndex': false,
    'gameVersion': gameVersion,
    'author': author,
    'replies': 1,
    'views': 10,
    'createdDate': 'May 04, 2014, 01:33:25 AM',
    'lastPostDate': 'April 15, 2016, 12:12:32 AM',
    'lastPostBy': author,
    'topicUrl': 'https://example/topic=$id',
    'scrapedAt': '2026-07-01T22:54:55.895486Z',
    'isWip': isWip,
    'sourceBoard': 8,
  };
}

void _writeIndex(String dataDir) {
  final rows = [
    _indexRow(100, 'Alpha mod', 'Ann', '0.98a', isWip: true),
    _indexRow(200, 'Beta mod', 'Bob', '0.98a'),
    _indexRow(300, 'Gamma mod', 'Cat', '0.98a'),
    _indexRow(400, 'Delta mod', 'Dan', '0.98a'),
    _indexRow(500, 'Epsilon mod', 'Eve', ''), // blank game version
  ];
  File('$dataDir/mods-index.json').writeAsStringSync(jsonEncode(rows));
}

Map<String, dynamic> _llmDownload(String confidence, String url) => {
      'url': url,
      'label': '',
      'kind': 'direct',
      'sourceHost': 'host',
      'fileName': 'file.zip',
      'confidence': confidence,
      'requiresManualStep': false,
    };

Map<String, dynamic> _llmEntry(String fp, List<Map<String, dynamic>> mods) => {
      'fingerprint': fp,
      'schemaVersion': 3,
      'promptVersion': 5,
      'mods': mods,
    };

Map<String, dynamic> _mod(String name, String role,
        {List<Map<String, dynamic>> downloads = const [],
        Map<String, dynamic>? extras}) =>
    {
      'name': name,
      'role': role,
      'downloads': downloads,
      if (extras != null) 'extras': extras,
    };

void _writeLlmCache(String dataDir) {
  final map = {
    // 100: one download whose URL matches the rules → not a "rules missed" one.
    '100': _llmEntry('f100', [
      _mod('Alpha', 'main',
          downloads: [_llmDownload('high', 'https://host/file.zip')]),
    ]),
    // 300: two mods (one with a rules-missed download) → multi-mod + llm found.
    '300': _llmEntry('f300', [
      _mod('Gamma', 'main',
          downloads: [_llmDownload('high', 'https://host/g.zip')]),
      _mod('Gamma Extras', 'addon', extras: {'version': '2.0'}),
    ]),
    // 400: one low-confidence download whose URL matches the rules.
    '400': _llmEntry('f400', [
      _mod('Delta', 'main',
          downloads: [_llmDownload('low', 'https://host/low.zip')]),
    ]),
  };
  File('$dataDir/llm-extraction-cache.json').writeAsStringSync(jsonEncode(map));
}

Map<String, dynamic> _assumedCandidate(String confidence,
        {String url = 'https://host/file.zip'}) =>
    {
      'sourceUrl': url,
      'resolvedUrl': url,
      'archiveFilename': 'file.zip',
      'confidence': confidence,
      'requiresManualStep': false,
      'linkText': '',
    };

void _writeAssumedCache(String dataDir) {
  final map = {
    '100': {
      'fingerprint': 'a100',
      'schemaVersion': 2,
      'candidates': [_assumedCandidate('high')],
    },
    '400': {
      'fingerprint': 'a400',
      'schemaVersion': 2,
      'candidates': [_assumedCandidate('low', url: 'https://host/low.zip')],
    },
  };
  File('$dataDir/assumed-downloads-cache.json')
      .writeAsStringSync(jsonEncode(map));
}

void _writePlaceholderDetail(String dataDir) {
  final dir = Directory('$dataDir/mods/500')..createSync(recursive: true);
  File('${dir.path}/detail.json').writeAsStringSync(
      jsonEncode({'topicId': 500, 'isPlaceholderDetail': true}));
}

/// A published bundle with one topic that has the rules-only `assumedDownloads`
/// and an `llm` mods list on its `index` item.
void _writeBundle(String outputsDir) {
  final bundle = {
    'updatedAt': '2026-07-01T22:54:55.895486Z',
    'index': [
      {
        'topicId': 100,
        'title': 'Alpha mod',
        'author': 'Ann',
        'llm': {
          'mods': [
            _mod('Alpha mod', 'main',
                downloads: [_llmDownload('low', 'https://host/llm.zip')],
                extras: {'version': '1.0.0'}),
          ],
        },
      },
    ],
    'details': {
      '100': {'topicId': 100, 'title': 'Alpha mod'},
    },
    'assumedDownloads': {
      '100': [_assumedCandidate('high')],
    },
  };
  File('$outputsDir/forum-data-bundle.json').writeAsStringSync(
      jsonEncode(bundle));
}
