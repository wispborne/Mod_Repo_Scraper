import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:mod_repo_scraper/bot/scraper/qb/json_data_store.dart';

/// Covers the bug surfaced by the smoke test: a legacy detail.json written
/// before the `isDownloadable` field existed must still produce `true` for
/// obviously-downloadable URLs when reloaded, so the bundle reflects reality.
void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('jds_backfill_');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  test('loadDetail backfills isDownloadable for legacy cached files that '
      'predate the field', () async {
    const topicId = 29012;
    final modDir = Directory(p.join(tmp.path, 'mods', '$topicId'));
    modDir.createSync(recursive: true);

    // Legacy JSON: links have no `isDownloadable` key at all.
    final legacyJson = jsonEncode({
      'topicId': topicId,
      'title': 'Roider Union',
      'author': 'SafariJohn',
      'authorPostCount': 0,
      'contentHtml': '',
      'images': [],
      'links': [
        {
          'url':
              'https://github.com/SafariJohn/Roider-Union/raw/refs/heads/main/Roider%20Union%202.2.8.zip',
          'text': 'Download v2.2.8',
          'isExternal': true,
        },
        {
          'url': 'https://fractalsoftworks.com/forum/index.php?topic=5444.0',
          'text': 'LazyLib',
          'isExternal': false,
        },
      ],
      'scrapedAt': DateTime.now().toUtc().toIso8601String(),
      'isPlaceholderDetail': false,
    });

    File(p.join(modDir.path, 'detail.json')).writeAsStringSync(legacyJson);

    final store = JsonDataStore(tmp.path);
    final detail = await store.loadDetail(topicId);

    expect(detail, isNotNull);
    final byUrl = {for (final l in detail!.links) l.url: l};
    final zipLink = byUrl[
        'https://github.com/SafariJohn/Roider-Union/raw/refs/heads/main/Roider%20Union%202.2.8.zip']!;
    final forumLink = byUrl[
        'https://fractalsoftworks.com/forum/index.php?topic=5444.0']!;

    expect(zipLink.isDownloadable, isTrue,
        reason: 'archive URL should be upgraded by the sync heuristic on load');
    expect(forumLink.isDownloadable, isFalse,
        reason: 'forum URL should remain false');
  });

  test('loadDetail does not downgrade links already marked isDownloadable=true',
      () async {
    const topicId = 11111;
    final modDir = Directory(p.join(tmp.path, 'mods', '$topicId'));
    modDir.createSync(recursive: true);

    // Hypothetical: async probe previously classified a non-obvious URL as
    // downloadable; we must preserve that decision on load.
    final json = jsonEncode({
      'topicId': topicId,
      'title': 'Test',
      'author': 'nobody',
      'authorPostCount': 0,
      'contentHtml': '',
      'images': [],
      'links': [
        {
          'url': 'https://cdn.example.com/opaque/path',
          'text': '',
          'isExternal': true,
          'isDownloadable': true,
        },
      ],
      'scrapedAt': DateTime.now().toUtc().toIso8601String(),
      'isPlaceholderDetail': false,
    });

    File(p.join(modDir.path, 'detail.json')).writeAsStringSync(json);

    final store = JsonDataStore(tmp.path);
    final detail = await store.loadDetail(topicId);

    expect(detail!.links.single.isDownloadable, isTrue);
  });

  test('loadDetail leaves non-downloadable links alone', () async {
    const topicId = 22222;
    final modDir = Directory(p.join(tmp.path, 'mods', '$topicId'));
    modDir.createSync(recursive: true);

    final json = jsonEncode({
      'topicId': topicId,
      'title': 'Test',
      'author': 'nobody',
      'authorPostCount': 0,
      'contentHtml': '',
      'images': [],
      'links': [
        {
          'url': 'https://imgur.com/a/abc',
          'text': 'screenshot',
          'isExternal': true,
        },
      ],
      'scrapedAt': DateTime.now().toUtc().toIso8601String(),
      'isPlaceholderDetail': false,
    });

    File(p.join(modDir.path, 'detail.json')).writeAsStringSync(json);

    final store = JsonDataStore(tmp.path);
    final detail = await store.loadDetail(topicId);

    expect(detail!.links.single.isDownloadable, isFalse);
  });
}
