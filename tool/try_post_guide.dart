// Runs the post guide check over every saved thread posted or edited since the
// guide, against the LLM named in config.properties. Answers are saved in the folder
// given, never in qb_data, so trying a changed question costs no real data.
// A thread already checked there with the same prompt is not sent again.
// Usage: dart run tool/try_post_guide.dart <folder>
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mod_repo_scraper/bot/scraper/qb/json_data_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/extraction_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/openai_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/post_guide_check.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/post_guide_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/throttled_client.dart';

Future<void> main(List<String> args) async {
  final config = {
    for (final line in File('config.properties').readAsLinesSync())
      if (line.contains('=') && !line.trimLeft().startsWith('#'))
        line.substring(0, line.indexOf('=')).trim(): line.substring(line.indexOf('=') + 1).trim(),
  };
  final client = OpenAiCompatibleClient(
    client: ThrottledClient(client: http.Client(), delayMs: 250),
    baseUrl: config['llm_base_url']!,
    model: config['llm_model']!,
    apiToken: config['llm_api_token'],
    disableThinking: config['llm_disable_thinking'] == 'true',
    structuredOutput: config['llm_structured_output'] == 'true',
    idleTimeout: const Duration(seconds: 180),
    totalTimeout: const Duration(seconds: 600),
  );
  final data = JsonDataStore('qb_data');
  final store = PostGuideStore(args.single);
  await store.load();
  final checker = PostGuideChecker(client: client, takeCall: () async => true, store: store);
  final extractions = LlmExtractionStore('qb_data');
  await extractions.load();
  final index = await data.loadIndex();
  final todo = <Future<void>>[];
  final inScope = <int>[];
  var running = 0;
  final watch = Stopwatch()..start();
  for (final summary in index) {
    final detail = await data.loadDetail(summary.topicId);
    if (detail == null || !postGuideApplies(detail, createdDate: summary.createdDate)) continue;
    final extraction = extractions.get(summary.topicId);
    if (notAModIn(extraction)) continue;
    inScope.add(detail.topicId);
    while (running >= 3) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
    running++;
    final started = watch.elapsedMilliseconds;
    todo.add(checker.check(detail,
        createdDate: summary.createdDate,
        sourceCodeFound: sourceCodeFoundIn(extraction),
        aiDisclaimer: aiDisclaimerFromFacts(extraction)).then((spent) {
      running--;
      final entry = store.get(detail.topicId);
      final missing = entry == null
          ? 'FAILED'
          : postGuideResults(entry).where((r) => r.fails).map((r) => r.item.reason).join('; ');
      stdout.writeln('${detail.topicId}\t${watch.elapsedMilliseconds - started}ms\t${detail.title}\t$missing');
    }));
  }
  await Future.wait(todo);
  store.finishPass(inScope);
  await store.save();
  stdout.writeln('calls=${checker.callCount} failures=${checker.failureCount} total=${watch.elapsed}');
  exit(0);
}
