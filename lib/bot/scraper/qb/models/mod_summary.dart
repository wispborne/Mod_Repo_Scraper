import 'package:dart_mappable/dart_mappable.dart';

import 'post_extraction.dart';

part 'mod_summary.mapper.dart';

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
    this.llm,
  }) : scrapedAt = scrapedAt ?? DateTime.now().toUtc();
}
