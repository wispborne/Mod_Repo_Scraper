import 'models/catalog_extras.dart';
import 'public_data_builder.dart';

/// The file name used in the outputs folder beside `mod-catalog.json`.
const catalogExtrasFileName = 'mod-catalog-extras.json';

/// Copies mod details for TriOS from [PublicSiteData.details].
/// Creates one record per mod, using the values from the website build.
CatalogExtras buildCatalogExtras(PublicSiteData data) {
  List<T>? orNull<T>(List<T>? list) => list == null || list.isEmpty ? null : list;

  return CatalogExtras(
    generatedAt: data.list.generatedAt,
    mods: {
      for (final MapEntry(key: id, value: detail) in data.details.entries)
        id: CatalogExtrasMod(
          displayName: detail.listing.displayName,
          categories: orNull(detail.listing.categories),
          rawCategories: orNull(detail.rawCategories),
          otherAuthorNames: detail.listing.otherAuthorNames.isEmpty ? null : detail.listing.otherAuthorNames,
          addedOn: detail.listing.addedOn,
          editedOn: detail.listing.editedOn,
          lastReleaseDate: detail.listing.lastReleaseDate,
          releases: orNull(detail.releases),
          needs: orNull(detail.listing.needs),
          optionalNeeds: orNull(detail.optionalNeeds),
          isTool: detail.listing.isTool,
          saveCompatible: detail.listing.saveCompatible,
          canAdd: detail.canAdd,
          canUpdate: detail.canUpdate,
          canRemove: detail.canRemove,
          saveCompatibilityText: detail.saveCompatibilityText,
          updateCompatibilityText: detail.updateCompatibilityText,
          removalCompatibilityText: detail.removalCompatibilityText,
          aiUse: detail.aiUse,
          sameNameMods: orNull(detail.sameNameMods),
          gallery: orNull(detail.gallery),
          discordPostHtml: detail.discordPostHtml,
        ),
    },
  );
}
