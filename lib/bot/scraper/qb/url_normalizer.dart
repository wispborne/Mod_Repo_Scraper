/// Normalizes hosting-provider URLs into direct-download forms.
class UrlNormalizer {
  UrlNormalizer._();

  static final _googleDriveFileRegex =
      RegExp(r'/file/d/([^/]+)', caseSensitive: false);

  /// Normalizes a download URL for known hosting providers.
  /// Returns the normalized URL, or the original if no normalization applies.
  static String normalizeDownloadUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final host = uri.host.toLowerCase();

    // Google Drive: /file/d/{id} → uc?export=download&id={id}
    if (host.contains('drive.google.com') ||
        host.contains('drive.usercontent.google.com')) {
      return _normalizeGoogleDrive(url, uri);
    }

    // Dropbox: dl=0 → dl=1
    if (host.contains('dropbox.com')) {
      return _normalizeDropbox(url, uri);
    }

    // OneDrive: append download=1
    if (host.contains('onedrive.live.com') || host == '1drv.ms') {
      return _normalizeOneDrive(url, uri);
    }

    // GitHub: /blob/ → raw.githubusercontent.com
    if (host.contains('github.com') && uri.path.contains('/blob/')) {
      return _normalizeGitHubBlob(uri);
    }

    return url;
  }

  /// Returns true if the host doesn't support automated downloads.
  static bool isUnsupportedAutoDownloadHost(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host.contains('mega.nz') || host.contains('mega.co.nz');
  }

  /// Returns true for Google Drive links that open a folder listing rather
  /// than a single file. These can't be turned into a direct download.
  static bool isGoogleDriveFolder(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (!uri.host.toLowerCase().contains('drive.google.com')) return false;
    final path = uri.path.toLowerCase();
    return path.contains('/folders/') || path.startsWith('/folderview');
  }

  /// Returns true for old-style `drive.google.com/open?id=...` links.
  /// These can point at either a file or a folder — only following the
  /// link tells us which.
  static bool isGoogleDriveOpenLink(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (!uri.host.toLowerCase().contains('drive.google.com')) return false;
    return uri.path == '/open' && (uri.queryParameters['id']?.isNotEmpty ?? false);
  }

  static String _normalizeGoogleDrive(String url, Uri uri) {
    final match = _googleDriveFileRegex.firstMatch(url);
    if (match != null) {
      final fileId = match.group(1)!;
      return 'https://drive.google.com/uc?export=download&id=$fileId';
    }
    // open?id={id} → uc?export=download&id={id}
    if (uri.path == '/open' && (uri.queryParameters['id']?.isNotEmpty ?? false)) {
      return 'https://drive.google.com/uc?export=download&id=${uri.queryParameters['id']}';
    }
    // Already in uc?export=download form or other format
    return url;
  }

  static String _normalizeDropbox(String url, Uri uri) {
    final params = Map<String, String>.from(uri.queryParameters);
    params['dl'] = '1';
    return uri.replace(queryParameters: params).toString();
  }

  static String _normalizeOneDrive(String url, Uri uri) {
    if (uri.queryParameters.containsKey('download')) return url;
    final params = Map<String, String>.from(uri.queryParameters);
    params['download'] = '1';
    return uri.replace(queryParameters: params).toString();
  }

  static String _normalizeGitHubBlob(Uri uri) {
    // github.com/user/repo/blob/branch/path → raw.githubusercontent.com/user/repo/branch/path
    final path = uri.path.replaceFirst('/blob/', '/');
    return 'https://raw.githubusercontent.com$path';
  }
}
