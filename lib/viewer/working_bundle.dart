import 'dart:io';

import 'package:path/path.dart' as p;

import '../bot/scraper/qb/html_processor.dart';
import '../bot/scraper/qb/mod_thread_filter.dart';
import '../bot/scraper/qb/models/assumed_download.dart';
import '../bot/scraper/qb/models/mod_detail.dart';
import '../bot/scraper/qb/models/mod_summary.dart';
import '../manager/bundle_snapshot_store.dart';
import 'data_access.dart';

/// The bundle as it would be published **right now**, built from the working
/// data on disk, in the same shape a saved snapshot has.
///
/// This is what makes a run watchable while it is still going. Everything that
/// costs money or network time is saved as the run goes — the mods index every
/// ten topics, each topic's detail as it is scraped, the LLM answers every five
/// — but the bundle itself is only published at the end. So the working data
/// runs ahead of the last published bundle, and the difference between the two
/// is what the run has done so far.
///
/// It is built to be compared against a saved snapshot and nothing else: the
/// post text is replaced by the same short fingerprint a snapshot keeps, so a
/// changed post reads as changed rather than as a post that appeared out of
/// nowhere. **Nothing here may be published or served as a bundle** — the same
/// rule a snapshot lives under, and for the same reason.
///
/// Which threads make it in is decided by [keepThreadInBundle], the same
/// function the real publisher calls. A rule copied instead of shared would
/// show a thread as added or removed for as long as a run lasted.
class WorkingBundle {
  final DataAccess data;

  WorkingBundle(this.data);

  /// One topic's trimmed detail, and the file stamp it was read at. A detail
  /// file only changes when its thread is re-scraped, so during a run all but a
  /// handful of these are still good.
  final Map<int, _HeldDetail> _details = {};

  /// The last answer, and what the working data looked like when it was built.
  Map<String, dynamic>? _built;
  String? _builtStamp;

  /// When any of the files the working data lives in was last written.
  DateTime? _lastWrittenAt;

  /// The working bundle, or null when there is no mods index to build one from.
  ///
  /// Held until something on disk moves. Working that out means asking every
  /// detail file for its size and last-modified time, which is quick; reading
  /// one back is only done for the files that actually changed.
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

  /// When any of this was last written to disk.
  ///
  /// Not the newest scrape time: an LLM pass changes what a run has produced
  /// without re-scraping a thing, so a page that read the scrape times would
  /// say the data was a week old while it was changing under the reader. Every
  /// file the working data lives in counts, and the newest of them wins. Null
  /// until [bundle] has been asked for once, since that is what looks.
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

    // The LLM's answer for a thread comes off its cache, exactly as the
    // publisher does it: the mods list is attached to the index item, and the
    // mod/not-mod call decides whether the thread is kept at all.
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
      // A detail file caught half-written mid-run is normal. The topic keeps
      // whatever the last good read gave and the next look picks it up.
      return null;
    }
    if (detail == null) return null;

    // The published bundle drops local image paths and the forum's session
    // token, and a snapshot's fingerprint is taken from the post text after
    // that stripping — so it has to happen here too, or every topic would read
    // as "the post text changed".
    final html = HtmlProcessor.stripSessionIds(detail.contentHtml);
    final map = detail
        .copyWith(
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
        )
        .toMap();
    map.remove('contentHtml');
    map[BundleSnapshotStore.fingerprintKey] =
        BundleSnapshotStore.fingerprintOf(html);
    // The author's later posts lose their text the same way, so this side and a
    // saved snapshot are the same shape and can be compared field for field.
    map['extraPosts'] = BundleSnapshotStore.postsWithoutText(map['extraPosts']);
    return map;
  }

  /// Every detail file's size and last-modified time, keyed by topic. Asking
  /// the filesystem is much cheaper than reading a thousand files back.
  ///
  /// It also notes the newest write time it saw, here and in the three files
  /// below, since it is already asking every one of them.
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

  /// The three files the index, the LLM answers and the rule-based downloads
  /// live in. Everything else is one file per topic under `mods/`.
  static const List<String> _dataFileNames = [
    'mods-index.json',
    'llm-extraction-cache.json',
    'assumed-downloads-cache.json',
  ];

  /// One short string standing for the whole state of the working data: every
  /// detail file, plus the three files the index, the LLM answers and the
  /// rule-based downloads live in.
  String _stampOf(Map<int, String> details) {
    final keys = details.keys.toList()..sort();
    final parts = <String>[
      for (final key in keys) '$key=${details[key]}',
      for (final name in _dataFileNames)
        '$name=${_fileStamp(p.join(data.dataDir, name)) ?? '-'}',
    ];
    // Only ever compared with itself, to answer "has any of this moved?".
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
