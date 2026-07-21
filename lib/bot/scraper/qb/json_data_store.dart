import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:synchronized/synchronized.dart';

import '../download_link_detector.dart';
import 'models/mod_detail.dart';
import 'models/mod_summary.dart';

class JsonDataStore {
  /// How many topics may finish between index writes. The index is what tells
  /// the next run "I already have this topic", so an index left unwritten until
  /// the end of a run orphans every detail file the run saved: they sit on disk
  /// but nothing points at them, and the next run scrapes them all again.
  /// Writing as we go keeps an interrupted run's work; batching keeps the cost
  /// of rewriting the whole file down.
  static const int _indexFlushEvery = 10;

  final String basePath;
  final Logger _log;
  List<QbModSummary>? _indexCache;
  String? _lastSavedIndexJson;

  /// Topics finished since the index was last written.
  int _indexDirtySinceFlush = 0;

  /// Topics are scraped with some overlap, so two saves can land at once.
  final Lock _indexWriteLock = Lock();

  JsonDataStore(this.basePath, {Logger? logger})
      : _log = logger ?? Logger('JsonDataStore') {
    Directory(basePath).createSync(recursive: true);
  }

  // --- Mods Index ---

  Future<List<QbModSummary>> loadIndex() async {
    if (_indexCache != null) return _indexCache!;

    final path = p.join(basePath, 'mods-index.json');
    final file = File(path);
    if (!file.existsSync()) return [];

    final json = await file.readAsString();
    _lastSavedIndexJson = json;
    final list = jsonDecode(json) as List<dynamic>;
    _indexCache =
        list.map((e) => QbModSummaryMapper.fromMap(e as Map<String, dynamic>)).toList();
    return _indexCache!;
  }

  Future<void> saveIndex(List<QbModSummary> mods) async {
    await _indexWriteLock.synchronized(() async {
      final path = p.join(basePath, 'mods-index.json');
      final json = const JsonEncoder.withIndent('  ')
          .convert(mods.map((m) => m.toMap()).toList());
      _indexCache = mods;
      _indexDirtySinceFlush = 0;
      if (json == _lastSavedIndexJson) {
        _log.info('Mods index unchanged; skipping write (${mods.length} entries)');
        return;
      }
      await File(path).writeAsString(json);
      _lastSavedIndexJson = json;
      _log.info('Saved mods index with ${mods.length} entries');
    });
  }

  /// Saves the index once [_indexFlushEvery] topics have finished since the
  /// last write. Call this as topics are scraped; a run that dies partway then
  /// still leaves an index that names the detail files it wrote.
  Future<void> saveIndexIfDue(List<QbModSummary> mods) async {
    if (++_indexDirtySinceFlush < _indexFlushEvery) return;
    await saveIndex(mods);
  }

  // --- Mod Detail ---

  Future<QbModDetail?> loadDetail(int topicId) async {
    final path = p.join(basePath, 'mods', topicId.toString(), 'detail.json');
    final file = File(path);
    if (!file.existsSync()) return null;

    final json = await file.readAsString();
    final detail = QbModDetailMapper.fromMap(
        jsonDecode(json) as Map<String, dynamic>);
    return _backfillDownloadableFlags(detail);
  }

  /// Lets cached detail files written before `isDownloadable` existed surface
  /// obvious download links without a re-scrape. Strictly additive — `true`
  /// values are never downgraded.
  static QbModDetail _backfillDownloadableFlags(QbModDetail detail) {
    bool needsUpgrade(LinkRef l) =>
        !l.isDownloadable && isLikelyModDownloadUrl(l.url);
    if (!detail.links.any(needsUpgrade)) return detail;
    return detail.copyWith(links: [
      for (final l in detail.links)
        needsUpgrade(l) ? l.copyWith(isDownloadable: true) : l,
    ]);
  }

  Future<void> saveDetail(QbModDetail detail) async {
    final dir = p.join(basePath, 'mods', detail.topicId.toString());
    Directory(dir).createSync(recursive: true);

    final path = p.join(dir, 'detail.json');
    final json = const JsonEncoder.withIndent('  ')
        .convert(detail.toMap());
    await File(path).writeAsString(json);
    _log.fine('Saved detail for topic ${detail.topicId}');
  }

  // --- Thumbnail ---

  String? pickThumbnail(int topicId, List<ImageRef> images) {
    for (final img in images) {
      final url = img.originalUrl;
      if (url.toLowerCase().contains('shields.io')) continue;
      if (url.toLowerCase().contains('loading.gif')) continue;
      return 'ext:$url';
    }
    return null;
  }
}
