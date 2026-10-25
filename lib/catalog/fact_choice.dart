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

  const FactSource(this.mod, this.kind, {this.postedAt});
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
LlmMod? chooseFacts(List<FactSource> sources) {
  if (sources.isEmpty) return null;
  final ordered = [...sources]..sort(_preferred);
  final first = ordered.first.mod;
  final all = [for (final s in ordered) s.mod];
  final extras = [for (final m in all) if (m.extras != null) m.extras!];

  T? firstOf<T>(T? Function(LlmExtras e) read, bool Function(T value) isSet) {
    for (final e in extras) {
      final value = read(e);
      if (value != null && isSet(value)) return value;
    }
    return null;
  }

  bool text(String? v) => v != null && v.trim().isNotEmpty;

  // An answer and the words behind it travel together: a "no" from Discord
  // must not sit under the forum's words.
  final adding = extras.firstWhere((e) => text(e.saveCompatibility) || e.canAdd != null,
      orElse: () => LlmExtras());
  final removing = extras.firstWhere((e) => text(e.removalCompatibility) || e.canRemove != null,
      orElse: () => LlmExtras());

  final combined = LlmExtras(
    version: _highestVersion([for (final e in extras) e.version]),
    changelog: firstOf((e) => e.changelog, (c) => !c.isEmpty),
    supportLinks: firstOf((e) => e.supportLinks, (l) => l.isNotEmpty),
    license: firstOf((e) => e.license, text),
    sourceCode: firstOf((e) => e.sourceCode, text),
    saveCompatibility: adding.saveCompatibility,
    canAdd: adding.canAdd,
    updateNotes: firstOf((e) => e.updateNotes, (l) => l.isNotEmpty),
    removalCompatibility: removing.removalCompatibility,
    canRemove: removing.canRemove,
    summary: firstOf((e) => e.summary, (s) => !s.isEmpty),
    needs: firstOf((e) => e.needs, (l) => l.isNotEmpty),
    optionalNeeds: firstOf((e) => e.optionalNeeds, (l) => l.isNotEmpty),
    // Taken whole from one answer. A forum "no AI" and a Discord "AI
    // portraits" are two statements, and joining them would misquote both.
    // A post that says nothing leaves the field to one that does; only when
    // none says anything is the mod "not stated" rather than not read yet.
    aiUse: firstOf((e) => e.aiUse, (a) => a.isStated) ??
        firstOf((e) => e.aiUse, (_) => true),
  );

  final downloads = [
    for (final kind in [SourceKind.forum, SourceKind.discord, SourceKind.nexus])
      for (final s in ordered)
        if (s.kind == kind && s.mod.downloads.isNotEmpty) s.mod.downloads,
  ].firstOrNull;

  final nicknames = <String>[];
  for (final m in all) {
    for (final name in m.nicknames ?? const <String>[]) {
      if (!nicknames.any((n) => n.toLowerCase() == name.toLowerCase())) nicknames.add(name);
    }
  }

  return first.copyWith(
    isTool: all.any((m) => m.isTool == true) ? true : first.isTool,
    nicknames: nicknames.isEmpty ? null : nicknames,
    requires: all.map((m) => m.requires).firstWhere(text, orElse: () => first.requires),
    downloads: downloads ?? const [],
    image: all.map((m) => m.image).firstWhere(text, orElse: () => null),
    extras: combined.isEmpty ? null : combined,
  );
}

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

String? _highestVersion(List<String?> versions) {
  String? best;
  for (final version in versions) {
    final v = version?.trim();
    if (v == null || v.isEmpty) continue;
    if (best == null || compareVersions(v, best) > 0) best = v;
  }
  return best;
}
