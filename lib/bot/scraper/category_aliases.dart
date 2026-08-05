/// Discord's tag names, and what the forum's mod index calls the same thing.
///
/// The two sources name their shelves differently, so a mod on both used to come out of the merge
/// labelled "Faction" *and* "Faction Mods" — one thing written twice. This table only holds tags that
/// are a plain synonym of a forum heading.
///
/// Most of Discord's tags are deliberately left out. They say what a mod *does* (Ship Pack, Exploration,
/// Audio/Visual, Quality of Life, ...) where the forum's ten headings say which shelf it sits on, so
/// there is nothing to fold them into: almost all would land on "Miscellaneous Mods". For a mod that is
/// only on Discord that is the one useful thing anyone knows about it, and it is worth keeping.
///
/// Three are left out for reasons of their own. "Portrait/Flag Pack" is one tag where the forum has two
/// headings (Portrait Packs and Flag Packs), and nothing in the data says which of the two a given mod is.
/// "Total Conversion" and "Mod Manager" both have a near-enough forum heading ("Megamods" and
/// "Utility mods"), but neither means quite the same thing, so they are left as Discord wrote them.
///
/// The answers here must be spelled exactly as the mod index spells them, or the merge will invent a
/// heading the forum does not have. A tag that is missing from this table is kept as it was written.
const Map<String, String> discordCategoryAliases = {
  'Faction': 'Faction Mods',
  'Utility': 'Utility mods',
  'Library': 'Libraries',
  'Megamod': 'Megamods',
};

/// One mod's categories with each source's wording folded into the forum's, duplicates dropped.
///
/// The order categories were found in is kept, so the list reads the same way from one run to the next.
/// Anything not in [discordCategoryAliases] comes back untouched.
List<String> tidyCategoryNames(List<String> categories) {
  final tidied = <String>[];

  for (final category in categories) {
    final name = _aliasFor(category) ?? category;
    if (!tidied.contains(name)) tidied.add(name);
  }

  return tidied;
}

String? _aliasFor(String category) {
  final trimmed = category.trim();
  if (trimmed.isEmpty) return null;

  final lower = trimmed.toLowerCase();
  for (final entry in discordCategoryAliases.entries) {
    if (entry.key.toLowerCase() == lower) return entry.value;
  }
  return null;
}
