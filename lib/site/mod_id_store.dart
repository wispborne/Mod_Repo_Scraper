import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../catalog/source_post.dart';
import 'mod_name_match.dart';

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

  /// Each id's entry under every source post it is linked to, keyed by
  /// [SourcePostRef.key] — `forum:34161#Useful.Tithes` names one mod on a
  /// shared topic, `forum:9175` a whole topic.
  final Map<String, _Entry> _byPost = {};

  /// The same entries keyed by the post alone, without the LLM's name.
  final Map<String, List<_Entry>> _byPostOnly = {};

  /// Entries a mod has already been given in this run, so two mods never share
  /// one id.
  final Set<_Entry> _givenThisRun = {};

  /// Entries held back for a Collection's page, never given to a mod.
  final Set<_Entry> _reserved = {};

  /// Every listing's [SourcePostRef.key] in this run, as the catalog gave them
  /// to [beginRun]. This is what says an old name has gone from its post.
  final Set<String> _keysThisRun = {};

  /// [_keysThisRun] without the LLM names: every post that gives a listing in
  /// this build.
  final Set<String> _postsThisRun = {};

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
      final entry = _Entry(
        id: id,
        firstSeen: (firstSeen?.isEmpty ?? true) ? null : firstSeen,
        mark: stored is Map ? stored['mark'] as String? : null,
      );
      _entries[name] = entry;
      _idsTaken.add(id);
      // Older entries have no posts yet; `bin/link_mod_ids.dart` fills them in.
      final posts = stored is Map ? stored['posts'] : null;
      if (posts is List) {
        for (final post in posts) {
          if (post is String && post.isNotEmpty) _linkKey(entry, post);
        }
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Ids found by source post
  // ---------------------------------------------------------------------------

  /// Starts a new catalog build: no id has been handed out in it yet, and no
  /// Collection is held back yet. A store kept between builds (a long-lived
  /// server) would otherwise treat every id as already taken.
  ///
  /// [refsThisRun] is every listing's ref in this build. Only with it can a
  /// mod the LLM renamed on a shared post keep its id (see [_renamedEntry]);
  /// without it nothing is re-linked.
  void beginRun({Iterable<SourcePostRef> refsThisRun = const []}) {
    _givenThisRun.clear();
    _reserved.clear();
    _keysThisRun
      ..clear()
      ..addAll([for (final ref in refsThisRun) if (ref.id.isNotEmpty) ref.key]);
    _postsThisRun
      ..clear()
      ..addAll([for (final ref in refsThisRun) if (ref.id.isNotEmpty) ref.post.key]);
  }

  /// The id for a mod made of [refs], found through its source posts first.
  ///
  /// A name changes — a better index line, an LLM name for a Discord
  /// announcement, a thread retitled for a release — and a post does not. So
  /// the posts are asked first, and the name only when none of them has an id
  /// yet; a brand-new mod gets a new id from its name, numbered when that is
  /// taken. Either way every one of [refs] is linked to the id from then on.
  ///
  /// An id that was a forum topic's own page stays with that topic. When this
  /// mod has a forum topic of its own, and the id's topic gives a listing in
  /// this build and is not one of [refs], the id is not taken here, even when
  /// another of the mod's posts is linked to it. A Discord announcement can
  /// join a different forum topic than the one the old site paired it with
  /// (Exotica's Discord thread is Kaysaar's edition, topic 29538, where the old
  /// site had it with topic 32811), and two forum topics are never one mod, so
  /// the topic's id belongs with the topic. A mod with no forum topic may still
  /// take it: `ModCatalog.build` hands ids to the mods with forum topics first,
  /// so by then the topic has had its chance, and an id it left is better used
  /// than lost (topic 30580 is now Xxarra's, and NEON's Discord threads keep
  /// "neon-s-ship-pack").
  ///
  /// When the posts still point at two different ids, two pages are being
  /// joined into one. The older id wins, [onClash] is told, and the other id is
  /// left where it is — never handed to another mod.
  ///
  /// [onRenamed] is told when a post's id was found under the LLM's old name
  /// for the mod.
  String idForPosts(
    String modName, {
    String? mark,
    required List<SourcePostRef> refs,
    void Function(String message)? onClash,
    void Function(String message)? onRenamed,
  }) {
    final found = <_Entry>[];
    for (final ref in refs) {
      final entry = _entryForRef(ref);
      if (entry != null && !found.contains(entry)) found.add(entry);
      if (entry != null && onRenamed != null && ref.llmModName != null && _byPost[ref.key] != entry) {
        final old = _oldNamesOn(entry, ref.post.key);
        if (old.isNotEmpty) {
          onRenamed('"${ref.llmModName}" on ${ref.post.key} keeps the id "${entry.id}", which it had as '
              '${old.map((n) => '"$n"').join(' and ')}: the LLM named it differently this time.');
        }
      }
    }

    final mine = {for (final ref in refs) ref.post.key};
    final hasForumTopic = mine.any((key) => key.startsWith('forum:'));
    if (hasForumTopic) found.removeWhere((entry) => _isOtherTopicsPage(entry, mine));

    _Entry? chosen;
    if (found.isNotEmpty) {
      found.sort(_olderFirst);
      chosen = found.first;
      if (found.length > 1) {
        onClash?.call('"$modName" comes from posts that had different ids '
            '(${found.map((e) => e.id).join(', ')}); it keeps the oldest, '
            '"${chosen.id}". Two pages are being joined into one; check it.');
      }
    } else {
      final existing = _entryFor(modName, mark, claim: false);
      if (existing == null) {
        chosen = _entryFor(modName, mark, claim: true);
      } else if (_givenThisRun.contains(existing) ||
          _reserved.contains(existing) ||
          _ownedByOtherPosts(existing, refs) ||
          (hasForumTopic && _isOtherTopicsPage(existing, mine))) {
        // The name's id already belongs to a different mod — one given out this
        // run, a Collection's page, or a mod from other posts. A new id, so no
        // id ever leads to two mods.
        final wanted = (mark ?? '').trim().toLowerCase();
        chosen = _claim(_freeKey(cleanName(modName), wanted), wanted, slugFrom: cleanName(modName));
      } else {
        // Claimed by name the way it always was, which also fills in the mark
        // of an entry written before marks were kept.
        chosen = _entryFor(modName, mark, claim: true);
      }
    }

    _givenThisRun.add(chosen!);
    for (final ref in refs) {
      if (ref.id.isEmpty) continue;
      _link(chosen, ref);
    }
    return chosen.id;
  }

  /// True when [entry] was the page of a whole forum topic that is not one of
  /// [mine] and still gives a listing in this build.
  bool _isOtherTopicsPage(_Entry entry, Set<String> mine) => entry.posts.any(
      (key) => key.startsWith('forum:') && !key.contains('#') && !mine.contains(key) && _postsThisRun.contains(key));

  /// The names the mods were known by when they were given the ids [refs] are
  /// already linked to, lower case, as the id file keys them. Hands nothing
  /// out. `ModCatalog.build` asks this to let the mod that still goes by an
  /// id's name claim it before anything else does.
  List<String> namesLinkedTo(List<SourcePostRef> refs) {
    final names = <String>[];
    for (final ref in refs) {
      final entry = _entryForRef(ref);
      if (entry == null) continue;
      for (final MapEntry(:key, :value) in _entries.entries) {
        if (!identical(value, entry)) continue;
        final at = key.indexOf('#');
        names.add(at < 0 ? key : key.substring(0, at));
      }
    }
    return names;
  }

  /// The id [ref] is already linked to, or null. Hands nothing out. The merge
  /// asks this to keep together the posts that already share an id.
  String? idLinkedTo(SourcePostRef ref) => _entryForRef(ref)?.id;

  /// Holds back the id a Collection's post already had, so its page stays at
  /// that address and no mod is ever given it. Returns the id, or null when the
  /// Collection never had one — it then gets no id and no page.
  String? reserveCollection(String collectionName, {String? mark, required SourcePostRef ref}) {
    final entry = _byPost[ref.post.key] ??
        _uniqueOrNull(_byPostOnly[ref.post.key]) ??
        _entryFor(collectionName, mark, claim: false);
    if (entry == null) return null;
    _reserved.add(entry);
    _link(entry, ref.post);
    return entry.id;
  }

  /// The day the mod with this id was first seen, or null.
  String? firstSeenOfId(String id) {
    for (final entry in _entries.values) {
      if (entry.id == id) return entry.firstSeen;
    }
    return null;
  }

  /// The source post keys linked to [id], for checks and tests.
  List<String> postsOfId(String id) {
    for (final entry in _entries.values) {
      if (entry.id == id) return List.unmodifiable(entry.posts);
    }
    return const [];
  }

  /// Links [ref] to the entry that has [id]. For the one-time linking step,
  /// which knows each id's posts from the published site.
  void linkIdToPost(String id, SourcePostRef ref) {
    for (final entry in _entries.values) {
      if (entry.id == id) {
        _link(entry, ref);
        return;
      }
    }
    throw ArgumentError('No mod has the id "$id".');
  }

  _Entry? _entryForRef(SourcePostRef ref) {
    if (ref.id.isEmpty) return null;
    final exact = _byPost[ref.key];
    if (_usable(exact)) return exact;
    if (ref.llmModName != null) {
      // Linked before the LLM named this mod: the whole post's entry, when the
      // post has just the one.
      final whole = _byPost[ref.post.key];
      if (_usable(whole) && (_byPostOnly[ref.post.key]?.length ?? 0) <= 1) return whole;
      return _renamedEntry(ref) ?? _wholePostEntryLeft(ref.post.key);
    }
    // Asked about a whole post: its entry when there is exactly one.
    final candidates = [for (final e in _byPostOnly[ref.post.key] ?? const <_Entry>[]) if (_usable(e)) e];
    return candidates.length == 1 ? candidates.single : _wholePostEntryLeft(ref.post.key);
  }

  /// The one whole-post id left on [post] once the ids that belong elsewhere
  /// are set aside, or null.
  ///
  /// The old site sometimes made two pages from one topic, and both were linked
  /// to the whole topic. Topic 35988 had one page of its own and one shared with
  /// its Discord thread. The Discord thread gives a mod of its own this run and
  /// keeps the shared id, so the topic's own id is the only one left for it.
  /// Without this the topic got a new id and lost its address.
  ///
  /// Only ids linked to the whole post count. An id linked under an LLM name is
  /// left to [_renamedEntry], which is careful for good reason (topic 34161).
  /// An id also linked to another post in this build is set aside: it goes with
  /// that post. Two or more left over is still nobody's.
  _Entry? _wholePostEntryLeft(String post) {
    final left = [
      for (final entry in _byPostOnly[post] ?? const <_Entry>[])
        if (_usable(entry) &&
            entry.posts.contains(post) &&
            _oldNamesOn(entry, post).isEmpty &&
            !entry.posts.any((key) => _postOnlyKey(key) != post && _postsThisRun.contains(_postOnlyKey(key))))
          entry,
    ];
    return left.length == 1 ? left.single : null;
  }

  bool _usable(_Entry? entry) =>
      entry != null && !_reserved.contains(entry) && !_givenThisRun.contains(entry);

  /// The id a mod had on a shared post under the LLM's old name for it, or
  /// null.
  ///
  /// The LLM reads a post again whenever the post or the prompt changes, and
  /// does not always spell a mod the same way: topic 12535's "BSP Peenemunde"
  /// came back as "Peenemunde Mobile Battlestation". On a post with one mod the
  /// whole post's id covers that. On a post with several, a new name finds
  /// nothing, and the mod would get a new id and lose its address.
  ///
  /// So an old name is looked for, carefully, because giving one mod's address
  /// to another is worse than a new address. All of these must hold:
  ///
  /// - The old name is gone from the post this run, and the new name is new.
  /// - The two names mean the same mod by [modNamesMatch], or they share a word
  ///   that no other name on the post uses, old or new, and that at most two
  ///   names in the whole id file use. That last part keeps out words like
  ///   "start" and "ships", which name a dozen different mods.
  /// - Exactly one old name fits the new name, and no other new name on the
  ///   post fits that old name.
  ///
  /// Being the one name left over on each side is never enough: topic 34161
  /// lost "Corrupt.Officials" and gained "Useful.Tithes" in the same run, and
  /// those are two mods.
  _Entry? _renamedEntry(SourcePostRef ref) {
    if (!_keysThisRun.contains(ref.key)) return null;
    final post = ref.post.key;
    final gone = [
      for (final entry in _byPostOnly[post] ?? const <_Entry>[])
        if (_usable(entry) && _goneFrom(entry, post) && _oldNamesOn(entry, post).isNotEmpty) entry,
    ];
    if (gone.isEmpty) return null;

    final fits = [for (final entry in gone) if (_couldBeRenamed(ref.llmModName!, entry, post, gone)) entry];
    if (fits.length != 1) return null;
    final match = fits.single;

    final otherNewNames = [
      for (final key in _keysThisRun)
        if (key != ref.key && _postOnlyKey(key) == post && key.length > post.length && !_byPost.containsKey(key))
          key.substring(post.length + 1),
    ];
    if (otherNewNames.any((name) => _couldBeRenamed(name, match, post, gone))) return null;
    return match;
  }

  /// True when none of [entry]'s keys on [post] is a listing in this run.
  bool _goneFrom(_Entry entry, String post) =>
      !entry.posts.any((key) => _postOnlyKey(key) == post && _keysThisRun.contains(key));

  /// The LLM's names [entry] was linked under on [post].
  static List<String> _oldNamesOn(_Entry entry, String post) => [
        for (final key in entry.posts)
          if (key.length > post.length && key.startsWith('$post#')) key.substring(post.length + 1),
      ];

  bool _couldBeRenamed(String newName, _Entry entry, String post, List<_Entry> gone) {
    final oldNames = _oldNamesOn(entry, post);
    if (oldNames.any((old) => modNamesMatch(old, newName))) return true;

    final oldWords = {for (final old in oldNames) ..._words(old)};
    final otherWords = {
      for (final key in _keysThisRun)
        if (_postOnlyKey(key) == post && key.length > post.length && key.substring(post.length + 1) != newName)
          ..._words(key.substring(post.length + 1)),
      for (final other in gone)
        if (other != entry)
          for (final old in _oldNamesOn(other, post)) ..._words(old),
    };
    return _words(newName).any(
        (word) => oldWords.contains(word) && !otherWords.contains(word) && _namesUsing(word) <= 2);
  }

  /// How many names in the id file use [word].
  int _namesUsing(String word) {
    var count = 0;
    for (final key in _entries.keys) {
      final at = key.indexOf('#');
      if (_words(at < 0 ? key : key.substring(0, at)).contains(word)) count++;
    }
    return count;
  }

  /// A name's words of four letters or more, lower case. Shorter words ("the",
  /// "bsp", "mod") say too little to tie two names together.
  static Set<String> _words(String name) => {
        for (final word in name.toLowerCase().split(_notWordy))
          if (word.length >= 4 && word.contains(_letter)) word,
      };

  static final RegExp _letter = RegExp('[a-z]');

  /// True when [entry] is linked to posts and none of them is one of [refs]:
  /// it is some other mod's id, and only shares this one's name.
  bool _ownedByOtherPosts(_Entry entry, List<SourcePostRef> refs) {
    if (entry.posts.isEmpty) return false;
    final mine = {for (final ref in refs) ref.post.key};
    return !entry.posts.any((key) => mine.contains(_postOnlyKey(key)));
  }

  static _Entry? _uniqueOrNull(List<_Entry>? entries) =>
      entries != null && entries.length == 1 ? entries.single : null;

  static int _olderFirst(_Entry a, _Entry b) {
    // No day at all means it was here before days were kept: oldest of all.
    final left = a.firstSeen ?? '';
    final right = b.firstSeen ?? '';
    final byDay = left.compareTo(right);
    return byDay != 0 ? byDay : a.id.compareTo(b.id);
  }

  void _link(_Entry entry, SourcePostRef ref) {
    if (entry.posts.contains(ref.key)) return;
    _linkKey(entry, ref.key);
    _changed = true;
  }

  void _linkKey(_Entry entry, String key) {
    if (!entry.posts.contains(key)) entry.posts.add(key);
    _byPost.putIfAbsent(key, () => entry);
    final postOnly = _postOnlyKey(key);
    final list = _byPostOnly.putIfAbsent(postOnly, () => []);
    if (!list.contains(entry)) list.add(entry);
  }

  /// `forum:34161#Useful.Tithes` without the name: `forum:34161`.
  static String _postOnlyKey(String key) {
    final at = key.indexOf('#');
    return at < 0 ? key : key.substring(0, at);
  }

  /// A key no entry has yet, for a new mod whose name and mark are taken.
  String _freeKey(String base, String mark) {
    final first = '$base#$mark';
    if (!_entries.containsKey(first)) return first;
    for (var n = 2;; n++) {
      final candidate = '$first#$n';
      if (!_entries.containsKey(candidate)) return candidate;
    }
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

  /// The earliest day any mod here was first seen.
  ///
  /// Every mod that already existed when this file was first written shares
  /// that day, because they were all given ids in one go. So "first seen on the
  /// seed day" means "was already here", not "arrived that day", and nothing
  /// should read it as when a mod turned up.
  String? get seedDay {
    if (_seedDay != null) return _seedDay;
    for (final entry in _entries.values) {
      final day = entry.firstSeen;
      if (day == null) continue;
      if (_seedDay == null || day.compareTo(_seedDay!) < 0) _seedDay = day;
    }
    return _seedDay;
  }

  String? _seedDay;

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
    _seedDay = null;
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
          if (_entries[name]!.posts.isNotEmpty)
            'posts': ([..._entries[name]!.posts]..sort()),
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

  /// The source posts this mod came from, as [SourcePostRef.key]s. Empty for a
  /// line written before posts were kept.
  final List<String> posts = [];

  _Entry({required this.id, this.firstSeen, this.mark});
}
