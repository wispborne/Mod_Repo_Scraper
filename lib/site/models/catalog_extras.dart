import 'package:dart_mappable/dart_mappable.dart';

import '../../bot/scraper/qb/models/post_extraction.dart';
import 'mod_release.dart';
import 'public_mod.dart';
import 'public_mod_detail.dart';

part 'catalog_extras.mapper.dart';

/// `mod-catalog-extras.json` contains mod details from the website build.
/// It is published beside `mod-catalog.json` for TriOS.
///
/// Fields are copied from the mod's [PublicMod] and [PublicModDetail],
/// with the same names and values. Increase [schemaVersion] when renaming
/// a field or changing its format. Adding a field does not require an increase.
@MappableClass(ignoreNull: true)
class CatalogExtras with CatalogExtrasMappable {
  /// Increase this when renaming a field or changing its format.
  final int schemaVersion;

  /// When the site's files were built.
  final DateTime generatedAt;

  /// Every published mod, keyed by its permanent id from `mod-catalog.json`.
  /// The site uses the same id. Collections, moved ids and taken-down mods
  /// have no entry.
  final Map<String, CatalogExtrasMod> mods;

  static const int currentSchemaVersion = 1;

  CatalogExtras({
    this.schemaVersion = currentSchemaVersion,
    required this.generatedAt,
    this.mods = const {},
  });
}

/// One mod's details from the website build. Nulls, empty lists and empty
/// maps are left out, except for [aiUse].
@MappableClass(ignoreNull: true)
class CatalogExtrasMod with CatalogExtrasModMappable {
  /// The name shown on the site, only when it differs from the catalog's name.
  final String? displayName;

  /// The categories used by the site.
  final List<String>? categories;

  /// The source categories after the merge combines matching names.
  final List<String>? rawCategories;

  /// Each credited author's other known names, keyed by the credited name.
  final Map<String, List<String>>? otherAuthorNames;

  /// `YYYY-MM-DD`.
  final String? addedOn;

  /// `YYYY-MM-DD`.
  final String? editedOn;

  final DateTime? lastReleaseDate;

  /// Newest first.
  final List<ModRelease>? releases;

  final List<PublicNeededMod>? needs;
  final List<PublicNeededMod>? optionalNeeds;

  final bool? isTool;
  final bool? saveCompatible;

  final SaveAnswer? canAdd;
  final SaveAnswer? canUpdate;
  final SaveAnswer? canRemove;
  final String? saveCompatibilityText;
  final String? updateCompatibilityText;
  final String? removalCompatibilityText;

  /// Left out when the LLM has not checked the post. Empty when it checked
  /// the post and found no statement about AI use.
  final LlmAiUse? aiUse;

  final List<PublicSameNameMod>? sameNameMods;
  final List<PublicImage>? gallery;

  /// The mod's Discord post as cleaned HTML, as shown on the site.
  final String? discordPostHtml;

  CatalogExtrasMod({
    this.displayName,
    this.categories,
    this.rawCategories,
    this.otherAuthorNames,
    this.addedOn,
    this.editedOn,
    this.lastReleaseDate,
    this.releases,
    this.needs,
    this.optionalNeeds,
    this.isTool,
    this.saveCompatible,
    this.canAdd,
    this.canUpdate,
    this.canRemove,
    this.saveCompatibilityText,
    this.updateCompatibilityText,
    this.removalCompatibilityText,
    this.aiUse,
    this.sameNameMods,
    this.gallery,
    this.discordPostHtml,
  });
}
