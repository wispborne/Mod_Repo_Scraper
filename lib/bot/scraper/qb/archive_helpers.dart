/// Helpers for checking and extracting archive file extensions.
class ArchiveHelpers {
  ArchiveHelpers._();

  static const _supportedExtensions = [
    '.zip',
    '.rar',
    '.7z',
    '.tar.gz',
    '.tar',
    '.bz2',
    '.gz',
    '.xz',
  ];

  /// Returns true if the filename has a supported archive extension.
  static bool hasSupportedArchiveExtension(String filename) {
    final lower = filename.toLowerCase();
    return _supportedExtensions.any((ext) => lower.endsWith(ext));
  }

  /// Extracts the base name by removing the archive extension.
  /// Returns the original name if no archive extension is found.
  static String getArchiveBaseName(String filename) {
    final lower = filename.toLowerCase();
    // Check longer extensions first (e.g. .tar.gz before .gz)
    for (final ext in _supportedExtensions) {
      if (lower.endsWith(ext)) {
        return filename.substring(0, filename.length - ext.length);
      }
    }
    return filename;
  }
}
