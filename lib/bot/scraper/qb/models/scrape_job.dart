import 'package:dart_mappable/dart_mappable.dart';

part 'scrape_job.mapper.dart';

@MappableEnum()
enum ScrapeState { idle, scraping, completed, failed, cancelled }

@MappableEnum()
enum ScopeType { newData, all, pages, topics, librariesOnly }

@MappableEnum()
enum ScrapeBoard {
  main, // Board 8
  lesser, // Board 3
  libraries, // Board 9
}

@MappableClass()
class ScrapeScope with ScrapeScopeMappable {
  final ScopeType type;
  // Per-board page limits used when type == ScopeType.pages; null means scrape
  // all pages for that board. The lesser board is always additionally capped at
  // ForumConstants.lesserBoardMaxPages regardless of scope type.
  final int? maxPagesMain; // board 8
  final int? maxPagesLesser; // board 3
  final int? maxPagesLibraries; // board 9
  final List<int>? topicIds;
  final Set<ScrapeBoard> boards;

  ScrapeScope({
    this.type = ScopeType.all,
    this.maxPagesMain,
    this.maxPagesLesser,
    this.maxPagesLibraries,
    this.topicIds,
    Set<ScrapeBoard>? boards,
  }) : boards = boards ?? {ScrapeBoard.main, ScrapeBoard.libraries};
}

class ScrapeJob {
  ScrapeState state = ScrapeState.idle;
  final ScrapeScope scope;
  DateTime? startedAt;
  DateTime? finishedAt;
  int totalTopics = 0;
  int processedTopics = 0;
  int totalImages = 0;
  int downloadedImages = 0;
  int errors = 0;
  String? currentItem;
  String? currentPhase;
  String? errorMessage;

  ScrapeJob({ScrapeScope? scope}) : scope = scope ?? ScrapeScope();

  double get progressPercent {
    if (totalTopics == 0) return 0;
    return (processedTopics / totalTopics * 100).clamp(0, 100);
  }

  String? get duration {
    if (startedAt == null) return null;
    final end = finishedAt ?? DateTime.now().toUtc();
    final d = end.difference(startedAt!);
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inSeconds}s';
  }
}

@MappableClass()
class ScrapeResult with ScrapeResultMappable {
  final bool success;
  final int modsScraped;
  final int imagesDownloaded;
  final int errors;
  final Duration duration;
  final String? errorMessage;

  ScrapeResult({
    this.success = true,
    this.modsScraped = 0,
    this.imagesDownloaded = 0,
    this.errors = 0,
    this.duration = Duration.zero,
    this.errorMessage,
  });
}
