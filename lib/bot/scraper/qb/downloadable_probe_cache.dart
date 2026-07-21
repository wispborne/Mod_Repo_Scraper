import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../download_link_detector.dart';

/// On-disk cache for the "is this link a direct download?" probe.
///
/// Classifying a link that isn't an obvious archive means a live HEAD/GET to
/// the outside host (see [isDownloadableUrl]). That probe is the slowest step
/// per topic and its answer almost never changes, so we remember each URL's
/// result on disk. Re-runs then pay nothing for links we've already seen.
///
/// Keyed by the raw link URL. Obvious downloads (handled by
/// [isLikelyModDownloadUrl]) are never stored — they resolve with no I/O.
class DownloadableProbeCache {
  /// Bump when the classification logic changes in a way that should discard
  /// old answers.
  static const int _schemaVersion = 1;
  static const String _cacheFilename = 'link-downloadable-cache.json';

  /// Write the file to disk once this many new answers have piled up, so an
  /// interrupted first run keeps most of its (expensive) probe work.
  static const int _flushEvery = 10;

  final String _dataPath;
  final Logger _log;

  /// url → isDownloadable
  final Map<String, bool> _cache = {};

  /// Checks currently in progress, so the same URL asked about twice at the
  /// same time only makes one request.
  final Map<String, Future<bool>> _inFlight = {};

  /// New answers since the last disk write, and a guard so overlapping probes
  /// never start two writes at once.
  int _unsaved = 0;
  bool _writing = false;

  /// Whether the file on disk has been read yet. [classify] reads it on
  /// first use, so a cache that nobody explicitly loaded still starts from
  /// the saved answers instead of overwriting them later.
  bool _loaded = false;
  Future<void>? _loading;

  DownloadableProbeCache({
    required String dataPath,
    Logger? logger,
  })  : _dataPath = dataPath,
        _log = logger ?? Logger('DownloadableProbeCache');

  /// Returns whether [url] is a direct download, using the cached answer when
  /// available and probing the network (once) otherwise.
  Future<bool> classify(
    String url, {
    http.Client? client,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // Obvious downloads are free to classify; don't bloat the cache with them.
    if (isLikelyModDownloadUrl(url)) return true;

    if (!_loaded) await (_loading ??= loadCache());

    final cached = _cache[url];
    if (cached != null) return cached;

    // If this exact URL is already being checked, wait for that answer
    // instead of asking the host a second time.
    final inFlight = _inFlight[url];
    if (inFlight != null) return inFlight;

    final probe = () async {
      try {
        final result =
            await isDownloadableUrl(url, client: client, timeout: timeout);
        _cache[url] = result;
        _unsaved++;
        _maybeFlush();
        return result;
      } finally {
        _inFlight.remove(url);
      }
    }();
    _inFlight[url] = probe;
    return probe;
  }

  /// Writes the cache in the background once enough new answers have piled up.
  /// Fire-and-forget: a probe should never block on disk I/O, and a failed
  /// write just means we retry at the next threshold (or the final save).
  void _maybeFlush() {
    if (_writing || _unsaved < _flushEvery) return;
    _writing = true;
    _unsaved = 0;
    saveCache().catchError((Object e) {
      _log.warning('Background probe-cache flush failed: $e');
    }).whenComplete(() => _writing = false);
  }

  /// Loads the cache from disk. A missing file or a schema-version mismatch
  /// simply starts empty.
  Future<void> loadCache() async {
    _loaded = true;
    final file = File(p.join(_dataPath, _cacheFilename));
    if (!file.existsSync()) return;

    try {
      final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (map['schemaVersion'] != _schemaVersion) {
        _log.info('Probe cache schema changed; starting fresh.');
        return;
      }
      final entries = map['entries'] as Map<String, dynamic>? ?? {};
      _cache.clear();
      entries.forEach((url, value) {
        if (value is bool) _cache[url] = value;
      });
      _log.info('Loaded downloadable-probe cache with ${_cache.length} entries');
    } catch (e) {
      _log.warning('Failed to load downloadable-probe cache: $e');
    }
  }

  /// Saves the cache to disk.
  Future<void> saveCache() async {
    final json = const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': _schemaVersion,
      'entries': _cache,
    });
    final file = File(p.join(_dataPath, _cacheFilename));
    await file.writeAsString(json);
    _log.info('Saved downloadable-probe cache with ${_cache.length} entries');
  }
}
