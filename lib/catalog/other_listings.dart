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
