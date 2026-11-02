import 'package:dart_mappable/dart_mappable.dart';

import 'public_mod_detail.dart';

part 'mod_conflict.mapper.dart';

/// `conflicts.json` lists every mod whose post names a conflict.
/// The Reports page reads it.
/// Each mod has the same conflicts as in its own file.
/// They are left out of `mods.json` because it is close to its size limit.
@MappableClass(ignoreNull: true)
class ModConflictList with ModConflictListMappable {
  /// When these files were built.
  final DateTime generatedAt;

  /// Sorted by the name shown on the site.
  final List<ModConflicts> mods;

  ModConflictList({required this.generatedAt, this.mods = const []});
}

/// One mod and the conflicts its own post names.
@MappableClass(ignoreNull: true)
class ModConflicts with ModConflictsMappable {
  final String modId;

  /// The name the site shows for the mod.
  final String modName;

  final List<PublicConflict> conflicts;

  ModConflicts({
    required this.modId,
    required this.modName,
    required this.conflicts,
  });
}
