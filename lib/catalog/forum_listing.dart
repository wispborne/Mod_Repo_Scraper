import '../bot/scraper/qb/forum_constants.dart';
import '../bot/scraper/qb/models/forum_date.dart';
import '../bot/scraper/qb/models/mod_summary.dart';
import '../bot/scraper/scraped_mod.dart';
import '../site/display_name.dart';
import '../site/mod_name_match.dart';
import '../site/version_compare.dart';
import 'listing.dart';
import 'source_post.dart';

/// The one listing the scraper's rules make for a forum topic.
///
/// A topic the mod index lists is named from the index's first line for it:
/// that line's name, author, game version and heading. The names on its other
/// lines are kept as other names for the same listing — "Exalted" and "The
/// Exalted" are usually one mod, and rules cannot tell when they are not, so
/// splitting them would give two spellings of one mod two permanent ids. It is
/// the LLM's job to say when a topic really holds several mods.
///
/// A topic the index does not list is named from its title the way the site
/// names it ([displayName]): the bracketed game version, the mod version, any
/// date, a leading dash and whatever a cut left dangling all come off. Taking
/// off only the version left names like "Everything Recoverable (v" and
/// "Companions of the Imperium - V", and TriOS shows this name as it is.
Listing forumRulesListing(QbModSummary summary) {
  final lines = summary.indexLines ?? const <QbIndexLine>[];
  final ref = SourcePostRef(kind: SourceKind.forum, id: '${summary.topicId}');
  final postedAt = parseForumDate(summary.lastPostDate);
  final url = summary.topicUrl.isNotEmpty ? summary.topicUrl : ForumConstants.topicUrl(summary.topicId);

  if (lines.isNotEmpty) {
    final first = lines.first;
    final author = first.author.trim().isNotEmpty ? first.author.trim() : summary.author.trim();
    final otherNames = <String>[];
    for (final line in lines.skip(1)) {
      if (modNamesMatch(line.name, first.name)) continue;
      if (otherNames.any((name) => modNamesMatch(name, line.name))) continue;
      otherNames.add(line.name);
    }
    return Listing(
      mod: ScrapedMod(
        name: first.name,
        gameVersionReq: _newerGameVersion(first.gameVersion ?? '', summary),
        authorsList: author.isEmpty ? const [] : [author],
        urls: {ModUrlType.Forum: url},
        sources: const [ModSource.Index],
        categories: first.category == ForumConstants.uncategorizedCategory ? const [] : [first.category],
        images: const {},
      ),
      ref: ref,
      otherNames: otherNames,
      postedAt: postedAt,
    );
  }

  final author = summary.author.trim();
  return Listing(
    mod: ScrapedMod(
      name: displayName(summary.title),
      gameVersionReq: summary.gameVersion ?? '',
      authorsList: author.isEmpty ? const [] : [author],
      urls: {ModUrlType.Forum: url},
      sources: const [ModSource.ModdingSubforum],
      categories: const [],
      images: const {},
    ),
    ref: ref,
    postedAt: postedAt,
  );
}

/// The game version for a topic the index lists: the higher of the index
/// line's version and the one in the thread title.
///
/// An old index post is never edited, but the author changes the title when
/// they update the mod. Ashes of the Domain (topic 26307) is listed only on the
/// 0.97a index post, and its title says "[0.98]". When today's index writes
/// "-" for a mod that works on any version, as it does for TriOS, the "-" is
/// kept. A title version that does not start with "0." is not used, so a mod
/// version in brackets cannot win.
String _newerGameVersion(String fromIndex, QbModSummary summary) {
  final onTodaysIndex = summary.inModIndex && !summary.isArchivedModIndex;
  final indexHasNumber = fromIndex.contains(RegExp(r'\d'));
  if (onTodaysIndex && fromIndex.trim().isNotEmpty && !indexHasNumber) return fromIndex;

  var fromTitle = ForumConstants.gameVersionRegex.firstMatch(summary.title)?.group(1);
  if (fromTitle == null) return fromIndex;
  if (fromTitle.startsWith('.')) fromTitle = '0$fromTitle';
  if (!fromTitle.startsWith('0.')) return fromIndex;
  if (!indexHasNumber) return fromTitle;

  return compareVersions(_inReleaseOrder(fromTitle), _inReleaseOrder(fromIndex)) > 0 ? fromTitle : fromIndex;
}

/// A game version rewritten so [compareVersions] puts it in release order, as
/// `gameVersionInOrder` in `site/version.js` does. The part after the first dot
/// is a decimal, so 0.65 becomes 0.650 and sits below 0.7 (0.700). A missing
/// third part becomes 0, so 0.95a sits below 0.95.1a.
String _inReleaseOrder(String version) {
  final match = RegExp(r'^(\d+)\.(\d{1,3})(?:\.(\d+))?(.*)$').firstMatch(version.trim());
  if (match == null) return version;
  return '${match.group(1)}.${match.group(2)!.padRight(3, '0')}.${match.group(3) ?? '0'}${match.group(4)}';
}
