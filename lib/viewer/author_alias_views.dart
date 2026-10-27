import '../bot/scraper/mod_repo_utils.dart';

/// Discord's placeholder for an account that no longer exists. It names
/// nobody, so it is never offered as anyone's alias.
const String deletedDiscordUser = 'Deleted User';

/// What the Author aliases page shows besides the list itself: how many mods
/// each name is on, and pairs of names that might be one person.
///
/// [catalogItems] are `mod-catalog.json`'s items. [forumAuthors] holds the
/// names the forum gives each topic (the poster and the mod index's credit),
/// keyed by topic id; [discordAuthors] the names the Discord reader gave each
/// thread, keyed by thread id. [notSame] are pairs already marked as different
/// people.
///
/// A suggestion is a forum name and a Discord name on one mod that the
/// aliases in force do not already call one person. Most are the same person
/// under two accounts; some are a team, where the forum post is by one member
/// and the Discord post by another. That is for a person to decide, so
/// nothing here is ever applied on its own.
Map<String, Object?> authorAliasReport({
  required List<Map<String, dynamic>> catalogItems,
  required Map<String, List<String>> forumAuthors,
  required Map<String, List<String>> discordAuthors,
  List<List<String>> notSame = const [],
}) {
  final modsByName = <String, Set<String>>{};
  final spellingOf = <String, String>{};
  final pairs = <String, ({String forum, String discord, List<Map<String, String>> mods})>{};
  final dismissed = {
    for (final pair in notSame)
      if (pair.length == 2) _pairKey(pair[0], pair[1]),
  };

  void count(String name, String modId) {
    final lower = name.toLowerCase();
    spellingOf.putIfAbsent(lower, () => name);
    modsByName.putIfAbsent(lower, () => {}).add(modId);
  }

  for (final mod in catalogItems) {
    final id = '${mod['id']}';
    final modName = '${mod['name'] ?? id}';
    final forum = <String>{};
    final discord = <String>{};
    for (final post in (mod['sourcePosts'] as List?) ?? const []) {
      if (post is! Map) continue;
      final postId = '${post['id']}';
      if (post['kind'] == 'forum') {
        for (final credit in forumAuthors[postId] ?? const <String>[]) {
          forum.addAll(ModRepoUtils.splitAuthorNames(credit));
        }
      } else if (post['kind'] == 'discord') {
        for (final credit in discordAuthors[postId] ?? const <String>[]) {
          discord.addAll(ModRepoUtils.splitAuthorNames(credit));
        }
      }
    }
    discord.remove(deletedDiscordUser);
    for (final name in {...forum, ...discord, for (final a in (mod['authorsList'] as List?) ?? const []) '$a'}) {
      count(name, id);
    }

    for (final d in discord) {
      if (forum.isEmpty || forum.any((f) => ModRepoUtils.samePerson(f, d))) continue;
      for (final f in forum) {
        final key = _pairKey(f, d);
        if (dismissed.contains(key)) continue;
        // "Princess of Evil" and "Princess_of_Evil" are one person already, so
        // they make one suggestion.
        final sameAs = pairs.entries
            .where((e) => ModRepoUtils.samePerson(e.value.forum, f) && ModRepoUtils.samePerson(e.value.discord, d))
            .firstOrNull;
        final pair = sameAs?.value ?? pairs.putIfAbsent(key, () => (forum: f, discord: d, mods: []));
        if (!pair.mods.any((m) => m['id'] == id)) pair.mods.add({'id': id, 'name': modName});
      }
    }
  }

  final suggestions = pairs.values.toList()
    ..sort((a, b) {
      final byCount = b.mods.length.compareTo(a.mods.length);
      return byCount != 0 ? byCount : a.forum.toLowerCase().compareTo(b.forum.toLowerCase());
    });
  return {
    'modCounts': {for (final e in modsByName.entries) e.key: e.value.length},
    'names': [for (final lower in spellingOf.keys.toList()..sort()) spellingOf[lower]],
    'suggestions': [
      for (final s in suggestions) {'forum': s.forum, 'discord': s.discord, 'mods': s.mods},
    ],
  };
}

String _pairKey(String a, String b) {
  final names = [a.toLowerCase(), b.toLowerCase()]..sort();
  return names.join('\n');
}
