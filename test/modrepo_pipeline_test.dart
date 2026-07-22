import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Pins what a ModRepo run writes, from the outside.
///
/// The scraper is started as its own program in a throwaway folder holding
/// nothing but a config file and two source cache files, so the test says
/// nothing about how the pipeline is put together — only what a run leaves
/// behind. That is the point: the pipeline is being moved into the manager, and
/// this test has to mean the same thing before and after the move.
void main() {
  final scraperMain = p.join(Directory.current.path, 'bin', 'scraper_main.dart');

  late Directory workDir;

  setUp(() async {
    workDir = await Directory.systemTemp.createTemp('modrepo_pipeline_test');
  });

  tearDown(() async {
    if (await workDir.exists()) {
      await workDir.delete(recursive: true);
    }
  });

  /// One mod as the source caches store them.
  Map<String, dynamic> mod({
    required String name,
    required String author,
    required String source,
    required Map<String, String> urls,
    String gameVersionReq = '0.98a',
  }) =>
      {
        'name': name,
        'authorsList': [author],
        'gameVersionReq': gameVersionReq,
        'sources': [source],
        'urls': urls,
      };

  Future<void> writeSourceCaches() async {
    // Same mod, seen on the forum and on Nexus. These should merge into one.
    await File(p.join(workDir.path, 'forum_cache.json')).writeAsString(jsonEncode({
      'items': [
        mod(
          name: 'Test Mod',
          author: 'Author Aaa',
          source: 'Index',
          urls: {'Forum': 'https://fractalsoftworks.com/forum/index.php?topic=1234.0'},
        ),
        mod(
          name: 'Another Mod',
          author: 'Someone Else',
          source: 'Index',
          urls: {'Forum': 'https://fractalsoftworks.com/forum/index.php?topic=5678.0'},
        ),
      ],
    }));

    await File(p.join(workDir.path, 'nexus_cache.json')).writeAsString(jsonEncode({
      'items': [
        mod(
          name: 'Test Mod',
          author: 'Author Aaa',
          source: 'NexusMods',
          urls: {'NexusMods': 'https://www.nexusmods.com/starsector/mods/1'},
        ),
      ],
    }));
  }

  Future<void> writeConfig({required bool mergeDebug}) async {
    await File(p.join(workDir.path, 'config.properties')).writeAsString([
      'log_level=INFO',
      'modrepo_enabled=true',
      // Reads the cache files above instead of going near the network.
      'modrepo_use_cached=true',
      'modrepo_forums_enabled=false',
      'modrepo_discord_enabled=false',
      'modrepo_nexus_enabled=false',
      'modrepo_merge_debug=$mergeDebug',
      'qb_enabled=false',
    ].join('\n'));
  }

  Future<ProcessResult> runScraper() => Process.run(
        Platform.resolvedExecutable,
        ['run', scraperMain],
        workingDirectory: workDir.path,
      );

  File outputFile(String name) => File(p.join(workDir.path, name));

  test('a debug-enabled run writes the merged repo and the merge debug file',
      () async {
    await writeSourceCaches();
    await writeConfig(mergeDebug: true);

    final result = await runScraper();
    expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');

    final repoFile = outputFile(p.join('outputs', 'ModRepo.json'));
    expect(repoFile.existsSync(), isTrue, reason: 'ModRepo.json should be written');

    final repo = jsonDecode(repoFile.readAsStringSync()) as Map<String, dynamic>;
    final items = (repo['items'] as List).cast<Map<String, dynamic>>();
    // Three entries went in; the forum and Nexus sightings of "Test Mod" are
    // one mod, so two come out.
    expect(items, hasLength(2));
    expect(repo['totalCount'], 2);
    expect(repo['lastUpdated'], isNotNull);
    expect(items.map((m) => m['name']), containsAll(['Test Mod', 'Another Mod']));

    final merged = items.firstWhere((m) => m['name'] == 'Test Mod');
    expect((merged['sources'] as List), containsAll(['Index', 'NexusMods']));
    expect((merged['urls'] as Map).keys, containsAll(['Forum', 'NexusMods']));

    final debugFile = outputFile('merge-debug.json');
    expect(debugFile.existsSync(), isTrue,
        reason: 'merge-debug.json should be written when debug is on');
    final debug = jsonDecode(debugFile.readAsStringSync()) as Map<String, dynamic>;
    expect(debug['inputCount'], 3);
    expect(debug['finalOutput'], hasLength(2));
    expect(debug['groups'], isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('a debug-off run writes the merged repo and no merge debug file',
      () async {
    await writeSourceCaches();
    await writeConfig(mergeDebug: false);

    final result = await runScraper();
    expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');

    expect(outputFile(p.join('outputs', 'ModRepo.json')).existsSync(), isTrue);
    expect(outputFile('merge-debug.json').existsSync(), isFalse,
        reason: 'no merge debug file when debug is off');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
