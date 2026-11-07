import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/viewer/api.dart';
import 'package:mod_repo_scraper/viewer/data_access.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// `GET /api/post-guide`: the report of which mod threads follow the forum's
/// mod post guide.
void main() {
  late Directory tmp;
  late String dataDir;
  late Handler handler;

  void writeJson(String path, Object value) {
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(value));
  }

  Map<String, dynamic> check(Map<String, String> llm, Map<String, String> rules) => {
        'fingerprint': 'f',
        'checkedAt': '2026-11-06T11:00:00.000Z',
        'llm': llm,
        'rules': rules,
      };

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('viewer_post_guide');
    dataDir = p.join(tmp.path, 'qb_data');
    writeJson(p.join(dataDir, 'mods-index.json'), [
      for (final (id, title) in [(1, 'Beta Mod'), (2, 'Alpha Mod'), (3, 'Gamma Mod'), (4, 'Delta Mod')])
        {'topicId': id, 'title': title, 'author': 'Author $id', 'scrapedAt': '2026-11-01T00:00:00Z'},
    ]);
    handler = ViewerApi(DataAccess(dataDir: dataDir, outputsDir: p.join(tmp.path, 'outputs'), rootDir: tmp.path))
        .router;
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Future<Map<String, dynamic>> report() async {
    final res = await handler(Request('GET', Uri.parse('http://localhost/post-guide')));
    expect(res.statusCode, 200);
    return jsonDecode(await res.readAsString()) as Map<String, dynamic>;
  }

  test('says so when nothing has been checked', () async {
    expect((await report())['missing'], true);
  });

  test('puts every thread in scope in one group: failed, imperfect, following the guide or unknown', () async {
    writeJson(p.join(dataDir, 'post-guide-checks.json'), {
      'guideVersion': 1,
      'lastPass': {
        'at': '2026-11-06T11:05:00.000Z',
        'topics': [1, 2, 3, 4],
      },
      'topics': {
        '1': check({'aiDisclaimer': 'no', 'saveCompatibility': 'no'}, {'gameVersionInTitle': 'yes', 'pictures': 'yes'}),
        '2': check({'sourceCode': 'yes'}, {'gameVersionInTitle': 'yes', 'pictures': 'yes'}),
        // Only recommendations missing: source code is not a requirement.
        '4': check({'sourceCode': 'no'}, {'gameVersionInTitle': 'yes', 'pictures': 'yes'}),
        // Checked once, but no longer in scope: left out of the report.
        '9': check({'sourceCode': 'no'}, {}),
      },
    });
    final body = await report();
    expect(body['lastPassAt'], '2026-11-06T11:05:00.000Z');
    expect(body['counts'], {'threads': 4, 'failed': 1, 'imperfect': 1, 'follows': 1, 'unknown': 1});
    final rows = (body['rows'] as List).cast<Map<String, dynamic>>();
    expect(rows.map((r) => r['title']), ['Alpha Mod', 'Beta Mod', 'Delta Mod', 'Gamma Mod']);
    expect(rows[0]['status'], 'follows');
    expect(rows[1]['status'], 'failed');
    expect(rows[2]['status'], 'imperfect');
    expect(rows[2]['missing'], [
      {'id': 'sourceCode', 'reason': 'No source code', 'required': false},
    ]);
    expect(rows[1]['missing'], [
      {'id': 'aiDisclaimer', 'reason': 'Incomplete AI use disclaimer', 'required': true},
      {'id': 'saveCompatibility', 'reason': 'Save compatibility not stated', 'required': false},
    ]);
    expect(rows[1]['missingRequired'], 1);
    expect(rows[3]['status'], 'unknown');
    expect(rows[3]['url'], 'https://fractalsoftworks.com/forum/index.php?topic=3.0');
  });
}
