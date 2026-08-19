/// The short, fixed set of categories the public website offers, and what each
/// of the sources' own names maps onto.
///
/// The forum's mod index and Discord's tags between them use 26 names, and
/// several of them mean the same thing. As published, a reader browsing by kind
/// got a dropdown holding "Utility mods", "Standalone Utilities" and "Quality
/// of Life" side by side, and "Other/Misc.", "Miscellaneous Mods" and "Misc.
/// Campaign Mods" as three separate choices. Nobody can use that.
///
/// So the site publishes these thirteen instead. The names each source gave a
/// mod are not thrown away — they are kept on the mod's own page, in the
/// Details box, in the words the source used.
///
/// Two rules to keep:
///
/// - A raw name that is not in [_publicCategoryByRawName] gets **no** public
///   category rather than a guessed one. A wrong shelf is worse than none, and
///   a new tag turning up is something to notice, not to paper over.
/// - "Discord Only" is not in the table on purpose. It says where a mod was
///   found, not what kind of mod it is, so it is published as a source instead
///   (see `PublicMod.sources`).

/// Names a source uses that say where a mod was found rather than what kind of
/// mod it is. They are published as `PublicMod.sources` instead, and they are
/// kept out of the raw names on a mod's page too — a page saying "Filed under:
/// Discord Only" beside "Found on: Discord" says the same thing twice.
const Set<String> sourceMarkerNames = {'discord only'};

/// True when [rawName] says where a mod was found rather than what it is.
bool isSourceMarker(String rawName) =>
    sourceMarkerNames.contains(rawName.trim().toLowerCase());

/// The thirteen, in the order the site lists them.
const List<String> publicCategories = [
  'Factions',
  'Ships and weapons',
  'Utilities',
  'Libraries',
  'Quality of life',
  'Campaign and exploration',
  'Content expansions',
  'Quests and stories',
  'Portraits and flags',
  'Sound and graphics',
  'Skills and officers',
  'Total conversions',
  'Everything else',
];

/// Every name the forum's index and Discord's tags use, and the public category
/// it belongs to. Keyed in lower case; [publicCategoryFor] does the folding.
const Map<String, String> _publicCategoryByRawName = {
  'faction mods': 'Factions',

  'ship pack': 'Ships and weapons',
  'weapon/fighter pack': 'Ships and weapons',
  'modular hullmods': 'Ships and weapons',

  'utility mods': 'Utilities',
  'standalone utilities': 'Utilities',
  'mod manager': 'Utilities',

  'libraries': 'Libraries',

  'quality of life': 'Quality of life',

  'misc. campaign mods': 'Campaign and exploration',
  'exploration': 'Campaign and exploration',
  'colonies': 'Campaign and exploration',

  'content expansions': 'Content expansions',
  'feature overhauls': 'Content expansions',

  'quests and bars': 'Quests and stories',

  'portrait/flag pack': 'Portraits and flags',
  'portrait packs': 'Portraits and flags',
  'flag packs': 'Portraits and flags',

  'audio/visual': 'Sound and graphics',

  'skills and abilities': 'Skills and officers',
  'officers': 'Skills and officers',

  'megamods': 'Total conversions',
  'total conversion': 'Total conversions',

  'miscellaneous mods': 'Everything else',
  'other/misc.': 'Everything else',
};

/// Every raw name the table knows, as the sources spell them. A test walks this
/// to check none of them has been left without a home.
List<String> get rawCategoryNames => _publicCategoryByRawName.keys.toList();

/// The public category [rawName] belongs to, or null when the table has never
/// heard of it.
String? publicCategoryFor(String rawName) =>
    _publicCategoryByRawName[rawName.trim().toLowerCase()];

/// The public categories for one mod, each once, in the order the site lists
/// them — so two mods on the same shelves always read the same way round.
List<String> publicCategoriesFor(List<String> rawNames) {
  final found = <String>{};
  for (final raw in rawNames) {
    final public = publicCategoryFor(raw);
    if (public != null) found.add(public);
  }
  return [
    for (final category in publicCategories)
      if (found.contains(category)) category,
  ];
}
