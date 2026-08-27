import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/download_resolver.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/extraction_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/llm_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/post_extractor.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:test/test.dart';

/// A client whose calls hang until the test lets each one finish, so the test
/// can see exactly how many are talking to it at once.
class _HeldLlmClient implements LlmClient {
  int callCount = 0;
  int inFlight = 0;
  int mostAtOnce = 0;
  final List<Completer<void>> _held = [];

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    callCount++;
    inFlight++;
    if (inFlight > mostAtOnce) mostAtOnce = inFlight;
    final hold = Completer<void>();
    _held.add(hold);
    await hold.future;
    inFlight--;
    return const LlmResponse(content: '{"mods":[]}', totalTokens: 1);
  }

  /// Lets the longest-held call finish.
  void finishOne() => _held.removeAt(0).complete();

  void finishAll() {
    while (_held.isNotEmpty) {
      finishOne();
    }
  }
}

QbModDetail _detail(int topicId) => QbModDetail(
    topicId: topicId,
    contentHtml: '<p>Post about mod $topicId</p>',
    title: 'Mod $topicId');

void main() {
  late Directory tempDir;
  late LlmExtractionStore store;
  late QbDownloadResolver resolver;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('llm_concurrency_test');
    store = LlmExtractionStore(tempDir.path, flushEveryN: 1000);
    resolver = QbDownloadResolver(
      client: MockClient((req) async => http.Response('', 200)),
      dataPath: tempDir.path,
    );
  });

  tearDown(() {
    // A failed test can leave a held call still writing; don't let cleanup
    // turn one failure into two.
    try {
      tempDir.deleteSync(recursive: true);
    } on FileSystemException {
      // Left for the OS to clean up.
    }
  });

  /// Waits until [ready] says so. The gap between one call finishing and the
  /// next taking its slot includes real disk writes, which pumpEventQueue()
  /// does not wait out.
  Future<void> waitUntil(bool Function() ready) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!ready()) {
      if (DateTime.now().isAfter(deadline)) fail('timed out waiting');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  PostExtractor makeExtractor(_HeldLlmClient client,
          {int maxConcurrentCalls = 3}) =>
      PostExtractor(
        client: client,
        store: store,
        resolver: resolver,
        dataPath: tempDir.path,
        maxConcurrentCalls: maxConcurrentCalls,
      );

  test('at most maxConcurrentCalls topics talk to the model at once',
      () async {
    final client = _HeldLlmClient();
    final extractor = makeExtractor(client, maxConcurrentCalls: 2);

    // Six reads started at once, the way the scrape now starts them.
    final reads = [
      for (var id = 1; id <= 6; id++)
        extractor.extractForTopic(_detail(id), const []),
    ];
    await waitUntil(() => client.inFlight == 2);

    // Only two got through; the other four are waiting their turn. Settle to
    // make sure a third is not on its way in.
    await pumpEventQueue();
    expect(client.inFlight, 2);
    expect(client.callCount, 2);

    // Finishing one hands its slot to the next in line.
    client.finishOne();
    await waitUntil(() => client.callCount == 3);
    expect(client.inFlight, 2);

    // Let the rest through, finishing each as it arrives.
    while (client.callCount < 6) {
      client.finishOne();
      await waitUntil(() => client.inFlight == 2 || client.callCount == 6);
    }
    client.finishAll();
    final spent = await Future.wait(reads);

    expect(client.mostAtOnce, 2);
    expect(client.callCount, 6);
    // Every read spent a call — none was a store hit.
    expect(spent, everyElement(isTrue));
  });

  test('stopNewCalls lets in-flight reads finish and turns away the queue',
      () async {
    final client = _HeldLlmClient();
    final extractor = makeExtractor(client, maxConcurrentCalls: 1);

    final reads = [
      for (var id = 1; id <= 3; id++)
        extractor.extractForTopic(_detail(id), const []),
    ];
    await waitUntil(() => client.inFlight == 1);

    // The run is cancelled while two reads are still waiting their turn.
    extractor.stopNewCalls();
    client.finishOne();
    final spent = await Future.wait(reads);

    // The read that was already talking finished and kept its answer; the
    // queued two came back without calling.
    expect(client.callCount, 1);
    expect(spent, [true, false, false]);
    expect(store.get(1), isNotNull);
    expect(store.get(2), isNull);
  });

  test('a stored answer costs no call and says so', () async {
    final client = _HeldLlmClient();
    final extractor = makeExtractor(client);

    final firstRead = extractor.extractForTopic(_detail(1), const []);
    await waitUntil(() => client.inFlight == 1);
    client.finishAll();
    expect(await firstRead, isTrue);

    // Same post again: answered from the store, no slot taken, no call made.
    expect(await extractor.extractForTopic(_detail(1), const []), isFalse);
    expect(client.callCount, 1);
  });
}
