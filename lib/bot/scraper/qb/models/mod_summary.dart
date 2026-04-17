import 'package:dart_mappable/dart_mappable.dart';

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
  }) : scrapedAt = scrapedAt ?? DateTime.now().toUtc();
}
