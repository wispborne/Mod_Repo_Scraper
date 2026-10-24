import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/catalog/takedowns.dart';
import 'package:mod_repo_scraper/viewer/api.dart';
import 'package:mod_repo_scraper/viewer/data_access.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// The viewer's takedown routes only read: the list, and what a takedown would
/// leave out of the current catalog.
void main() {
  late Directory tmp;
  late String dataDir;
  late Handler handler;

  Map<String, dynamic> mod(String id, String name, List<String> authors, List<Map<String, String>> posts) => {
        'id': id,
        'name': name,
        'authorsList': authors,
        'sourcePosts': posts,
      };

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('viewer_takedowns');
    dataDir = p.join(tmp.path, 'qb_data');
    final outputsDir = p.join(tmp.path, 'outputs');
    Directory(dataDir).createSync(recursive: true);
    Directory(outputsDir).createSync(recursive: true);
    File(p.join(outputsDir, 'mod-catalog.json')).writeAsStringSync(jsonEncode({
      'items': [
        mod('diable-avionics-tidal-fork', 'Diable Avionics (TIDAL FORK)', ['tidal5590'], [
          {'kind': 'discord', 'id': '1507163509224509510', 'llmModName': 'Diable Avionics'},
        ]),
        mod('lpc-editor', 'lpc editor', ['tidal5590'], [
          {'kind': 'discord', 'id': '42'},
        ]),
        mod('diable-avionics-original-flavor', 'Diable Avionics: Original Flavor', ['After', 'Tartiflette', 'Tidal'], [
          {'kind': 'forum', 'id': '14'},
        ]),
        mod('project-solar-tail', 'Project Solar Tail', ['TIDAL'], [
          {'kind': 'forum', 'id': '20'},
        ]),
        mod('waves', 'Waves', ['Tidalwave'], [
          {'kind': 'forum', 'id': '21'},
        ]),
        mod('useful-tithes', 'Useful.Tithes', ['SirHartley'], [
          {'kind': 'forum', 'id': '34161', 'llmModName': 'Useful.Tithes'},
        ]),
        mod('corrupt-officials', 'Corrupt.Officials', ['SirHartley'], [
          {'kind': 'forum', 'id': '34161', 'llmModName': 'Corrupt.Officials'},
        ]),
      ],
      'collections': [
        {
          'id': 'hartleys-mods',
          'name': "Hartley's Mods",
          'sourcePost': {'kind': 'forum', 'id': '34161'},
          'modIds': ['useful-tithes', 'corrupt-officials'],
        },
      ],
      'movedIds': {'useful-tithes-old': 'useful-tithes'},
      'lastUpdated': '2026-10-22T00:00:00Z',
    }));
    handler = ViewerApi(DataAccess(dataDir: dataDir, outputsDir: outputsDir, rootDir: tmp.path)).router;
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Future<Map<String, dynamic>> get(String path) async {
    final res = await handler(Request('GET', Uri.parse('http://localhost/$path')));
    return jsonDecode(await res.readAsString()) as Map<String, dynamic>;
  }

  List<String> filesInData() => [for (final f in Directory(dataDir).listSync()) p.basename(f.path)]..sort();

  test('an author preview lists every mod with the credit that matched', () async {
    final before = filesInData();
    final body = await get('takedowns/preview?author=tidal5590');
    final credits = {for (final m in body['mods'] as List) m['name']: m['credit']};
    expect(credits, {
      'Diable Avionics (TIDAL FORK)': 'tidal5590',
      'lpc editor': 'tidal5590',
      'Diable Avionics: Original Flavor': 'Tidal',
      'Project Solar Tail': 'TIDAL',
    });
    expect(filesInData(), before, reason: 'a preview writes nothing');
    expect(TakedownList.fileIn(dataDir).existsSync(), isFalse);
  });

  test('a mod on a shared topic is shown as a named key, with its Collection and old ids', () async {
    final body = await get('takedowns/preview?mod=useful-tithes');
    expect(body['posts'], [
      {'key': 'forum:34161#Useful.Tithes', 'whole': false},
    ]);
    expect(body['notInModRepo'], ['forum:34161#Useful.Tithes']);
    expect((body['collections'] as List).single['id'], 'hartleys-mods');
    expect(body['oldIds'], ['useful-tithes-old']);
  });

  test("the Tidal fork's thread is a whole post", () async {
    final body = await get('takedowns/preview?mod=diable-avionics-tidal-fork');
    expect(body['posts'], [
      {'key': 'discord:1507163509224509510', 'whole': true},
    ]);
    expect(body['notInModRepo'], isEmpty);
  });

  test('a thread lists its mods from the catalog', () async {
    final body = await get('takedowns/preview?post=forum:34161');
    expect([for (final m in body['mods'] as List) m['id']], ['useful-tithes', 'corrupt-officials']);
  });

  test('every credited person is offered once, with every spelling, most mods first', () async {
    final body = await get('takedowns/authors');
    final authors = {for (final a in body['authors'] as List) a['name']: a};
    expect((body['authors'] as List).first['name'], 'tidal5590');
    expect(authors['tidal5590']['mods'], 4);
    expect(authors['tidal5590']['others'], unorderedEquals(['Tidal', 'TIDAL']));
    expect(authors['Tidalwave']['others'], isEmpty, reason: 'a longer name is somebody else');
    expect(authors['SirHartley']['mods'], 2);
  });

  test('an unknown id is a plain error', () async {
    final res = await handler(Request('GET', Uri.parse('http://localhost/takedowns/preview?mod=no-such-mod')));
    expect(res.statusCode, 400);
    expect(await res.readAsString(), contains('no-such-mod'));
  });

  test('the list comes back with the last build\'s matches', () async {
    const TakedownList(authors: [AuthorTakedown(names: ['tidal5590'], on: '2026-10-22')]).write(dataDir);
    File(p.join(dataDir, TakedownList.matchesFileName)).writeAsStringSync(jsonEncode({
      'matches': [
        {'entry': 'author:tidal5590', 'mods': [], 'collections': []},
      ],
    }));
    final body = await get('takedowns');
    expect(((body['list'] as Map)['authors'] as List).single['names'], ['tidal5590']);
    expect(((body['matches'] as Map)['matches'] as List).single['entry'], 'author:tidal5590');
  });
}
