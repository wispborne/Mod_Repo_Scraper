import 'package:dart_mappable/dart_mappable.dart';

import 'post_extraction.dart';

part 'mod_summary.mapper.dart';

/// One line of the forum's mod index that links to a topic: the name the index
/// gives the mod, who it credits, the game version in its brackets, and the
/// heading it sits under. A topic can be linked from several lines.
@MappableClass(ignoreNull: true)
class QbIndexLine with QbIndexLineMappable {
  final String name;
  final String author;
  final String? gameVersion;
  final String category;

  const QbIndexLine({
    required this.name,
    this.author = '',
    this.gameVersion,
    this.category = 'uncategorized',
  });
}

@MappableClass(ignoreNull: true)
class QbModSummary with QbModSummaryMappable {
  final int topicId;
  final String title;
  final String category;
  final bool inModIndex;
  final bool isArchivedModIndex;
  final String? gameVersion;
  final String author;
  final int replies;
  final int views;
  final String? createdDate;
  final String? lastPostDate;
  final String? lastPostBy;
  final String topicUrl;
  final String? thumbnailPath;
  final DateTime scrapedAt;
  final bool isWip;
  final int? sourceBoard;

  /// Every mod index line that links to this topic, in the order the index
  /// lists them. Read from today's index when it lists the topic, otherwise
  /// from the older index posts. Null when the index does not list it, so a
  /// topic outside the index is written exactly as it was before this existed.
  final List<QbIndexLine>? indexLines;

  /// The LLM's output for this thread: a list of the mods it found, each with
  /// its own downloads and extras. Missing when the LLM feature is off or it
  /// found nothing. When present, it is the full answer for this thread's mods
  /// and downloads; when missing, use the rules-based `assumedDownloads`.
  final LlmThreadData? llm;

  QbModSummary({
    required this.topicId,
    this.title = '',
    this.category = 'uncategorized',
    this.inModIndex = false,
    this.isArchivedModIndex = false,
    this.gameVersion,
    this.author = '',
    this.replies = 0,
    this.views = 0,
    this.createdDate,
    this.lastPostDate,
    this.lastPostBy,
    this.topicUrl = '',
    this.thumbnailPath,
    DateTime? scrapedAt,
    this.isWip = false,
    this.sourceBoard,
    this.indexLines,
    this.llm,
  }) : scrapedAt = scrapedAt ?? DateTime.now().toUtc();
}
