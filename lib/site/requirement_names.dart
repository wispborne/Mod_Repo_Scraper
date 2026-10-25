import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'mod_id_store.dart';

/// The key used to match a requirement name. Remove any version and date.
/// Keep only letters and digits, in lower case.
///
/// Posts use different names for the same library: "LazyLib", "Lazy Lib",
/// "lazylib v3.0". All three produce the same key.
String requirementKey(String name) => ModIdStore.cleanName(name)
    .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

/// Who decided what a requirement's name means.
enum RequirementAnswerBy {
  /// Written into the file by a person. Always takes priority and is never replaced.
  hand,

  /// The LLM's answer. Replaced only when it said "none of these" and the list
  /// it was shown has changed since.
  llm,
}

/// What one way of writing a requirement's name means.
class RequirementAnswer {
  /// The name as a post first wrote it.
  final String written;

  /// The mod it means, by permanent id. Null means it is none of our mods.
  final String? id;

  final RequirementAnswerBy by;

  /// The date of the LLM's answer.
  final String? on;

  /// For an LLM answer of "none": a short fingerprint of the mods shown.
  /// When the list changes, ask about the name again.
  /// The intended mod may have just been added.
  final String? offered;

  const RequirementAnswer({
    required this.written,
    required this.id,
    required this.by,
    this.on,
    this.offered,
  });

  Map<String, dynamic> toJson() => {
        'written': written,
        'id': id,
        'by': by.name,
        if (on != null) 'on': on,
        if (offered != null) 'offered': offered,
      };

  static RequirementAnswer? fromJson(Object? json) {
    if (json is! Map) return null;
    final written = json['written'];
    final rawId = json['id'];
    if (written is! String || written.trim().isEmpty) return null;
    if (rawId != null && rawId is! String) return null;
    final id = (rawId as String?)?.trim();
    final by = RequirementAnswerBy.values
        .where((b) => b.name == json['by'])
        .firstOrNull;
    return RequirementAnswer(
      written: written,
      id: id == null || id.isEmpty ? null : id,
      // An entry with no "by" was written by a person.
      by: by ?? RequirementAnswerBy.hand,
      on: json['on'] is String ? json['on'] as String : null,
      offered: json['offered'] is String ? json['offered'] as String : null,
    );
  }
}

/// The saved answers to "which mod does this requirement name mean?", kept
/// between runs in `<qb_data_path>/requirement-names.json`.
///
/// Each spelling is matched once. The rules match most names on every build
/// at no cost. Rule matches are not saved. This file stores answers for names
/// the rules could not match: LLM answers and entries written by a person.
/// A hand entry needs only `written` and `id` (null for "none of our mods").
class RequirementNameStore {
  static const fileName = 'requirement-names.json';

  /// The last website build's requirement name matches, for the viewer.
  /// Written by the build. Never published.
  static const reportFileName = 'requirement-names-report.json';

  final String dataPath;
  final Logger _log;

  final Map<String, RequirementAnswer> _answers = {};
  bool _changed = false;

  /// True when the file exists but could not be read. It is not overwritten.
  /// This preserves hand entries if the file has a typo.
  bool _unreadable = false;

  RequirementNameStore(this.dataPath, {Logger? logger})
      : _log = logger ?? Logger('RequirementNameStore');

  File get file => File(p.join(dataPath, fileName));

  /// True when the file exists but could not be read. Saving is blocked.
  bool get isUnreadable => _unreadable;

  /// Every saved answer, by [requirementKey].
  Map<String, RequirementAnswer> get answers => Map.unmodifiable(_answers);

  /// Reads the file. A missing file is an empty store; one that cannot be read
  /// is logged and treated as empty.
  void load() {
    _answers.clear();
    _changed = false;
    _unreadable = false;
    final f = file;
    if (!f.existsSync()) return;
    try {
      final json = jsonDecode(f.readAsStringSync());
      final names = json is Map ? json['names'] : null;
      if (names is! Map) throw const FormatException('no "names" object');
      for (final entry in names.entries) {
        final answer = RequirementAnswer.fromJson(entry.value);
        if (answer == null) {
          _log.warning('Skipped an entry in ${f.path} that could not be read: '
              '"${entry.key}".');
          continue;
        }
        final key = requirementKey(answer.written);
        if (key.isEmpty) continue;
        // A hand entry takes priority over an LLM entry for the same name,
        // regardless of their order in the file.
        final there = _answers[key];
        if (there != null && there.by == RequirementAnswerBy.hand) continue;
        _answers[key] = answer;
      }
    } catch (e) {
      _unreadable = true;
      _answers.clear();
      _log.warning('Could not read ${f.path}. Saved dependency names will not be '
          'used. The file will not be overwritten: $e');
    }
  }

  RequirementAnswer? answerFor(String written) {
    final key = requirementKey(written);
    return key.isEmpty ? null : _answers[key];
  }

  /// Saves the LLM's answer for [written]. A hand entry is never replaced.
  void putLlmAnswer(String written, String? id,
      {required String offered, DateTime? now}) {
    final key = requirementKey(written);
    if (key.isEmpty) return;
    if (_answers[key]?.by == RequirementAnswerBy.hand) return;
    _answers[key] = RequirementAnswer(
      written: written,
      id: id,
      by: RequirementAnswerBy.llm,
      on: (now ?? DateTime.now()).toUtc().toIso8601String().substring(0, 10),
      offered: id == null ? offered : null,
    );
    _changed = true;
  }

  /// Saves a person's answer for [written]. The value is a mod id or null for
  /// none of our mods. Replaces the saved answer.
  void putHandAnswer(String written, String? id) {
    final key = requirementKey(written);
    if (key.isEmpty) return;
    _answers[key] =
        RequirementAnswer(written: written.trim(), id: id, by: RequirementAnswerBy.hand);
    _changed = true;
  }

  /// Removes the saved answer for [written]. The rules apply again.
  /// If they find no match, the LLM is asked again.
  void forget(String written) {
    if (_answers.remove(requirementKey(written)) != null) _changed = true;
  }

  /// Writes the file, if anything changed.
  Future<void> save() async {
    if (!_changed || _unreadable) return;
    final f = file;
    await f.parent.create(recursive: true);
    final keys = _answers.keys.toList()..sort();
    final text = const JsonEncoder.withIndent('  ').convert({
      'names': {for (final key in keys) key: _answers[key]!.toJson()},
    });
    final temp = File('${f.path}.tmp');
    await temp.writeAsString(text);
    await temp.rename(f.path);
    _changed = false;
  }
}

/// One mod a requirement can refer to, with all its names.
class RequiredModNames {
  final String id;

  /// What the site calls it.
  final String shownName;

  /// Its other real names: the catalog's name, the LLM's name for it.
  final List<String> names;

  /// The short names its own post uses ("Nex", "IndEvo"). Used only where no
  /// mod has that as a real name, and only when one mod uses it.
  final List<String> nicknames;

  const RequiredModNames({
    required this.id,
    required this.shownName,
    this.names = const [],
    this.nicknames = const [],
  });
}

/// How a requirement name was matched.
enum RequirementDecidedBy {
  /// A hand entry in the saved file.
  hand,

  /// The rules matched the name to a mod.
  rule,

  /// A saved LLM answer.
  llm,

  /// No match to our mods yet, or the LLM said none of our mods.
  unmatched,
}

/// A requirement name spelling used in the last build.
class RequirementNameSeen {
  /// The spelling first seen.
  final String written;

  /// How many times mods named it.
  final int count;

  /// The mod it was matched to, or null.
  final RequiredModMatch? match;

  final RequirementDecidedBy by;

  const RequirementNameSeen({
    required this.written,
    required this.count,
    required this.match,
    required this.by,
  });

  Map<String, dynamic> toJson() => {
        'written': written,
        'count': count,
        if (match != null) 'id': match!.id,
        if (match != null) 'name': match!.name,
        'by': by.name,
      };
}

/// A mod a requirement name was matched to.
class RequiredModMatch {
  final String id;
  final String name;

  const RequiredModMatch(this.id, this.name);
}

/// Works out which of our mods a requirement's name means.
///
/// First check for a hand entry in the saved file. Then apply the rules,
/// which compare only letters and digits in every mod name and nickname.
/// Then check for a saved LLM answer. Keep unmatched names as written in the
/// post. [unmatched] counts how often each name appeared.
/// The LLM step asks about these names.
class RequirementResolver {
  final Map<String, RequiredModNames> _byId = {};
  final Map<String, String> _byName = {};
  final Map<String, String> _byNickname = {};
  final RequirementNameStore? _store;

  /// Names nothing matched, by [requirementKey], with the spelling first seen
  /// and how many mods wrote it.
  final Map<String, ({String written, int count})> unmatched = {};

  /// Every name checked, by [requirementKey], and how it was matched.
  final Map<String, RequirementNameSeen> seen = {};

  RequirementResolver(Iterable<RequiredModNames> mods,
      {RequirementNameStore? store})
      : _store = store {
    final nicknameOwners = <String, Set<String>>{};
    for (final mod in mods) {
      _byId.putIfAbsent(mod.id, () => mod);
      for (final name in [mod.shownName, ...mod.names]) {
        final key = requirementKey(name);
        // Two mods can share a name (a fork, an old thread); the first one
        // keeps it, as it always has.
        if (key.isNotEmpty) _byName.putIfAbsent(key, () => mod.id);
      }
      for (final nickname in mod.nicknames) {
        final key = requirementKey(nickname);
        if (key.isNotEmpty) {
          (nicknameOwners[key] ??= <String>{}).add(mod.id);
        }
      }
    }
    for (final MapEntry(:key, :value) in nicknameOwners.entries) {
      if (value.length == 1 && !_byName.containsKey(key)) {
        _byNickname[key] = value.single;
      }
    }
  }

  /// The mod named by [written]. Returns null if it names none of our mods
  /// or has no match yet. Names with no match are counted in [unmatched].
  RequiredModMatch? resolve(String written) {
    final key = requirementKey(written);
    if (key.isEmpty) return null;

    final saved = _store?.answerFor(written);
    if (saved != null && saved.by == RequirementAnswerBy.hand) {
      return _note(key, written, _matchFor(saved.id), RequirementDecidedBy.hand);
    }

    final byRule = _byName[key] ?? _byNickname[key];
    if (byRule != null) {
      return _note(key, written, _matchFor(byRule), RequirementDecidedBy.rule);
    }

    // Ignore an LLM answer for a mod that is no longer in the catalog.
    final match = _matchFor(saved?.id);
    if (match != null) return _note(key, written, match, RequirementDecidedBy.llm);
    _note(key, written, null, RequirementDecidedBy.unmatched);

    // Count this even when the LLM said "none of these". The LLM step asks
    // again when the list of mods shown to it changes.
    final seen = unmatched[key];
    unmatched[key] = (written: seen?.written ?? written, count: (seen?.count ?? 0) + 1);
    return null;
  }

  RequiredModMatch? _note(
      String key, String written, RequiredModMatch? match, RequirementDecidedBy by) {
    final before = seen[key];
    seen[key] = RequirementNameSeen(
      written: before?.written ?? written,
      count: (before?.count ?? 0) + 1,
      match: match,
      by: by,
    );
    return match;
  }

  RequiredModMatch? _matchFor(String? id) {
    final mod = id == null ? null : _byId[id];
    return mod == null ? null : RequiredModMatch(mod.id, mod.shownName);
  }
}
