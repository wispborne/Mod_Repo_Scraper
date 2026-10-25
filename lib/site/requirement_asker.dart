import 'dart:convert';

import 'package:logging/logging.dart';

import '../bot/scraper/qb/llm/llm_client.dart';
import 'requirement_names.dart';

/// Asks the LLM to match requirement names the rules could not match.
/// Saves each answer so the same name does not need another call.
///
/// The extraction prompt stays unchanged. A library list in that prompt would
/// change every post's fingerprint each time a library was added.
/// Every post would then be read again. This step asks about several spellings
/// in one small call, once per spelling.
class RequirementAsker {
  /// Names sent in one call.
  static const namesPerCall = 20;

  /// A name shorter than this (letters and digits) is never asked about.
  /// "Nex" could be Nexerelin or something else, and a wrong guess sends
  /// readers to the wrong mod. Such a name needs a hand entry.
  static const shortestNameAsked = 4;

  final LlmClient _client;

  /// Reserves one call from the run's LLM budget. Returns false if none remain.
  final Future<bool> Function() _takeCall;

  final Logger _log;

  int _calls = 0;

  RequirementAsker({
    required LlmClient client,
    required Future<bool> Function() takeCall,
    Logger? logger,
  })  : _client = client,
        _takeCall = takeCall,
        _log = logger ?? Logger('RequirementAsker');

  /// How many calls this asker has made.
  int get callCount => _calls;

  /// Asks about every name in [unmatched] that has no saved answer yet, or
  /// whose saved "none" was given against a different list of mods. Returns
  /// how many names were matched to a mod.
  Future<int> ask({
    required Map<String, ({String written, int count})> unmatched,
    required List<RequiredModNames> candidates,
    required RequirementNameStore store,
    void Function(String message)? log,
  }) async {
    if (unmatched.isEmpty || candidates.isEmpty) return 0;
    final offered = offeredFingerprint(candidates);
    final byId = {for (final c in candidates) c.id: c};

    final tooShort = <String>[];
    final toAsk = <String>[];
    final names = unmatched.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    for (final name in names) {
      final saved = store.answerFor(name.written);
      if (saved != null &&
          (saved.by == RequirementAnswerBy.hand ||
              saved.id != null ||
              saved.offered == offered)) {
        continue;
      }
      if (requirementKey(name.written).length < shortestNameAsked) {
        tooShort.add(name.written);
      } else {
        toAsk.add(name.written);
      }
    }
    if (tooShort.isNotEmpty) {
      _say(
          log,
          'These dependency names are too short to send to the LLM. Add '
          'hand entries in ${RequirementNameStore.fileName}: '
          '${tooShort.map((n) => '"$n"').join(', ')}.');
    }
    if (toAsk.isEmpty) return 0;

    var matched = 0;
    var asked = 0;
    for (var start = 0; start < toAsk.length; start += namesPerCall) {
      if (!await _takeCall()) {
        _say(
            log,
            'The LLM budget ran out with ${toAsk.length - start} dependency '
            'names still to ask about. The next run will ask about them.');
        break;
      }
      _calls++;
      final batch = toAsk.skip(start).take(namesPerCall).toList();
      final answers = await _askOnce(batch, candidates);
      if (answers == null) continue;
      for (final written in batch) {
        // A name the answer left out is asked about again next run.
        if (!answers.containsKey(written)) continue;
        final id = answers[written];
        store.putLlmAnswer(written, byId.containsKey(id) ? id : null,
            offered: offered);
        asked++;
        if (byId.containsKey(id)) matched++;
      }
      // Save after each call so paid answers are kept if the run fails.
      await store.save();
    }
    _say(
        log,
        'Asked the LLM about $asked dependency names in $_calls calls. '
        '$matched names matched our mods.');
    return matched;
  }

  /// Sends one batch. Null when the call failed or the answer could not be
  /// read; the names are then asked about next run.
  Future<Map<String, String?>?> _askOnce(
      List<String> names, List<RequiredModNames> candidates) async {
    final request = LlmRequest(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt(names, candidates),
      maxTokens: 100 + 40 * names.length,
      jsonSchema: responseSchema,
      schemaName: 'requirement_names',
    );
    try {
      final response = await _client.complete(request);
      final answers = parseAnswer(response.content, names);
      if (answers == null) {
        _log.warning('Could not read the LLM\'s answer about dependency '
            'names: ${response.content}');
      }
      return answers;
    } on LlmException catch (e) {
      _log.warning('The LLM call about dependency names failed: $e');
      return null;
    }
  }

  static const systemPrompt =
      'Match requirement names to Starsector mods. Each name below appears in a '
      "mod's forum post as a required mod. For each name, return the id of "
      'the mod it refers to from the list. Treat spelling mistakes, missing '
      'or extra spaces, a missing or extra "s", and short forms as the same '
      'mod. Do not match a different mod just because its name is similar. '
      'Return null if none of the listed mods match or you are not sure. '
      'Answer in JSON only: {"answers": [{"name": "<name as given>", '
      '"id": "<id from the list or null>"}]}';

  static String userPrompt(List<String> names, List<RequiredModNames> candidates) {
    final b = StringBuffer('=== MODS ===\n');
    for (final c in candidates) {
      final others = {...c.names, ...c.nicknames}
          .where((n) => n.trim().isNotEmpty && n != c.shownName)
          .toList();
      b.write('- ${c.id}: ${c.shownName}');
      if (others.isNotEmpty) b.write(' (also: ${others.join(', ')})');
      b.writeln();
    }
    b.writeln('\n=== NAMES ===');
    for (final name in names) {
      b.writeln('- $name');
    }
    return b.toString();
  }

  static const responseSchema = <String, dynamic>{
    'type': 'object',
    'properties': {
      'answers': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'id': {
              'type': ['string', 'null'],
            },
          },
          'required': ['name', 'id'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['answers'],
    'additionalProperties': false,
  };

  /// The model's answers, keyed by the names sent to it. Use [requirementKey]
  /// to match names the model spelled differently. Names the model left out
  /// are absent from the map.
  static Map<String, String?>? parseAnswer(String content, List<String> asked) {
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(content.substring(start, end + 1));
    } catch (_) {
      return null;
    }
    final list = decoded is Map ? decoded['answers'] : null;
    if (list is! List) return null;

    final askedByKey = {for (final name in asked) requirementKey(name): name};
    final answers = <String, String?>{};
    for (final item in list) {
      if (item is! Map) continue;
      final name = item['name'];
      final id = item['id'];
      if (name is! String) continue;
      final written = askedByKey[requirementKey(name)];
      if (written == null) continue;
      answers[written] = id is String && id.trim().isNotEmpty && id != 'null'
          ? id.trim()
          : null;
    }
    return answers;
  }

  /// A short fingerprint of which mods were offered. A saved "none" is asked
  /// again when this changes.
  static String offeredFingerprint(List<RequiredModNames> candidates) {
    final ids = candidates.map((c) => c.id).toList()..sort();
    // FNV-1a, 32 bits: short, and the same on every machine.
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode(ids.join('\n'))) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  void _say(void Function(String message)? log, String message) {
    _log.info(message);
    log?.call(message);
  }
}
