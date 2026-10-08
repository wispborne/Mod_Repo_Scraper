import '../bot/scraper/qb/models/post_extraction.dart';
import 'version_text.dart';

/// Picks the note about updating that speaks for one version of a mod.
///
/// A note written for a release speaks for that release and no other: "Minor
/// patch v1.0.1 is out. It is save-compatible." says nothing about v3.0.2. So a
/// note whose version matches [version] wins. A note tied to no release — "All
/// updates are save-compatible", "Not save compatible with versions prior to
/// 2.0.0" — describes the mod as the post stands now, so it only speaks for the
/// current version, and only when [isCurrent] says [version] is that one.
///
/// Notes about other versions are never picked. They stay in the bundle, but a
/// page showing one beside the wrong version is the mistake this is here to
/// stop.
LlmUpdateNote? updateNoteFor(
  List<LlmUpdateNote>? notes, {
  required String? version,
  required bool isCurrent,
}) {
  if (notes == null || notes.isEmpty) return null;

  final wanted = VersionText.clean(version);
  if (wanted != null) {
    for (final note in notes) {
      if (VersionText.clean(note.version) == wanted) return note;
    }
  }

  if (!isCurrent) return null;
  for (final note in notes) {
    if (note.version == null) return note;
  }
  return null;
}

/// True when [a] and [b] read as the same version.
bool sameVersion(String? a, String? b) {
  final left = VersionText.clean(a);
  return left != null && left == VersionText.clean(b);
}
