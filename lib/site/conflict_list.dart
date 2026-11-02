import 'models/mod_conflict.dart';
import 'public_data_builder.dart';

/// Lists every mod in [PublicSiteData.details] whose post names a conflict.
ModConflictList buildConflictList(PublicSiteData data) {
  final mods = [
    for (final MapEntry(key: id, value: detail) in data.details.entries)
      if (detail.conflicts case final conflicts? when conflicts.isNotEmpty)
        ModConflicts(
          modId: id,
          modName: detail.listing.displayName ?? detail.listing.name,
          conflicts: conflicts,
        ),
  ]..sort((a, b) => a.modName.toLowerCase().compareTo(b.modName.toLowerCase()));
  return ModConflictList(generatedAt: data.list.generatedAt, mods: mods);
}
