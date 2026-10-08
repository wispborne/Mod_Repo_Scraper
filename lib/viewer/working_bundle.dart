import 'dart:io';

import 'package:path/path.dart' as p;

import '../bot/scraper/qb/html_processor.dart';
import '../bot/scraper/qb/mod_thread_filter.dart';
import '../bot/scraper/qb/models/assumed_download.dart';
import '../bot/scraper/qb/models/mod_detail.dart';
import '../bot/scraper/qb/models/mod_summary.dart';
import '../manager/bundle_snapshot_store.dart';
import 'data_access.dart';

/// Builds working data in snapshot form for comparisons during a run.
///
/// Scraped data and LLM results are saved incrementally; the published bundle
/// is written at the end. Comparing working data with a snapshot shows changes
/// saved so far.
///
/// Post text is replaced with snapshot fingerprints. This result must never be
/// published or served as a bundle.
///
/// Uses the publisher's [keepThreadInBundle] filter to avoid false additions
/// and removals during a run.
class WorkingBundle {
  final DataAccess data;

  WorkingBundle(this.data);

  /// Trimmed details cached by file stamp; unchanged files are not re-read.
  final Map<int, _HeldDetail> _details = {};

  /// The last answer, and what the working data looked like when it was built.
  Map<String, dynamic>? _built;
  String? _builtStamp;

  /// When any of the files the working data lives in was last written.
  DateTime? _lastWrittenAt;

  /// The working bundle, or null when there is no mods index to build one from.
  ///
  /// Rebuilt when file sizes or modification times change; only changed
  /// detail files are re-read.
  Map<String, dynamic>? get bundle {
    final index = data.index;
    if (index == null) return null;

    final stamps = _detailStamps();
    final stamp = _stampOf(stamps);
    if (_built != null && _builtStamp == stamp) return _built;

    _built = _build(index, stamps);
    _builtStamp = stamp;
    return _built;
  }

  /// Newest write time across working files, including LLM and download caches.
  /// Scrape times alone would miss extraction-only changes. Null until [bundle]
  /// is first read.
  DateTime? get lastWrittenAt => _lastWrittenAt;

  /// The newest scrape time in the index — what a published bundle carries as
  /// its own `updatedAt`, mirrored here so the two are built alike.
  DateTime? get scrapedUpTo {
    final index = data.index;
    if (index == null || index.isEmpty) return null;
    return index.map((s) => s.scrapedAt).reduce((a, b) => a.isAfter(b) ? a : b);
  }

  Map<String, dynamic> _build(
      List<QbModSummary> index, Map<int, String> stamps) {
    final llm = data.llmCache ?? const {};

    // Match publication: filter using isMod and attach LLM mods to the index.
    final sorted = index.toList()
      ..sort((a, b) => a.topicId.compareTo(b.topicId));
    final kept = <QbModSummary>[];
    for (final summary in sorted) {
      final entry = llm[summary.topicId];
      if (!keepThreadInBundle(title: summary.title, llmSaidMod: entry?.isMod)) {
        continue;
      }
      final thread = entry?.toThreadData();
      kept.add(thread == null || thread.isEmpty
          ? summary.copyWith(llm: null)
          : summary.copyWith(llm: thread));
    }
    final keptIds = {for (final s in kept) s.topicId};

    final details = <String, dynamic>{};
    for (final summary in kept) {
      final held = _detailFor(summary.topicId, stamps[summary.topicId]);
      if (held != null) details['${summary.topicId}'] = held;
    }

    final downloads = <String, dynamic>{};
    for (final entry in (data.assumedDownloads ?? const {}).entries) {
      if (!keptIds.contains(entry.key)) continue;
      final candidates = [
        for (final candidate in entry.value)
          AssumedDownloadCandidate.fromDownloadCandidate(candidate).toMap(),
      ];
      if (candidates.isEmpty) continue;
      downloads['${entry.key}'] = candidates;
    }

    return {
      'updatedAt': (scrapedUpTo ?? DateTime.now().toUtc()).toIso8601String(),
      'index': [for (final s in kept) s.toMap()],
      'details': details,
      'assumedDownloads': downloads,
    };
  }

  /// One topic's detail, trimmed the way a snapshot trims it: no post text, a
  /// fingerprint of it instead, and no local image paths. Re-read only when the
  /// file on disk has moved.
  Map<String, dynamic>? _detailFor(int topicId, String? stamp) {
    if (stamp == null) return null;
    final held = _details[topicId];
    if (held != null && held.stamp == stamp) return held.detail;

    final detail = _readDetail(topicId);
    if (detail == null) return null;
    _details[topicId] = _HeldDetail(stamp, detail);
    return detail;
  }

  Map<String, dynamic>? _readDetail(int topicId) {
    final QbModDetail? detail;
    try {
      detail = data.loadDetail(topicId);
    } catch (_) {
      // A file may be half-written during a run. Leave it uncached for retry.
      return null;
    }
    if (detail == null) return null;

    // Apply publication's HTML cleanup before fingerprinting to avoid false
    // text changes; local image paths are also excluded from snapshots.
    final html = HtmlProcessor.stripSessionIds(detail.contentHtml);
    final map = detail.copyWith(
      contentHtml: html,
      images: [
        for (final image in detail.images)
          ImageRef(
              originalUrl: image.originalUrl, localPath: '', alt: image.alt),
      ],
      extraPosts: [
        for (final post in detail.extraPosts)
          QbForumPost(
            contentHtml: HtmlProcessor.stripSessionIds(post.contentHtml),
            images: [
              for (final image in post.images)
                ImageRef(
                    originalUrl: image.originalUrl,
                    localPath: '',
                    alt: image.alt),
            ],
            links: post.links,
            postDate: post.postDate,
            lastEditDate: post.lastEditDate,
          ),
      ],
    ).toMap();
    map.remove('contentHtml');
    map[BundleSnapshotStore.fingerprintKey] =
        BundleSnapshotStore.fingerprintOf(html);
    // Follow-up posts must use the same fingerprint format as saved snapshots.
    map['extraPosts'] = BundleSnapshotStore.postsWithoutText(map['extraPosts']);
    return map;
  }

  /// Collects detail file stamps and the newest write time across working files.
  Map<int, String> _detailStamps() {
    _lastWrittenAt = null;
    for (final name in _dataFileNames) {
      _noteWrite(File(p.join(data.dataDir, name)));
    }

    final folder = Directory(p.join(data.dataDir, 'mods'));
    if (!folder.existsSync()) return const {};

    final stamps = <int, String>{};
    for (final entry in folder.listSync(followLinks: false)) {
      final topicId = int.tryParse(p.basename(entry.path));
      if (topicId == null) continue;
      final file = File(p.join(entry.path, 'detail.json'));
      final stamp = _fileStamp(file.path);
      if (stamp == null) continue;
      stamps[topicId] = stamp;
      _noteWrite(file);
    }
    return stamps;
  }

  void _noteWrite(File file) {
    final stat = file.statSync();
    if (stat.type == FileSystemEntityType.notFound) return;
    final at = stat.modified.toUtc();
    if (_lastWrittenAt == null || at.isAfter(_lastWrittenAt!)) {
      _lastWrittenAt = at;
    }
  }

  static const List<String> _dataFileNames = [
    'mods-index.json',
    'llm-extraction-cache.json',
    'assumed-downloads-cache.json',
  ];

  /// Cache stamp covering detail files, the index, LLM results and downloads.
  String _stampOf(Map<int, String> details) {
    final keys = details.keys.toList()..sort();
    final parts = <String>[
      for (final key in keys) '$key=${details[key]}',
      for (final name in _dataFileNames)
        '$name=${_fileStamp(p.join(data.dataDir, name)) ?? '-'}',
    ];
    return BundleSnapshotStore.fingerprintOf(parts.join('|')) ?? '-';
  }

  /// A file's last-modified time and size, or null when it isn't there.
  String? _fileStamp(String path) {
    final stat = File(path).statSync();
    if (stat.type == FileSystemEntityType.notFound) return null;
    return '${stat.modified.microsecondsSinceEpoch}:${stat.size}';
  }
}

class _HeldDetail {
  final String stamp;
  final Map<String, dynamic> detail;

  _HeldDetail(this.stamp, this.detail);
}
