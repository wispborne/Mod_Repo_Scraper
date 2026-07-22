import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/bot/scraper/debug/merge_debug_data.dart';
import 'package:mod_repo_scraper/bot/scraper/scraped_mod.dart';
import 'package:mod_repo_scraper/manager/merge_snapshot_store.dart';
import 'package:mod_repo_scraper/viewer/api.dart';
import 'package:mod_repo_scraper/viewer/data_access.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// The merge run picker, the before-and-after table, and the comparison of two
/// merges, driven through the real handlers over real saved snapshots.
void main() {
  late Directory tmp;
  late String dataDir;
  late Handler handler;
  late MergeSnapshotStore snapshots;

  Future<Map<String, dynamic>> get(String path) async {
    final res =
        await handler(Request('GET', Uri.parse('http://localhost/$path')));
    return jsonDecode(await res.readAsString()) as Map<String, dynamic>;
  }

  ScrapedMod mod(
    String name, {
    List<String> authors = const ['Author Aaa'],
    String? topic,
    String? nexus,
    String? version,
    List<ModSource> sources = const [ModSource.Index],
    String? summary,
  }) =>
      ScrapedMod(
        name: name,
        authorsList: authors,
        gameVersionReq: version ?? '0.98a',
        summary: summary,
        sources: sources,
        urls: {
          if (topic != null)
            ModUrlType.Forum:
                'https://fractalsoftworks.com/forum/index.php?topic=$topic.0',
          if (nexus != null)
            ModUrlType.NexusMods: 'https://www.nexusmods.com/starsector/mods/$nexus',
        },
      );

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('merge_views_');
    dataDir = '${tmp.path}/qb_data';
    Directory(dataDir).createSync(recursive: true);
    Directory('${tmp.path}/outputs').createSync(recursive: true);

    snapshots = MergeSnapshotStore(dataDir);

    final data = DataAccess(
      dataDir: dataDir,
      outputsDir: '${tmp.path}/outputs',
      rootDir: tmp.path,
    );
    handler = ViewerApi(data).router;
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  /// A merge where a forum sighting and a Nexus sighting of one mod were joined.
  MergeDebugData mergedPair({String finalName = 'Test Mod'}) {
    final forum = mod('Test Mod', topic: '1234', summary: 'From the forum');
    final nexus = mod('Test Mod',
        nexus: '1', sources: [ModSource.NexusMods], version: '0.97a');
    final merged = ScrapedMod(
      name: finalName,
      authorsList: const ['Author Aaa'],
      gameVersionReq: '0.98a',
      summary: 'From the forum',
      sources: const [ModSource.Index, ModSource.NexusMods],
      urls: {
        ModUrlType.Forum:
            'https://fractalsoftworks.com/forum/index.php?topic=1234.0',
        ModUrlType.NexusMods: 'https://www.nexusmods.com/starsector/mods/1',
      },
    );

    return MergeDebugData(
      inputCount: 2,
      afterPreDedupCount: 2,
      groupsCreated: 1,
      finalCount: 1,
      groups: [
        DebugModGroup(groupIndex: 0, members: [forum, nexus], matchEntries: []),
      ],
      mergeDecisions: [
        MergeDecision(
          groupIndex: 0,
          inputMods: [forum, nexus],
          steps: [
            MergeStepEntry(
              left: forum,
              right: nexus,
              reason: MergePriorityReason.higherGameVersion,
              doesRightHavePriority: false,
              result: merged,
            ),
          ],
          finalResult: merged,
        ),
      ],
      finalOutput: [merged],
    );
  }

  group('picking which merge to look at', () {
    test('the saved merges are listed newest first', () async {
      await snapshots.save('20260720T100000Z-mergeModRepo', mergedPair());
      await snapshots.save('20260722T100000Z-mergeModRepo', mergedPair());

      final body = await get('merge/runs');
      expect(body['total'], 2);
      expect((body['items'] as List).map((r) => r['id']), [
        '20260722T100000Z-mergeModRepo',
        '20260720T100000Z-mergeModRepo',
      ]);
      expect((body['items'] as List).first['finalCount'], 1);
    });

    test('with no run named, the newest merge is the one shown', () async {
      await snapshots.save(
          '20260720T100000Z-mergeModRepo', mergedPair(finalName: 'Old Name'));
      await snapshots.save(
          '20260722T100000Z-mergeModRepo', mergedPair(finalName: 'New Name'));

      final summary = await get('merge/summary');
      expect(summary['runId'], '20260722T100000Z-mergeModRepo');

      final groups = await get('merge/groups');
      expect((groups['items'] as List), hasLength(1));
    });

    test('an older merge can be asked for by name', () async {
      await snapshots.save('20260720T100000Z-mergeModRepo', mergedPair());
      await snapshots.save('20260722T100000Z-mergeModRepo', mergedPair());

      final summary =
          await get('merge/summary?run=20260720T100000Z-mergeModRepo');
      expect(summary['runId'], '20260720T100000Z-mergeModRepo');
    });

    test('no merges saved and no merge-debug.json says what to do', () async {
      final summary = await get('merge/summary');
      expect(summary['missing'], isTrue);
      expect(summary['hint'], contains('Run a merge'));
    });
  });

  group('before and after for one group', () {
    setUp(() async {
      await snapshots.save('20260722T100000Z-mergeModRepo', mergedPair());
    });

    test('each field says which member it came from', () async {
      final body = await get('merge/groups/0/fields');
      expect(body['wasMerged'], isTrue);
      expect(body['memberCount'], 2);

      final rows = {
        for (final r in body['rows'] as List) r['field'] as String: r,
      };

      // The summary only the forum entry had.
      expect(rows['summary']!['final'], 'From the forum');
      expect(rows['summary']!['from'], [0]);
      expect(rows['summary']!['verdict'], 'one');

      // Both agreed on the name.
      expect(rows['name']!['verdict'], 'agreed');
      expect(rows['name']!['from'], [0, 1]);
    });

    test('a merged-together map is picked apart entry by entry', () async {
      final body = await get('merge/groups/0/fields');
      final urls = (body['rows'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((r) => r['field'] == 'urls');

      final entries = {
        for (final e in urls['entries'] as List) e['key'] as String: e,
      };
      expect(entries['Forum']!['from'], [0]);
      expect(entries['NexusMods']!['from'], [1]);
    });

    test('a field nobody had is marked as empty, not guessed at', () async {
      final body = await get('merge/groups/0/fields');
      final description = (body['rows'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((r) => r['field'] == 'description');
      expect(description['verdict'], 'empty');
      expect(description['from'], isEmpty);
    });

    test('a group that is not there says so', () async {
      final res = await handler(
          Request('GET', Uri.parse('http://localhost/merge/groups/99/fields')));
      expect(res.statusCode, 404);
    });
  });

  group('what changed between two merges', () {
    Future<void> saveTwo({
      required List<ScrapedMod> before,
      required List<ScrapedMod> after,
    }) async {
      await snapshots.save(
          '20260720T100000Z-mergeModRepo',
          MergeDebugData(
              inputCount: before.length,
              finalCount: before.length,
              finalOutput: before));
      await snapshots.save(
          '20260722T100000Z-mergeModRepo',
          MergeDebugData(
              inputCount: after.length,
              finalCount: after.length,
              finalOutput: after));
    }

    Future<Map<String, dynamic>> compare({String extra = ''}) => get(
        'merge/compare?a=20260720T100000Z-mergeModRepo'
        '&b=20260722T100000Z-mergeModRepo$extra');

    test('added, gone, changed and unchanged are counted', () async {
      await saveTwo(
        before: [
          mod('Stayed The Same', topic: '1'),
          mod('Went Away', topic: '2'),
          mod('Changed Version', topic: '3', version: '0.97a'),
        ],
        after: [
          mod('Stayed The Same', topic: '1'),
          mod('Changed Version', topic: '3', version: '0.98a'),
          mod('Brand New', topic: '4'),
        ],
      );

      final body = await compare();
      expect(body['sameCount'], 1);
      expect(body['addedCount'], 1);
      expect(body['goneCount'], 1);
      expect(body['changedCount'], 1);

      final rows = (body['items'] as List).cast<Map<String, dynamic>>();
      final changed = rows.firstWhere((r) => r['kind'] == 'changed');
      expect(changed['name'], 'Changed Version');
      final fields =
          (changed['changes'] as List).map((c) => c['field']).toList();
      expect(fields, ['gameVersionReq']);
    });

    test('a mod whose name gained a suffix is changed, not swapped', () async {
      await saveTwo(
        before: [mod('Nexerelin', topic: '9')],
        after: [mod('Nexerelin 0.12', topic: '9')],
      );

      final body = await compare();
      expect(body['addedCount'], 0);
      expect(body['goneCount'], 0);
      expect(body['changedCount'], 1);
    });

    test('a mod with no forum link still lines up by name and author',
        () async {
      await saveTwo(
        before: [
          mod('Discord Only', nexus: '7', sources: [ModSource.Discord])
        ],
        after: [
          mod('Discord Only', nexus: '7', sources: [ModSource.Discord])
        ],
      );

      final body = await compare();
      expect(body['sameCount'], 1);
      expect(body['items'], isEmpty);
    });

    test('comparing a merge with itself finds no differences', () async {
      await saveTwo(
        before: [mod('One', topic: '1'), mod('Two', topic: '2')],
        after: [mod('One', topic: '1'), mod('Two', topic: '2')],
      );

      final body = await get('merge/compare'
          '?a=20260722T100000Z-mergeModRepo&b=20260722T100000Z-mergeModRepo');
      expect(body['sameCount'], 2);
      expect(body['addedCount'], 0);
      expect(body['goneCount'], 0);
      expect(body['changedCount'], 0);
    });

    test('the differences can be searched and filtered', () async {
      await saveTwo(
        before: [mod('Gone Mod', topic: '1', authors: ['Someone'])],
        after: [mod('New Mod', topic: '2', authors: ['Nobody'])],
      );

      final searched = await compare(extra: '&q=new');
      expect((searched['items'] as List), hasLength(1));
      expect((searched['items'] as List).first['name'], 'New Mod');
      // The counts stay honest about the whole comparison, not the search.
      expect(searched['goneCount'], 1);

      final byAuthor = await compare(extra: '&q=someone');
      expect((byAuthor['items'] as List).first['name'], 'Gone Mod');

      final onlyGone = await compare(extra: '&kind=gone');
      expect((onlyGone['items'] as List), hasLength(1));
      expect((onlyGone['items'] as List).first['kind'], 'gone');
    });

    test('naming a merge that is no longer kept says so', () async {
      await saveTwo(before: [mod('One', topic: '1')], after: [
        mod('One', topic: '1')
      ]);

      final body = await get('merge/compare'
          '?a=20250101T000000Z-mergeModRepo&b=20260722T100000Z-mergeModRepo');
      expect(body['missing'], isTrue);
      expect(body['hint'], contains('no longer kept'));
    });

    test('asking for one merge only is refused in plain words', () async {
      final res = await handler(Request('GET',
          Uri.parse('http://localhost/merge/compare?a=20260722T100000Z-x')));
      expect(res.statusCode, 404);
      final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(body['error'], contains('two merges'));
    });
  });

  test('no merge endpoint hands over a whole snapshot', () async {
    await snapshots.save('20260722T100000Z-mergeModRepo', mergedPair());

    for (final path in [
      'merge/runs',
      'merge/summary',
      'merge/groups',
      'merge/groups/0/fields',
    ]) {
      final body = await get(path);
      // `finalOutput` and `mergeDecisions` are the two big lists in a snapshot.
      expect(body.containsKey('finalOutput'), isFalse, reason: path);
      expect(body.containsKey('mergeDecisions'), isFalse, reason: path);
    }
  });
}
