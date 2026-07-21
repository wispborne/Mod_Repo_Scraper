import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:mod_repo_scraper/utilities/caching_http_client.dart';

/// The raw-HTTP cache used to hold every response in memory and write the lot
/// at the end of the run, so an interrupted run recorded nothing. It now writes
/// each response as it arrives, and still reads files written the old way.
void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('caching_client_');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  String cachePath() => p.join(tmp.path, 'raw_cache.json');

  http.Client fakeServer() => MockClient((request) async =>
      http.Response('body for ${request.url.path}', 200));

  test('each response is on disk before the run finishes', () async {
    final client =
        CachingClient(fakeServer(), recordPath: cachePath());

    await client.get(Uri.parse('https://example.com/one'));
    await client.get(Uri.parse('https://example.com/two'));

    // No saveToFile() call yet — this is what an interrupted run would leave.
    final lines = File(cachePath())
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .toList();
    expect(lines, hasLength(2));
    expect(jsonDecode(lines.first)['url'], 'https://example.com/one');
    expect(jsonDecode(lines.last)['body'], 'body for /two');

    client.close();
  });

  test('what an interrupted run wrote can be replayed by the next run',
      () async {
    final recorder =
        CachingClient(fakeServer(), recordPath: cachePath());
    await recorder.get(Uri.parse('https://example.com/one'));
    await recorder.get(Uri.parse('https://example.com/two'));
    // Deliberately no saveToFile(): the run "died" here. close() stands in for
    // the process exiting and releasing the file.
    recorder.close();

    final replayer = await CachingClient.fromFile(cachePath());
    expect(replayer.isReplaying, isTrue);

    final one = await replayer.get(Uri.parse('https://example.com/one'));
    final two = await replayer.get(Uri.parse('https://example.com/two'));
    expect(one.body, 'body for /one');
    expect(two.body, 'body for /two');
  });

  test('a half-written last line is skipped, not fatal', () async {
    final recorder =
        CachingClient(fakeServer(), recordPath: cachePath());
    await recorder.get(Uri.parse('https://example.com/one'));
    await recorder.saveToFile(cachePath());

    // Simulate being killed mid-write on the second response.
    File(cachePath())
        .writeAsStringSync('{"method":"GET","url":"https://exa',
            mode: FileMode.append);

    final replayer = await CachingClient.fromFile(cachePath());
    final one = await replayer.get(Uri.parse('https://example.com/one'));
    expect(one.body, 'body for /one');
  });

  test('files written by the old end-of-run format still replay', () async {
    // The old format: one big JSON list, written once at the end.
    final legacy = jsonEncode([
      {
        'method': 'GET',
        'url': 'https://example.com/old',
        'statusCode': 200,
        'body': 'legacy body',
        'headers': <String, String>{},
      },
    ]);
    File(cachePath()).writeAsStringSync(legacy);

    final replayer = await CachingClient.fromFile(cachePath());
    final response = await replayer.get(Uri.parse('https://example.com/old'));
    expect(response.body, 'legacy body');
  });

  test('with no record path it still writes everything on save', () async {
    final client = CachingClient(fakeServer());
    await client.get(Uri.parse('https://example.com/one'));

    expect(File(cachePath()).existsSync(), isFalse);

    await client.saveToFile(cachePath());
    final saved = jsonDecode(File(cachePath()).readAsStringSync()) as List;
    expect(saved, hasLength(1));
    expect(saved.single['url'], 'https://example.com/one');
  });

  test('a response after a save adds to the file rather than wiping it',
      () async {
    final client =
        CachingClient(fakeServer(), recordPath: cachePath());

    await client.get(Uri.parse('https://example.com/one'));
    await client.saveToFile(cachePath());

    // A straggler request after the save must not truncate what we recorded.
    await client.get(Uri.parse('https://example.com/two'));
    await client.saveToFile(cachePath());

    final replayer = await CachingClient.fromFile(cachePath());
    expect((await replayer.get(Uri.parse('https://example.com/one'))).body,
        'body for /one');
    expect((await replayer.get(Uri.parse('https://example.com/two'))).body,
        'body for /two');
  });

  test('a run that fetched nothing leaves an existing cache alone', () async {
    File(cachePath()).writeAsStringSync('{"method":"GET","url":"keep me"}\n');

    final client =
        CachingClient(fakeServer(), recordPath: cachePath());
    await client.saveToFile(cachePath());

    expect(File(cachePath()).readAsStringSync(), contains('keep me'),
        reason: 'an empty run should not wipe the cache from a previous run');
  });
}
