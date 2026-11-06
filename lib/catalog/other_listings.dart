import '../bot/scraper/scraped_mod.dart';
import 'discord_posts.dart';
import 'listing.dart';
import 'source_post.dart';

/// The rules listing for a Discord thread: the mod the Discord reader made
/// from it, unchanged, with a ref to the thread. Null when the mod carries no
/// Discord link to say which thread it is.
///
/// [knownThreadIds] are the threads `discord-posts.json` holds, so a link to a
/// post that is not in a thread finds its saved entry too.
Listing? discordRulesListing(ScrapedMod mod, {Set<String>? knownThreadIds}) {
  final threadId = discordThreadIdOf(mod.getUrls()[ModUrlType.Discord], knownThreadIds: knownThreadIds);
  if (threadId == null) return null;
  return Listing(
    mod: mod,
    ref: SourcePostRef(kind: SourceKind.discord, id: threadId),
    postedAt: mod.dateTimeEdited ?? mod.dateTimeCreated,
  );
}

/// The Discord reader takes a forum link in the post to be the mod's own
/// thread. Sometimes it is a thread the post only mentions: the 0.98.5a
/// Preview Mod links Alex's patch notes (topic 35147). When the linked topic is
/// in [notModTopics], topics the catalog read and decided are not a mod, the
/// link is taken off, and so is a download page that is the same link (the
/// reader falls back to the forum link for that).
///
/// Returns the mod unchanged when there is nothing to take off.
ScrapedMod withoutForumLinkToNonMod(ScrapedMod mod, Set<String> notModTopics) {
  final urls = mod.getUrls();
  final forumUrl = urls[ModUrlType.Forum];
  final topicId = forumUrl == null ? null : RegExp(r'topic=(\d+)').firstMatch(forumUrl)?.group(1);
  if (topicId == null || !notModTopics.contains(topicId)) return mod;
  return mod.copyWith(urls: {
    for (final entry in urls.entries)
      if (entry.key != ModUrlType.Forum && entry.value != forumUrl) entry.key: entry.value,
  });
}

/// The listing for a Nexus page: the mod the Nexus reader made, unchanged,
/// with a ref to the page. Nexus is not read by the LLM yet, so this is all a
/// Nexus page gives. Null when the mod carries no Nexus link.
Listing? nexusListing(ScrapedMod mod) {
  final id = nexusIdOf(mod.getUrls()[ModUrlType.NexusMods]);
  if (id == null) return null;
  return Listing(
    mod: mod,
    ref: SourcePostRef(kind: SourceKind.nexus, id: id),
    postedAt: mod.dateTimeEdited ?? mod.dateTimeCreated,
  );
}

/// The mod number in a Nexus link: `https://www.nexusmods.com/starsector/mods/12`
/// gives "12".
String? nexusIdOf(String? url) {
  if (url == null) return null;
  return RegExp(r'/mods/(\d+)').firstMatch(url)?.group(1);
}
