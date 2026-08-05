/// Category names the mod index used to use, and what the index calls them now.
///
/// The index post is followed by older posts, one per past game version, and those still carry the
/// wording of their day. This table only applies to a name the index has stopped using: "Utility mods"
/// is a heading in its own right today, so it must be left alone even though it appears here.
const Map<String, String> legacyCategoryMap = {
  'Factions': 'Faction Mods',
  'Miscellany': 'Miscellaneous Mods',
  'Utility mods': 'Standalone Utilities',
  'Add-On Mods': 'Content Expansions',
  'Mission-only': 'Content Expansions',
  'Compilations': 'Megamods',
  'Total Conversions': 'Megamods',
};

/// What the mod index calls [category] today, given [categoriesInUse] — the headings on its current post.
///
/// A name the index still uses comes back untouched. An old name comes back as its current one.
/// Null means neither: the index no longer has that heading and [legacyCategoryMap] has nothing for it,
/// so the caller decides what to do (the QB scraper files it under "uncategorized"; the ModRepo scraper
/// keeps the old wording). Either way it is worth a line in the log, so the table can be filled in.
///
/// Names are matched ignoring capitals, and the answer is always spelled the way the index spells it.
String? currentCategoryName(String category, Set<String> categoriesInUse) {
  final trimmed = category.trim();
  if (trimmed.isEmpty) return null;

  final inUse = _matchIgnoringCapitals(trimmed, categoriesInUse);
  if (inUse != null) return inUse;

  for (final entry in legacyCategoryMap.entries) {
    if (entry.key.toLowerCase() == trimmed.toLowerCase()) {
      return _matchIgnoringCapitals(entry.value, categoriesInUse);
    }
  }

  return null;
}

String? _matchIgnoringCapitals(String name, Set<String> names) {
  final lower = name.toLowerCase();
  for (final candidate in names) {
    if (candidate.toLowerCase() == lower) return candidate;
  }
  return null;
}
