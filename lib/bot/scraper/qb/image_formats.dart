class ImageFormats {
  ImageFormats._();

  static const Map<String, String> _extToMime = {
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.svg': 'image/svg+xml',
    '.bmp': 'image/bmp',
  };

  static const Map<String, String> _mimeToExt = {
    'image/png': '.png',
    'image/jpeg': '.jpg',
    'image/gif': '.gif',
    'image/webp': '.webp',
    'image/svg+xml': '.svg',
    'image/bmp': '.bmp',
  };

  static String getMimeType(String extension) =>
      _extToMime[extension.toLowerCase()] ?? 'application/octet-stream';

  static String? getExtension(String? mimeType) =>
      mimeType != null ? _mimeToExt[mimeType.toLowerCase()] : null;

  static bool isImageExtension(String extension) =>
      _extToMime.containsKey(extension.toLowerCase());

  static String guessExtensionFromUrl(String url) {
    final path = Uri.parse(url).path.toLowerCase();
    for (final ext in _extToMime.keys) {
      if (path.endsWith(ext)) {
        return ext == '.jpeg' ? '.jpg' : ext;
      }
    }
    return '.png';
  }
}
