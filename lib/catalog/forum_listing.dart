import '../bot/scraper/qb/forum_constants.dart';
import '../bot/scraper/qb/models/forum_date.dart';
import '../bot/scraper/qb/models/mod_summary.dart';
import '../bot/scraper/scraped_mod.dart';
import '../site/display_name.dart';
import '../site/mod_name_match.dart';
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
        gameVersionReq: first.gameVersion ?? '',
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
