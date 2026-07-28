import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mod_repo_scraper/manager/cancel_token.dart';
import 'package:mod_repo_scraper/manager/job.dart';
import 'package:mod_repo_scraper/manager/merge_snapshot_store.dart';
import 'package:mod_repo_scraper/manager/modrepo_service.dart';
import 'package:mod_repo_scraper/manager/run_reporter.dart';
import 'package:mod_repo_scraper/manager/scraper_settings.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Fails the test if anything tries to reach the network.
class _NoNetworkClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    fail('This job should not have gone near the network, but it asked for '
        '${request.url}');
  }
}

void main() {
  late Directory workDir;
  late ModRepoService service;
  late RecordingRunReporter reporter;

  Map<String, dynamic> mod(String name, String author, String source,
          Map<String, String> urls) =>
      {
        'name': name,
        'authorsList': [author],
        'gameVersionReq': '0.98a',
        'sources': [source],
        'urls': urls,
      };

  void writeSourceCaches() {
    File(p.join(workDir.path, 'forum_cache.json')).writeAsStringSync(jsonEncode({
      'items': [
        mod('Test Mod', 'Author Aaa', 'Index', {
          'Forum': 'https://fractalsoftworks.com/forum/index.php?topic=1234.0'
        }),
        mod('Another Mod', 'Someone Else', 'Index', {
          'Forum': 'https://fractalsoftworks.com/forum/index.php?topic=5678.0'
        }),
      ],
    }));
    File(p.join(workDir.path, 'nexus_cache.json')).writeAsStringSync(jsonEncode({
      'items': [
        mod('Test Mod', 'Author Aaa', 'NexusMods',
            {'NexusMods': 'https://www.nexusmods.com/starsector/mods/1'}),
      ],
    }));
    File(p.join(workDir.path, 'discord_cache.json')).writeAsStringSync(jsonEncode({
      'items': [
        mod('Discord Only Mod', 'Discord Author', 'Discord',
            {'Discord': 'https://discord.com/channels/1/2/3'}),
      ],
    }));
  }

  /// A recording of Discord's own answers, holding one mod that is nowhere in
  /// `discord_cache.json`. Standing in for the file a dev machine leaves behind
  /// when `modrepo_use_cached` was on months ago.
  void writeDiscordRecording() {
    const serverId = '1';
    const channelId = '10';
    const threadId = '1000';
    final lines = <String>[];

    void record(String url, Object body) {
      lines.add(jsonEncode({
        'method': 'GET',
        'url': url,
        'statusCode': 200,
        'headers': <String, String>{},
        'body': jsonEncode(body),
      }));
    }

    record('https://discord.com/api/channels/$channelId',
        {'id': channelId, 'name': 'mod_updates'});
    record('https://discord.com/api/guilds/$serverId/threads/active', {
      'threads': [
        {'id': threadId, 'name': 'Stale Discord Mod', 'parent_id': channelId},
      ],
    });
    record(
      'https://discord.com/api/channels/$channelId/threads/archived/public?limit=100',
      {'threads': <dynamic>[], 'has_more': false},
    );
    record('https://discord.com/api/channels/$threadId',
        {'id': threadId, 'name': 'Stale Discord Mod', 'parent_id': channelId});
    record('https://discord.com/api/channels/$threadId/messages?limit=100', [
      {
        'id': '2000',
        'content': 'Stale Discord Mod\nAn old release.',
        'timestamp': '2026-01-01T00:00:00.000Z',
        'author': {'id': '3000', 'username': 'Discord Author'},
      },
    ]);

    File(p.join(workDir.path, 'discord_raw_cache.json'))
        .writeAsStringSync('${lines.join('\n')}\n');
  }

  setUp(() async {
    workDir = await Directory.systemTemp.createTemp('modrepo_service');
    reporter = RecordingRunReporter();
    service = ModRepoService(
      environment: ModRepoEnvironment(
        workingPath: workDir.path,
        outputPath: p.join(workDir.path, 'outputs'),
        snapshotPath: p.join(workDir.path, 'qb_data'),
      ),
      createNetworkClient: _NoNetworkClient.new,
    );
  });

  tearDown(() async {
    if (await workDir.exists()) await workDir.delete(recursive: true);
  });

  File outputFile(String name) => File(p.join(workDir.path, name));

  Map<String, dynamic> readJson(File file) =>
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

  test('merging from saved files goes nowhere near the network', () async {
    writeSourceCaches();

    final outcome = await service.runJob(
      JobRequest.mergeModRepo(),
      reporter: reporter,
      runId: '20260722T120000Z-mergeModRepo',
    );

    expect(outcome.cancelled, isFalse);
    expect(outcome.errors, 0);
    // Four went in (2 Forum, 1 Nexus, 1 Discord), three came out (the Forum
    // "Test Mod" and the Nexus "Test Mod" merge into one group).
    expect(outcome.itemsTotal, 4);
    expect(outcome.itemsDone, 3);

    final repo = readJson(outputFile(p.join('outputs', 'ModRepo.json')));
    expect(repo['totalCount'], 3);
    expect(repo['lastUpdated'], isNotNull);
  });

  test('the saved Discord file wins over an older recording of the API',
      () async {
    writeSourceCaches();
    writeDiscordRecording();

    // Same environment, plus the Discord credentials the recording needs to be
    // read back. Nothing here reaches the network: the recording answers
    // everything, and anything it does not answer throws.
    final withDiscord = ModRepoService(
      environment: ModRepoEnvironment(
        workingPath: workDir.path,
        outputPath: p.join(workDir.path, 'outputs'),
        snapshotPath: p.join(workDir.path, 'qb_data'),
        discordAuthToken: 'not-a-real-token',
        discordServerId: '1',
        discordForumChannels: const {'10': '0.98a'},
      ),
      createNetworkClient: _NoNetworkClient.new,
    );

    await withDiscord.runJob(JobRequest.mergeModRepo(), reporter: reporter);

    final names = (readJson(outputFile(p.join('outputs', 'ModRepo.json')))
            ['items'] as List)
        .map((m) => (m as Map<String, dynamic>)['name'])
        .toList();
    expect(names, contains('Discord Only Mod'),
        reason: 'discord_cache.json is written after every successful scrape, '
            'so it is the fresher of the two');
    expect(names, isNot(contains('Stale Discord Mod')),
        reason: 'the recording is only ever written on a dev machine and can '
            'be months behind');
  });

  test('a merge saves its own snapshot as well as merge-debug.json', () async {
    writeSourceCaches();

    await service.runJob(
      JobRequest.mergeModRepo(),
      reporter: reporter,
      runId: '20260722T120000Z-mergeModRepo',
    );

    expect(outputFile('merge-debug.json').existsSync(), isTrue);

    final snapshots = MergeSnapshotStore(p.join(workDir.path, 'qb_data'));
    expect(snapshots.list().map((s) => s.id),
        ['20260722T120000Z-mergeModRepo']);
    final saved = snapshots.read('20260722T120000Z-mergeModRepo');
    expect(saved!.inputCount, 4);
    expect(saved.finalCount, 3);
  });

  test('debug collection off writes neither the debug file nor a snapshot',
      () async {
    writeSourceCaches();

    await service.runJob(
      JobRequest.mergeModRepo(collectMergeDebug: false),
      reporter: reporter,
      runId: '20260722T120000Z-mergeModRepo',
    );

    expect(outputFile(p.join('outputs', 'ModRepo.json')).existsSync(), isTrue);
    expect(outputFile('merge-debug.json').existsSync(), isFalse);
    expect(MergeSnapshotStore(p.join(workDir.path, 'qb_data')).list(), isEmpty);
  });

  test('a cancelled merge leaves the old output alone', () async {
    writeSourceCaches();
    // An earlier merge's output, which must survive.
    final repoFile = outputFile(p.join('outputs', 'ModRepo.json'));
    repoFile.parent.createSync(recursive: true);
    repoFile.writeAsStringSync('{"totalCount": 99}');

    final cancel = CancelToken()..cancel();
    final outcome = await service.runJob(
      JobRequest.mergeModRepo(),
      reporter: reporter,
      cancel: cancel,
      runId: '20260722T120000Z-mergeModRepo',
    );

    expect(outcome.cancelled, isTrue);
    expect(readJson(repoFile)['totalCount'], 99);
    expect(outputFile('merge-debug.json').existsSync(), isFalse);
    expect(MergeSnapshotStore(p.join(workDir.path, 'qb_data')).list(), isEmpty);
  });

  test('a source asked for with no token set up is skipped, not failed',
      () async {
    writeSourceCaches();

    final outcome = await service.runJob(
      // Nexus has no token in this environment, so it should be skipped and
      // its saved results used.
      JobRequest.scrapeAndMerge(sources: {ModSourceKind.nexus}),
      reporter: reporter,
      runId: '20260722T120000Z-scrapeAndMerge',
    );

    expect(outcome.errors, 0);
    expect(outcome.cancelled, isFalse);
    expect(
        reporter.logs.any((l) => l.contains('Skipping Nexus')), isTrue,
        reason: 'the log should say why Nexus was skipped');
  });

  test('a source the job did not ask for is left alone', () async {
    writeSourceCaches();

    await service.runJob(
      JobRequest.scrapeAndMerge(sources: {ModSourceKind.nexus}),
      reporter: reporter,
      runId: '20260722T120000Z-scrapeAndMerge',
    );

    expect(
        reporter.logs.any(
            (l) => l.contains('Skipping Forum') && l.contains('did not ask')),
        isTrue);
    expect(
        reporter.logs.any(
            (l) => l.contains('Skipping Discord') && l.contains('did not ask')),
        isTrue);
  });

  test('the merge job reports its phases in order', () async {
    writeSourceCaches();

    await service.runJob(JobRequest.mergeModRepo(), reporter: reporter);

    expect(reporter.phases, ['Forum', 'Discord', 'Nexus', 'Merge', 'Save']);
  });

  test('the QB kinds are refused', () async {
    expect(
      () => service.runJob(JobRequest.rebuildBundle(), reporter: reporter),
      throwsA(isA<ArgumentError>()),
    );
  });
}
