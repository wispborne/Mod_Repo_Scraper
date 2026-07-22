import 'dart:io' as io;

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:logging/logging.dart';

import 'board_scraper.dart';
import 'download_resolver.dart';
import 'downloadable_probe_cache.dart';
import 'forum_constants.dart';
import 'html_processor.dart';
import 'json_data_store.dart';
import 'mod_index_scraper.dart';
import 'models/mod_detail.dart';
import 'models/mod_summary.dart';
import 'models/scrape_job.dart';
import 'throttled_client.dart';
import 'topic_scraper.dart';

class QbScraperEngine {
  final Logger _log;
  final JsonDataStore _store;
  final ThrottledClient _client;
  final http.Client _downloadClient;
  final QbDownloadResolver downloadResolver;
  final DownloadableProbeCache probeCache;
  final ScrapeJob currentJob = ScrapeJob();

  /// Optional progress reporter, invoked whenever a topic finishes (or fails).
  /// Set for the duration of [run].
  void Function(int processed, int total, String? item)? _onProgress;

  /// [probeCache] and [downloadResolver] can be passed in when the caller keeps
  /// them across several jobs (the manager does, so the answers loaded once are
  /// reused). Left out, the engine makes its own, which is what a one-shot run
  /// wants.
  factory QbScraperEngine({
    required JsonDataStore store,
    required ThrottledClient client,
    Logger? logger,
    DownloadableProbeCache? probeCache,
    QbDownloadResolver? downloadResolver,
  }) {
    final downloadClient = IOClient(
      io.HttpClient()..connectionTimeout = const Duration(seconds: 30),
    );
    // Build the "does this link lead to a file?" cache once and share it, so the
    // scrape step and the resolver reuse each other's answers.
    final sharedProbeCache =
        probeCache ?? DownloadableProbeCache(dataPath: store.basePath);
    return QbScraperEngine._(
      store: store,
      client: client,
      downloadClient: downloadClient,
      probeCache: sharedProbeCache,
      downloadResolver: downloadResolver ??
          QbDownloadResolver(
            client: downloadClient,
            dataPath: store.basePath,
            probeCache: sharedProbeCache,
          ),
      logger: logger,
    );
  }

  QbScraperEngine._({
    required JsonDataStore store,
    required ThrottledClient client,
    required http.Client downloadClient,
    required DownloadableProbeCache probeCache,
    required QbDownloadResolver downloadResolver,
    Logger? logger,
  })  : _store = store,
        _client = client,
        _downloadClient = downloadClient,
        probeCache = probeCache,
        downloadResolver = downloadResolver,
        _log = logger ?? Logger('QbScraperEngine');

  /// [shouldStop] is checked before each topic. Returning true ends the scrape
  /// tidily: the topics already done stay saved and the index still names them.
  Future<ScrapeResult> run(
    ScrapeScope scope, {
    Future<void> Function(QbModDetail detail)? onTopicSaved,
    void Function(int processed, int total, String? item)? onProgress,
    bool Function()? shouldStop,
  }) async {
    _onProgress = onProgress;
    final startTime = DateTime.now().toUtc();
    currentJob.state = ScrapeState.scraping;
    currentJob.startedAt = startTime;
    currentJob.errorMessage = null;
    currentJob.currentPhase = 'Initializing';

    // Declared out here so the failure path below can still save what the
    // index learned before the scrape broke.
    final indexMap = <int, QbModSummary>{};

    try {
      _log.info('Starting scrape job with scope ${scope.type}');

      final boardScraper = QbBoardScraper(_client, logger: _log);
      final topicScraper = QbTopicScraper(
        _client,
        logger: _log,
        externalClient: _downloadClient,
        probeCache: probeCache,
      );
      final modIndexScraper = QbModIndexScraper(_client, logger: _log);

      final existingIndex = await _store.loadIndex();
      indexMap.addEntries(existingIndex.map((m) => MapEntry(m.topicId, m)));
      final preScrapeSnapshot = <int, _MeaningfulSnapshot>{
        for (final m in existingIndex)
          m.topicId: _snapshotMeaningfulFields(m)
      };
      final meaningfullyChangedIds = <int>[];

      // --- Mod Index ---
      currentJob.currentPhase = 'Mod index (topic 177)';
      final modIndex = await modIndexScraper.scrape();
      for (final topicId in indexMap.keys.toList()) {
        indexMap[topicId] =
            _applyCategoryFromModIndex(indexMap[topicId]!, modIndex);
      }

      if (modIndex.unknownLegacyCategories.isNotEmpty) {
        final deduped = modIndex.unknownLegacyCategories
            .map((s) => s.toLowerCase())
            .toSet()
            .toList()
          ..sort();
        // QbModIndexScraper.scrape() already logged the warning; just surface
        // it on the job status.
        currentJob.errorMessage =
            'Unmapped legacy categories (update lib/bot/scraper/qb/legacy_category_map.dart): ${deduped.join(', ')}';
      }

      // --- Board Scraping ---
      List<QbModSummary> modSummaries;
      final mainTopicIds = <int>{};
      final lesserTopicIds = <int>{};
      final libraryTopicIds = <int>{};

      if (scope.type == ScopeType.topics &&
          scope.topicIds != null &&
          scope.topicIds!.isNotEmpty) {
        modSummaries = scope.topicIds!
            .map((id) => QbModSummary(
                  topicId: id,
                  topicUrl: ForumConstants.topicUrl(id),
                ))
            .toList();
        _log.info('Scraping ${modSummaries.length} specific topics');
      } else if (scope.type == ScopeType.librariesOnly) {
        _log.info('Scraping library board (board 9) only');
        currentJob.currentPhase = 'Library board (board 9)';
        modSummaries = await boardScraper.scrapeAllPages(
          sortByLastPostDesc: true,
          boardBaseUrl: ForumConstants.libraryBoardUrl,
          topicTitleFilter: ForumConstants.isLibraryThreadTitle,
        );
        for (var i = 0; i < modSummaries.length; i++) {
          final m = modSummaries[i];
          libraryTopicIds.add(m.topicId);
          modSummaries[i] = m.copyWith(sourceBoard: 9);
        }
      } else {
        final isPages = scope.type == ScopeType.pages;
        final isNewData = scope.type == ScopeType.newData;

        var mainList = <QbModSummary>[];
        var lesserList = <QbModSummary>[];
        var libraryList = <QbModSummary>[];

        if (scope.boards.contains(ScrapeBoard.main)) {
          bool Function(List<QbModSummary>)? shouldContinueMain;
          if (isNewData) {
            shouldContinueMain = (pageMods) =>
                pageMods.any((m) => _isNewOrLastPostChanged(m, indexMap));
          }

          final maxPagesMain = isPages ? scope.maxPagesMain : null;
          currentJob.currentPhase = 'Mods board (8)';
          mainList = await boardScraper.scrapeAllPages(
            maxPages: maxPagesMain,
            shouldContinueAfterPage: shouldContinueMain,
            sortByLastPostDesc: isNewData,
          );
          mainList = mainList.map((m) {
            mainTopicIds.add(m.topicId);
            return m.copyWith(
              sourceBoard: 8,
              isWip: ForumConstants.isWipTitle(m.title),
            );
          }).toList();
        }

        if (scope.boards.contains(ScrapeBoard.lesser)) {
          final lesserMax = _min(
            scope.maxPagesLesser ?? ForumConstants.lesserBoardMaxPages,
            ForumConstants.lesserBoardMaxPages,
          );

          bool Function(List<QbModSummary>)? shouldContinueLesser;
          if (isNewData) {
            shouldContinueLesser = (pageMods) =>
                pageMods.any((m) => _isNewOrLastPostChanged(m, indexMap));
          }

          currentJob.currentPhase = 'Lesser mods board (3)';
          _log.info('Scraping lesser mods board (board 3), max $lesserMax pages');
          lesserList = await boardScraper.scrapeAllPages(
            maxPages: lesserMax,
            shouldContinueAfterPage: shouldContinueLesser,
            sortByLastPostDesc: isNewData,
            boardBaseUrl: ForumConstants.lesserBoardUrl,
            topicTitleFilter: ForumConstants.isLesserBoardTopicTitle,
          );
          lesserList = lesserList.map((m) {
            lesserTopicIds.add(m.topicId);
            return m.copyWith(
              sourceBoard: 3,
              isWip: ForumConstants.isWipTitle(m.title),
            );
          }).toList();
        }

        if (scope.boards.contains(ScrapeBoard.libraries)) {
          bool Function(List<QbModSummary>)? shouldContinueLibrary;
          if (isNewData) {
            shouldContinueLibrary = (pageMods) {
              final matching = pageMods
                  .where((m) => ForumConstants.isLibraryThreadTitle(m.title))
                  .toList();
              if (matching.isEmpty) return true;
              return matching
                  .any((m) => _isNewOrLastPostChanged(m, indexMap));
            };
          }

          final maxPagesLibraries = isPages ? scope.maxPagesLibraries : null;
          _log.info('Scraping library board (board 9)');
          currentJob.currentPhase = 'Library board (9)';
          libraryList = await boardScraper.scrapeAllPages(
            maxPages: maxPagesLibraries,
            shouldContinueAfterPage: shouldContinueLibrary,
            sortByLastPostDesc: true,
            boardBaseUrl: ForumConstants.libraryBoardUrl,
            topicTitleFilter: ForumConstants.isLibraryThreadTitle,
          );
          libraryList = libraryList.map((m) {
            libraryTopicIds.add(m.topicId);
            return m.copyWith(sourceBoard: 9);
          }).toList();
        }

        modSummaries = _mergeDedupeBoards(mainList, lesserList, libraryList);

        if (isNewData) {
          modSummaries =
              _applyIncrementalFilter(modSummaries, indexMap);
        }
      }

      currentJob.totalTopics = modSummaries.length;
      _log.info('Found ${modSummaries.length} topics to scrape');
      currentJob.currentPhase = null;
      _reportProgress();

      // --- Topic Scraping (pipelined) ---
      // ThrottledClient serializes network calls; this buffer only overlaps
      // in-memory work (parse, regex, disk write) with the next request's wait.
      const maxPending = 3;
      final pending = <Future<void>>{};

      Future<void> track(Future<void> f) {
        late Future<void> wrapped;
        wrapped = f.whenComplete(() => pending.remove(wrapped));
        pending.add(wrapped);
        return wrapped;
      }

      for (var i = 0; i < modSummaries.length; i++) {
        if (shouldStop?.call() ?? false) {
          _log.info('Stopping the scrape on request after '
              '${currentJob.processedTopics} topic(s).');
          break;
        }

        var summary = modSummaries[i];
        summary = _applyCategoryFromModIndex(summary, modIndex);

        if (libraryTopicIds.contains(summary.topicId) &&
            !mainTopicIds.contains(summary.topicId)) {
          summary = summary.copyWith(category: ForumConstants.libraryCategory);
        }

        if (!summary.inModIndex) {
          summary = summary.copyWith(
            category: ForumConstants.guessCategoryFromTitle(summary.title),
          );
        }

        currentJob.currentItem = summary.title.isNotEmpty
            ? summary.title
            : 'Topic ${summary.topicId}';
        _log.info(
            'Scraping topic ${summary.topicId}: ${currentJob.currentItem}');

        try {
          final detail = await topicScraper.scrapeTopic(summary.topicId);

          track(_processTopicDetail(
            detail: detail,
            summary: summary,
            indexMap: indexMap,
            preScrapeSnapshot: preScrapeSnapshot,
            meaningfullyChangedIds: meaningfullyChangedIds,
            onTopicSaved: onTopicSaved,
          ));
        } catch (e) {
          _log.warning(
              'Failed to process topic ${summary.topicId}: $e');
          currentJob.errors++;
          currentJob.processedTopics++;
          _reportProgress();
        }

        if (pending.length >= maxPending) {
          await Future.any(pending);
        }
      }

      // Drain remaining futures.
      while (pending.isNotEmpty) {
        try {
          await Future.any(pending);
        } catch (e) {
          _log.warning('Pending topic future failed: $e');
          currentJob.errors++;
        }
      }

      // Save final index
      await _store.saveIndex(_sortedIndex(indexMap));

      _logMeaningfulChanges(meaningfullyChangedIds, modSummaries.length);

      currentJob.state = ScrapeState.completed;
      currentJob.finishedAt = DateTime.now().toUtc();

      final result = _buildResult(true, startTime);
      _log.info(
          'Scrape completed: ${result.modsScraped} mods, ${result.errors} errors, '
          'wall-clock ${result.duration.inSeconds}s');
      return result;
    } catch (e) {
      currentJob.state = ScrapeState.failed;
      currentJob.finishedAt = DateTime.now().toUtc();
      currentJob.errorMessage = e.toString();
      _log.severe('Scrape job failed: $e');

      // The detail files for the topics done so far are already on disk. Save
      // the index that names them, or the next run won't know they exist and
      // will scrape them all over again.
      if (indexMap.isNotEmpty) {
        try {
          await _store.saveIndex(_sortedIndex(indexMap));
        } catch (saveError) {
          _log.warning('Failed to save index after scrape failure: $saveError');
        }
      }

      return _buildResult(false, startTime, errorMessage: e.toString());
    } finally {
      currentJob.currentPhase = null;
      _onProgress = null;
    }
  }

  void _reportProgress() {
    _onProgress?.call(
      currentJob.processedTopics,
      currentJob.totalTopics,
      currentJob.currentItem,
    );
  }

  Future<void> _processTopicDetail({
    required QbModDetail? detail,
    required QbModSummary summary,
    required Map<int, QbModSummary> indexMap,
    required Map<int, _MeaningfulSnapshot> preScrapeSnapshot,
    required List<int> meaningfullyChangedIds,
    required Future<void> Function(QbModDetail detail)? onTopicSaved,
  }) async {
    var s = summary;

    if (detail != null) {
      if (s.sourceBoard == 3 &&
          !ForumConstants.hasFileHostingLinks(detail.links)) {
        _log.info(
            'Board-3 topic ${s.topicId} has no qualifying external links; skipping.');
        currentJob.processedTopics++;
        _reportProgress();
        indexMap[s.topicId] = s;
        await _store.saveIndexIfDue(_sortedIndex(indexMap));
        return;
      }

      if (s.title.isEmpty) {
        s = s.copyWith(
          title: detail.title,
          gameVersion: detail.gameVersion,
          author: detail.author,
        );
      }
      s = s.copyWith(
        createdDate: detail.postDate,
        scrapedAt: DateTime.now().toUtc(),
      );

      final processedHtml = HtmlProcessor.processHtml(detail.contentHtml);
      final processedDetail = QbModDetail(
        topicId: detail.topicId,
        title: detail.title,
        category: detail.category,
        gameVersion: detail.gameVersion,
        author: detail.author,
        authorTitle: detail.authorTitle,
        authorPostCount: detail.authorPostCount,
        authorAvatarPath: detail.authorAvatarPath,
        postDate: detail.postDate,
        lastEditDate: detail.lastEditDate,
        contentHtml: processedHtml,
        images: detail.images,
        links: detail.links,
        scrapedAt: detail.scrapedAt,
        isPlaceholderDetail: detail.isPlaceholderDetail,
      );
      await _store.saveDetail(processedDetail);

      if (onTopicSaved != null) {
        await onTopicSaved(processedDetail);
      }

      s = s.copyWith(
        thumbnailPath: _store.pickThumbnail(detail.topicId, detail.images),
      );
    } else {
      currentJob.errors++;
    }

    indexMap[s.topicId] = s;
    final prevSnap = preScrapeSnapshot[s.topicId];
    if (prevSnap == null || _hasMeaningfulChanges(s, prevSnap)) {
      meaningfullyChangedIds.add(s.topicId);
    }
    currentJob.processedTopics++;
    _reportProgress();

    // The detail file for this topic is saved above. Keep the index that names
    // it roughly in step, so an interrupted run doesn't leave detail files that
    // nothing points at.
    await _store.saveIndexIfDue(_sortedIndex(indexMap));
  }

  /// The index in the order it is written to disk: newest scrape first.
  static List<QbModSummary> _sortedIndex(Map<int, QbModSummary> indexMap) =>
      indexMap.values.toList()
        ..sort((a, b) => b.scrapedAt.compareTo(a.scrapedAt));

  ScrapeResult _buildResult(bool success, DateTime startTime,
      {String? errorMessage}) {
    final end = currentJob.finishedAt ?? DateTime.now().toUtc();
    return ScrapeResult(
      success: success,
      modsScraped: currentJob.processedTopics,
      imagesDownloaded: currentJob.downloadedImages,
      errors: currentJob.errors,
      duration: end.difference(startTime),
      errorMessage: errorMessage,
    );
  }

  static QbModSummary _applyCategoryFromModIndex(
      QbModSummary summary, ModIndexCategoriesResult categories) {
    final main = categories.mainTopicCategoryMap[summary.topicId];
    if (main != null) {
      return summary.copyWith(
        category: main,
        inModIndex: true,
        isArchivedModIndex: false,
      );
    }
    final archived = categories.archivedTopicCategoryMap[summary.topicId];
    if (archived != null) {
      return summary.copyWith(
        category: archived,
        inModIndex: true,
        isArchivedModIndex: true,
      );
    }
    return summary.copyWith(
      category: ForumConstants.uncategorizedCategory,
      inModIndex: false,
      isArchivedModIndex: false,
    );
  }

  static _MeaningfulSnapshot _snapshotMeaningfulFields(QbModSummary s) =>
      _MeaningfulSnapshot(
        title: s.title,
        category: s.category,
        inModIndex: s.inModIndex,
        isArchivedModIndex: s.isArchivedModIndex,
        gameVersion: s.gameVersion,
        author: s.author,
        createdDate: s.createdDate,
        thumbnailPath: s.thumbnailPath,
        isWip: s.isWip,
        sourceBoard: s.sourceBoard,
      );

  static bool _hasMeaningfulChanges(
      QbModSummary s, _MeaningfulSnapshot old) =>
      s.title != old.title ||
      s.category != old.category ||
      s.inModIndex != old.inModIndex ||
      s.isArchivedModIndex != old.isArchivedModIndex ||
      s.gameVersion != old.gameVersion ||
      s.author != old.author ||
      s.createdDate != old.createdDate ||
      s.thumbnailPath != old.thumbnailPath ||
      s.isWip != old.isWip ||
      s.sourceBoard != old.sourceBoard;

  void _logMeaningfulChanges(List<int> changedIds, int totalScraped) {
    changedIds.sort();
    if (changedIds.isEmpty) {
      _log.info(
          'Meaningful changes: none among $totalScraped scraped topic(s)');
    } else {
      _log.info(
          'Meaningful changes in ${changedIds.length}/$totalScraped scraped topic(s) — IDs: $changedIds');
    }
  }

  static bool _isNewOrLastPostChanged(
      QbModSummary summary, Map<int, QbModSummary> indexMap) {
    final existing = indexMap[summary.topicId];
    if (existing == null) return true;
    return existing.lastPostDate != summary.lastPostDate;
  }

  static List<QbModSummary> _mergeDedupeBoards(
    List<QbModSummary> main,
    List<QbModSummary> lesser,
    List<QbModSummary> library,
  ) {
    final seen = <int>{};
    final result = <QbModSummary>[];
    for (final m in main) {
      if (seen.add(m.topicId)) result.add(m);
    }
    for (final m in lesser) {
      if (seen.add(m.topicId)) result.add(m);
    }
    for (final m in library) {
      if (seen.add(m.topicId)) result.add(m);
    }
    return result;
  }

  List<QbModSummary> _applyIncrementalFilter(
    List<QbModSummary> modSummaries,
    Map<int, QbModSummary> indexMap,
  ) {
    final filtered = <QbModSummary>[];
    for (final summary in modSummaries) {
      final existing = indexMap[summary.topicId];
      if (existing == null) {
        _log.info('Incremental: new topic ${summary.topicId}');
        filtered.add(summary);
        continue;
      }

      if (existing.lastPostDate != summary.lastPostDate) {
        _log.info(
            'Incremental: topic ${summary.topicId} changed '
            '(${existing.lastPostDate} -> ${summary.lastPostDate})');
        filtered.add(summary);
        continue;
      }

      _log.fine('Incremental: skipping unchanged topic ${summary.topicId}');
    }
    return filtered;
  }

  static int _min(int a, int b) => a < b ? a : b;
}

class _MeaningfulSnapshot {
  final String title;
  final String category;
  final bool inModIndex;
  final bool isArchivedModIndex;
  final String? gameVersion;
  final String author;
  final String? createdDate;
  final String? thumbnailPath;
  final bool isWip;
  final int? sourceBoard;

  _MeaningfulSnapshot({
    required this.title,
    required this.category,
    required this.inModIndex,
    required this.isArchivedModIndex,
    required this.gameVersion,
    required this.author,
    required this.createdDate,
    required this.thumbnailPath,
    required this.isWip,
    required this.sourceBoard,
  });
}
