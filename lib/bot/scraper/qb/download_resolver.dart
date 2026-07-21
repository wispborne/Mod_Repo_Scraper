import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:synchronized/synchronized.dart';

import 'archive_helpers.dart';
import 'downloadable_probe_cache.dart';
import 'forum_constants.dart';
import 'html_processor.dart';
import 'models/mod_detail.dart';
import 'url_normalizer.dart';

/// Confidence level for a resolved download candidate.
enum DownloadConfidence { high, medium, low }

/// A resolved download candidate.
class DownloadCandidate {
  final String sourceUrl;
  final String resolvedUrl;
  final String? archiveFilename;
  final DownloadConfidence confidence;
  final bool requiresManualStep;
  final String linkText;

  DownloadCandidate({
    required this.sourceUrl,
    required this.resolvedUrl,
    this.archiveFilename,
    this.confidence = DownloadConfidence.medium,
    this.requiresManualStep = false,
    this.linkText = '',
  });

  Map<String, dynamic> toJson() => {
        'sourceUrl': sourceUrl,
        'resolvedUrl': resolvedUrl,
        if (archiveFilename != null) 'archiveFilename': archiveFilename,
        'confidence': confidence.name,
        'requiresManualStep': requiresManualStep,
        if (linkText.isNotEmpty) 'linkText': linkText,
      };

  factory DownloadCandidate.fromJson(Map<String, dynamic> json) => DownloadCandidate(
        sourceUrl: json['sourceUrl'] as String,
        resolvedUrl: json['resolvedUrl'] as String,
        archiveFilename: json['archiveFilename'] as String?,
        confidence: DownloadConfidence.values.firstWhere((e) => e.name == json['confidence']),
        requiresManualStep: json['requiresManualStep'] as bool? ?? false,
        linkText: json['linkText'] as String? ?? '',
      );
}

/// Cached entry for a topic's resolved downloads.
class _CacheEntry {
  final String fingerprint;
  final int schemaVersion;
  final List<DownloadCandidate> candidates;

  _CacheEntry({
    required this.fingerprint,
    required this.schemaVersion,
    required this.candidates,
  });

  Map<String, dynamic> toJson() => {
        'fingerprint': fingerprint,
        'schemaVersion': schemaVersion,
        'candidates': candidates.map((c) => c.toJson()).toList(),
      };

  factory _CacheEntry.fromJson(Map<String, dynamic> json) => _CacheEntry(
        fingerprint: json['fingerprint'] as String,
        schemaVersion: json['schemaVersion'] as int? ?? 0,
        candidates: (json['candidates'] as List<dynamic>)
            .map((e) => DownloadCandidate.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Resolves direct download URLs from links found in forum topic first posts.
class QbDownloadResolver {
  // v3: GitHub releases/latest/download links resolve as direct assets;
  // Google Drive folder and open?id= links (including folders hiding behind
  // open?id=) are handled correctly; unknown hosts are checked for a real
  // file before being dropped.
  static const int _schemaVersion = 3;
  static const String _cacheFilename = 'assumed-downloads-cache.json';

  /// Write the file once this many topics have been resolved. Resolving a topic
  /// means live calls out to GitHub, Google Drive, MediaFire and friends, so an
  /// interrupted run that saved nothing has thrown away real work.
  static const int _flushEvery = 10;

  final http.Client _client;
  final String _dataPath;
  final Logger _log;

  /// Topics resolved since the last disk write, and a guard so overlapping
  /// topics never start two writes at once.
  int _unsaved = 0;
  final Lock _writeLock = Lock();

  /// The shared "does this link lead to a file?" cache. The unknown-host
  /// fallback reuses its saved answers (and adds to them) instead of asking
  /// the same host twice. If the caller doesn't pass one in, the resolver
  /// makes its own over the same data folder.
  final DownloadableProbeCache _probeCache;

  /// topicId → cache entry
  final Map<int, _CacheEntry> _cache = {};

  static const _shortenerHosts = [
    'tinyurl.com',
    'bit.ly',
    't.co',
    'goo.gl',
    'ow.ly',
    'is.gd',
    'buff.ly',
    'rebrand.ly',
  ];

  static const _nonArchiveExtensions = [
    '.ogg',
    '.mp3',
    '.wav',
    '.flac',
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.bmp',
    '.webp',
    '.svg',
    '.pdf',
    '.txt',
    '.doc',
    '.docx',
    '.jar',
    '.exe',
    '.msi',
    '.json',
    '.xml',
    '.csv',
    '.html',
    '.htm',
  ];

  // Matches both asset URL forms: /releases/download/{tag}/{file} and the
  // "always newest" permalink /releases/latest/download/{file}.
  static final _githubDirectAssetRegex = RegExp(
    r'github\.com/[^/]+/[^/]+/releases/(?:download/[^/]+|latest/download)/.+',
    caseSensitive: false,
  );

  static final _githubReleasesPageRegex = RegExp(
    r'github\.com/([^/]+)/([^/]+)/releases(?:/tag/[^/]+)?$',
    caseSensitive: false,
  );

  static final _archiveFilenameRegex = RegExp(
    r'[\w\-.\+\[\]\(\) ]+\.(?:zip|rar|7z|tar\.gz|tar|bz2|gz|xz)',
    caseSensitive: false,
  );

  static final _mediafireCdnRegex1 = RegExp(
    r'''(https?://download\d*\.mediafire\.com/[^\s"'<>]+)''',
    caseSensitive: false,
  );

  static final _mediafireCdnRegex2 = RegExp(
    r'''(https?:\\?/\\?/download\d*\.mediafire\.com\\?/[^\s"'<>\\]+)''',
    caseSensitive: false,
  );

  static final _mediafireCdnRegex3 = RegExp(
    r'''href=["'](https?://download\d*\.mediafire\.com/[^"']+)["']''',
    caseSensitive: false,
  );

  static final _googleDriveTitleRegex = RegExp(
    r'<title>\s*(.*?)\s*(?:-\s*Google Drive)?\s*</title>',
    caseSensitive: false,
    dotAll: true,
  );

  static final _googleDriveOgTitleRegex = RegExp(
    r'''property\s*=\s*["']og:title["'][^>]*content\s*=\s*["']([^"']+)["']''',
    caseSensitive: false,
  );

  static final _googleDriveOgTitleAltRegex = RegExp(
    r'''content\s*=\s*["']([^"']+)["'][^>]{0,240}?property\s*=\s*["']og:title["']''',
    caseSensitive: false,
  );

  static final _googleDriveJsonTitleRegex = RegExp(
    r'"title"\s*:\s*"([^"]+\.(?:zip|rar|7z|tar\.gz|tar|bz2))"',
    caseSensitive: false,
  );

  static final _gdriveDispositionUtf8StarRegex = RegExp(
    r"filename\*=UTF-8''([^;\s""']+)",
    caseSensitive: false,
  );

  static final _gdriveDispositionQuotedRegex = RegExp(
    r'filename\s*=\s*"([^"]+)"',
    caseSensitive: false,
  );

  QbDownloadResolver({
    required http.Client client,
    required String dataPath,
    DownloadableProbeCache? probeCache,
    Logger? logger,
  })  : _client = client,
        _dataPath = dataPath,
        _probeCache = probeCache ?? DownloadableProbeCache(dataPath: dataPath),
        _log = logger ?? Logger('QbDownloadResolver');

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Resolves download candidates for a topic's links.
  Future<List<DownloadCandidate>> resolveForTopic(
    int topicId,
    List<LinkRef> links,
  ) async {
    final externalLinks = links
        .where((l) =>
            l.isExternal && l.url.trim().isNotEmpty && !ForumConstants.isForumHosted(l.url) && !_isIgnoredHost(l.url))
        .toList();

    if (externalLinks.isEmpty) return [];

    final fingerprint = _computeFingerprint(externalLinks);

    // Check cache
    final cached = _cache[topicId];
    if (cached != null && cached.fingerprint == fingerprint && cached.schemaVersion == _schemaVersion) {
      _log.fine('Cache hit for topic $topicId');
      return cached.candidates;
    }

    _log.info('Resolving downloads for topic $topicId '
        '(${externalLinks.length} external links)');

    final results = await Future.wait(
      externalLinks.map((link) async {
        try {
          final candidate = await _resolveLink(link);
          if (candidate != null) {
            return DownloadCandidate(
              sourceUrl: candidate.sourceUrl,
              resolvedUrl: candidate.resolvedUrl,
              archiveFilename: candidate.archiveFilename,
              confidence: candidate.confidence,
              requiresManualStep: candidate.requiresManualStep,
              linkText: link.text,
            );
          }
          return null;
        } catch (e) {
          _log.warning('Failed to resolve link ${link.url}: $e');
          return null;
        }
      }),
    );
    final candidates = results.whereType<DownloadCandidate>().toList();

    // Post-processing
    _extractFilenames(candidates, externalLinks);
    _inferFilenames(candidates);
    _filterNonArchives(candidates);
    _dedup(candidates);

    // Cache result
    _cache[topicId] = _CacheEntry(
      fingerprint: fingerprint,
      schemaVersion: _schemaVersion,
      candidates: candidates,
    );
    _unsaved++;
    await _maybeFlush();

    return candidates;
  }

  /// Writes the cache once enough topics have been resolved since the last
  /// write, so an interrupted run keeps most of its resolution work.
  Future<void> _maybeFlush() async {
    if (_unsaved < _flushEvery) return;
    try {
      await saveCache();
    } catch (e) {
      // A failed write just means we try again at the next threshold, or at the
      // final save. The answers are still in memory either way.
      _log.warning('Background download-cache flush failed: $e');
    }
  }

  /// Turns a single link into a download candidate, without touching the
  /// per-topic cache. Used by the LLM flow to look up a link the LLM chose as
  /// a download. Returns null when the link can't be turned into a download
  /// (e.g. an unknown host), so the caller can keep the raw link instead.
  Future<DownloadCandidate?> resolveSingleLink(LinkRef link) async {
    try {
      return await _resolveLink(link);
    } catch (e) {
      _log.warning('Failed to resolve LLM-chosen link ${link.url}: $e');
      return null;
    }
  }

  /// Returns cached candidates for a topic, or null if not cached.
  List<DownloadCandidate>? getCachedCandidates(int topicId) => _cache[topicId]?.candidates;

  /// Returns true if candidates are cached for the given topic.
  bool hasCachedCandidates(int topicId) => _cache.containsKey(topicId);

  /// Returns all cached candidates across all topics.
  Map<int, List<DownloadCandidate>> getAllCandidates() => _cache.map((k, v) => MapEntry(k, v.candidates));

  /// Topics whose saved entries were made by an older version of this
  /// resolver. Their results may be missing the newer rules, so the caller
  /// should redo them (using the links already saved on disk) when it can.
  Set<int> get outdatedTopicIds => _cache.entries
      .where((e) => e.value.schemaVersion != _schemaVersion)
      .map((e) => e.key)
      .toSet();

  /// Imports externally-provided candidates with a sentinel fingerprint.
  void importCandidates(int topicId, List<DownloadCandidate> candidates) {
    _cache[topicId] = _CacheEntry(
      fingerprint: 'bundle',
      schemaVersion: _schemaVersion,
      candidates: candidates,
    );
  }

  // ---------------------------------------------------------------------------
  // Cache persistence
  // ---------------------------------------------------------------------------

  /// Loads the cache from disk.
  Future<void> loadCache() async {
    final file = File(p.join(_dataPath, _cacheFilename));
    if (!file.existsSync()) return;

    try {
      final json = await file.readAsString();
      final map = jsonDecode(json) as Map<String, dynamic>;
      _cache.clear();
      for (final entry in map.entries) {
        final topicId = int.tryParse(entry.key);
        if (topicId == null) continue;
        final cacheEntry = _CacheEntry.fromJson(entry.value as Map<String, dynamic>);
        // Entries saved by an older version are kept: they still fill the
        // bundle for topics that aren't re-scraped this run. resolveForTopic
        // treats them as misses, and the main flow redoes them from the links
        // already on disk (see [outdatedTopicIds]).
        _cache[topicId] = cacheEntry;
      }
      _log.info('Loaded download cache with ${_cache.length} entries');
    } catch (e) {
      _log.warning('Failed to load download cache: $e');
    }
  }

  /// Saves the cache to disk. Safe to call from multiple places at once.
  Future<void> saveCache() async {
    await _writeLock.synchronized(() async {
      _unsaved = 0;
      final map = _cache.map((k, v) => MapEntry(k.toString(), v.toJson()));
      final json = const JsonEncoder.withIndent('  ').convert(map);
      final file = File(p.join(_dataPath, _cacheFilename));
      await file.writeAsString(json);
      _log.info('Saved download cache with ${_cache.length} entries');
    });
  }

  // ---------------------------------------------------------------------------
  // Link resolution
  // ---------------------------------------------------------------------------

  Future<DownloadCandidate?> _resolveLink(LinkRef link) async {
    var url = link.url.trim();
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // Follow URL shorteners first
    final host = uri.host.toLowerCase();
    if (_isShortenerHost(host)) {
      final resolved = await _followRedirect(url);
      if (resolved != null) {
        url = resolved;
      } else {
        return null;
      }
    }

    final resolvedUri = Uri.tryParse(url);
    if (resolvedUri == null) return null;
    final resolvedHost = resolvedUri.host.toLowerCase();

    // Unsupported hosts
    if (UrlNormalizer.isUnsupportedAutoDownloadHost(url)) {
      return DownloadCandidate(
        sourceUrl: link.url,
        resolvedUrl: url,
        confidence: DownloadConfidence.low,
        requiresManualStep: true,
      );
    }

    // GitHub direct asset
    if (_githubDirectAssetRegex.hasMatch(url)) {
      return _resolveGitHubDirectAsset(link.url, url);
    }

    // GitHub releases page
    if (_githubReleasesPageRegex.hasMatch(url)) {
      return await _resolveGitHubReleasesPage(link.url, url);
    }

    // Google Drive
    if (resolvedHost.contains('drive.google.com') || resolvedHost.contains('drive.usercontent.google.com')) {
      return await _resolveGoogleDrive(link.url, url);
    }

    // Dropbox
    if (resolvedHost.contains('dropbox.com')) {
      return _resolveDropbox(link.url, url);
    }

    // MediaFire
    if (resolvedHost.contains('mediafire.com')) {
      return await _resolveMediaFire(link.url, url);
    }

    // OneDrive
    if (resolvedHost.contains('onedrive.live.com') || resolvedHost == '1drv.ms') {
      return _resolveOneDrive(link.url, url);
    }

    // Bitbucket
    if (resolvedHost.contains('bitbucket.org') && resolvedUri.path.contains('/downloads/')) {
      return _resolveBitbucket(link.url, url);
    }

    // Patreon
    if (resolvedHost.contains('patreon.com')) {
      return DownloadCandidate(
        sourceUrl: link.url,
        resolvedUrl: url,
        confidence: DownloadConfidence.low,
        requiresManualStep: true,
      );
    }

    // No host-specific rule matched. Before giving up, ask whether the link
    // actually serves a file: an obvious archive extension answers with no
    // request; anything else does one HEAD/GET that inspects Content-Disposition
    // and Content-Type. Answers are saved, so each link is only asked about
    // once — later runs reuse the answer from disk. If it is a real download,
    // keep it as a direct link rather than mislabelling it a manual step.
    final servesFile = await _probeCache.classify(url, client: _client);
    if (servesFile) {
      return DownloadCandidate(
        sourceUrl: link.url,
        resolvedUrl: url,
        confidence: DownloadConfidence.medium,
      );
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // URL shortener following
  // ---------------------------------------------------------------------------

  bool _isShortenerHost(String host) => _shortenerHosts.any((s) => host == s || host.endsWith('.$s'));

  Future<String?> _followRedirect(String url) async {
    try {
      final response = await _client.get(
        Uri.parse(url),
        headers: {'Accept': '*/*'},
      );
      // Check for redirect via location header or final URL
      final location = response.headers['location'];
      if (location != null && location.isNotEmpty) {
        return location;
      }
      // If we got a 2xx with a different URL, it was followed automatically
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // http package follows redirects by default
        return response.request?.url.toString() ?? url;
      }
      return null;
    } catch (e) {
      _log.warning('Failed to follow redirect for $url: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // GitHub resolution
  // ---------------------------------------------------------------------------

  DownloadCandidate _resolveGitHubDirectAsset(String sourceUrl, String url) {
    final filename = Uri.parse(url).pathSegments.last;
    return DownloadCandidate(
      sourceUrl: sourceUrl,
      resolvedUrl: url,
      archiveFilename: ArchiveHelpers.hasSupportedArchiveExtension(filename) ? filename : null,
      confidence: DownloadConfidence.high,
    );
  }

  Future<DownloadCandidate> _resolveGitHubReleasesPage(String sourceUrl, String url) async {
    final match = _githubReleasesPageRegex.firstMatch(url);
    if (match == null) {
      return DownloadCandidate(
        sourceUrl: sourceUrl,
        resolvedUrl: url,
        confidence: DownloadConfidence.low,
        requiresManualStep: true,
      );
    }

    final owner = match.group(1)!;
    final repo = match.group(2)!;

    try {
      final apiUrl = Uri.parse('https://api.github.com/repos/$owner/$repo/releases');
      final response = await _client.get(apiUrl, headers: {
        'Accept': 'application/vnd.github.v3+json',
      });

      if (response.statusCode == 200) {
        final releases = jsonDecode(response.body) as List<dynamic>;
        for (final release in releases) {
          final assets = release['assets'] as List<dynamic>? ?? [];
          for (final asset in assets) {
            final name = asset['name'] as String? ?? '';
            final downloadUrl = asset['browser_download_url'] as String? ?? '';
            if (ArchiveHelpers.hasSupportedArchiveExtension(name) && !_isSourceArchive(name)) {
              return DownloadCandidate(
                sourceUrl: sourceUrl,
                resolvedUrl: downloadUrl,
                archiveFilename: name,
                confidence: DownloadConfidence.high,
              );
            }
          }
          // Only check the latest release
          break;
        }
      }
    } catch (e) {
      _log.warning('GitHub API call failed for $owner/$repo: $e');
    }

    return DownloadCandidate(
      sourceUrl: sourceUrl,
      resolvedUrl: url,
      confidence: DownloadConfidence.low,
      requiresManualStep: true,
    );
  }

  bool _isSourceArchive(String name) {
    final lower = name.toLowerCase();
    return lower.contains('source') && !lower.contains('resource');
  }

  // ---------------------------------------------------------------------------
  // Google Drive resolution
  // ---------------------------------------------------------------------------

  Future<DownloadCandidate> _resolveGoogleDrive(String sourceUrl, String url) async {
    // A folder link opens a file listing, not a download — the user has to
    // open it and pick a file themselves.
    if (UrlNormalizer.isGoogleDriveFolder(url)) {
      return DownloadCandidate(
        sourceUrl: sourceUrl,
        resolvedUrl: url,
        confidence: DownloadConfidence.low,
        requiresManualStep: true,
      );
    }

    // An old-style open?id= link can hide either a file or a folder. Follow
    // the redirect once to find out; if it lands on a folder, treat it like
    // one. If we can't tell, assume it's a file, as before.
    if (UrlNormalizer.isGoogleDriveOpenLink(url)) {
      final followed = await _followRedirect(url);
      if (followed != null && UrlNormalizer.isGoogleDriveFolder(followed)) {
        return DownloadCandidate(
          sourceUrl: sourceUrl,
          resolvedUrl: followed,
          confidence: DownloadConfidence.low,
          requiresManualStep: true,
        );
      }
    }

    final normalized = UrlNormalizer.normalizeDownloadUrl(url);
    String? filename;

    try {
      // Probe the uc download URL first (Content-Disposition + HTML).
      filename = await _tryGoogleDriveNameFromUc(normalized);
      // Fall back to the original view/share URL's HTML metadata.
      if (filename == null) {
        final viewHtml = await _client.get(Uri.parse(url));
        if (viewHtml.statusCode == 200) {
          filename = _parseDriveHtml(viewHtml.body);
        }
      }
    } catch (e) {
      _log.fine('Google Drive probe failed for $url: $e');
    }

    return DownloadCandidate(
      sourceUrl: sourceUrl,
      resolvedUrl: normalized,
      archiveFilename: filename,
      confidence: DownloadConfidence.medium,
    );
  }

  Future<String?> _tryGoogleDriveNameFromUc(String downloadUrl) async {
    try {
      final response = await _client.get(Uri.parse(downloadUrl));

      // Try Content-Disposition header.
      final contentDisp = response.headers['content-disposition'];
      if (contentDisp != null) {
        final name = _sanitizeDriveArchiveName(
            _rawContentDispositionFileName(contentDisp));
        if (name != null) return name;
      }

      // If the response is HTML (virus-scan interstitial), parse it.
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('text/html')) return null;
      return _parseDriveHtml(response.body);
    } catch (e) {
      _log.fine('Google Drive uc download probe failed for $downloadUrl: $e');
      return null;
    }
  }

  String? _rawContentDispositionFileName(String header) {
    var m = _gdriveDispositionUtf8StarRegex.firstMatch(header);
    if (m != null) return _tryDecodeFull(m.group(1)!);
    m = _gdriveDispositionQuotedRegex.firstMatch(header);
    return m?.group(1);
  }

  String? _sanitizeDriveArchiveName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final hint = _extractArchiveFilename(raw) ?? raw.trim().replaceAll('"', '');
    if (hint.isEmpty) return null;
    return ArchiveHelpers.hasSupportedArchiveExtension(hint) ? hint : null;
  }

  String? _parseDriveHtml(String html) {
    // Try <title>, og:title, og:title (reversed attr order)
    for (final regex in [
      _googleDriveTitleRegex,
      _googleDriveOgTitleRegex,
      _googleDriveOgTitleAltRegex,
    ]) {
      final m = regex.firstMatch(html);
      if (m != null) {
        final name = _sanitizeDriveArchiveName(
            HtmlProcessor.decodeEntities(m.group(1)!.trim()));
        if (name != null) return name;
      }
    }

    // Try Content-Disposition patterns embedded in HTML (virus-scan page)
    for (final m in _gdriveDispositionUtf8StarRegex.allMatches(html)) {
      final name = _sanitizeDriveArchiveName(
          _tryDecodeFull(m.group(1)!));
      if (name != null) return name;
    }
    for (final m in _gdriveDispositionQuotedRegex.allMatches(html)) {
      final name = _sanitizeDriveArchiveName(m.group(1));
      if (name != null) return name;
    }

    // Try JSON title
    for (final m in _googleDriveJsonTitleRegex.allMatches(html)) {
      final name = _sanitizeDriveArchiveName(m.group(1));
      if (name != null) return name;
    }

    // Last resort: scan entire HTML for archive filename pattern
    return _sanitizeDriveArchiveName(_extractArchiveFilename(html));
  }

  // ---------------------------------------------------------------------------
  // Dropbox resolution
  // ---------------------------------------------------------------------------

  DownloadCandidate _resolveDropbox(String sourceUrl, String url) {
    final normalized = UrlNormalizer.normalizeDownloadUrl(url);
    final uri = Uri.tryParse(normalized);
    String? filename;
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final last = _tryDecodeFull(uri.pathSegments.last);
      if (last != null && ArchiveHelpers.hasSupportedArchiveExtension(last)) {
        filename = last;
      }
    }
    return DownloadCandidate(
      sourceUrl: sourceUrl,
      resolvedUrl: normalized,
      archiveFilename: filename,
      confidence: DownloadConfidence.medium,
    );
  }

  // ---------------------------------------------------------------------------
  // MediaFire resolution
  // ---------------------------------------------------------------------------

  Future<DownloadCandidate> _resolveMediaFire(String sourceUrl, String url) async {
    try {
      final response = await _client.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final body = response.body;
        final cdnUrl = _extractMediaFireCdnUrl(body);
        if (cdnUrl != null) {
          final filename = _extractFilenameFromUrl(cdnUrl);
          return DownloadCandidate(
            sourceUrl: sourceUrl,
            resolvedUrl: cdnUrl,
            archiveFilename: filename,
            confidence: DownloadConfidence.medium,
          );
        }
      }
    } catch (e) {
      _log.fine('MediaFire page fetch failed for $url: $e');
    }

    return DownloadCandidate(
      sourceUrl: sourceUrl,
      resolvedUrl: url,
      confidence: DownloadConfidence.low,
      requiresManualStep: true,
    );
  }

  String? _extractMediaFireCdnUrl(String html) {
    // Try plain URL
    var match = _mediafireCdnRegex1.firstMatch(html);
    if (match != null) return match.group(1);

    // Try JSON-escaped URL
    match = _mediafireCdnRegex2.firstMatch(html);
    if (match != null) {
      return match.group(1)!.replaceAll(r'\/', '/');
    }

    // Try href attribute
    match = _mediafireCdnRegex3.firstMatch(html);
    if (match != null) return match.group(1);

    return null;
  }

  // ---------------------------------------------------------------------------
  // OneDrive resolution
  // ---------------------------------------------------------------------------

  DownloadCandidate _resolveOneDrive(String sourceUrl, String url) {
    final normalized = UrlNormalizer.normalizeDownloadUrl(url);
    return DownloadCandidate(
      sourceUrl: sourceUrl,
      resolvedUrl: normalized,
      confidence: DownloadConfidence.medium,
    );
  }

  // ---------------------------------------------------------------------------
  // Bitbucket resolution
  // ---------------------------------------------------------------------------

  DownloadCandidate _resolveBitbucket(String sourceUrl, String url) {
    final filename = _extractFilenameFromUrl(url);
    return DownloadCandidate(
      sourceUrl: sourceUrl,
      resolvedUrl: url,
      archiveFilename: filename,
      confidence: DownloadConfidence.high,
    );
  }

  // ---------------------------------------------------------------------------
  // Filename extraction (task 4.1)
  // ---------------------------------------------------------------------------

  /// Extracts archive filenames from URL paths and link text.
  /// Link text takes priority over URL.
  void _extractFilenames(List<DownloadCandidate> candidates, List<LinkRef> links) {
    for (var i = 0; i < candidates.length; i++) {
      final c = candidates[i];
      if (c.archiveFilename != null) continue;

      // Find the matching link for this candidate
      final link = links.firstWhere(
        (l) => l.url.trim() == c.sourceUrl,
        orElse: () => LinkRef(),
      );

      // Try link text first (priority)
      if (link.text.isNotEmpty) {
        final fromText = _extractArchiveFilename(link.text);
        if (fromText != null) {
          candidates[i] = DownloadCandidate(
            sourceUrl: c.sourceUrl,
            resolvedUrl: c.resolvedUrl,
            archiveFilename: fromText,
            confidence: c.confidence,
            requiresManualStep: c.requiresManualStep,
            linkText: c.linkText,
          );
          continue;
        }
      }

      // Try URL path
      final fromUrl = _extractFilenameFromUrl(c.resolvedUrl);
      if (fromUrl != null) {
        candidates[i] = DownloadCandidate(
          sourceUrl: c.sourceUrl,
          resolvedUrl: c.resolvedUrl,
          archiveFilename: fromUrl,
          confidence: c.confidence,
          requiresManualStep: c.requiresManualStep,
          linkText: c.linkText,
        );
      }
    }
  }

  String? _extractArchiveFilename(String text) {
    final match = _archiveFilenameRegex.firstMatch(text);
    if (match == null) return null;
    final filename = match.group(0)!;
    return ArchiveHelpers.hasSupportedArchiveExtension(filename) ? filename : null;
  }

  String? _extractFilenameFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.pathSegments.isEmpty) return null;
    final last = _tryDecodeFull(uri.pathSegments.last);
    if (last == null) return null;
    return ArchiveHelpers.hasSupportedArchiveExtension(last) ? last : null;
  }

  // ---------------------------------------------------------------------------
  // Filename inference (task 4.2)
  // ---------------------------------------------------------------------------

  void _inferFilenames(List<DownloadCandidate> candidates) {
    if (candidates.isEmpty) return;

    // Collect unique filenames
    final knownFilenames = candidates.where((c) => c.archiveFilename != null).map((c) => c.archiveFilename!).toSet();

    final uniqueFilename = knownFilenames.length == 1 ? knownFilenames.first : null;

    if (uniqueFilename == null) return;

    for (var i = 0; i < candidates.length; i++) {
      final c = candidates[i];
      if (c.archiveFilename != null) continue;

      final host = Uri.tryParse(c.sourceUrl)?.host.toLowerCase() ?? '';
      if (host.contains('drive.google.com') || host.contains('drive.usercontent.google.com')) {
        candidates[i] = DownloadCandidate(
          sourceUrl: c.sourceUrl,
          resolvedUrl: c.resolvedUrl,
          archiveFilename: uniqueFilename,
          confidence: c.confidence,
          requiresManualStep: c.requiresManualStep,
          linkText: c.linkText,
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Non-archive file filtering (task 4.4)
  // ---------------------------------------------------------------------------

  void _filterNonArchives(List<DownloadCandidate> candidates) {
    candidates.removeWhere((c) {
      if (c.archiveFilename != null) {
        return !ArchiveHelpers.hasSupportedArchiveExtension(c.archiveFilename!);
      }
      // Check resolved URL for non-archive extension
      final filename = _extractFilenameFromUrl(c.resolvedUrl);
      if (filename != null && _hasNonArchiveExtension(filename)) {
        return true;
      }
      return false;
    });
  }

  bool _hasNonArchiveExtension(String filename) {
    final lower = filename.toLowerCase();
    return _nonArchiveExtensions.any((ext) => lower.endsWith(ext));
  }

  // ---------------------------------------------------------------------------
  // Deduplication (task 4.3)
  // ---------------------------------------------------------------------------

  void _dedup(List<DownloadCandidate> candidates) {
    // Dedup by resolved URL (normalized, path-only, case-insensitive)
    final seenUrls = <String>{};
    candidates.removeWhere((c) {
      final key = _normalizeUrlForDedup(c.resolvedUrl);
      if (seenUrls.contains(key)) return true;
      seenUrls.add(key);
      return false;
    });

    // Dedup by archive filename
    final seenFilenames = <String>{};
    candidates.removeWhere((c) {
      if (c.archiveFilename == null) return false;
      final key = c.archiveFilename!.toLowerCase();
      if (seenFilenames.contains(key)) return true;
      seenFilenames.add(key);
      return false;
    });
  }

  String _normalizeUrlForDedup(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url.toLowerCase();
    return uri.path.toLowerCase();
  }

  // ---------------------------------------------------------------------------
  // Fingerprint computation (task 5.1)
  // ---------------------------------------------------------------------------

  String _computeFingerprint(List<LinkRef> links) {
    final normalized = links.map((l) => UrlNormalizer.normalizeDownloadUrl(l.url.trim())).toList()..sort();
    return normalized.join('|');
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String? _tryDecodeFull(String encoded) {
    try {
      return Uri.decodeFull(encoded);
    } catch (e) {
      _log.warning('Failed to decode URL segment "$encoded": $e');
      return null;
    }
  }

  bool _isIgnoredHost(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return true;
    final host = uri.host.toLowerCase();
    return host.contains('nexusmods.com') || host == 'youtu.be' || host.contains('youtube.com');
  }
}
