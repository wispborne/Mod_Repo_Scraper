import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';

import '../../../../site/gallery_filter.dart';
import '../../../../site/post_html.dart';
import '../models/forum_date.dart';
import '../models/mod_detail.dart';
import '../models/post_extraction.dart';
import 'extraction_store.dart';
import 'llm_client.dart';
import 'post_guide_store.dart';

/// Checks a mod thread's first post against the forum's mod post guide
/// (SirHartley, topic 36046, posted September 21, 2026) and its rules for
/// posting a new mod (topic 36265, posted November 5, 2026). The second adds
/// two requirements: an .exe must have its source code linked, and an AI
/// disclaimer must name the model and the kinds of assets made with it.
///
/// Each guide item is one question. A failed item shows the item's fixed
/// reason, so a reason is never longer than eight words and reads the same on
/// every run. Three items are answered by code, because code can answer them
/// exactly: the game version in the title, pictures, and (when it finds one) an
/// outside download. The LLM answers the rest in one call per post.
///
/// A post is checked when it was posted or last edited on or after the day the
/// guide was posted ([postGuideApplies]). A post nobody has touched since then
/// was written before the guide existed. After the first check, a post is
/// checked again whenever its HTML changes.

/// The guide's thread.
const postGuideUrl = 'https://fractalsoftworks.com/forum/index.php?topic=36046.0';

/// The rules for posting a new mod, which add to the guide.
const postRulesUrl = 'https://fractalsoftworks.com/forum/index.php?topic=36265.0';

/// The day the guide was posted. A post neither made nor edited since then is
/// not checked.
final postGuideDate = DateTime(2026, 9, 21);

/// Raise when the questions or the prompt change, so every checked post is
/// checked again.
const postGuideVersion = 2;

/// Who answers a guide item.
enum GuideAnsweredBy {
  /// Code reads the answer off the saved post.
  rules,

  /// The LLM answers.
  llm,

  /// Code first. When code finds nothing, the LLM's answer is used.
  rulesThenLlm,

  /// Code's answer whenever it has one, "no" included. The LLM's answer only
  /// when code has none.
  rulesFirst,
}

/// One item of the mod post guide.
class GuideItem {
  final String id;

  /// A few words naming the item, for the viewer.
  final String label;

  /// What a failing post is missing, in eight words or fewer.
  final String reason;

  /// One of the guide's hard requirements. Source code in general is not one:
  /// both posts call it strongly suggested. Source code for an .exe is one.
  final bool required;

  final GuideAnsweredBy answeredBy;

  /// The question the LLM is asked. Null for an item code answers alone.
  final String? question;

  /// Whether the LLM may answer "notApplicable". Where it may not, the answer
  /// schema only offers "yes" and "no".
  final bool allowsNotApplicable;

  const GuideItem({
    required this.id,
    required this.label,
    required this.reason,
    required this.required,
    required this.answeredBy,
    this.question,
    this.allowsNotApplicable = false,
  });

  bool get askLlm => answeredBy != GuideAnsweredBy.rules;
}

/// The guide's items, in the guide's order. "Keep the post current" is left
/// out: every post checked is newer than the guide, so it would never fail.
const postGuideItems = <GuideItem>[
  GuideItem(
    id: 'externalDownload',
    label: 'Download that is not a forum attachment',
    reason: 'No download outside forum attachments',
    required: true,
    answeredBy: GuideAnsweredBy.rulesThenLlm,
    question: 'Does the post link to a download of the mod that is not a forum '
        'attachment? Forum attachment links contain "action=dlattach". '
        'GitHub, Google Drive, OneDrive, Dropbox, MediaFire and similar hosts '
        'count, and so does a mod manager install button.',
  ),
  GuideItem(
    id: 'gameVersionInTitle',
    label: 'Game version in the title',
    reason: 'No game version in title',
    required: true,
    answeredBy: GuideAnsweredBy.rules,
  ),
  GuideItem(
    id: 'aiDisclaimer',
    label: 'AI use disclaimer, if AI was used',
    reason: 'Incomplete AI use disclaimer',
    required: true,
    // The post's own LLM read already records the AI tools named and the
    // kinds of assets, each checked against the post. On 146 real threads
    // this question alone failed clear disclaimers such as "Code by Claude
    // (Anthropic)", so those facts decide where they can ([aiDisclaimerFromFacts]).
    answeredBy: GuideAnsweredBy.rulesFirst,
    allowsNotApplicable: true,
    question: 'If the post says generative AI tools were used to make the mod, '
        'does it name the AI model or models used AND say which kinds of '
        'assets were made with them (for example code, portraits, sprites, '
        'music, text)? Short statements count when they give both: "code '
        'vibe coded with Kimi K3.1" and "portraits made with Midjourney" each '
        'name a model and a kind of asset. Answer "no" if the post admits AI '
        'use but does not name the model, or does not say what was made with '
        'it ("AI was used extensively", "vibe coded"). Answer "yes" if the post '
        'says no AI was used. Answer "notApplicable" if the post does not '
        'mention AI tools at all. In Starsector posts "AI" usually means ship '
        'AI, fleet AI or AI cores; that is not AI use.',
  ),
  GuideItem(
    id: 'exeSourceCode',
    label: 'Source code for an .exe',
    reason: 'No source code for the .exe',
    required: true,
    answeredBy: GuideAnsweredBy.rulesThenLlm,
    allowsNotApplicable: true,
    question: 'Does the mod include a program that runs outside the game, such '
        'as an .exe file (a mod manager, launcher, installer or other tool)? '
        'If so, does the post link to its source code, for example on GitHub? '
        'Answer "notApplicable" if the mod includes no such program. Ordinary '
        'Starsector mods contain .jar files that the game loads; those do not '
        'count.',
  ),
  GuideItem(
    id: 'sourceCode',
    label: 'Source code',
    reason: 'No source code',
    required: false,
    answeredBy: GuideAnsweredBy.rulesThenLlm,
    question: "Does the post link to the mod's source code (for example a GitHub "
        'repository), or say the source code is included in the download? A '
        'mod released as uncompiled source code, or whose download is said to '
        'contain its .java files, counts.',
  ),
  GuideItem(
    id: 'downloadNearTop',
    label: 'Download near the top, not in a spoiler',
    reason: 'Download buried or inside a spoiler',
    required: false,
    answeredBy: GuideAnsweredBy.llm,
    allowsNotApplicable: true,
    question: 'Is the main download link near the top of the post, before the '
        'long description, and not inside a spoiler? If the post offers a mod '
        'manager install button, is there also a plain download link? Answer '
        '"no" if any of these fails. Answer "notApplicable" if the post has no '
        'download link at all.',
  ),
  GuideItem(
    id: 'requirementsByDownload',
    label: 'Required mods next to the download',
    reason: 'Requirements not stated near download',
    required: false,
    answeredBy: GuideAnsweredBy.llm,
    question: 'Close to the download, does the post say which other mods are '
        'required, or that none are needed? Answer "no" if requirements are '
        'only mentioned far from the download, or not at all. A mod that needs '
        'nothing still has to say so.',
  ),
  GuideItem(
    id: 'saveCompatibility',
    label: 'Save compatibility',
    reason: 'Save compatibility not stated',
    required: false,
    answeredBy: GuideAnsweredBy.llm,
    question: 'Does the post say anything about save compatibility: whether the '
        'mod can be added to a game already in progress, whether an older '
        'version can be updated, or whether it can be removed from a save?',
  ),
  GuideItem(
    id: 'shortDescriptionFirst',
    label: 'Short description first',
    reason: 'No short description at the top',
    required: false,
    answeredBy: GuideAnsweredBy.llm,
    question: 'Near the start of the post, is there a short description (a few '
        'sentences at most) of what the mod does or changes, before any long '
        'explanation?',
  ),
  GuideItem(
    id: 'pictures',
    label: 'Pictures',
    reason: 'No pictures',
    required: false,
    answeredBy: GuideAnsweredBy.rules,
  ),
  GuideItem(
    id: 'warningsVisible',
    label: 'Important warnings easy to see',
    reason: 'Important warnings hard to find',
    required: false,
    answeredBy: GuideAnsweredBy.llm,
    allowsNotApplicable: true,
    question: 'Does the post give important warnings, such as needing a new game, '
        'a known conflict with another mod, or content that is deliberately '
        'very hard? If so, are they easy to see before the download or near '
        'the top, and not hidden in a spoiler or tiny text? Answer '
        '"notApplicable" if the post gives no such warnings.',
  ),
  GuideItem(
    id: 'longMaterialInSpoilers',
    label: 'Long material in spoilers',
    reason: 'Long sections not in spoilers',
    required: false,
    answeredBy: GuideAnsweredBy.llm,
    allowsNotApplicable: true,
    question: 'Does the post have lengthy material such as a long FAQ, a large '
        'gallery, detailed instructions or old changelogs? If so, is that '
        'material inside spoilers? Answer "notApplicable" if there is no '
        'lengthy material.',
  ),
  GuideItem(
    id: 'reusePermissions',
    label: 'Credits and reuse permissions',
    reason: 'No reuse permissions stated',
    required: false,
    answeredBy: GuideAnsweredBy.llm,
    question: "Does the post say whether others may reuse the mod's code or art, "
        'for example with a license or a permissions note? Credits alone are '
        'not enough.',
  ),
];

/// The item with [id], or null.
GuideItem? postGuideItem(String id) {
  for (final item in postGuideItems) {
    if (item.id == id) return item;
  }
  return null;
}

/// An answer to one guide item.
enum GuideAnswer {
  yes,
  no,
  notApplicable;

  static GuideAnswer? read(Object? value) => switch (value) {
        'yes' || true => GuideAnswer.yes,
        'no' || false => GuideAnswer.no,
        'notApplicable' || 'n/a' || 'na' || 'not applicable' => GuideAnswer.notApplicable,
        _ => null,
      };
}

/// One guide item's result for one post.
class GuideItemResult {
  final GuideItem item;

  /// Null when nobody answered: the LLM left the item out of its answer, or
  /// the post has not been sent to the LLM yet.
  final GuideAnswer? answer;

  /// Which answer was used: `rules` or `llm`. Null when [answer] is null.
  final GuideAnsweredBy? by;

  const GuideItemResult(this.item, this.answer, this.by);

  bool get fails => answer == GuideAnswer.no;

  Map<String, dynamic> toMap() => {
        'id': item.id,
        'label': item.label,
        'required': item.required,
        'answer': answer?.name,
        if (by != null) 'by': by!.name,
        if (fails) 'reason': item.reason,
      };
}

/// Every item's result for a saved check: code's answers first where code
/// answers, the LLM's otherwise.
List<GuideItemResult> postGuideResults(PostGuideEntry entry) => [
      for (final item in postGuideItems)
        switch (item.answeredBy) {
          GuideAnsweredBy.rules => GuideItemResult(
              item, entry.rules[item.id], entry.rules[item.id] == null ? null : GuideAnsweredBy.rules),
          GuideAnsweredBy.llm => GuideItemResult(
              item, entry.llm[item.id], entry.llm[item.id] == null ? null : GuideAnsweredBy.llm),
          // A "does not apply" from the LLM wins over code's yes: code says
          // yes to the .exe item whenever a source link exists, though most
          // mods have no .exe at all.
          GuideAnsweredBy.rulesThenLlm when entry.llm[item.id] == GuideAnswer.notApplicable =>
            GuideItemResult(item, GuideAnswer.notApplicable, GuideAnsweredBy.llm),
          GuideAnsweredBy.rulesFirst => entry.rules[item.id] != null
              ? GuideItemResult(item, entry.rules[item.id], GuideAnsweredBy.rules)
              : GuideItemResult(
                  item, entry.llm[item.id], entry.llm[item.id] == null ? null : GuideAnsweredBy.llm),
          GuideAnsweredBy.rulesThenLlm => entry.rules[item.id] == GuideAnswer.yes
              ? GuideItemResult(item, GuideAnswer.yes, GuideAnsweredBy.rules)
              : GuideItemResult(item, entry.llm[item.id] ?? entry.rules[item.id],
                  entry.llm[item.id] != null
                      ? GuideAnsweredBy.llm
                      : entry.rules[item.id] == null
                          ? null
                          : GuideAnsweredBy.rules),
        },
    ];

/// Whether [detail]'s first post is checked against the guide: it was posted
/// or last edited on or after [postGuideDate]. [createdDate] is the topic
/// list's date for the thread, used when the post's own date is missing.
bool postGuideApplies(QbModDetail detail, {String? createdDate}) =>
    isAfterPostGuide(detail.postDate, createdDate) ||
    isAfterPostGuide(detail.lastEditDate, null);

/// Whether a forum date is on or after [postGuideDate]. The first of [first]
/// and [second] that can be read decides. The forum writes "Today at" and
/// "Yesterday at" for recent dates; they name no day but are always recent.
/// An edit date's "by <name>" tail is ignored.
bool isAfterPostGuide(String? first, String? second) {
  for (final text in [first, second]) {
    if (text == null || text.trim().isEmpty) continue;
    final trimmed = text.trim();
    if (trimmed.startsWith('Today') || trimmed.startsWith('Yesterday')) {
      return true;
    }
    final parsed = parseForumDate(trimmed);
    if (parsed != null) return !parsed.isBefore(postGuideDate);
  }
  return false;
}

/// The answers code can give for [detail], by item id. [sourceCodeFound] is
/// true when the post's own LLM read found a link to the mod's source code.
/// [aiDisclaimer] is the AI item's answer from that read's facts
/// ([aiDisclaimerFromFacts]), or null when they do not settle it.
Map<String, GuideAnswer> postGuideRules(QbModDetail detail,
    {bool sourceCodeFound = false, GuideAnswer? aiDisclaimer}) {
  final externalDownload = detail.links.any((link) =>
      link.isDownloadable && !link.url.contains('dlattach'));
  final pictures = detail.images.any((image) =>
      !isBadgeOrDonationImage(image.originalUrl) && !isForumFurniture(image.originalUrl));
  return {
    'gameVersionInTitle':
        hasGameVersionInTitle(detail.title) ? GuideAnswer.yes : GuideAnswer.no,
    'pictures': pictures ? GuideAnswer.yes : GuideAnswer.no,
    // Code only says yes. A post whose downloads the rules missed goes to the
    // LLM.
    if (externalDownload) 'externalDownload': GuideAnswer.yes,
    // The post's own LLM read already looks for a source code link, with its
    // own checks against the post. Where it found one, that settles it, for
    // an .exe too (unless the LLM says there is no .exe).
    if (sourceCodeFound) 'sourceCode': GuideAnswer.yes,
    if (sourceCodeFound) 'exeSourceCode': GuideAnswer.yes,
    if (aiDisclaimer != null) 'aiDisclaimer': aiDisclaimer,
  };
}

/// The AI disclaimer item answered from the post's own LLM read, which
/// records what the author says about AI use: whether AI was used, the tools
/// named (each one a whole word in the post) and the kinds of assets made.
/// The rules for posting a new mod ask for the model and the kinds of assets.
///
/// - The author says no AI was used: yes.
/// - AI was used and no tool is named: no.
/// - AI was used, a tool is named and at least one kind of asset: yes.
/// - Anything else (nothing stated, no answer saved, a tool named but no kind
///   of asset): null, and the guide check's own LLM answer is used.
///
/// A thread holding several mods counts as using AI when any of its mods does.
GuideAnswer? aiDisclaimerFromFacts(LlmStoreEntry? extraction) {
  final stated = [
    for (final mod in extraction?.mods ?? const <LlmMod>[])
      if (mod.extras?.aiUse case final aiUse?) aiUse,
  ];
  final used = stated.where((a) => a.usesAi == true).toList();
  if (used.isEmpty) {
    return stated.any((a) => a.usesAi == false) ? GuideAnswer.yes : null;
  }
  final toolNamed = used.any(
      (a) => (a.tools ?? const <String>[]).any((t) => t.trim().isNotEmpty));
  if (!toolNamed) return GuideAnswer.no;
  final assetsNamed = used.any((a) =>
      (a.uses ?? const <LlmAiUseEntry>[]).any((u) => u.area != AiUseArea.other));
  return assetsNamed ? GuideAnswer.yes : null;
}

/// Whether the post's own LLM read found a link to any of its mods' source
/// code.
bool sourceCodeFoundIn(LlmStoreEntry? extraction) =>
    extraction?.mods.any((mod) => mod.extras?.sourceCode?.trim().isNotEmpty ?? false) ??
    false;

/// Whether the post's own LLM read decided the thread is not a mod, such as a
/// question asked on a mod board. Those threads are not checked against the
/// guide.
bool notAModIn(LlmStoreEntry? extraction) => extraction?.isMod == false;

/// A game version in brackets anywhere in the title, such as "[0.98a]" or
/// "(0.97a-RC11)". Game versions all start with "0.". A dash on its own, as
/// TriOS's title has, is not a version.
bool hasGameVersionInTitle(String title) =>
    RegExp(r'[\[(][^\])]*?\b0\.\d').hasMatch(title);

/// Asks the LLM the guide's questions about one post at a time, and saves the
/// answers.
class PostGuideChecker {
  /// Used when the run sets no input limit. A forum post is rarely longer.
  static const defaultMaxInputChars = 60000;

  final LlmClient _client;
  final Future<bool> Function() _takeCall;
  final PostGuideStore store;
  final int maxInputChars;
  final Logger _log;

  int _calls = 0;
  int _failures = 0;

  PostGuideChecker({
    required LlmClient client,
    required Future<bool> Function() takeCall,
    required this.store,
    int? maxInputChars,
    Logger? logger,
  })  : _client = client,
        _takeCall = takeCall,
        maxInputChars = maxInputChars ?? defaultMaxInputChars,
        _log = logger ?? Logger('PostGuideChecker');

  /// Calls made by this checker.
  int get callCount => _calls;

  /// Calls that failed or gave an answer that could not be read.
  int get failureCount => _failures;

  /// Checks [detail] when its saved check is missing or out of date. Code's
  /// answers are worked out again every time, at no cost. Returns true when a
  /// call was spent, and false when the saved answer was still good, the post is
  /// too old, or the run's call budget is used up.
  ///
  /// [sourceCodeFound] says the post's own LLM read found a source code link,
  /// and [aiDisclaimer] is the AI item's answer from that read's facts.
  Future<bool> check(QbModDetail detail,
      {String? createdDate,
      bool sourceCodeFound = false,
      GuideAnswer? aiDisclaimer}) async {
    if (detail.isPlaceholderDetail) return false;
    if (!postGuideApplies(detail, createdDate: createdDate)) return false;

    final rules = postGuideRules(detail,
        sourceCodeFound: sourceCodeFound, aiDisclaimer: aiDisclaimer);
    final prompt = userPrompt(detail, maxInputChars: maxInputChars);
    final fingerprint = promptFingerprint(prompt);
    final saved = store.get(detail.topicId);
    if (saved != null && saved.fingerprint == fingerprint) {
      if (!_sameAnswers(saved.rules, rules)) {
        store.put(detail.topicId, saved.copyWith(rules: rules));
        await store.save();
      }
      return false;
    }

    if (!await _takeCall()) return false;
    _calls++;
    final request = LlmRequest(
      systemPrompt: systemPrompt,
      userPrompt: prompt,
      maxTokens: 400,
      jsonSchema: responseSchema,
      schemaName: 'post_guide_check',
    );
    Map<String, GuideAnswer>? answers;
    LlmResponse? response;
    try {
      response = await _client.complete(request);
      answers = parseAnswer(response.content);
      if (answers == null) {
        _log.warning('Could not read the LLM\'s post guide answer for topic '
            '${detail.topicId}: ${response.content}');
      }
    } on LlmException catch (e) {
      _log.warning('The post guide check for topic ${detail.topicId} failed: $e');
    }
    if (answers == null) {
      // Keep the old answer, if any, and try again next run.
      _failures++;
      return true;
    }
    store.put(
      detail.topicId,
      PostGuideEntry(
        fingerprint: fingerprint,
        checkedAt: DateTime.now().toUtc(),
        model: response?.model,
        endpoint: response?.endpoint,
        llm: answers,
        rules: rules,
      ),
    );
    await store.save();
    return true;
  }

  static bool _sameAnswers(Map<String, GuideAnswer> a, Map<String, GuideAnswer> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

  static final String systemPrompt = () {
    final b = StringBuffer()
      ..writeln("You check a Starsector mod's forum post against the forum's "
          'mod post guide. You get the thread title and the first post as '
          'simplified HTML. A spoiler is <details class="spoiler">, with its name '
          'in <summary>. A picture is <img>. Classes starting "size-" mark text '
          'the author made bigger or smaller.')
      ..writeln()
      ..writeln('Answer every question below with "yes", "no" or '
          '"notApplicable". Judge only what the post shows. Use "notApplicable" '
          'only where a question allows it. Answer in JSON only, with one '
          'field per question id.')
      ..writeln();
    for (final item in postGuideItems) {
      if (!item.askLlm) continue;
      b.writeln('${item.id}: ${item.question}');
    }
    return b.toString().trimRight();
  }();

  /// The thread title and the first post, as [cleanPostHtml] writes it, cut
  /// to [maxInputChars].
  static String userPrompt(QbModDetail detail, {required int maxInputChars}) {
    var post = cleanPostHtml(detail.contentHtml) ?? '';
    var cut = false;
    if (post.length > maxInputChars) {
      post = post.substring(0, maxInputChars);
      cut = true;
    }
    final b = StringBuffer()
      ..writeln('=== THREAD TITLE ===')
      ..writeln(detail.title)
      ..writeln()
      ..writeln('=== FIRST POST ===')
      ..writeln(post);
    if (cut) {
      b
        ..writeln()
        ..writeln('(The post was cut here for length. The rest of it is not '
            'shown.)');
    }
    return b.toString();
  }

  /// Changes whenever the prompt the post would be sent with changes.
  static String promptFingerprint(String userPrompt) => sha256
      .convert(utf8.encode('$postGuideVersion\n$systemPrompt\n$userPrompt'))
      .toString()
      .substring(0, 16);

  static final Map<String, dynamic> responseSchema = {
    'type': 'object',
    'properties': {
      for (final item in postGuideItems)
        if (item.askLlm)
          item.id: {
            'type': 'string',
            'enum': [
              'yes',
              'no',
              if (item.allowsNotApplicable) 'notApplicable',
            ],
          },
    },
    'required': [
      for (final item in postGuideItems)
        if (item.askLlm) item.id,
    ],
    'additionalProperties': false,
  };

  /// The model's answers by item id, or null when the answer is not JSON. Items
  /// the model left out or answered with something else are absent. A
  /// "notApplicable" is kept only where the question allows it; anywhere else it
  /// is dropped, so the item shows as unanswered rather than as a pass.
  static Map<String, GuideAnswer>? parseAnswer(String content) {
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(content.substring(start, end + 1));
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    final answers = <String, GuideAnswer>{};
    for (final item in postGuideItems) {
      if (!item.askLlm) continue;
      final answer = GuideAnswer.read(decoded[item.id]);
      if (answer == null) continue;
      if (answer == GuideAnswer.notApplicable && !item.allowsNotApplicable) {
        continue;
      }
      answers[item.id] = answer;
    }
    return answers;
  }
}
