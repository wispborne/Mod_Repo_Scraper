import 'package:dart_mappable/dart_mappable.dart';

import '../download_resolver.dart';

part 'assumed_download.mapper.dart';

@MappableClass(ignoreNull: true)
class AssumedDownloadCandidate with AssumedDownloadCandidateMappable {
  final String originalUrl;
  final String? resolvedDirectUrl;
  final String sourceHost;
  final String? fileName;
  final String confidence;
  final bool requiresManualStep;
  final String linkText;

  AssumedDownloadCandidate({
    this.originalUrl = '',
    this.resolvedDirectUrl,
    this.sourceHost = '',
    this.fileName,
    this.confidence = 'medium',
    this.requiresManualStep = false,
    this.linkText = '',
  });

  /// Converts a [DownloadCandidate] from the resolver into the bundle format.
  factory AssumedDownloadCandidate.fromDownloadCandidate(
    DownloadCandidate candidate,
  ) {
    return AssumedDownloadCandidate(
      originalUrl: candidate.sourceUrl,
      resolvedDirectUrl: candidate.resolvedUrl,
      sourceHost: _inferSourceHost(candidate.resolvedUrl),
      fileName: candidate.archiveFilename,
      confidence: candidate.confidence.name,
      requiresManualStep: candidate.requiresManualStep,
      linkText: candidate.linkText,
    );
  }

  static String _inferSourceHost(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    final host = uri.host.toLowerCase();
    if (host.contains('github.com')) return 'GitHub';
    if (host.contains('drive.google.com') ||
        host.contains('drive.usercontent.google.com')) {
      return 'Google Drive';
    }
    if (host.contains('dropbox.com')) return 'Dropbox';
    if (host.contains('mediafire.com')) return 'MediaFire';
    if (host.contains('onedrive.live.com') || host == '1drv.ms') return 'OneDrive';
    if (host.contains('bitbucket.org')) return 'Bitbucket';
    if (host.contains('patreon.com')) return 'Patreon';
    return host;
  }
}
