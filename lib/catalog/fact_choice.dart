import '../bot/scraper/qb/models/post_extraction.dart';
import '../site/version_compare.dart';
import 'source_post.dart';

/// One LLM answer about a mod, and the post it was read from.
class FactSource {
  final LlmMod mod;
  final SourceKind kind;

  /// When the post was last written to, so the newer of two posts of one kind
  /// is read first. Null when the source does not say.
  final DateTime? postedAt;

  /// Which post this answer was read from, and the LLM's name for the mod on
  /// it. Only used to say where each chosen fact came from; null gives a
  /// source with the kind and nothing else.
  final SourcePostRef? ref;

  const FactSource(this.mod, this.kind, {this.postedAt, this.ref});

  SourcePostRef get _ref => ref ?? SourcePostRef(kind: kind, id: '', llmModName: mod.name);
}

/// Where one published fact came from.
///
/// - [FactOrigin.post]: one source post supplied it. With an LLM name, it is
///   that LLM answer; without one, the post itself (its title, its words, its
///   pictures).
/// - [FactOrigin.rules]: the rules worked it out (the download rules, the
///   release detector).
/// - [FactOrigin.merged]: the merge made it, from the merged mod record, or it
///   was put together from several answers, which are then in [from].
class FactOrigin {
  /// The post, for a fact one post supplied.
  final SourcePostRef? post;

  /// `rules` or `merged`, for a fact no one post supplied.
  final String? word;

  /// The posts a merged fact was put together from. Empty when the merge made
  /// it from the merged mod record.
  final List<SourcePostRef> from;

  const FactOrigin._({this.post, this.word, this.from = const []});

  const FactOrigin.post(SourcePostRef this.post)
      : word = null,
        from = const [];

  static const FactOrigin rules = FactOrigin._(word: 'rules');
  static const FactOrigin merged = FactOrigin._(word: 'merged');

  /// Combines several answers. A single answer uses its post as the source.
  factory FactOrigin.several(List<SourcePostRef> posts) =>
      posts.length == 1 ? FactOrigin.post(posts.single) : FactOrigin._(word: 'merged', from: List.unmodifiable(posts));

  /// `{kind, id, llmName}` for a post, otherwise the word `rules` or `merged`.
  Object toJson() => post == null ? word! : refToJson(post!);

  /// The posts behind a merged fact, or null when there are none to name.
  List<Map<String, String>>? fromJson() => from.isEmpty ? null : [for (final ref in from) refToJson(ref)];

  static Map<String, String> refToJson(SourcePostRef ref) => {
        'kind': ref.kind.name,
        'id': ref.id,
        if (ref.llmModName != null) 'llmName': ref.llmModName!,
      };

  /// Reads what [toJson] wrote, with [from] from [fromJson]. Null when the
  /// value is not one of those shapes.
  static FactOrigin? read(Object? value, [Object? from]) {
    SourcePostRef? refOf(Object? map) {
      if (map is! Map) return null;
      final kind = SourceKind.values.where((k) => k.name == map['kind']).firstOrNull;
      final id = map['id'];
      if (kind == null || id is! String) return null;
      final name = map['llmName'];
      return SourcePostRef(kind: kind, id: id, llmModName: name is String ? name : null);
    }

    if (value == 'rules') return rules;
    if (value == 'merged') {
      final posts = [
        for (final item in from is List ? from : const [])
          if (refOf(item) case final ref?) ref,
      ];
      return posts.isEmpty ? merged : FactOrigin._(word: 'merged', from: posts);
    }
    final ref = refOf(value);
    return ref == null ? null : FactOrigin.post(ref);
  }

  @override
  bool operator ==(Object other) =>
      other is FactOrigin &&
      other.word == word &&
      other.post?.key == post?.key &&
      other.from.map((r) => r.key).join('|') == from.map((r) => r.key).join('|');

  @override
  int get hashCode => Object.hash(word, post?.key, from.map((r) => r.key).join('|'));

  @override
  String toString() => post?.key ?? (from.isEmpty ? word! : '$word(${from.map((r) => r.key).join(', ')})');
}

/// The chosen facts and where each one came from.
class ChosenFacts {
  final LlmMod facts;

  /// By the [LlmMod] or [LlmExtras] field name (`name`, `downloads`,
  /// `version`, `license`…). A field no answer filled has no entry.
  final Map<String, FactOrigin> sources;

  const ChosenFacts(this.facts, this.sources);
}

/// One mod's facts, put together from every LLM answer about it.
///
/// A forum post is usually the author's whole write-up; a Discord announcement
/// is usually a few lines. So each field is taken from the forum answer, and a
/// Discord answer only fills a field the forum left empty. Between two posts of
/// one kind, the newer is read first.
///
/// Two exceptions. The downloads are one field, not one per link: the forum
/// answer's list if it has any, otherwise the Discord answer's. Mixing them
/// would put a Discord link beside forum links for the same file. And the mod
/// version is the higher of all of them, by TriOS's comparison, because
/// Discord often announces a release before the forum post is edited.
///
/// The description anchors point into one post's words, so they are only ever
/// taken from the post read first — they cannot be checked against another.
///
/// Null when there are no answers at all.
LlmMod? chooseFacts(List<FactSource> sources) => chooseFactsWithSources(sources)?.facts;

/// [chooseFacts], plus the answer that supplied each field. Sources are
/// recorded as facts are chosen, so the two cannot disagree.
ChosenFacts? chooseFactsWithSources(List<FactSource> sources) {
  if (sources.isEmpty) return null;
  final ordered = [...sources]..sort(_preferred);
  final first = ordered.first.mod;
  final all = [for (final s in ordered) s.mod];
  final withExtras = [for (final s in ordered) if (s.mod.extras != null) s];
  final origins = <String, FactOrigin>{};

  FactOrigin originOf(FactSource source) => FactOrigin.post(source._ref);

  T? firstOf<T>(String field, T? Function(LlmExtras e) read, bool Function(T value) isSet) {
    for (final s in withExtras) {
      final value = read(s.mod.extras!);
      if (value != null && isSet(value)) {
        origins[field] = originOf(s);
        return value;
      }
    }
    return null;
  }

  bool text(String? v) => v != null && v.trim().isNotEmpty;

  // An answer and the words behind it travel together: a "no" from Discord
  // must not sit under the forum's words.
  FactSource? firstWhere(String field, bool Function(LlmExtras e) test) {
    final found = withExtras.where((s) => test(s.mod.extras!)).firstOrNull;
    if (found != null) origins[field] = originOf(found);
    return found;
  }

  final adding = firstWhere('saveCompatibility', (e) => text(e.saveCompatibility) || e.canAdd != null)?.mod.extras ??
      LlmExtras();
  final removing =
      firstWhere('removalCompatibility', (e) => text(e.removalCompatibility) || e.canRemove != null)?.mod.extras ??
          LlmExtras();

  String? version;
  for (final s in withExtras) {
    final v = s.mod.extras!.version?.trim();
    if (v == null || v.isEmpty) continue;
    if (version == null || compareVersions(v, version) > 0) {
      version = v;
      origins['version'] = originOf(s);
    }
  }

  final combined = LlmExtras(
    version: version,
    changelog: firstOf('changelog', (e) => e.changelog, (c) => !c.isEmpty),
    supportLinks: firstOf('supportLinks', (e) => e.supportLinks, (l) => l.isNotEmpty),
    license: firstOf('license', (e) => e.license, text),
    sourceCode: firstOf('sourceCode', (e) => e.sourceCode, text),
    saveCompatibility: adding.saveCompatibility,
    canAdd: adding.canAdd,
    updateNotes: firstOf('updateNotes', (e) => e.updateNotes, (l) => l.isNotEmpty),
    removalCompatibility: removing.removalCompatibility,
    canRemove: removing.canRemove,
    summary: firstOf('summary', (e) => e.summary, (s) => !s.isEmpty),
    needs: firstOf('needs', (e) => e.needs, (l) => l.isNotEmpty),
    optionalNeeds: firstOf('optionalNeeds', (e) => e.optionalNeeds, (l) => l.isNotEmpty),
    conflicts: firstOf('conflicts', (e) => e.conflicts, (l) => l.isNotEmpty),
    // Taken whole from one answer. A forum "no AI" and a Discord "AI
    // portraits" are two statements, and joining them would misquote both.
    // A post that says nothing leaves the field to one that does; only when
    // none says anything is the mod "not stated" rather than not read yet.
    aiUse: firstOf('aiUse', (e) => e.aiUse, (a) => a.isStated) ?? firstOf('aiUse', (e) => e.aiUse, (_) => true),
  );
  // An empty extras field has no source.
  if (combined.saveCompatibility == null && combined.canAdd == null) origins.remove('saveCompatibility');
  if (combined.removalCompatibility == null && combined.canRemove == null) origins.remove('removalCompatibility');

  List<LlmDownload>? downloads;
  for (final kind in [SourceKind.forum, SourceKind.discord, SourceKind.nexus]) {
    final found = ordered.where((s) => s.kind == kind && s.mod.downloads.isNotEmpty).firstOrNull;
    if (found != null) {
      downloads = found.mod.downloads;
      origins['downloads'] = originOf(found);
      break;
    }
  }

  final nicknames = <String>[];
  final nicknameSources = <SourcePostRef>[];
  for (final s in ordered) {
    var added = false;
    for (final name in s.mod.nicknames ?? const <String>[]) {
      if (!nicknames.any((n) => n.toLowerCase() == name.toLowerCase())) {
        nicknames.add(name);
        added = true;
      }
    }
    if (added) nicknameSources.add(s._ref);
  }
  if (nicknameSources.isNotEmpty) origins['nicknames'] = FactOrigin.several(nicknameSources);

  final firstSource = ordered.first;
  origins['name'] = originOf(firstSource);
  if (first.descriptionAnchors != null) origins['descriptionAnchors'] = originOf(firstSource);

  final tool = ordered.where((s) => s.mod.isTool == true).firstOrNull;
  if (tool != null) {
    origins['isTool'] = originOf(tool);
  } else if (first.isTool != null) {
    origins['isTool'] = originOf(firstSource);
  }

  final requiresFrom = ordered.where((s) => text(s.mod.requires)).firstOrNull;
  if (requiresFrom != null) {
    origins['requires'] = originOf(requiresFrom);
  } else if (first.requires != null) {
    origins['requires'] = originOf(firstSource);
  }

  final imageFrom = ordered.where((s) => text(s.mod.image)).firstOrNull;
  if (imageFrom != null) origins['image'] = originOf(imageFrom);

  final facts = first.copyWith(
    isTool: all.any((m) => m.isTool == true) ? true : first.isTool,
    nicknames: nicknames.isEmpty ? null : nicknames,
    requires: requiresFrom?.mod.requires ?? first.requires,
    downloads: downloads ?? const [],
    image: imageFrom?.mod.image,
    extras: combined.isEmpty ? null : combined,
  );
  if (facts.extras == null) {
    for (final field in _extrasFields) {
      origins.remove(field);
    }
  }
  return ChosenFacts(facts, Map.unmodifiable(origins));
}

const _extrasFields = [
  'version',
  'changelog',
  'supportLinks',
  'license',
  'sourceCode',
  'saveCompatibility',
  'updateNotes',
  'removalCompatibility',
  'summary',
  'needs',
  'optionalNeeds',
  'conflicts',
  'aiUse',
];

/// Forum before Discord before Nexus; within one kind, the newer post first.
int _preferred(FactSource a, FactSource b) {
  final byKind = a.kind.index.compareTo(b.kind.index);
  if (byKind != 0) return byKind;
  final left = a.postedAt;
  final right = b.postedAt;
  if (left == null && right == null) return 0;
  if (left == null) return 1;
  if (right == null) return -1;
  return right.compareTo(left);
}
