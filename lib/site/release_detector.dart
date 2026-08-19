import '../bot/scraper/qb/models/forum_data_bundle.dart';
import '../bot/scraper/qb/models/mod_summary.dart';
import '../bot/scraper/qb/models/post_extraction.dart';
import 'release_state_store.dart';
import 'version_text.dart';

/// Works out which mods actually put out a new version.
///
/// It is handed one bundle at a time and moves its state on by one step. It
/// never walks history itself: a run gives it the bundle that run published, and
/// the one-off backfill command gives it every saved bundle in turn.
///
/// The extractor it reads is noisy — over one month of real data it re-read the
/// same post and contradicted itself 279 times. Four rules deal with that, and
/// between them they leave the feed worth reading:
///
/// - A reading has to hold for two scrapes running before it is believed, so a
///   single odd reading never reaches the feed.
/// - A believed version never moves backwards. Without this, every wobble makes
///   the site forget a release and announce it again when the reading recovers.
/// - A version that matches the game's version is thrown out, because the
///   extractor confuses the two.
/// - Where the thread title names a version, a new version that disagrees with
///   it is dropped. Titles are the author's own words. Only some threads carry
///   one, so a title can veto but never propose.
///
/// The first version believed for a thread is never a release — otherwise the
/// backfill would announce every mod at once.
class ReleaseDetector {
  final ReleaseState state;

  ReleaseDetector(this.state);

  /// Moves the state on by one bundle and returns the releases that bundle
  /// showed. [bundleId] is the saved bundle's name, so the same bundle is never
  /// walked twice; pass null for a bundle that has no name yet.
  ///
  /// [seenOn] is the day to file any release under. It defaults to the day the
  /// bundle was built.
  List<ThreadRelease> advance(
    ForumDataBundle bundle, {
    String? bundleId,
    DateTime? seenOn,
  }) {
    if (bundleId != null && !state.bundlesSeen.add(bundleId)) return const [];

    final day = dayOf(seenOn ?? bundle.meta?.generatedAt ?? bundle.updatedAt);
    final found = <ThreadRelease>[];

    for (final thread in bundle.index) {
      final release = _advanceThread(thread, day);
      if (release != null) found.add(release);
    }

    state.releases.addAll(found);
    return found;
  }

  /// A day written the way the feed files it, `YYYY-MM-DD` in UTC.
  static String dayOf(DateTime when) {
    final utc = when.toUtc();
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    return '${utc.year}-$month-$day';
  }

  // ---------------------------------------------------------------------------

  ThreadRelease? _advanceThread(QbModSummary thread, String day) {
    final mod = _mainMod(thread);
    final rawVersion = mod?.extras?.version;

    // The game's version is not the mod's, however confidently it is offered.
    if (VersionText.isGameVersion(rawVersion,
        threadGameVersion: thread.gameVersion, threadTitle: thread.title)) {
      return null;
    }

    final reading = VersionText.clean(rawVersion);
    // Nothing readable this time. That is not news either way, so the state is
    // left exactly as it was.
    if (reading == null) return null;

    final versions = state.of(thread.topicId);

    if (versions.reading == reading) {
      versions.readingCount++;
    } else {
      versions.reading = reading;
      versions.readingRaw = rawVersion?.trim();
      versions.readingCount = 1;
    }

    // One scrape is not enough. Two in a row saying the same thing is.
    if (versions.readingCount < 2) return null;

    final believed = versions.believed;
    if (believed == null) {
      // The first version we are willing to believe for this mod. Not a
      // release — we have no idea what it was on before.
      versions.believed = reading;
      versions.believedRaw = versions.readingRaw;
      return null;
    }

    // A believed version never moves backwards, even when the older reading
    // settles across several scrapes.
    if (VersionText.compare(reading, believed) <= 0) return null;

    // The title is the author's own words. Where it names a version, it has the
    // last word; where it names none, it has no say.
    final titleVersion = VersionText.versionFromTitle(thread.title);
    if (titleVersion != null && VersionText.compare(titleVersion, reading) != 0) {
      return null;
    }

    final oldRaw = versions.believedRaw ?? believed;
    versions.believed = reading;
    versions.believedRaw = versions.readingRaw;

    return ThreadRelease(
      topicId: thread.topicId,
      modName: _modNameOf(thread, mod),
      seenOn: day,
      oldVersion: oldRaw,
      newVersion: versions.believedRaw ?? reading,
      gameVersion: _blankToNull(thread.gameVersion),
      changelogNotes: _notesFor(mod, versions.believedRaw ?? reading),
    );
  }

  /// The mod on the thread the version is read from: the one the LLM called the
  /// main mod, or the only one there is.
  LlmMod? _mainMod(QbModSummary thread) {
    final mods = thread.llm?.mods ?? const <LlmMod>[];
    if (mods.isEmpty) return null;
    if (mods.length == 1) return mods.first;
    for (final mod in mods) {
      if (mod.role == LlmModRole.main) return mod;
    }
    return mods.first;
  }

  String _modNameOf(QbModSummary thread, LlmMod? mod) {
    final fromLlm = mod?.name.trim();
    if (fromLlm != null && fromLlm.isNotEmpty) return fromLlm;
    return thread.title.trim();
  }

  /// The changelog the post gave for this version, word for word. The post
  /// spells its versions its own way, so the entries are matched on the cleaned
  /// spelling rather than character by character.
  String? _notesFor(LlmMod? mod, String version) {
    final entries = mod?.extras?.changelog?.entries;
    if (entries == null || entries.isEmpty) return null;

    final exact = entries[version];
    if (exact != null && exact.trim().isNotEmpty) return exact.trim();

    final wanted = VersionText.clean(version);
    if (wanted == null) return null;
    for (final entry in entries.entries) {
      if (VersionText.clean(entry.key) != wanted) continue;
      final notes = entry.value.trim();
      if (notes.isNotEmpty) return notes;
    }
    return null;
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
