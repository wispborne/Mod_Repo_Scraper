import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/bot/common.dart';
import 'package:mod_repo_scraper/bot/scraper/discord_reader.dart';
import 'package:mod_repo_scraper/utilities/caching_http_client.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Reading Discord back from recorded answers must not sit and wait.
///
/// The reader pauses 40ms between calls so it stays inside Discord's rate
/// limit. A run playing answers back off disk asks Discord for nothing, so that
/// pause buys nothing and costs a great deal: there are thousands of calls in a
/// full recording, and 40ms each turns a job that touches no network into one
/// that takes minutes. This pins the pause at nothing while replaying.
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('discord_replay');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// A recording holding the answers one small channel's worth of reading needs.
  Future<CachingClient> recordedClient() async {
    const serverId = '1';
    const channelId = '10';
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

    // Enough threads that a 40ms pause each would be plain to see.
    const threadCount = 40;
    // The channel itself is asked about first.
    record('https://discord.com/api/channels/$channelId',
        {'id': channelId, 'name': 'mod_updates'});
    record(
      'https://discord.com/api/guilds/$serverId/threads/active',
      {
        'threads': [
          for (var i = 0; i < threadCount; i++)
            {
              'id': '${1000 + i}',
              'name': 'Mod $i',
              'parent_id': channelId,
            },
        ],
      },
    );
    record(
      'https://discord.com/api/channels/$channelId/threads/archived/public?limit=100',
      {'threads': <dynamic>[], 'has_more': false},
    );
    for (var i = 0; i < threadCount; i++) {
      record('https://discord.com/api/channels/${1000 + i}',
          {'id': '${1000 + i}', 'name': 'Mod $i', 'parent_id': channelId});
      record(
        'https://discord.com/api/channels/${1000 + i}/messages?limit=100',
        <dynamic>[],
      );
    }

    final file = File(p.join(tmp.path, 'discord_raw_cache.json'));
    await file.writeAsString('${lines.join('\n')}\n');
    return CachingClient.fromFile(file.path);
  }

  test('playing recorded answers back waits for nothing', () async {
    final client = await recordedClient();

    final config = BotConfig(
      lessScraping: false,
      enableForums: false,
      enableDiscord: true,
      enableNexus: false,
      logLevel: 'INFO',
      discordAuthToken: 'not-a-real-token',
      discordServerId: '1',
      discordForumChannelIdsAndGameVersions: const {'10': '0.98a'},
    );

    final started = DateTime.now();
    await DiscordReader.readAllMessages(config, httpClient: client);
    final took = DateTime.now().difference(started);

    // With the pause left in, the calls above alone would cost about 3
    // seconds. Off disk this is a few milliseconds; a second is a generous
    // ceiling that still fails loudly if the pause creeps back.
    expect(took.inMilliseconds, lessThan(1000),
        reason: 'a replayed read should not be waiting between answers');
  });

  test('a replaying client never reaches the network', () async {
    final client = await recordedClient();
    // A replaying client has no inner client to fall back on: anything it was
    // not given an answer for throws rather than quietly fetching.
    expect(client.isReplaying, isTrue);
    expect(
      () => client.get(Uri.parse('https://discord.com/api/not-recorded')),
      throwsA(isA<StateError>()),
    );
  });
}
