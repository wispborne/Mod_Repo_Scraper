import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/site/requirement_names.dart';
import 'package:mod_repo_scraper/viewer/api.dart';
import 'package:mod_repo_scraper/viewer/data_access.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// `GET /api/requirement-names`: every row and every saved answer carries the
/// key the server saves answers under, so the Dependency names page can tell
/// which pending change belongs to which row.
void main() {
  late Directory tmp;
  late String dataDir;
  late Handler handler;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('viewer_requirement_names');
    dataDir = p.join(tmp.path, 'qb_data');
    final outputsDir = p.join(tmp.path, 'outputs');
    Directory(dataDir).createSync(recursive: true);
    Directory(outputsDir).createSync(recursive: true);
    handler = ViewerApi(DataAccess(dataDir: dataDir, outputsDir: outputsDir, rootDir: tmp.path)).router;
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('report rows and saved answers carry the requirement key', () async {
    File(p.join(dataDir, RequirementNameStore.reportFileName)).writeAsStringSync(jsonEncode({
      'names': [
        {'key': 'lazylib', 'written': 'LazyLib', 'count': 3, 'by': 'rule'},
        // A row with no key gets the one the server would save it under.
        {'written': 'Nexerelin v0.11.2', 'count': 1, 'by': 'unmatched'},
        {'written': 'Größe Lib', 'count': 1, 'by': 'unmatched'},
      ],
      'mods': [],
    }));
    final store = RequirementNameStore(dataDir)..load();
    store.putHandAnswer('Größe Lib 1.2', null);
    await store.save();

    final res = await handler(Request('GET', Uri.parse('http://localhost/requirement-names')));
    expect(res.statusCode, 200);
    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;

    final rows = ((body['report'] as Map)['names'] as List).cast<Map<String, dynamic>>();
    expect([for (final row in rows) row['key']], [
      'lazylib',
      requirementKey('Nexerelin v0.11.2'),
      requirementKey('Größe Lib'),
    ]);
    final saved = (body['saved'] as List).cast<Map<String, dynamic>>();
    expect(saved.single['key'], requirementKey('Größe Lib 1.2'));
    // The saved answer and the row are the same spelling, with the same key.
    expect(saved.single['key'], rows.last['key']);
  });
}
