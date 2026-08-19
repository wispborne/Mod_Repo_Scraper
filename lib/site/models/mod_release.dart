import 'package:dart_mappable/dart_mappable.dart';

part 'mod_release.mapper.dart';

/// `updates.json` — the mods that put out a new version, newest first.
@MappableClass(ignoreNull: true)
class ModReleaseFeed with ModReleaseFeedMappable {
  /// When these files were built.
  final DateTime generatedAt;

  /// Newest first.
  final List<ModRelease> releases;

  ModReleaseFeed({required this.generatedAt, this.releases = const []});
}

/// One mod putting out one new version.
///
/// A release is only recorded when a mod's version moves forward and holds —
/// see the `mod-release-detection` spec. Replies, view counts and one-off
/// misreadings never make one.
@MappableClass(ignoreNull: true)
class ModRelease with ModReleaseMappable {
  /// The mod's permanent id, so the row can link to its page.
  final String modId;

  /// The mod's name at the time the release was seen.
  final String modName;

  /// The day the new version was first believed, as a plain `YYYY-MM-DD` date.
  /// The home page groups the feed by this.
  final String seenOn;

  /// What the mod was on before. Null on the first release we ever recorded for
  /// a mod, which only happens when the history was backfilled.
  final String? oldVersion;

  final String newVersion;

  /// The game version the thread was for when the release was seen.
  final String? gameVersion;

  /// That version's changelog notes, copied word for word from the post. Null
  /// when the post gave none.
  final String? changelogNotes;

  ModRelease({
    required this.modId,
    required this.modName,
    required this.seenOn,
    this.oldVersion,
    required this.newVersion,
    this.gameVersion,
    this.changelogNotes,
  });
}
