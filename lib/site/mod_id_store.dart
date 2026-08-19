import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Hands out each mod's permanent id, and remembers every one it has given.
///
/// A mod's web address is built from its id, so the id can never be worked out
/// fresh on every run: a thread's title carries the version and changes on every
/// release, so "Nexerelin v0.12.1e" and "Nexerelin v0.12.2" have to end up at
/// the same address. So the id is worked out once, from the mod's name with the
/// version parts stripped off, written to `<data path>/mod-ids.json`, and read
/// back on every later run.
///
/// If that file exists but cannot be read, [load] throws. The run must then fail
/// and publish nothing — handing out fresh ids would move every mod's page to a
/// new address and break every link anyone had saved.
class ModIdStore {
  static const String fileName = 'mod-ids.json';

  final String dataPath;

  /// Everything remembered about one mod, keyed by what identifies it between
  /// runs. The id never changes once it is in here.
  final Map<String, _Entry> _entries = {};

  /// What today is. Only tests change it.
  final DateTime Function() _now;

  /// Every id given out so far, so a new mod never lands on a taken one.
  final Set<String> _idsTaken = {};

  /// True when [idFor] handed out something new since the last [save].
  bool _changed = false;

  ModIdStore(this.dataPath, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  String get filePath => p.join(dataPath, fileName);

  /// How many mods have an id.
  int get count => _entries.length;

  /// True when there are new ids to write.
  bool get hasUnsavedIds => _changed;

  /// Reads the stored ids. A missing file is fine — that is the first run, and
  /// every mod is about to be given its first id. A file that is there but
  /// cannot be read is not fine, and throws.
  void load() {
    final file = File(filePath);
    if (!file.existsSync()) return;

    final Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } catch (e) {
      throw StateError(
        'Cannot read the mod id file at $filePath: $e\n'
        'Every mod page is at an address built from these ids, so the run has '
        'stopped rather than hand out new ones. Put the file back, or delete it '
        'if you mean every mod to get a new address.',
      );
    }

    if (decoded is! Map || decoded['ids'] is! Map) {
      throw StateError(
        'The mod id file at $filePath is not the shape we wrote it in — it '
        'should hold an "ids" object of mod name to id. The run has stopped '
        'rather than hand out new ids for mods that already had them.',
      );
    }

    (decoded['ids'] as Map).forEach((name, stored) {
      if (name is! String || name.isEmpty) return;

      // Written as a plain id to begin with, and as an object once the day a
      // mod was first seen was worth keeping. Both are read.
      final String? id;
      final String? firstSeen;
      if (stored is String) {
        id = stored;
        firstSeen = null;
      } else if (stored is Map) {
        id = stored['id'] as String?;
        firstSeen = stored['firstSeen'] as String?;
      } else {
        return;
      }

      if (id == null || id.isEmpty) return;
      _entries[name] = _Entry(
        id: id,
        firstSeen: (firstSeen?.isEmpty ?? true) ? null : firstSeen,
        mark: stored is Map ? stored['mark'] as String? : null,
      );
      _idsTaken.add(id);
    });
  }

  /// The id for [modName], handing out a new one the first time a mod is seen.
  /// The same mod always comes back with the same id, whatever else changed
  /// about it.
  ///
  /// [mark] is whatever tells two mods of the same name apart — its forum topic
  /// id, or failing that its author. A dozen real mods share a name with an
  /// unrelated mod (two different "Kadur Remnant" threads, "CarrierUI" by two
  /// people), and each of them needs its own page. The first one to claim a name
  /// keeps the plain id; the next gets the same id with a number on the end.
  String idFor(String modName, {String? mark}) {
    final entry = _entryFor(modName, mark, claim: true);
    return entry!.id;
  }

  /// The day this mod was first seen, as `YYYY-MM-DD`, or null for one that was
  /// already in the file before we started keeping that.
  String? firstSeenFor(String modName, {String? mark}) =>
      _entryFor(modName, mark, claim: false)?.firstSeen;

  /// Finds the entry for a mod, and — when [claim] — makes one if there is none.
  ///
  /// A mod is looked for under its name first. When that name is already spoken
  /// for by a different mod, it is looked for under its name and its mark
  /// together, which is what gives the second mod of a name its own id.
  _Entry? _entryFor(String modName, String? mark, {required bool claim}) {
    final base = cleanName(modName);
    final wanted = (mark ?? '').trim().toLowerCase();

    final held = _entries[base];
    if (held != null) {
      // An entry written before marks were kept belongs to whichever mod asks
      // first, and takes that mod's mark from then on.
      if (held.mark == null) {
        if (claim) {
          held.mark = wanted;
          _changed = true;
        }
        return held;
      }
      if (held.mark == wanted) return held;
    } else {
      if (!claim) return null;
      return _claim(base, wanted);
    }

    // Somebody else has the plain name. This mod is remembered under its name
    // and its mark, and gets a numbered id.
    final key = '$base#$wanted';
    final own = _entries[key];
    if (own != null) return own;
    if (!claim) return null;
    return _claim(key, wanted, slugFrom: base);
  }

  _Entry _claim(String key, String mark, {String? slugFrom}) {
    final entry = _Entry(
      id: _freeId(slugify(slugFrom ?? key)),
      firstSeen: _today(),
      mark: mark,
    );
    _entries[key] = entry;
    _idsTaken.add(entry.id);
    _changed = true;
    return entry;
  }

  String _today() {
    final now = _now().toUtc();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  /// The id already given to [modName], or null when it has never been seen.
  /// Hands nothing out.
  String? existingIdFor(String modName, {String? mark}) =>
      _entryFor(modName, mark, claim: false)?.id;

  /// Writes the ids back, if any were handed out. Written every time the caller
  /// asks, not at the end of a run, so a run that dies part-way keeps the ids it
  /// already gave.
  void save() {
    final dir = Directory(dataPath);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    // Sorted, so the file reads plainly and its diffs stay small.
    final names = _entries.keys.toList()..sort();
    final ids = <String, dynamic>{
      for (final name in names)
        name: {
          'id': _entries[name]!.id,
          if (_entries[name]!.firstSeen != null)
            'firstSeen': _entries[name]!.firstSeen,
          if (_entries[name]!.mark != null) 'mark': _entries[name]!.mark,
        },
    };
    File(filePath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({'ids': ids}),
    );
    _changed = false;
  }

  /// [base] itself when nothing has it, else [base] with a number on the end.
  /// The mod that got there first keeps the plain one.
  String _freeId(String base) {
    final start = base.isEmpty ? 'mod' : base;
    if (!_idsTaken.contains(start)) return start;
    for (var n = 2;; n++) {
      final candidate = '$start-$n';
      if (!_idsTaken.contains(candidate)) return candidate;
    }
  }

  // ---------------------------------------------------------------------------

  /// A game version in square brackets at the front of a thread title, e.g.
  /// "[0.98a]" or "[0.98a-RC8]". Several in a row are stripped, so
  /// "[0.98a][WIP] Some Mod" comes back as "Some Mod".
  static final RegExp _leadingBrackets = RegExp(r'^(?:\s*[\[(][^\]\)]*[\]\)])+');

  /// A date on the end, in any of the spellings threads use.
  static final RegExp _trailingDate = RegExp(
    r'[\s,\-\(\[]*\d{1,4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,4}[\s\)\]]*$',
  );

  /// A version on the end: "v1.2.3", "1.2.3a", "ver 2.0", "(v0.9 beta)".
  ///
  /// It has to be either a "v" and digits, or digits with a dot in them. A lone
  /// number on the end is left alone, because plenty of mods really are called
  /// "Ship Pack 2" and their name is not a version.
  static final RegExp _trailingVersion = RegExp(
    r'[\s,\-\u2013\u2014\(\[]*'
    r'(?:'
    r'(?:v|v\.|ver|ver\.|version|rev|update)\s*\d+(?:\.\d+)*[a-z]{0,2}'
    r'|'
    r'\d+(?:\.\d+)+[a-z]{0,2}'
    r')'
    r'(?:[\s\-]*(?:rc|alpha|beta|pre|dev|wip)[\s\-]*\d*)?'
    r'[\s\)\]]*$',
    caseSensitive: false,
  );

  /// A version written out anywhere in the name, e.g. " v0.12.2" or " ver 1.4".
  /// A "v" and digits is only ever a version, so it is safe to take out wherever
  /// it sits — which is what handles "Nexerelin v0.12.2 - diplomacy and war".
  static final RegExp _versionAnywhere = RegExp(
    r'\s(?:v|ver|version|rev)\.?\s?\d+(?:\.\d+)*[a-z]{0,2}\b',
    caseSensitive: false,
  );

  /// Whitespace, in any amount.
  static final RegExp _spaces = RegExp(r'\s+');

  /// Anything that is not a letter or a number.
  static final RegExp _notWordy = RegExp(r'[^a-z0-9]+');

  /// A mod's name with everything that changes on a release taken off: the
  /// bracketed game version at the front, the mod version, and any date. What is
  /// left is what stays the same from one release to the next, so it is what the
  /// id is remembered under.
  static String cleanName(String modName) => stripReleaseParts(modName).toLowerCase();

  /// The same stripping as [cleanName], with the author's own capitals left
  /// alone. The id wants it lower case; the name shown on the site does not.
  static String stripReleaseParts(String modName) {
    var name = modName.trim();
    name = name.replaceFirst(_leadingBrackets, '').trim();
    name = name.replaceAll(_versionAnywhere, ' ').trim();

    // A version and a date can both be on the end, in either order, and a title
    // can carry more than one bracketed part. Keep taking bits off while
    // something comes off, so "Some Mod v1.2 (2024-01-05)" ends at "Some Mod".
    for (var pass = 0; pass < 4; pass++) {
      final before = name;
      name = name.replaceFirst(_trailingDate, '').trim();
      name = name.replaceFirst(_trailingVersion, '').trim();
      if (name == before) break;
    }

    return name.replaceAll(_spaces, ' ').trim();
  }

  /// A cleaned name turned into something that reads plainly in an address:
  /// lower case, letters and numbers, dashes between the words.
  static String slugify(String cleanedName) {
    final slug = cleanedName
        .toLowerCase()
        .replaceAll(_notWordy, '-')
        .replaceAll(RegExp(r'-+'), '-');
    return slug.replaceAll(RegExp(r'^-|-$'), '');
  }
}

/// One mod's line in the id file.
class _Entry {
  /// The id it was given, which never changes.
  final String id;

  /// The day it was first seen, as `YYYY-MM-DD`. Null for a mod already in the
  /// file before that was kept.
  final String? firstSeen;

  /// What tells this mod apart from another of the same name — its forum topic
  /// id, or its author. Null for a line written before this was kept, which is
  /// filled in the next time that mod is seen.
  String? mark;

  _Entry({required this.id, this.firstSeen, this.mark});
}
