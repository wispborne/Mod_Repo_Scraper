import 'models/mod_conflict.dart';
import 'models/public_mod_detail.dart';
import 'public_data_builder.dart';

/// Lists mods in [PublicSiteData.details] whose own posts name conflicts.
/// Leaves out conflicts copied from the other mod's post.
/// Each conflict is listed once, under the mod whose post names it.
ModConflictList buildConflictList(PublicSiteData data) {
  final mods = [
    for (final MapEntry(key: id, value: detail) in data.details.entries)
      if ([
        for (final conflict in detail.conflicts ?? const <PublicConflict>[])
          if (conflict.fromOtherMod != true) conflict,
      ]
          case final conflicts when conflicts.isNotEmpty)
        ModConflicts(
          modId: id,
          modName: detail.listing.displayName ?? detail.listing.name,
          conflicts: conflicts,
        ),
  ]..sort((a, b) => a.modName.toLowerCase().compareTo(b.modName.toLowerCase()));
  return ModConflictList(generatedAt: data.list.generatedAt, mods: mods);
}
