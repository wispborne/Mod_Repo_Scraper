import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mod_repo_scraper/bot/common.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/download_resolver.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/extraction_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/openai_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/post_extractor.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/post_extraction.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/throttled_client.dart';

/// Where the model is and what it is called. Read from the environment first
/// (`LLM_BASE_URL`, `LLM_MODEL`, `LLM_API_TOKEN`), then from
/// `config.properties` if there is one, then the llama.cpp default. So these
/// tests read the same model the real runs use, and there is no second place
/// to keep the settings in step.
class LiveLlmSettings {
  final String baseUrl;
  final String model;
  final String? apiToken;
  final bool disableThinking;
  final bool structuredOutput;

  LiveLlmSettings({
    required this.baseUrl,
    required this.model,
    this.apiToken,
    this.disableThinking = true,
    this.structuredOutput = true,
  });

  static LiveLlmSettings read() {
    final env = Platform.environment;
    final config =
        File('config.properties').existsSync() ? Common.readConfig() : null;
    return LiveLlmSettings(
      baseUrl: env['LLM_BASE_URL'] ??
          config?.llmBaseUrl ??
          'http://localhost:8080/v1/chat/completions',
      model: env['LLM_MODEL'] ?? config?.llmModel ?? '',
      apiToken: env['LLM_API_TOKEN'] ?? config?.llmApiToken,
      disableThinking: config?.llmDisableThinking ?? true,
      structuredOutput: config?.llmStructuredOutput ?? true,
    );
  }

  /// The server's own address, without the chat-completions path — what the
  /// health check asks.
  Uri? get origin {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || !uri.hasAuthority) return null;
    return Uri(scheme: uri.scheme, host: uri.host, port: uri.port);
  }
}

bool _checked = false;
String? _reason;

/// Why the live tests cannot run, or null when they can. Asked once and
/// remembered, so a whole file of tests costs one request.
Future<String?> whyLiveLlmIsOff() async {
  if (_checked) return _reason;
  _checked = true;
  _reason = await _check();
  return _reason;
}

Future<String?> _check() async {
  final settings = LiveLlmSettings.read();
  if (settings.model.trim().isEmpty) {
    return 'no model named — set LLM_MODEL, or llm_model in config.properties';
  }
  final origin = settings.origin;
  if (origin == null) {
    return 'llm_base_url is not a URL: "${settings.baseUrl}"';
  }
  try {
    final answer = await http
        .get(origin.resolve('/v1/models'))
        .timeout(const Duration(seconds: 5));
    if (answer.statusCode >= 400) {
      return 'the model server at $origin answered ${answer.statusCode}';
    }
    final body = jsonDecode(answer.body);
    final ids = <String>[
      if (body is Map && body['data'] is List)
        for (final m in body['data'] as List)
          if (m is Map && m['id'] is String) m['id'] as String,
    ];
    if (ids.isNotEmpty && !ids.contains(settings.model)) {
      return 'the server at $origin does not offer "${settings.model}"';
    }
    return null;
  } catch (e) {
    return 'no model server at $origin ($e)';
  }
}

/// A saved forum thread from `test/llm_live/posts/`. These are real posts,
/// copied out of a real scrape, because what these tests are for is what the
/// model does with what authors actually write.
QbModDetail loadPost(int topicId) {
  final file = File('test/llm_live/posts/$topicId.json');
  if (!file.existsSync()) {
    throw StateError('No saved post for topic $topicId at ${file.path}');
  }
  return QbModDetailMapper.fromJson(file.readAsStringSync());
}

/// Reads one saved thread with the real model and hands back what was stored.
///
/// The download resolver is given a mock HTTP client: these tests are about
/// what the model says, and resolving a download would otherwise reach out to
/// GitHub and friends on every run.
Future<LlmStoreEntry?> readWithTheModel(
  int topicId, {
  bool summaries = true,
  int? maxTokens,
}) async {
  final settings = LiveLlmSettings.read();
  final tempDir = Directory.systemTemp.createTempSync('llm_live');
  final httpClient = ThrottledClient(
    client: http.Client(),
    delayMs: 0,
    timeout: const Duration(seconds: 300),
  );
  final store = LlmExtractionStore(tempDir.path, flushEveryN: 1000);
  try {
    final extractor = PostExtractor(
      client: OpenAiCompatibleClient(
        client: httpClient,
        baseUrl: settings.baseUrl,
        model: settings.model,
        apiToken: settings.apiToken,
        disableThinking: settings.disableThinking,
        structuredOutput: settings.structuredOutput,
      ),
      store: store,
      resolver: QbDownloadResolver(
        client: MockClient((req) async => http.Response('', 200)),
        dataPath: tempDir.path,
      ),
      dataPath: tempDir.path,
      generateSummaries: summaries,
      maxTokens: maxTokens,
      maxConcurrentCalls: 1,
    );
    await extractor.extractForTopic(loadPost(topicId), []);
    return store.get(topicId);
  } finally {
    httpClient.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  }
}

/// Every download URL the model gave, across every mod on the thread.
List<String> allDownloadUrls(LlmStoreEntry? entry) => [
      for (final mod in entry?.mods ?? const <LlmMod>[])
        for (final download in mod.downloads) download.url,
    ];

/// The mod on the thread whose name holds [wanted], or null. Names are
/// compared on letters and digits only, so punctuation, capitals and spacing
/// don't matter — the model writes "Kwin's Sector Industry Compilation" one
/// run and "Kwins Sector Industry Compilation" the next, and that is not a
/// difference worth failing over.
LlmMod? modNamed(LlmStoreEntry? entry, String wanted) {
  for (final mod in entry?.mods ?? const <LlmMod>[]) {
    if (nameHolds(mod.name, wanted)) return mod;
  }
  return null;
}

/// True when [name] and [wanted] are the same name written differently.
bool sameName(String name, String wanted) => flatten(name) == flatten(wanted);

/// True when [name] holds [wanted] somewhere inside it, compared the same way.
bool nameHolds(String name, String wanted) =>
    flatten(name).contains(flatten(wanted));

String flatten(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// What the model said, written out for a failure message. A test that fails
/// here is usually a prompt to tighten, so the message has to show enough to
/// work from without running the whole thing again by hand.
String describe(LlmStoreEntry? entry) {
  if (entry == null) return '(nothing stored — the call failed)';
  final b = StringBuffer('isMod=${entry.isMod}, ${entry.mods.length} mod(s):');
  for (final mod in entry.mods) {
    b.write('\n  - "${mod.name}" (${mod.role}');
    if (mod.requires != null) b.write(', requires "${mod.requires}"');
    b.write(')');
    for (final d in mod.downloads) {
      b.write('\n      ${d.kind}: ${d.url}');
    }
    final needs = mod.extras?.needs;
    if (needs != null && needs.isNotEmpty) b.write('\n      needs: $needs');
    final version = mod.extras?.version;
    if (version != null) b.write('\n      version: $version');
  }
  return b.toString();
}
