import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:synchronized/synchronized.dart';

import '../download_resolver.dart';
import '../html_processor.dart';
import '../models/assumed_download.dart';
import '../models/mod_detail.dart';
import '../models/post_extraction.dart';
import '../url_normalizer.dart';
import '../../../../site/description_slice.dart';
import '../../../../site/gallery_filter.dart';
import 'extraction_store.dart';
import 'llm_client.dart';
import 'post_reducer.dart';
import 'prompt.dart';

/// One download line the model returned, before it is grounded or resolved.
class _RawDownload {
  final String url;
  final String label;
  final String kind;
  _RawDownload(this.url, this.label, this.kind);
}

/// One mod the model returned, parsed but not yet checked against the post.
class _RawMod {
  final String name;
  final String role;
  final String? requires;
  final List<_RawDownload> downloads;

  /// A post image URL the model tied to this mod, before it is checked against
  /// the post's real images. Null when the model chose none.
  final String? image;
  final String? changelogLink;

  /// Changelog notes keyed by version string. Empty when the model returned a
  /// link or no changelog text.
  final Map<String, String> changelogEntries;
  final String? version;
  final List<String> supportLinks;
  final String? license;

  /// A link to where the mod's code is kept, before it is checked against the
  /// post's links.
  final String? sourceCode;
  final String? saveCompatibility;

  /// The generated summary, when summaries are on and the model returned one.
  /// Not checked against the post (it is written, not copied).
  final LlmModSummary? summary;

  /// The other mods this one needs, before they are checked against the post.
  final List<String> needs;

  /// Where in the post the author describes this mod: the first few words and
  /// the last few words of that stretch of text. Checked against the posts
  /// before it is kept.
  final LlmDescriptionAnchors? descriptionAnchors;

  _RawMod({
    required this.name,
    required this.role,
    this.requires,
    required this.downloads,
    this.image,
    this.changelogLink,
    required this.changelogEntries,
    this.version,
    required this.supportLinks,
    this.license,
    this.sourceCode,
    this.saveCompatibility,
    this.summary,
    this.needs = const [],
    this.descriptionAnchors,
  });
}

/// The author's opening posts, cleaned up for the model.
///
/// [posts] is one entry per post, in the order they were posted — the prompt
/// shows them apart, and a description anchor has to sit inside one of them.
/// [combined] is the same thing as a single post, which is what every check
/// that treats a thread as one lump of text reads.
class _ReadPosts {
  final List<ReducedPost> posts;
  final ReducedPost combined;

  _ReadPosts(this.posts, this.combined);

  factory _ReadPosts.of(QbModDetail detail) {
    final posts = [
      for (final post in detail.openingPosts)
        PostReducer.reduce(post.contentHtml),
    ];

    final links = <String, ReducedLink>{};
    final urls = <String>{};
    for (final post in posts) {
      for (final link in post.links) {
        links.putIfAbsent(
            PostReducer.normalizeForMatching(link.url), () => link);
      }
      urls.addAll(post.urlSet);
    }

    return _ReadPosts(
      posts,
      ReducedPost(
        text: posts
            .map((p) => p.text)
            .where((t) => t.trim().isNotEmpty)
            .join('\n\n'),
        links: links.values.toList(),
        urlSet: urls,
      ),
    );
  }

  /// The first post's text. Empty when the thread somehow has no posts.
  String get firstText => posts.isEmpty ? '' : posts.first.text;

  /// The author's later posts' text, in order.
  List<String> get followUpTexts =>
      posts.length < 2 ? const [] : [for (final p in posts.skip(1)) p.text];
}

/// The model's answer: the list of mods it found for the thread, and its call
/// on whether the thread is a downloadable mod release at all.
class _LlmAnswer {
  final List<_RawMod> mods;
  final bool isMod;
  _LlmAnswer(this.mods, {this.isMod = true});
}

/// A successful call: the raw response plus the parsed answer.
class _Attempt {
  final LlmResponse response;
  final _LlmAnswer answer;
  _Attempt(this.response, this.answer);
}

/// Reads each scraped post once with the LLM and turns the answer into a list of
/// mods, each with its own grounded, resolver-filled downloads and extras.
/// Handles retry, stopping after repeated failures, and the optional limit. Safe
/// to call from multiple places at once: shared counters use a lock.
class PostExtractor {
  /// The fields we always ask the model for; changing these re-runs cached
  /// posts. When [generateSummaries] is on, 'summary' is added on top (see
  /// [_effectiveFieldSet]).
  static const List<String> fieldSet = [
    'isMod',
    'mods',
    'downloads',
    'image',
    'changelog',
    'version',
    'supportLinks',
    'license',
    'sourceCode',
    'saveCompatibility',
    'needs',
    'descriptionAnchors',
  ];

  final LlmClient _client;
  final LlmExtractionStore _store;

  /// Resolves the links the LLM chooses, so each stored download carries a
  /// direct URL, filename, and manual-step flag — the same work the rules-based
  /// download step does.
  final QbDownloadResolver _resolver;

  final Logger _log;

  final int maxConsecutiveFailures;
  final int? maxTopics;

  /// Cap on tokens per reply. null = [ExtractionPrompt.maxTokens]. Raise it for
  /// reasoning models that can't turn thinking off, so the reply is not cut off
  /// before the JSON is written.
  final int? maxTokens;

  /// Cap on how many characters of the post body are sent to the model. null =
  /// no cap. Guards against a very long post overflowing the model's context
  /// window. Only the body text is trimmed; the title and links are always sent
  /// in full, and grounding still checks the model's answer against the whole
  /// post, not the trimmed copy.
  final int? maxInputChars;

  /// When true, ask the model for a plain-English summary too, and include it
  /// in each mod's extras.
  final bool generateSummaries;

  final bool testMode;
  final int testLimit;
  final Set<int>? testTopicIds;
  final String _dataPath;

  /// How many topics may be talking to the model at the same time. A caller
  /// can start a read for every topic it has and move on; only this many are
  /// actually in flight, and the rest wait their turn. From
  /// `llm_max_concurrent_calls`.
  final int maxConcurrentCalls;

  final Lock _lock = Lock();
  int _consecutiveFailures = 0;
  bool _bailed = false;
  int _processed = 0;

  late final _CallSlots _slots =
      _CallSlots(maxConcurrentCalls < 1 ? 1 : maxConcurrentCalls);

  /// Set when a caller asked for no more calls (a cancelled run). Reads
  /// already talking to the model finish and are kept; reads still waiting
  /// their turn come back without calling.
  bool _stopAsked = false;

  int _testCallCount = 0;
  final List<Map<String, dynamic>> _testReport = [];

  PostExtractor({
    required LlmClient client,
    required LlmExtractionStore store,
    required QbDownloadResolver resolver,
    required String dataPath,
    this.maxConsecutiveFailures = 10,
    this.maxTopics,
    this.maxConcurrentCalls = 3,
    this.maxTokens,
    this.maxInputChars,
    this.generateSummaries = false,
    this.testMode = false,
    this.testLimit = 5,
    this.testTopicIds,
    Logger? logger,
  })  : _client = client,
        _store = store,
        _resolver = resolver,
        _dataPath = dataPath,
        _log = logger ?? Logger('PostExtractor');

  bool get hasBailed => _bailed;

  /// Asks for no more calls this run. Reads already talking to the model
  /// finish and their answers are kept; reads still waiting their turn come
  /// back without calling. For a cancelled run with reads queued up — they
  /// should not keep spending money after the person said stop.
  void stopNewCalls() => _stopAsked = true;

  /// How many live calls this run has spent, counting the ones that failed.
  /// This is what [maxTopics] caps, so a caller can tell whether the run still
  /// has budget left and report how much of it was used.
  int get liveCallCount => _processed;

  /// The field set for the current settings: [fieldSet], plus 'summary' when
  /// summaries are on. Part of the cache key, so flipping summaries on re-runs
  /// posts and flipping it off returns to the earlier cached results.
  List<String> get _effectiveFieldSet =>
      generateSummaries ? [...fieldSet, 'summary'] : fieldSet;

  /// How many live test-mode calls have been made so far (for driving the loop
  /// that feeds stored posts in).
  int get testCallCount => _testCallCount;

  // ---------------------------------------------------------------------------
  // Entry point
  // ---------------------------------------------------------------------------

  /// Returns true when a live call was spent on this topic (a failed call
  /// counts — it still spent the budget), false when a stored answer, a
  /// guardrail, or [stopNewCalls] meant no call was made. Test mode always
  /// returns false; it keeps its own counter ([testCallCount]).
  Future<bool> extractForTopic(
    QbModDetail detail,
    List<DownloadCandidate> ruleCandidates,
  ) async {
    // Never spend a call on a stub post.
    if (detail.isPlaceholderDetail) {
      _log.fine('Skipping placeholder topic ${detail.topicId}');
      return false;
    }

    if (testMode) {
      await _extractTestMode(detail, ruleCandidates);
      return false;
    }

    final read = _ReadPosts.of(detail);
    final userPrompt = _buildUserPrompt(detail, read, ruleCandidates);

    final fingerprint = LlmExtractionStore.computeFingerprint(
      userPrompt: userPrompt,
      promptVersion: ExtractionPrompt.promptVersion,
      fieldSet: _effectiveFieldSet,
    );

    // Already done (also lets interrupted runs pick up here): skip the call.
    //
    // This check must stay ahead of _reserveSlot(): a stored result costs no
    // [maxTopics] budget, so a capped run spends its budget only on topics that
    // really need a call. That is what lets a run over every stored topic pick
    // up where the last one stopped instead of re-chewing the same first few
    // topics every time.
    if (_store.isFresh(
        detail.topicId, fingerprint, ExtractionPrompt.promptVersion)) {
      _log.fine('LLM store hit for topic ${detail.topicId}');
      return false;
    }

    // Wait for a turn. Callers fire a read per topic without waiting for the
    // answers, so this is the one place that keeps the calls to
    // [maxConcurrentCalls] at a time. Everything past this point — the call
    // and putting its answer away — happens inside the slot.
    await _slots.take();
    try {
      // The run was cancelled while this read waited its turn.
      if (_stopAsked) {
        _log.fine('Skipping topic ${detail.topicId} (asked to stop)');
        return false;
      }

      // Check if we've stopped or hit the limit before making a call. Inside
      // the slot on purpose: budget is spent in the order calls are actually
      // made, not the order reads were started.
      if (!await _reserveSlot()) {
        _log.fine('Skipping topic ${detail.topicId} '
            '(${_bailed ? 'LLM gave up' : 'limit reached'})');
        return false;
      }

      await _callAndStore(detail, read, ruleCandidates, userPrompt, fingerprint);
      return true;
    } finally {
      _slots.release();
    }
  }

  /// The live half of [extractForTopic]: one call to the model, the answer
  /// checked against the post and put in the store. Runs inside a
  /// [_CallSlots] slot, after the budget was spent on it.
  Future<void> _callAndStore(
    QbModDetail detail,
    _ReadPosts read,
    List<DownloadCandidate> ruleCandidates,
    String userPrompt,
    String fingerprint,
  ) async {
    final request = LlmRequest(
      systemPrompt:
          ExtractionPrompt.buildSystemPrompt(includeSummary: generateSummaries),
      userPrompt: userPrompt,
      temperature: ExtractionPrompt.temperature,
      maxTokens: maxTokens ?? ExtractionPrompt.maxTokens,
      // The client only sends this when structured output is on; it does not
      // affect the cache key, so turning structured output on/off does not
      // re-run stored posts.
      jsonSchema:
          ExtractionPrompt.buildResponseSchema(includeSummary: generateSummaries),
    );

    final attempt = await _callWithRetry(request, detail.topicId);
    if (attempt == null) {
      await _recordFailure(detail.topicId);
      _log.warning(
          'LLM extraction failed for topic ${detail.topicId}; using rule-based results instead');
      return;
    }
    await _recordSuccess();
    _log.info('LLM ok for topic ${detail.topicId} '
        '(${attempt.response.usageSummary})');

    final postUrls = _postUrls(detail, read.combined, ruleCandidates);
    final postImages = _postImages(detail);
    final postRepoUrls = _postRepoUrls(detail, read.combined, ruleCandidates);
    final checked = _checkAgainstPost(detail.topicId, attempt.answer, read,
        postUrls, postImages, postRepoUrls,
        truncated: attempt.response.wasTruncated, postTitle: detail.title);
    final mods = await _resolveMods(checked, ruleCandidates);

    await _store.put(
      detail.topicId,
      LlmStoreEntry(
        fingerprint: fingerprint,
        schemaVersion: LlmExtractionStore.schemaVersion,
        promptVersion: ExtractionPrompt.promptVersion,
        mods: mods,
        isMod: attempt.answer.isMod,
        stats: attempt.response.stats,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Prompt building
  // ---------------------------------------------------------------------------

  String _buildUserPrompt(
    QbModDetail detail,
    _ReadPosts read,
    List<DownloadCandidate> ruleCandidates,
  ) {
    final reduced = read.combined;

    // Flag reduced links the scraper already marked downloadable.
    final downloadable = <String, bool>{
      for (final l in detail.allLinks)
        PostReducer.normalizeForMatching(l.url): l.isDownloadable,
    };
    final links = reduced.links
        .map((l) => (
              url: l.url,
              text: l.text,
              isDownloadable:
                  downloadable[PostReducer.normalizeForMatching(l.url)] ??
                      false,
            ))
        .toList();

    // Rule links handed to the model as their ORIGINAL post URLs.
    final ruleLinks = ruleCandidates.map((c) => c.sourceUrl).toList();

    // Trim only the body text when a cap is set, so a very long post can't
    // overflow the model's context window. The title and links are still sent
    // in full below, and grounding checks against the whole post.
    //
    // The author's later posts keep their words; the first post gives up
    // whatever room is left over. Those later posts are short and are usually
    // where the downloads are, while the first post is the long write-up — so
    // trimming in the order they were posted would let a huge first post push
    // the Downloads post out of the prompt entirely, which is the very thing
    // reading them was for.
    var bodyText = read.firstText;
    final followUpTexts = read.followUpTexts;
    final cap = maxInputChars;
    if (cap != null) {
      final followUpLength =
          followUpTexts.fold<int>(0, (n, text) => n + text.length);
      final roomForFirst = cap - followUpLength;
      if (bodyText.length > roomForFirst) {
        _log.warning(
            'The opening posts of topic ${detail.topicId} run to '
            '${bodyText.length + followUpLength} chars; trimming the first '
            'post to ${roomForFirst < 0 ? 0 : roomForFirst} before sending to '
            'the LLM, and sending the author\'s other '
            '${followUpTexts.length} post(s) whole');
        bodyText = roomForFirst <= 0 ? '' : bodyText.substring(0, roomForFirst);
      }
    }

    // The post's images, so the model can tie one to a mod. Donation buttons,
    // badges, avatars and spinners are dropped before the model ever sees them
    // — asking it nicely not to pick a Patreon banner is weaker than never
    // offering one. The filter is the site's own (see gallery_filter.dart), so
    // the two can never disagree about what a donation button looks like.
    final images = [
      for (final img in detail.allImages)
        if (!isBadgeOrDonationImage(img.originalUrl))
          (url: img.originalUrl, alt: img.alt),
    ];

    return ExtractionPrompt.buildUserPrompt(
      reducedText: bodyText,
      links: links,
      ruleLinks: ruleLinks,
      images: images,
      gameVersion: detail.gameVersion,
      // The thread title helps the model name each mod, so it is always sent.
      modTitle: detail.title,
      followUpTexts: followUpTexts,
    );
  }

  // ---------------------------------------------------------------------------
  // Call + retry
  // ---------------------------------------------------------------------------
  static const maxAttempts = 3;

  /// Temperature used on a retry after the model returned unparseable JSON. At
  /// the request's temperature (0 for extraction) the model is deterministic, so
  /// a plain retry would reproduce the same broken text; a small bump makes it
  /// sample differently and gives the retry a real chance to recover. Only
  /// reached when structured output is off (or the endpoint ignored it) — a
  /// compliant server can't return unparseable JSON.
  static const _parseRetryTemperature = 0.4;

  Future<_Attempt?> _callWithRetry(LlmRequest request, int topicId) async {
    // Bumped only after a parse failure, so a network/server retry keeps the
    // original (deterministic) settings.
    var req = request;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await _client.complete(req);
        final answer = _parseAnswer(response.content);
        return _Attempt(response, answer);
      } on LlmException catch (e) {
        // The call itself failed (network, bad status, timeout, empty answer).
        _log.warning('LLM attempt $attempt failed for topic $topicId: $e');
        // A timeout means the request ran past the limit. Retrying with the
        // same limit would almost always time out again — just burning more
        // minutes — so stop now and fall back to the rule-based result. Raise
        // llm_timeout_seconds if this happens a lot.
        if (e.cause is TimeoutException) {
          _log.warning('LLM timed out for topic $topicId; not retrying. Raise '
              'llm_timeout_seconds if this is common.');
          return null;
        }
        if (attempt == maxAttempts) return null;
        // else: retry as-is (a transient network/server problem).
      } catch (e) {
        // The call returned, but the answer wasn't usable JSON. Retry at a
        // higher temperature so a deterministic model doesn't just repeat the
        // same broken output.
        _log.warning('LLM answer for topic $topicId was not valid JSON on '
            'attempt $attempt ($e); retrying at a higher temperature.');
        if (attempt == maxAttempts) return null;
        req = request.copyWith(temperature: _parseRetryTemperature);
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Parsing the model's answer
  // ---------------------------------------------------------------------------

  _LlmAnswer _parseAnswer(String content) {
    final cleaned = _extractJsonObject(content);
    final decoded = jsonDecode(cleaned);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Answer is not a JSON object');
    }

    final mods = <_RawMod>[];
    final rawMods = decoded['mods'];
    if (rawMods is List) {
      for (final m in rawMods) {
        if (m is! Map<String, dynamic>) continue;
        mods.add(_parseMod(m));
      }
    }
    // Absent or non-bool = assume it is a mod. We never drop a thread on a
    // missing judgment; the bundle filter also requires no version tag before
    // dropping anything.
    final rawIsMod = decoded['isMod'];
    final isMod = rawIsMod is bool ? rawIsMod : true;
    return _LlmAnswer(mods, isMod: isMod);
  }

  _RawMod _parseMod(Map<String, dynamic> m) {
    String? asString(Object? v) =>
        v is String && v.trim().isNotEmpty ? v.trim() : null;

    final downloads = <_RawDownload>[];
    final rawDownloads = m['downloads'];
    if (rawDownloads is List) {
      for (final d in rawDownloads) {
        if (d is! Map<String, dynamic>) continue;
        final url = d['url'];
        if (url is! String || url.trim().isEmpty) continue;
        final label = d['label'];
        final kind = d['kind'];
        downloads.add(_RawDownload(
          url.trim(),
          label is String ? label.trim() : '',
          LlmDownloadKind.orDirect(kind is String ? kind.trim() : null),
        ));
      }
    }

    String? changelogLink;
    final changelogEntries = <String, String>{};
    final changelog = m['changelog'];
    if (changelog is Map<String, dynamic>) {
      changelogLink = asString(changelog['link']);
      final rawEntries = changelog['entries'];
      if (rawEntries is Map) {
        for (final e in rawEntries.entries) {
          final version = e.key;
          final text = asString(e.value);
          if (version is String && version.trim().isNotEmpty && text != null) {
            changelogEntries[version.trim()] = text;
          }
        }
      }
    }

    final supportLinks = <String>[];
    final rawSupport = m['supportLinks'];
    if (rawSupport is List) {
      for (final s in rawSupport) {
        final u = asString(s);
        if (u != null) supportLinks.add(u);
      }
    }

    final needs = <String>[];
    final rawNeeds = m['needs'];
    if (rawNeeds is List) {
      for (final n in rawNeeds) {
        final name = asString(n);
        if (name != null) needs.add(name);
      }
    }

    LlmModSummary? summary;
    final rawSummary = generateSummaries ? m['summary'] : null;
    if (rawSummary is Map<String, dynamic>) {
      final sentence = asString(rawSummary['sentence']);
      final paragraph = asString(rawSummary['paragraph']);
      if (sentence != null || paragraph != null) {
        summary = LlmModSummary(sentence: sentence, paragraph: paragraph);
      }
    }

    LlmDescriptionAnchors? anchors;
    final rawAnchors = m['descriptionAnchors'];
    if (rawAnchors is Map<String, dynamic>) {
      final startsWith = asString(rawAnchors['startsWith']);
      final endsWith = asString(rawAnchors['endsWith']);
      if (startsWith != null && endsWith != null) {
        anchors =
            LlmDescriptionAnchors(startsWith: startsWith, endsWith: endsWith);
      }
    }

    return _RawMod(
      name: asString(m['name']) ?? '',
      role: LlmModRole.orMain(asString(m['role'])),
      requires: asString(m['requires']),
      downloads: downloads,
      image: asString(m['image']),
      changelogLink: changelogLink,
      changelogEntries: changelogEntries,
      version: asString(m['version']),
      supportLinks: supportLinks,
      license: asString(m['license']),
      sourceCode: asString(m['sourceCode']),
      saveCompatibility: asString(m['saveCompatibility']),
      summary: summary,
      needs: needs,
      descriptionAnchors: anchors,
    );
  }

  static String _stripCodeFences(String content) {
    var s = content.trim();
    if (s.startsWith('```')) {
      final firstNewline = s.indexOf('\n');
      if (firstNewline != -1) s = s.substring(firstNewline + 1);
      if (s.endsWith('```')) s = s.substring(0, s.length - 3);
    }
    return s.trim();
  }

  /// Pulls the JSON object out of the model's reply. Some models — especially
  /// local reasoning GGUFs — ignore the "JSON only" instruction and wrap the
  /// object in prose, e.g. `Here's a thinking process: ... {..}`. We strip any
  /// markdown fences, then return the first balanced `{...}` object, ignoring
  /// braces that sit inside strings. When there is no object, the original text
  /// is returned so [jsonDecode] reports a clear error.
  static String _extractJsonObject(String content) {
    final s = _stripCodeFences(content);
    if (s.startsWith('{')) return s;
    final start = s.indexOf('{');
    if (start == -1) return s;

    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < s.length; i++) {
      final ch = s[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == r'\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }
      if (ch == '"') {
        inString = true;
      } else if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) return s.substring(start, i + 1);
      }
    }
    // Unbalanced (e.g. the reply was cut off): hand back what we have so the
    // caller's decode fails loudly and the call is retried.
    return s.substring(start);
  }

  // ---------------------------------------------------------------------------
  // Checking answers against the post
  // ---------------------------------------------------------------------------

  /// Grounds every mod against the post: drops download/support/changelog URLs
  /// that do not appear, and copied text that cannot be found. The summary is
  /// passed through (it is written, not copied). Mods with nothing left are
  /// dropped.
  List<_CheckedMod> _checkAgainstPost(
    int topicId,
    _LlmAnswer answer,
    _ReadPosts read,
    Set<String> postUrls,
    Map<String, String> postImages,
    List<Uri> postRepoUrls, {
    required bool truncated,
    required String postTitle,
  }) {
    // All the text we showed the model — the thread title, post text (including
    // image alt text), link URLs, and link labels. Facts can sit in the title,
    // a badge, or a link. Version numbers in particular often live only in the
    // thread title (e.g. "My Mod v1.2.3").
    final corpus = _fullPostText(read.combined, postTitle);
    final postTexts = [for (final post in read.posts) post.text];

    final checked = <_CheckedMod>[];
    for (final mod in answer.mods) {
      final c = _checkMod(topicId, mod, postUrls, postImages, postRepoUrls,
          corpus, postTexts,
          truncated: truncated);
      if (!c.isEmpty) checked.add(c);
    }
    return checked;
  }

  _CheckedMod _checkMod(
    int topicId,
    _RawMod mod,
    Set<String> postUrls,
    Map<String, String> postImages,
    List<Uri> postRepoUrls,
    String corpus,
    List<String> postTexts, {
    required bool truncated,
  }) {
    // Downloads: every URL must appear in the post.
    final downloads = <_RawDownload>[];
    for (final d in mod.downloads) {
      if (_urlInPost(d.url, postUrls)) {
        downloads.add(d);
      } else {
        _log.warning(
            'Dropped download URL not found in post (topic $topicId): ${d.url}');
      }
    }

    // Support links: every URL must appear in the post.
    final supportLinks = <String>[];
    for (final s in mod.supportLinks) {
      if (_urlInPost(s, postUrls)) {
        supportLinks.add(s);
      } else {
        _log.warning(
            'Dropped support URL not found in post (topic $topicId): $s');
      }
    }

    // Changelog link must appear in the post; text must be found word-for-word.
    String? changelogLink;
    if (mod.changelogLink != null) {
      if (_urlInPost(mod.changelogLink!, postUrls)) {
        changelogLink = mod.changelogLink;
      } else {
        _log.warning(
            'Dropped changelog link not found in post (topic $topicId): ${mod.changelogLink}');
      }
    }

    // Changelog entries: exact matching of long copied text is fragile, so we
    // keep every entry and only flag ones we can't find in the post. On
    // truncation the last entry may be cut off, so drop the whole map instead.
    final changelogEntries = <String, String>{};
    if (mod.changelogEntries.isNotEmpty) {
      if (truncated) {
        _log.warning(
            'Answer truncated (topic $topicId); dropping changelog entries');
      } else {
        for (final e in mod.changelogEntries.entries) {
          changelogEntries[e.key] = e.value;
          if (!_textInPost(e.value, corpus)) {
            _log.warning(
                'Changelog entry "${e.key}" not found verbatim in post (topic $topicId); keeping anyway');
          }
        }
      }
    }

    String? version;
    if (mod.version != null) {
      if (_textInPost(mod.version!, corpus)) {
        version = mod.version;
      } else {
        _log.warning(
            'Dropped version not found in post (topic $topicId): ${mod.version}');
      }
    }
    String? license;
    if (mod.license != null) {
      if (_textInPost(mod.license!, corpus)) {
        license = mod.license;
      } else if (_hasLicenseLink(postUrls)) {
        // The post links to a license (e.g. a Creative Commons badge or a
        // LICENSE file), so the model naming that license still counts even
        // though the exact name isn't spelled out in the text.
        license = mod.license;
        _log.info(
            'License "${mod.license}" confirmed via a license link (topic $topicId)');
      } else {
        _log.warning(
            'Dropped license not found in post (topic $topicId): ${mod.license}');
      }
    }

    final sourceCode = mod.sourceCode == null
        ? null
        : _groundSourceCode(topicId, mod.sourceCode!, postUrls, postRepoUrls);

    // Save compatibility: copied word-for-word, so it must be found in the post.
    String? saveCompatibility;
    if (mod.saveCompatibility != null) {
      if (_textInPost(mod.saveCompatibility!, corpus)) {
        saveCompatibility = mod.saveCompatibility;
      } else {
        _log.warning(
            'Dropped save-compatibility text not found in post (topic $topicId): ${mod.saveCompatibility}');
      }
    }

    // Image: the model must have copied a real post image URL. Keep the exact
    // scraped URL (not the model's copy) and store it in the `ext:` form the
    // thread thumbnail uses. Drop anything not in the post's images.
    String? image;
    if (mod.image != null) {
      final match = postImages[PostReducer.normalizeForMatching(
          HtmlProcessor.decodeEntities(mod.image!))];
      if (match != null) {
        image = 'ext:$match';
      } else {
        _log.warning(
            'Dropped image not found in post images (topic $topicId): ${mod.image}');
      }
    }

    return _CheckedMod(
      name: mod.name,
      role: mod.role,
      requires: mod.requires,
      downloads: downloads,
      image: image,
      changelogLink: changelogLink,
      changelogEntries: changelogEntries,
      version: version,
      supportLinks: supportLinks,
      license: license,
      sourceCode: sourceCode,
      saveCompatibility: saveCompatibility,
      // Passed through as-is: the summary is written, not copied, so there is
      // nothing to find in the post.
      summary: mod.summary,
      needs: _groundNeeds(topicId, mod.needs, corpus, mod.name),
      descriptionAnchors:
          _groundAnchors(topicId, mod.descriptionAnchors, postTexts, mod.name),
    );
  }

  /// The description anchors the post really backs up, or null.
  ///
  /// Both ends have to be found in one post, the start at or before the end. A
  /// model asked where a mod's description sits will point somewhere whether the
  /// words are there or not, and what it points at is published as the author's
  /// own writing — so anything that cannot be found is thrown away rather than
  /// guessed at. Anchors that straddle two posts are dropped for the same
  /// reason: text cut from two places was never one description.
  LlmDescriptionAnchors? _groundAnchors(
    int topicId,
    LlmDescriptionAnchors? anchors,
    List<String> postTexts,
    String name,
  ) {
    if (anchors == null || anchors.isEmpty) return null;

    for (final text in postTexts) {
      if (anchorsFoundIn(text, anchors.startsWith, anchors.endsWith)) {
        return anchors;
      }
    }

    _log.warning('Dropped where "$name" is described (topic $topicId): the '
        'words are not in any one of the author\'s posts.');
    return null;
  }

  /// The needed mods the post really names.
  ///
  /// A name the post never mentions is dropped: nearly every Starsector mod
  /// needs LazyLib, so a model asked what a mod needs will happily say LazyLib
  /// whether the post did or not, and a wrong requirement sends a reader off to
  /// install something they do not need.
  List<String> _groundNeeds(
    int topicId,
    List<String> names,
    String corpus,
    String ownName,
  ) {
    final kept = <String>[];
    final seen = <String>{};
    for (final raw in names) {
      final name = raw.trim();
      if (name.length < 2) continue;
      // A mod does not need itself.
      if (name.toLowerCase() == ownName.trim().toLowerCase()) continue;
      if (!seen.add(name.toLowerCase())) continue;
      if (_textInPost(name, corpus)) {
        kept.add(name);
      } else {
        _log.warning('Dropped a needed mod not named in the post '
            '(topic $topicId): $name');
      }
    }
    return kept;
  }

  /// The source-code link to keep, or null when the post does not back it up.
  ///
  /// A post rarely links the repository's own page: it links a file inside it —
  /// a raw file, a release, a page of the code. That file's own URL says which
  /// repository it belongs to, so a repository link the model returns counts as
  /// stated when the post links something inside it. What gets kept is then the
  /// post's own spelling of that repository, cut out of the longer link, rather
  /// than the model's copy — the same rule the mod image follows.
  String? _groundSourceCode(
    int topicId,
    String candidate,
    Set<String> postUrls,
    List<Uri> postRepoUrls,
  ) {
    // A file to download is never the answer, even when the post has it.
    if (_isDownloadLink(candidate)) {
      _log.warning('Dropped source-code link that is a download rather than a '
          'repository (topic $topicId): $candidate');
      return null;
    }
    // Spelled out in the post: kept as written, except for a clone link's
    // ".git" tail, which is the same repository written for git rather than
    // for a reader.
    if (_urlInPost(candidate, postUrls)) return _withoutGitTail(candidate.trim());

    final wanted = Uri.tryParse(candidate.trim());
    final wantedPath = _pathParts(wanted);
    // Two parts is owner and repository. One is a person's page, which says
    // nothing about where this mod's code is.
    if (wanted != null && _isCodeHost(wanted.host) && wantedPath.length >= 2) {
      for (final url in postRepoUrls) {
        if (url.host.toLowerCase() != wanted.host.toLowerCase()) continue;
        final path = _pathParts(url);
        if (path.length < wantedPath.length) continue;
        var same = true;
        for (var i = 0; i < wantedPath.length; i++) {
          if (_samePathPart(path[i], wantedPath[i])) continue;
          same = false;
          break;
        }
        if (!same) continue;
        final kept = path.take(wantedPath.length).toList();
        // A clone link ends in ".git". That is the same repository, but it is
        // not what anyone wants to be sent to, so the tail comes off.
        kept[kept.length - 1] = _withoutGitTail(kept.last);
        final root = Uri(
          scheme: url.scheme,
          host: url.host,
          pathSegments: kept,
        ).toString();
        _log.info('Source code "$root" confirmed by a link inside that '
            'repository (topic $topicId)');
        return root;
      }
    }

    _log.warning(
        'Dropped source-code link not found in post (topic $topicId): '
        '$candidate');
    return null;
  }

  /// Whether two parts of a link's path name the same thing. Case is ignored,
  /// and so is the ".git" a clone link ends in: a post that says
  /// `.../Guardian-Prototype.git` is naming the same repository as
  /// `.../Guardian-Prototype`.
  static bool _samePathPart(String a, String b) =>
      _withoutGitTail(a).toLowerCase() == _withoutGitTail(b).toLowerCase();

  /// The same text without a clone link's ".git" tail. Works on one part of a
  /// path or on a whole link, since either way the tail is at the end.
  static String _withoutGitTail(String text) =>
      text.toLowerCase().endsWith('.git')
          ? text.substring(0, text.length - 4)
          : text;

  static List<String> _pathParts(Uri? url) =>
      url == null ? const [] : url.pathSegments.where((s) => s.isNotEmpty).toList();

  /// The code-hosting sites we can read a repository out of a link's path on.
  /// Anywhere else, only a link the post spells out in full is kept.
  static const List<String> _codeHosts = [
    'github.com',
    'gitlab.com',
    'bitbucket.org',
    'codeberg.org',
  ];

  static bool _isCodeHost(String host) {
    final h = host.toLowerCase();
    return _codeHosts.any((c) => h == c || h.endsWith('.$c'));
  }

  /// The links to code-hosting sites the post really has, kept as written, so
  /// [_groundSourceCode] can tell which repository each one belongs to.
  List<Uri> _postRepoUrls(
    QbModDetail detail,
    ReducedPost reduced,
    List<DownloadCandidate> ruleCandidates,
  ) {
    final urls = <String, Uri>{};
    void add(String raw) {
      final u = HtmlProcessor.decodeEntities(raw.trim());
      if (u.isEmpty) return;
      final parsed = Uri.tryParse(u);
      if (parsed == null || !_isCodeHost(parsed.host)) return;
      urls.putIfAbsent(PostReducer.normalizeForMatching(u), () => parsed);
    }

    // The links as written come first, so the post's own spelling is what gets
    // kept. The reducer's URL set is lowercased for matching, so it goes last:
    // it is the only place a URL written as bare text turns up, and a
    // lowercased repository link still works, but it is not what the post says.
    for (final l in detail.allLinks) {
      add(l.url);
    }
    for (final l in reduced.links) {
      add(l.url);
    }
    for (final c in ruleCandidates) {
      add(c.sourceUrl);
    }
    for (final u in reduced.urlSet) {
      add(u);
    }
    return urls.values.toList();
  }

  bool _urlInPost(String url, Set<String> postUrls) {
    if (postUrls.contains(PostReducer.normalizeForMatching(url))) return true;
    // Fall back to the direct-download form. This matches a clean link the
    // model returned against a messy one in the post that points at the same
    // file — e.g. a Google Drive link with a junk "//link" glued on the end, or
    // one written as a share URL where the model gave the download URL.
    return postUrls.contains(PostReducer.normalizeForMatching(
        UrlNormalizer.normalizeDownloadUrl(url)));
  }

  /// Every URL that really belongs to this post. We collect them from three
  /// places: the URLs the reducer pulled from the post, the links the page
  /// reader already found ([QbModDetail.links]), and the rule links we showed
  /// the model. The reducer scans the post a second time and can miss links the
  /// page reader caught — a link wrapped around an image, a link written without
  /// quotes, or links in an unusual order. For each one we store both the link
  /// as written and its direct-download form, so the model's answer matches even
  /// when its link and the post's link differ only in download-host cruft. We
  /// check the model's answer against this fuller list, so we only drop URLs the
  /// model made up.
  Set<String> _postUrls(
    QbModDetail detail,
    ReducedPost reduced,
    List<DownloadCandidate> ruleCandidates,
  ) {
    final urls = <String>{};
    void add(String raw) {
      final u = raw.trim();
      if (u.isEmpty) return;
      final decoded = HtmlProcessor.decodeEntities(u);
      urls.add(PostReducer.normalizeForMatching(decoded));
      urls.add(PostReducer.normalizeForMatching(
          UrlNormalizer.normalizeDownloadUrl(decoded)));
    }

    for (final u in reduced.urlSet) {
      add(u);
    }
    for (final l in detail.allLinks) {
      add(l.url);
    }
    for (final c in ruleCandidates) {
      add(c.sourceUrl);
    }
    return urls;
  }

  /// The post's real images, keyed by their normalized URL and valued by the
  /// exact scraped URL. Used to ground the image the model picked for a mod and
  /// to store the scraped URL rather than the model's copy. Badges and spinners
  /// are left out — they are never offered to the model as a mod image.
  Map<String, String> _postImages(QbModDetail detail) {
    final images = <String, String>{};
    for (final img in detail.allImages) {
      final url = img.originalUrl.trim();
      if (url.isEmpty || isBadgeOrDonationImage(url)) continue;
      images[PostReducer.normalizeForMatching(
          HtmlProcessor.decodeEntities(url))] = url;
    }
    return images;
  }

  /// Everything we showed the model, used to check its answers: the cleaned-up
  /// post text (which includes image alt text) plus every link URL and label.
  String _fullPostText(ReducedPost reduced, String postTitle) {
    final b = StringBuffer(postTitle);
    b.write('\n');
    b.write(reduced.text);
    for (final l in reduced.links) {
      b.write('\n');
      b.write(l.url);
      if (l.text.isNotEmpty) {
        b.write(' ');
        b.write(l.text);
      }
    }
    return b.toString();
  }

  static final RegExp _licenseUrlHint =
      RegExp(r'licen[sc]e|creativecommons', caseSensitive: false);

  /// True when the post links to a license — a LICENSE file, a Creative Commons
  /// page, a shields.io license badge, and the like.
  bool _hasLicenseLink(Set<String> postUrls) =>
      postUrls.any(_licenseUrlHint.hasMatch);

  /// A link to a file you download rather than a page you read: a GitHub
  /// release asset, a source zip, or any archive. Used to keep such a link out
  /// of the source-code field, which wants the repository's own page.
  static final RegExp _downloadUrlHint = RegExp(
      r'/releases/download/|/archive/|\.(zip|7z|rar|jar|tgz|gz)(\?|#|$)',
      caseSensitive: false);

  static bool _isDownloadLink(String url) => _downloadUrlHint.hasMatch(url);

  // A non-breaking space in any form the post or the model might use: the
  // literal `&nbsp;` entity, its numeric forms (`&#160;` / `&#xa0;`), or the
  // raw U+00A0 character. All become a plain space so checking treats them the
  // same — the model often reads `&nbsp;` back as a normal space.
  static final RegExp _nbsp = RegExp(r'&nbsp;|&#0*160;|&#x0*a0;',
      caseSensitive: false);
  static final RegExp _whitespace = RegExp(r'\s+');

  bool _textInPost(String needle, String postText) {
    final n = _norm(needle);
    if (n.isEmpty) return false;
    return _norm(postText).contains(n);
  }

  static String _norm(String s) => s
      .replaceAll(_nbsp, ' ')
      .toLowerCase()
      .replaceAll(_whitespace, ' ')
      .trim();

  // ---------------------------------------------------------------------------
  // Resolve each mod's downloads and build its extras
  // ---------------------------------------------------------------------------

  /// Turns grounded mods into stored [LlmMod]s: runs each kept download link
  /// through the resolver (reusing the rule candidate when it already resolved
  /// the same link), and builds each mod's extras.
  Future<List<LlmMod>> _resolveMods(
    List<_CheckedMod> mods,
    List<DownloadCandidate> ruleCandidates,
  ) async {
    // Index the rule candidates by their normalized URL, so a link the rules
    // already resolved is reused instead of resolved again.
    final ruleByKey = <String, DownloadCandidate>{
      for (final c in ruleCandidates) _matchKey(c.sourceUrl): c,
    };

    final result = <LlmMod>[];
    for (final mod in mods) {
      final downloads = <LlmDownload>[];
      final seen = <String>{};
      for (final raw in mod.downloads) {
        final key = _matchKey(raw.url);
        if (!seen.add(key)) continue; // drop a repeat of the same link
        downloads.add(await _resolveDownload(raw, ruleByKey[key]));
      }
      result.add(LlmMod(
        name: mod.name,
        role: mod.role,
        requires: mod.requires,
        downloads: downloads,
        image: mod.image,
        extras: _buildExtras(mod),
        descriptionAnchors: mod.descriptionAnchors,
      ));
    }
    return result;
  }

  /// Resolves one download. Prefers the matching rule candidate (already
  /// resolved); otherwise resolves the link through the resolver; failing that,
  /// keeps the raw link as a low-confidence manual step.
  Future<LlmDownload> _resolveDownload(
    _RawDownload raw,
    DownloadCandidate? ruleMatch,
  ) async {
    final candidate = ruleMatch ??
        await _resolver.resolveSingleLink(
            LinkRef(url: raw.url, text: raw.label, isExternal: true));

    if (candidate == null) {
      // Unknown host or nothing to resolve — keep the raw link, flagged manual.
      return LlmDownload(
        url: raw.url,
        label: raw.label,
        kind: raw.kind,
        sourceHost: Uri.tryParse(raw.url)?.host ?? '',
        confidence: DownloadConfidence.low.name,
        requiresManualStep: true,
      );
    }

    // Reuse the resolver's host/filename inference via the bundle candidate.
    final resolved = AssumedDownloadCandidate.fromDownloadCandidate(candidate);
    return LlmDownload(
      url: raw.url,
      label: raw.label.isNotEmpty ? raw.label : resolved.linkText,
      kind: raw.kind,
      resolvedDirectUrl: resolved.resolvedDirectUrl,
      sourceHost: resolved.sourceHost,
      fileName: resolved.fileName,
      confidence: resolved.confidence,
      requiresManualStep: resolved.requiresManualStep,
    );
  }

  static String _matchKey(String url) => PostReducer.normalizeForMatching(
      UrlNormalizer.normalizeDownloadUrl(url.trim()));

  // ---------------------------------------------------------------------------
  // Extras
  // ---------------------------------------------------------------------------

  LlmExtras? _buildExtras(_CheckedMod g) {
    // A post can offer both a link to a full changelog page AND copied notes
    // for recent versions — keep whichever the post has. They are not exclusive.
    final link = g.changelogLink;
    final entries = g.changelogEntries.isEmpty ? null : g.changelogEntries;
    final changelog = (link != null || entries != null)
        ? LlmChangelog(link: link, entries: entries)
        : null;

    final summary =
        (g.summary != null && !g.summary!.isEmpty) ? g.summary : null;

    final extras = LlmExtras(
      version: g.version,
      changelog: changelog,
      supportLinks: g.supportLinks.isEmpty
          ? null
          : g.supportLinks.map(LlmSupportLink.fromUrl).toList(),
      license: g.license,
      sourceCode: g.sourceCode,
      saveCompatibility: g.saveCompatibility,
      summary: summary,
      needs: g.needs.isEmpty ? null : g.needs,
    );
    return extras.isEmpty ? null : extras;
  }

  // ---------------------------------------------------------------------------
  // Shared counters (locked)
  // ---------------------------------------------------------------------------

  Future<bool> _reserveSlot() => _lock.synchronized(() {
        if (_bailed) return false;
        if (maxTopics != null && _processed >= maxTopics!) return false;
        _processed++;
        return true;
      });

  Future<void> _recordSuccess() => _lock.synchronized(() {
        _consecutiveFailures = 0;
      });

  Future<void> _recordFailure(int topicId) => _lock.synchronized(() {
        _consecutiveFailures++;
        if (!_bailed && _consecutiveFailures >= maxConsecutiveFailures) {
          _bailed = true;
          _log.warning(
              'LLM stopping: $_consecutiveFailures consecutive failures reached '
              'the limit ($maxConsecutiveFailures). No more LLM calls this '
              'run; remaining topics use rule-based downloads only.');
        }
      });

  // ---------------------------------------------------------------------------
  // Test mode
  // ---------------------------------------------------------------------------

  Future<void> _extractTestMode(
    QbModDetail detail,
    List<DownloadCandidate> ruleCandidates,
  ) async {
    // Selection: explicit topic IDs, else sample the hard posts.
    final targeted = testTopicIds != null
        ? testTopicIds!.contains(detail.topicId)
        : _isHardPost(ruleCandidates);
    if (!targeted) return;

    if (!await _reserveTestSlot()) return;

    final read = _ReadPosts.of(detail);
    final userPrompt = _buildUserPrompt(detail, read, ruleCandidates);
    final request = LlmRequest(
      systemPrompt:
          ExtractionPrompt.buildSystemPrompt(includeSummary: generateSummaries),
      userPrompt: userPrompt,
      temperature: ExtractionPrompt.temperature,
      maxTokens: maxTokens ?? ExtractionPrompt.maxTokens,
      jsonSchema:
          ExtractionPrompt.buildResponseSchema(includeSummary: generateSummaries),
    );

    // Live call, no saved answers, nothing written to disk.
    String? rawAnswer;
    String? error;
    _LlmAnswer? answer;
    LlmResponse? response;
    try {
      response = await _client.complete(request);
      rawAnswer = response.content;
      answer = _parseAnswer(rawAnswer);
    } catch (e) {
      error = e.toString();
      _log.warning('Test-mode call failed for topic ${detail.topicId}: $e');
    }

    final record = <String, dynamic>{
      'topicId': detail.topicId,
      'title': detail.title,
      'inputSent': userPrompt,
      'rawAnswer': rawAnswer,
      if (error != null) 'error': error,
      if (response != null) 'tokenUsage': response.usageSummary,
    };

    if (answer != null) {
      final postUrls = _postUrls(detail, read.combined, ruleCandidates);
      final postImages = _postImages(detail);
      final postRepoUrls = _postRepoUrls(detail, read.combined, ruleCandidates);
      final checked = _checkAgainstPost(
          detail.topicId, answer, read, postUrls, postImages, postRepoUrls,
          truncated: response?.wasTruncated ?? false, postTitle: detail.title);
      final mods = await _resolveMods(checked, ruleCandidates);
      record['isMod'] = answer.isMod;
      record['parsedGrounded'] = {
        'mods': mods.map((m) => m.toMap()).toList(),
      };
      final rawDownloadCount =
          answer.mods.fold<int>(0, (n, m) => n + m.downloads.length);
      final keptDownloadCount =
          mods.fold<int>(0, (n, m) => n + m.downloads.length);
      record['dropped'] = {
        'downloads': rawDownloadCount - keptDownloadCount,
        'mods': answer.mods.length - mods.length,
      };
      record['rulesVsLlm'] = {
        'ruleLinks': ruleCandidates.map((c) => c.sourceUrl).toList(),
        'llmMods': answer.mods
            .map((m) => {
                  'name': m.name,
                  'role': m.role,
                  if (m.requires != null) 'requires': m.requires,
                  'downloads': m.downloads
                      .map((d) =>
                          {'url': d.url, 'label': d.label, 'kind': d.kind})
                      .toList(),
                })
            .toList(),
      };
    }

    await _lock.synchronized(() => _testReport.add(record));
  }

  Future<bool> _reserveTestSlot() => _lock.synchronized(() {
        if (_testCallCount >= testLimit) return false;
        _testCallCount++;
        return true;
      });

  bool _isHardPost(List<DownloadCandidate> candidates) =>
      candidates.isEmpty ||
      candidates.every((c) => c.confidence == DownloadConfidence.low);

  /// Writes the verbose test-mode report. Call after the run in test mode.
  Future<void> writeTestReport() async {
    final path = p.join(_dataPath, 'llm-test-output.json');
    await Directory(_dataPath).create(recursive: true);
    final json = const JsonEncoder.withIndent('  ').convert({
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'promptVersion': ExtractionPrompt.promptVersion,
      'callCount': _testCallCount,
      'topics': _testReport,
    });
    await File(path).writeAsString(json);
    _log.info(
        'Wrote LLM test report to $path ($_testCallCount call(s))');
  }
}

/// One grounded mod, ready to resolve and store.
class _CheckedMod {
  final String name;
  final String role;
  final String? requires;
  final List<_RawDownload> downloads;

  /// A grounded post image for this mod, already in `ext:<url>` form, or null.
  final String? image;
  final String? changelogLink;
  final Map<String, String> changelogEntries;
  final String? version;
  final List<String> supportLinks;
  final String? license;

  /// The link to where the mod's code is kept, once checked against the post.
  final String? sourceCode;
  final String? saveCompatibility;
  final LlmModSummary? summary;

  /// The other mods this one needs, once checked against the post.
  final List<String> needs;

  /// Where the author describes this mod, once found in one of the posts.
  final LlmDescriptionAnchors? descriptionAnchors;

  _CheckedMod({
    required this.name,
    required this.role,
    this.requires,
    required this.downloads,
    this.image,
    this.changelogLink,
    required this.changelogEntries,
    this.version,
    required this.supportLinks,
    this.license,
    this.sourceCode,
    this.saveCompatibility,
    this.summary,
    this.needs = const [],
    this.descriptionAnchors,
  });

  /// True when nothing downloadable or factual survived grounding. A name alone
  /// does not count: a mod that is only mentioned (its download URL was not in
  /// the post, and it carries no grounded extras) is dropped, so only mods
  /// actually downloadable from this thread are kept.
  bool get isEmpty =>
      downloads.isEmpty &&
      changelogLink == null &&
      changelogEntries.isEmpty &&
      version == null &&
      supportLinks.isEmpty &&
      license == null &&
      sourceCode == null &&
      saveCompatibility == null &&
      needs.isEmpty &&
      (summary == null || summary!.isEmpty);
}

/// A fixed number of turns. [take] waits until one of [limit] slots is free;
/// [release] hands the slot straight to whoever has waited longest. This is
/// what holds [PostExtractor] to `llm_max_concurrent_calls` topics talking to
/// the model at once, however many reads its callers have started.
class _CallSlots {
  final int limit;
  int _inUse = 0;
  final List<Completer<void>> _waiting = [];

  _CallSlots(this.limit);

  Future<void> take() {
    if (_inUse < limit) {
      _inUse++;
      return Future.value();
    }
    final turn = Completer<void>();
    _waiting.add(turn);
    return turn.future;
  }

  void release() {
    if (_waiting.isNotEmpty) {
      // The slot passes straight along, so _inUse stays as it is.
      _waiting.removeAt(0).complete();
    } else {
      _inUse--;
    }
  }
}
