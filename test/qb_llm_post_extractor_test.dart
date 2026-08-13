import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/download_resolver.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/extraction_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/llm_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/post_extractor.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/post_reducer.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/post_extraction.dart';
import 'package:test/test.dart';

/// A scripted [LlmClient]: each call returns (or throws) the next behavior.
class _FakeLlmClient implements LlmClient {
  final List<Object> behaviors; // LlmResponse to return, or Object to throw
  int callCount = 0;

  /// The temperature each call was made with, in order — lets a test check that
  /// a retry bumped it.
  final List<double> temperatures = [];

  /// The schema each call carried (or null), in order.
  final List<Map<String, dynamic>?> schemas = [];

  _FakeLlmClient(this.behaviors);

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    temperatures.add(request.temperature);
    schemas.add(request.jsonSchema);
    final i = callCount < behaviors.length ? callCount : behaviors.length - 1;
    callCount++;
    final behavior = behaviors[i];
    if (behavior is LlmResponse) return behavior;
    throw behavior;
  }
}

LlmResponse _json(String content, {String? finishReason}) =>
    LlmResponse(content: content, totalTokens: 42, finishReason: finishReason);

QbModDetail _detail(int topicId, String html,
        {List<LinkRef> links = const [],
        List<ImageRef> images = const [],
        String title = ''}) =>
    QbModDetail(
        topicId: topicId,
        contentHtml: html,
        links: links,
        images: images,
        title: title);

DownloadCandidate _rule(String sourceUrl, String resolvedUrl,
        {DownloadConfidence confidence = DownloadConfidence.high,
        String? archiveFilename}) =>
    DownloadCandidate(
      sourceUrl: sourceUrl,
      resolvedUrl: resolvedUrl,
      confidence: confidence,
      archiveFilename: archiveFilename,
    );

void main() {
  late Directory tempDir;
  late LlmExtractionStore store;
  late QbDownloadResolver resolver;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('llm_test');
    // Large flush threshold so we read the in-memory map, not disk cadence.
    store = LlmExtractionStore(tempDir.path, flushEveryN: 1000);
    // A resolver over a stub HTTP client, so resolving an LLM-only link never
    // touches the network. Empty 200s make host probes (Drive, GitHub) fall
    // back to a plain candidate instead of hanging.
    resolver = QbDownloadResolver(
      client: MockClient((req) async => http.Response('', 200)),
      dataPath: tempDir.path,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  PostExtractor makeExtractor(
    _FakeLlmClient client, {
    int maxConsecutiveFailures = 10,
    int? maxTopics,
    bool generateSummaries = false,
  }) =>
      PostExtractor(
        client: client,
        store: store,
        resolver: resolver,
        dataPath: tempDir.path,
        maxConsecutiveFailures: maxConsecutiveFailures,
        maxTopics: maxTopics,
        generateSummaries: generateSummaries,
      );

  // --- Small readers over the new per-thread mods shape ---

  List<LlmMod> modsOf(int id) => store.get(id)?.mods ?? const [];

  List<LlmDownload> downloadsOf(int id) =>
      modsOf(id).expand((m) => m.downloads).toList();

  /// The first mod's extras, or null when the thread has no (kept) mod.
  LlmExtras? extrasOf(int id) {
    final ms = modsOf(id);
    return ms.isEmpty ? null : ms.first.extras;
  }

  group('PostReducer', () {
    test('keeps links inside spoiler boxes', () {
      final html = 'Intro text '
          '<div class="sp-wrap"><div class="sp-body">'
          '<a href="https://example.com/mod.zip">Download</a>'
          '</div></div>';
      final reduced = PostReducer.reduce(html);
      expect(reduced.links.map((l) => l.url), contains('https://example.com/mod.zip'));
      expect(reduced.urlSet, contains('https://example.com/mod.zip'));
    });
  });

  group('checking answers against the post', () {
    test('invented URL is dropped, real one kept', () async {
      final client = _FakeLlmClient([
        _json('''
{"mods":[{"name":"Mod","role":"main","downloads":[
  {"url":"https://example.com/mod.zip","label":"Download","kind":"direct"},
  {"url":"https://invented.example/fake.zip","label":"x","kind":"direct"}
]}]}'''),
      ]);
      final extractor = makeExtractor(client);

      await extractor.extractForTopic(
        _detail(1, '<a href="https://example.com/mod.zip">Download</a>'),
        [],
      );

      expect(downloadsOf(1).map((d) => d.url), ['https://example.com/mod.zip']);
    });

    test('pulls the JSON out of a chatty reply with prose around it', () async {
      // Some local GGUFs ignore "JSON only" and wrap the object in prose. The
      // download URL "https://x.com/a{b}.zip" also proves brace-in-string is
      // handled: the "}" inside the URL must not end the object early.
      final client = _FakeLlmClient([
        _json('Here\'s a thinking process:\n'
            '{"mods":[{"name":"a","role":"main","downloads":[{"url":"https://x.com/a{b}.zip","label":"a","kind":"direct"}]}]}\n'
            'Hope that helps!'),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
        _detail(85, '<a href="https://x.com/a{b}.zip">a</a>',
            links: [
              LinkRef(url: 'https://x.com/a{b}.zip', text: 'a', isExternal: true)
            ]),
        [],
      );
      expect(downloadsOf(85).single.url, 'https://x.com/a{b}.zip');
    });

    test('keeps a URL the parser found but the reducer regex missed', () async {
      // The download link is written without quotes and has round brackets in
      // its path, so the reducer garbles it — but the page reader read it
      // cleanly, so it sits in detail.links. The check must fall back to that
      // fuller list.
      const url = 'https://example.com/hidden_(v2).zip';
      final html = '<a href=$url>Get it</a>';
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"m","role":"main","downloads":[{"url":"$url","label":"Get it","kind":"direct"}]}]}'),
      ]);
      final extractor = makeExtractor(client);

      // Confirm the reducer alone does NOT see this URL.
      final reduced = PostReducer.reduce(html);
      expect(reduced.urlSet, isNot(contains(url)));

      await extractor.extractForTopic(
        _detail(70, html,
            links: [LinkRef(url: url, text: 'Get it', isExternal: true)]),
        [],
      );

      expect(downloadsOf(70).map((d) => d.url), contains(url));
    });

    test('keeps a clean Drive link when the post link has junk on the end',
        () async {
      // Real case: the post's href has a stray "//link" glued on, and the
      // model returned the clean share URL. Both point at the same file, so the
      // check must accept it via the direct-download form.
      const clean =
          'https://drive.google.com/file/d/1ruyXhd3QekMrnkW-QF021TTSrdH3DAj6/view?usp=sharing';
      const inPost = '$clean//link';
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"Alice Blue","role":"main","downloads":[{"url":"$clean","label":"Alice Blue","kind":"direct"}]}]}'),
      ]);
      final extractor = makeExtractor(client);

      await extractor.extractForTopic(
        _detail(71, '<a href="$inPost">Alice Blue</a>',
            links: [LinkRef(url: inPost, text: 'Alice Blue', isExternal: true)]),
        [],
      );

      expect(downloadsOf(71).map((d) => d.url), contains(clean));
    });

    test('grounds text separated by &nbsp; in the post', () async {
      // Post keeps the literal entity; the model reads it back as a space.
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"m","role":"main","license":"CC BY-NC"}]}'),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
        _detail(60, 'License: CC&nbsp;BY-NC'),
        [],
      );
      expect(extrasOf(60)!.license, 'CC BY-NC');
    });

    test('license from an alt-text badge grounds', () async {
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"m","role":"main","license":"MIT"}]}'),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
        _detail(61,
            '<img alt="License: MIT" src="https://img.shields.io/badge/x">'),
        [],
      );
      expect(extrasOf(61)!.license, 'MIT');
    });

    test('license grounds via a license link even if the name is not in text',
        () async {
      // A Creative Commons badge: the canonical name is not spelled out, only
      // linked. The model naming it is still grounded.
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"m","role":"main","license":"CC BY-NC 4.0"}]}'),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
        _detail(62,
            'Released under this license: <a href="https://creativecommons.org/licenses/by-nc/4.0/">badge</a>'),
        [],
      );
      expect(extrasOf(62)!.license, 'CC BY-NC 4.0');
    });

    test('invented license with no supporting link or text is dropped',
        () async {
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"","role":"main","license":"WTFPL"}]}'),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
        _detail(63, 'A cool mod with some ships. No license mentioned.'),
        [],
      );
      expect(extrasOf(63)?.license, isNull);
    });

    test('version not present in post is left blank', () async {
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"","role":"main","version":"9.9.9-invented"}]}'),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(_detail(2, 'A mod, version 1.0.'), []);
      expect(extrasOf(2)?.version, isNull);
    });

    test('version found only in the thread title still grounds', () async {
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"My Mod","role":"main","version":"1.2.3"}]}'),
      ]);
      final extractor = makeExtractor(client);
      // Version is in the title, not the post body.
      await extractor.extractForTopic(
        _detail(3, 'Here is my cool mod. Enjoy!', title: '[0.98a] My Mod v1.2.3'),
        [],
      );
      expect(extrasOf(3)?.version, '1.2.3');
    });
  });

  group('mods list', () {
    test('a single-mod thread is a one-item list with role main', () async {
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"Solo","role":"main","downloads":[{"url":"https://example.com/solo.zip","label":"dl","kind":"direct"}]}]}'),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
        _detail(100, '<a href="https://example.com/solo.zip">dl</a>'),
        [],
      );
      final mods = modsOf(100);
      expect(mods, hasLength(1));
      expect(mods.single.name, 'Solo');
      expect(mods.single.role, LlmModRole.main);
      expect(mods.single.downloads.single.url, 'https://example.com/solo.zip');
    });

    test('a main mod plus an add-on keeps both, add-on requires the main mod',
        () async {
      final client = _FakeLlmClient([
        _json('''
{"mods":[
  {"name":"Base","role":"main","downloads":[{"url":"https://example.com/base.zip","label":"Base","kind":"direct"}]},
  {"name":"Extra","role":"addon","requires":"Base","downloads":[{"url":"https://example.com/extra.zip","label":"Extra","kind":"direct"}]}
]}'''),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
        _detail(
            101,
            '<a href="https://example.com/base.zip">Base</a> '
            '<a href="https://example.com/extra.zip">Extra</a>'),
        [],
      );
      final mods = modsOf(101);
      expect(mods.map((m) => m.name), ['Base', 'Extra']);
      expect(mods[0].role, LlmModRole.main);
      expect(mods[1].role, LlmModRole.addon);
      expect(mods[1].requires, 'Base');
    });

    test('a mirror is a second download under the same mod with kind mirror',
        () async {
      final client = _FakeLlmClient([
        _json('''
{"mods":[{"name":"Mirrored","role":"main","downloads":[
  {"url":"https://example.com/main.zip","label":"Download","kind":"direct"},
  {"url":"https://mirror.example/main.zip","label":"Mirror","kind":"mirror"}
]}]}'''),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
        _detail(
            102,
            '<a href="https://example.com/main.zip">Download</a> '
            '<a href="https://mirror.example/main.zip">Mirror</a>'),
        [],
      );
      final dls = modsOf(102).single.downloads;
      expect(dls, hasLength(2));
      expect(dls.map((d) => d.kind), [LlmDownloadKind.direct, LlmDownloadKind.mirror]);
    });

    test('a mod whose only download is not in the post is dropped', () async {
      // The second "mod" is only mentioned (its download URL is not in the
      // post), so grounding removes its download and the empty mod is dropped —
      // only mods actually downloadable from this thread survive.
      final client = _FakeLlmClient([
        _json('''
{"mods":[
  {"name":"Real","role":"main","downloads":[{"url":"https://example.com/real.zip","label":"Real","kind":"direct"}]},
  {"name":"Mentioned","role":"separate","downloads":[{"url":"https://elsewhere.example/other.zip","label":"Other","kind":"direct"}]}
]}'''),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
        _detail(103, '<a href="https://example.com/real.zip">Real</a>'),
        [],
      );
      expect(modsOf(103).map((m) => m.name), ['Real']);
    });
  });

  group('per-mod image', () {
    test('an image in the post is kept, stored as ext:<url>', () async {
      const img = 'https://example.com/banner.png';
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"Solo","role":"main","image":"$img",'
            '"downloads":[{"url":"https://example.com/solo.zip","label":"dl","kind":"direct"}]}]}'),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
        _detail(110, '<a href="https://example.com/solo.zip">dl</a>',
            images: [ImageRef(originalUrl: img, alt: 'Banner')]),
        [],
      );
      expect(modsOf(110).single.image, 'ext:$img');
    });

    test('an image not among the post images is dropped', () async {
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"Solo","role":"main",'
            '"image":"https://invented.example/made-up.png",'
            '"downloads":[{"url":"https://example.com/solo.zip","label":"dl","kind":"direct"}]}]}'),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
        _detail(111, '<a href="https://example.com/solo.zip">dl</a>',
            images: [
              ImageRef(originalUrl: 'https://example.com/real.png')
            ]),
        [],
      );
      expect(modsOf(111).single.image, isNull);
    });

    test('a badge image is never used even if the model returns it', () async {
      const badge = 'https://img.shields.io/badge/license-MIT-blue';
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"Solo","role":"main","image":"$badge",'
            '"downloads":[{"url":"https://example.com/solo.zip","label":"dl","kind":"direct"}]}]}'),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
        _detail(112, '<a href="https://example.com/solo.zip">dl</a>',
            images: [ImageRef(originalUrl: badge, alt: 'License: MIT')]),
        [],
      );
      // The badge is filtered out of the post images, so it cannot be grounded.
      expect(modsOf(112).single.image, isNull);
    });

    test('each mod in a multi-mod thread keeps its own image', () async {
      const baseImg = 'https://example.com/base.png';
      const extraImg = 'https://example.com/extra.png';
      final client = _FakeLlmClient([
        _json('''
{"mods":[
  {"name":"Base","role":"main","image":"$baseImg","downloads":[{"url":"https://example.com/base.zip","label":"Base","kind":"direct"}]},
  {"name":"Extra","role":"addon","requires":"Base","image":"$extraImg","downloads":[{"url":"https://example.com/extra.zip","label":"Extra","kind":"direct"}]}
]}'''),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
        _detail(
            113,
            '<a href="https://example.com/base.zip">Base</a> '
            '<a href="https://example.com/extra.zip">Extra</a>',
            images: [
              ImageRef(originalUrl: baseImg),
              ImageRef(originalUrl: extraImg),
            ]),
        [],
      );
      final mods = modsOf(113);
      expect(mods.map((m) => m.image), ['ext:$baseImg', 'ext:$extraImg']);
    });
  });

  group('support links', () {
    test('each verified link gets a type worked out from its host', () async {
      final client = _FakeLlmClient([
        _json('''
{"mods":[{"name":"m","role":"main","supportLinks":[
  "https://www.patreon.com/someone",
  "https://ko-fi.com/someone",
  "https://example.com/donate.html"
]}]}'''),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
        _detail(
            80,
            'Support me: '
            '<a href="https://www.patreon.com/someone">Patreon</a> '
            '<a href="https://ko-fi.com/someone">Ko-fi</a> '
            '<a href="https://example.com/donate.html">Donate</a>'),
        [],
      );

      final links = extrasOf(80)!.supportLinks!;
      expect(
        links.map((s) => (s.url, s.type)),
        [
          ('https://www.patreon.com/someone', 'patreon'),
          ('https://ko-fi.com/someone', 'kofi'),
          ('https://example.com/donate.html', 'other'),
        ],
      );
    });

    test('unknown URL falls back to "other"', () {
      expect(SupportLinkType.fromUrl('not a url'), 'other');
      expect(SupportLinkType.fromUrl('https://github.com/user/repo'), 'other');
      expect(SupportLinkType.fromUrl('https://github.com/sponsors/user'),
          'githubsponsors');
    });

    test('an entry saved under an older schema version is dropped on load',
        () async {
      // The schema bump means stale entries are skipped and re-derived rather
      // than mis-read against the new per-thread mods layout.
      final file = File('${tempDir.path}/llm-extraction-cache.json');
      file.writeAsStringSync('''
{
  "90": {
    "fingerprint": "abc",
    "schemaVersion": 2,
    "promptVersion": 4,
    "downloads": []
  }
}''');

      final fresh = LlmExtractionStore(tempDir.path);
      await fresh.load();

      expect(fresh.get(90), isNull);
    });
  });

  group('changelog', () {
    test('keeps every copied version (changelog matching is lenient)', () async {
      final client = _FakeLlmClient([
        _json('''
{"mods":[{"name":"m","role":"main","changelog":{"entries":{
  "1.2.0":"added ships",
  "1.1.0":"fixed bugs"
}}}]}'''),
      ]);
      final extractor = makeExtractor(client);

      await extractor.extractForTopic(
        _detail(50, '<div>Changelog: 1.2.0 added ships. 1.1.0 fixed bugs.</div>'),
        [],
      );

      final entries = extrasOf(50)!.changelog!.entries!;
      expect(entries.keys, containsAll(['1.2.0', '1.1.0']));
      expect(entries['1.2.0'], 'added ships');
    });

    test('a link and copied entries are both kept', () async {
      const url = 'https://example.com/changelog.txt';
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"m","role":"main","changelog":{"link":"$url","entries":{"1.0":"notes"}}}]}'),
      ]);
      final extractor = makeExtractor(client);

      await extractor.extractForTopic(
        _detail(51, '<a href="$url">changelog</a> 1.0 notes'),
        [],
      );

      final changelog = extrasOf(51)!.changelog!;
      expect(changelog.link, url);
      expect(changelog.entries, {'1.0': 'notes'});
    });
  });

  group('save compatibility', () {
    test('text found in the post is kept word-for-word', () async {
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"m","role":"main","saveCompatibility":"Save compatible"}]}'),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
        _detail(120, 'A cool mod. Save compatible, add it any time.'),
        [],
      );
      expect(extrasOf(120)!.saveCompatibility, 'Save compatible');
    });

    test('a needs-new-game note found in the post is kept', () async {
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"m","role":"main","saveCompatibility":"Requires a new game"}]}'),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
        _detail(121, 'Heads up: Requires a new game to work properly.'),
        [],
      );
      expect(extrasOf(121)!.saveCompatibility, 'Requires a new game');
    });

    test('save-compatibility text not in the post is dropped', () async {
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"","role":"main","saveCompatibility":"Save compatible"}]}'),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
        _detail(122, 'A mod with some ships. Nothing about saves here.'),
        [],
      );
      expect(extrasOf(122)?.saveCompatibility, isNull);
    });
  });

  group('source code', () {
    test('a repository link in the post is kept', () async {
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"m","role":"main",'
            '"sourceCode":"https://github.com/someone/theirmod"}]}'),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
        _detail(130,
            'Code is here: <a href="https://github.com/someone/theirmod">GitHub</a>'),
        [],
      );
      expect(extrasOf(130)!.sourceCode, 'https://github.com/someone/theirmod');
    });

    test('a link that is not in the post is dropped', () async {
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"","role":"main",'
            '"sourceCode":"https://github.com/someone/guessed"}]}'),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
        _detail(131, 'A mod with some ships. No repository linked.'),
        [],
      );
      expect(extrasOf(131)?.sourceCode, isNull);
    });

    test('a file inside the repository proves the repository', () async {
      // The post links a zip held in the repo, never the repo's own page. The
      // link still says which repo it is, so the repo counts as stated — and
      // the post's spelling of it is what gets kept, not the model's.
      const zip = 'https://github.com/connortron7/keruvim-shipyards/raw/'
          'master/keruvim%20shipyards%200.6.1.zip';
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"m","role":"main",'
            '"sourceCode":"https://github.com/connortron7/Keruvim-Shipyards",'
            '"downloads":[{"url":"$zip","label":"Download","kind":"direct"}]}]}'),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
        _detail(133, '<a href="$zip">Download</a>'),
        [],
      );
      expect(extrasOf(133)!.sourceCode,
          'https://github.com/connortron7/keruvim-shipyards');
    });

    test('a clone link names the same repository', () async {
      // The post gives the link you would hand to git, ending in ".git". That
      // is the same repository, and what is stored is the page, not the clone
      // link.
      const clone = 'https://github.com/Dhunt05/Guardian-Prototype.git';
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"m","role":"main",'
            '"sourceCode":"https://github.com/Dhunt05/Guardian-Prototype"}]}'),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
        _detail(136, 'Clone it: <a href="$clone">$clone</a>'),
        [],
      );
      expect(extrasOf(136)!.sourceCode,
          'https://github.com/Dhunt05/Guardian-Prototype');
    });

    test('the clone link itself is stored as the repository page', () async {
      const clone = 'https://github.com/Dhunt05/Guardian-Prototype.git';
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"m","role":"main","sourceCode":"$clone"}]}'),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
        _detail(137, 'Clone it: <a href="$clone">$clone</a>'),
        [],
      );
      expect(extrasOf(137)!.sourceCode,
          'https://github.com/Dhunt05/Guardian-Prototype');
    });

    test('a link to someone else\'s repository is still dropped', () async {
      const zip = 'https://github.com/connortron7/keruvim-shipyards/raw/'
          'master/mod.zip';
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"m","role":"main",'
            '"sourceCode":"https://github.com/someoneelse/otherthing",'
            '"downloads":[{"url":"$zip","label":"Download","kind":"direct"}]}]}'),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
        _detail(134, '<a href="$zip">Download</a>'),
        [],
      );
      expect(extrasOf(134)?.sourceCode, isNull);
    });

    test('an author page is not a repository', () async {
      const zip = 'https://github.com/connortron7/keruvim-shipyards/raw/'
          'master/mod.zip';
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"m","role":"main",'
            '"sourceCode":"https://github.com/connortron7",'
            '"downloads":[{"url":"$zip","label":"Download","kind":"direct"}]}]}'),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
        _detail(135, '<a href="$zip">Download</a>'),
        [],
      );
      expect(extrasOf(135)?.sourceCode, isNull);
    });

    test('a release file is not treated as the source code', () async {
      const asset =
          'https://github.com/someone/theirmod/releases/download/v1.0/mod.zip';
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"m","role":"main","sourceCode":"$asset",'
            '"downloads":[{"url":"$asset","label":"Download","kind":"direct"}]}]}'),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
        _detail(132, '<a href="$asset">Download</a>'),
        [],
      );
      expect(extrasOf(132)?.sourceCode, isNull);
      // The same link is still a perfectly good download.
      expect(downloadsOf(132).map((d) => d.url), [asset]);
    });
  });

  group('resolving downloads', () {
    test('a download the rules already resolved reuses the resolved fields',
        () async {
      const original = 'https://drive.google.com/file/d/ABC123/view';
      const resolved =
          'https://drive.google.com/uc?export=download&id=ABC123';
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"m","role":"main","downloads":[{"url":"$original","label":"Get it","kind":"direct"}]}]}'),
      ]);
      final extractor = makeExtractor(client);

      await extractor.extractForTopic(
        _detail(3, '<a href="$original">Get it</a>'),
        [_rule(original, resolved, archiveFilename: 'mod.zip')],
      );

      final dl = downloadsOf(3).single;
      expect(dl.url, original);
      expect(dl.resolvedDirectUrl, resolved);
      expect(dl.fileName, 'mod.zip');
      expect(dl.sourceHost, 'Google Drive');
    });

    test('a rule link the LLM does not list is not in the mod downloads',
        () async {
      // The rules flag a dependency as a download, but the LLM, seeing the whole
      // post, groups only the real download under the mod. The dependency does
      // not appear in the mod's downloads.
      const dep = 'https://example.com/dependency.zip';
      const real = 'https://example.com/mod.zip';
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"m","role":"main","downloads":[{"url":"$real","label":"Download","kind":"direct"}]}]}'),
      ]);
      final extractor = makeExtractor(client);

      await extractor.extractForTopic(
        _detail(
            4,
            '<a href="$dep">Dependency</a> <a href="$real">Download</a>'),
        [_rule(dep, dep), _rule(real, real)],
      );

      final urls = downloadsOf(4).map((d) => d.url).toList();
      expect(urls, [real]);
      expect(urls, isNot(contains(dep)));
    });
  });

  group('failure handling', () {
    test('both attempts fail → fallback, no store entry', () async {
      final client = _FakeLlmClient([
        LlmException('boom-1'),
        LlmException('boom-2'),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(_detail(5, '<a href="https://x.com/a.zip">a</a>'), []);
      expect(store.get(5), isNull);
      expect(client.callCount, 3); // two retries
    });

    test('first attempt fails, retry succeeds → retry answer used', () async {
      final client = _FakeLlmClient([
        LlmException('transient'),
        _json('{"mods":[{"name":"a","role":"main","downloads":[{"url":"https://x.com/a.zip","label":"a","kind":"direct"}]}]}'),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(_detail(6, '<a href="https://x.com/a.zip">a</a>'), []);
      expect(client.callCount, 2);
      expect(downloadsOf(6).single.url, 'https://x.com/a.zip');
      // A network retry keeps the original (deterministic) temperature.
      expect(client.temperatures, [0, 0]);
    });

    test('unparseable JSON is retried at a higher temperature, then recovers',
        () async {
      final client = _FakeLlmClient([
        // Returns (no exception) but the body is not valid JSON.
        _json('this is not json at all'),
        _json('{"mods":[{"name":"a","role":"main","downloads":[{"url":"https://x.com/a.zip","label":"a","kind":"direct"}]}]}'),
      ]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
          _detail(8, '<a href="https://x.com/a.zip">a</a>'), []);
      expect(client.callCount, 2);
      expect(downloadsOf(8).single.url, 'https://x.com/a.zip');
      // First try at 0; the parse failure bumps the retry above 0.
      expect(client.temperatures.first, 0);
      expect(client.temperatures[1], greaterThan(0));
    });

    test('unparseable JSON on every attempt → no store entry, one slot spent',
        () async {
      final client = _FakeLlmClient([_json('not json')]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
          _detail(9, '<a href="https://x.com/a.zip">a</a>'), []);
      expect(store.get(9), isNull);
      expect(client.callCount, 3); // all attempts used
      expect(extractor.liveCallCount, 1); // but only one slot was reserved
    });

    test('consecutive failures bail; a success resets the count', () async {
      // Always throws.
      final client = _FakeLlmClient([LlmException('down')]);
      final extractor = makeExtractor(client, maxConsecutiveFailures: 2);

      await extractor.extractForTopic(_detail(10, '<a href="https://x/a.zip">a</a>'), []);
      expect(extractor.hasBailed, isFalse);
      await extractor.extractForTopic(_detail(11, '<a href="https://x/b.zip">b</a>'), []);
      expect(extractor.hasBailed, isTrue);

      final before = client.callCount;
      // Once bailed, no further calls are made.
      await extractor.extractForTopic(_detail(12, '<a href="https://x/c.zip">c</a>'), []);
      expect(client.callCount, before);
    });

    test('scattered failures do not bail (success resets)', () async {
      final client = _FakeLlmClient([
        LlmException('f1'),
        LlmException('f1-retry'),
        _json('{"mods":[]}'), // topic 21 succeeds
        _json('{"mods":[]}'),
        LlmException('f2'),
        LlmException('f2-retry'),
      ]);
      final extractor = makeExtractor(client, maxConsecutiveFailures: 2);
      await extractor.extractForTopic(_detail(20, 'x'), []); // fail (2 attempts)
      await extractor.extractForTopic(_detail(21, 'x'), []); // success → reset
      await extractor.extractForTopic(_detail(22, 'x'), []); // fail (2 attempts)
      expect(extractor.hasBailed, isFalse);
    });
  });

  group('cache / resume', () {
    test('second run on unchanged post makes no new call', () async {
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"a","role":"main","downloads":[{"url":"https://x.com/a.zip","label":"a","kind":"direct"}]}]}'),
      ]);
      final extractor = makeExtractor(client);
      final detail = _detail(7, '<a href="https://x.com/a.zip">a</a>');

      await extractor.extractForTopic(detail, []);
      expect(client.callCount, 1);

      // Same post again → served from the store, no network call.
      await extractor.extractForTopic(detail, []);
      expect(client.callCount, 1);
    });
  });

  group('volume cap', () {
    test('cap stops new calls once reached', () async {
      final client = _FakeLlmClient([_json('{"mods":[]}')]);
      final extractor = makeExtractor(client, maxTopics: 1);
      await extractor.extractForTopic(_detail(30, 'x'), []);
      await extractor.extractForTopic(_detail(31, 'x'), []);
      expect(client.callCount, 1); // second topic skipped by the cap
    });
  });

  group('placeholder', () {
    test('placeholder posts are skipped without a call', () async {
      final client = _FakeLlmClient([_json('{"mods":[]}')]);
      final extractor = makeExtractor(client);
      await extractor.extractForTopic(
        QbModDetail(topicId: 40, contentHtml: 'x', isPlaceholderDetail: true),
        [],
      );
      expect(client.callCount, 0);
    });
  });

  group('summaries', () {
    test('summary is stored as-is (not checked against the post)', () async {
      // The paragraph says things the post never states — summaries are the
      // model's own words, so nothing is dropped for being absent from the post.
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"m","role":"main","summary":{'
            '"sentence":"A ship pack that adds a new faction.",'
            '"paragraph":"This mod adds several new ships and a small faction."'
            '}}]}'),
      ]);
      final extractor = makeExtractor(client, generateSummaries: true);
      await extractor.extractForTopic(_detail(80, 'Some post text'), []);

      final summary = extrasOf(80)!.summary!;
      expect(summary.sentence, 'A ship pack that adds a new faction.');
      expect(summary.paragraph,
          'This mod adds several new ships and a small faction.');
    });

    test('summaries off: a summary in the answer is ignored', () async {
      final client = _FakeLlmClient([
        _json('{"mods":[{"name":"","role":"main","summary":{"sentence":"x","paragraph":"y"}}]}'),
      ]);
      final extractor = makeExtractor(client); // generateSummaries defaults off
      await extractor.extractForTopic(_detail(81, 'text'), []);
      expect(extrasOf(81), isNull);
    });

    test('turning summaries on re-runs a post cached without them', () async {
      final withoutClient = _FakeLlmClient([_json('{"mods":[]}')]);
      final detail = _detail(82, 'text');

      // First pass, summaries off: cached with no mods.
      await makeExtractor(withoutClient).extractForTopic(detail, []);
      expect(extrasOf(82), isNull);

      // Second pass, summaries on: the cache key changed, so it calls again.
      final withClient = _FakeLlmClient([
        _json('{"mods":[{"name":"m","role":"main","summary":{"sentence":"s","paragraph":"p"}}]}'),
      ]);
      await makeExtractor(withClient, generateSummaries: true)
          .extractForTopic(detail, []);
      expect(withClient.callCount, 1);
      expect(extrasOf(82)!.summary!.sentence, 's');
    });
  });
}
