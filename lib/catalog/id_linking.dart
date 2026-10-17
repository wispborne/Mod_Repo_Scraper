import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../bot/scraper/mod_merger.dart';
import '../bot/scraper/qb/models/forum_data_bundle.dart';
import '../bot/scraper/qb/models/post_extraction.dart';
import '../site/mod_id_store.dart';
import '../site/mod_name_match.dart';
import 'discord_posts.dart';
import 'other_listings.dart';
import 'source_post.dart';

/// What [linkIdsFromPublishedSite] did.
class IdLinkReport {
  /// Mod pages read.
  final int pages;

  /// Source posts linked to an id.
  final int links;

  /// Ids a page carries that `mod-ids.json` does not have. Each is a page the
  /// file has lost track of, and worth looking at before switching over.
  final List<String> unknownIds;

  const IdLinkReport({this.pages = 0, this.links = 0, this.unknownIds = const []});
}

/// Links every id in `mod-ids.json` to the source posts its page came from,
/// read off the published site's own files, so the catalog merge finds each
/// mod's existing id through its posts rather than its name.
///
/// Each `mods/<id>.json` already says which forum topic, Discord thread and
/// Nexus page the mod was published from. On a topic holding several mods the
/// topic alone does not say which mod an id is, so the LLM's name for it goes
/// into the forum link too: the name a thread-only mod was published under, or
/// for a merged mod the LLM mod the site's own matching picked for it.
/// Without that, Hartley's three Discord mods would all point at topic 34161
/// with nothing to say which id is which.
///
/// Reading the same files twice gives the same file: a post already linked is
/// not linked again, and the posts are written sorted.
IdLinkReport linkIdsFromPublishedSite({
  required ModIdStore ids,
  required Directory modsDir,
  ForumDataBundle? bundle,
  DiscordPostsFile discordPosts = const DiscordPostsFile(),
}) {
  final threads = {for (final thread in bundle?.index ?? const []) '${thread.topicId}': thread};
  final knownThreads = discordPosts.threads.keys.toSet();

  final files = modsDir.existsSync()
      ? (modsDir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
        ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path))))
      : <File>[];

  var pages = 0;
  var links = 0;
  final unknown = <String>[];

  for (final file in files) {
    final page = jsonDecode(file.readAsStringSync());
    if (page is! Map || page['listing'] is! Map) continue;
    final listing = page['listing'] as Map;
    final id = listing['id'] as String?;
    if (id == null || id.isEmpty) continue;
    pages++;

    final name = (listing['name'] as String?) ?? '';
    final refs = <SourcePostRef>[];

    final topicId = ModMerger.extractForumTopicId((listing['forumUrl'] ?? page['forumUrl']) as String?);
    if (topicId != null) {
      refs.add(SourcePostRef(
        kind: SourceKind.forum,
        id: topicId,
        llmModName: _llmNameOnSharedTopic(
          name: name,
          isThreadOnly: listing['partOfThreadTitle'] != null,
          llmMods: threads[topicId]?.llm?.mods ?? const [],
        ),
      ));
    }

    final threadId = discordThreadIdOf((listing['discordUrl'] ?? page['discordUrl']) as String?,
        knownThreadIds: knownThreads);
    if (threadId != null) refs.add(SourcePostRef(kind: SourceKind.discord, id: threadId));

    final nexusId = nexusIdOf(listing['nexusUrl'] as String?);
    if (nexusId != null) refs.add(SourcePostRef(kind: SourceKind.nexus, id: nexusId));

    for (final ref in refs) {
      try {
        ids.linkIdToPost(id, ref);
        links++;
      } on ArgumentError {
        unknown.add(id);
        break;
      }
    }
  }

  return IdLinkReport(pages: pages, links: links, unknownIds: unknown);
}

/// The LLM's name for this mod when its topic holds two or more main mods,
/// else null — a topic of one mod needs no name to tell its mods apart.
///
/// A thread-only mod was published under the LLM's own name. A merged mod
/// takes the LLM mod whose name matches its own, which is the choice the site
/// made for it (`_mainLlmMod`); on a shared topic the site never fell back to
/// the only main mod, so neither does this.
String? _llmNameOnSharedTopic({
  required String name,
  required bool isThreadOnly,
  required List<LlmMod> llmMods,
}) {
  final mains = [for (final m in llmMods) if (m.role == LlmModRole.main) m];
  if (mains.length < 2) return null;
  if (isThreadOnly) return name.trim();
  for (final candidate in llmMods) {
    if (modNamesMatch(candidate.name, name)) return candidate.name.trim();
  }
  return null;
}
