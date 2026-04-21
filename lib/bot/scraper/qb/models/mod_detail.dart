import 'package:dart_mappable/dart_mappable.dart';

part 'mod_detail.mapper.dart';

@MappableClass(ignoreNull: true)
class QbModDetail with QbModDetailMappable {
  final int topicId;
  final String title;
  final String? category;
  final String? gameVersion;
  final String author;
  final String? authorTitle;
  final int authorPostCount;
  final String? authorAvatarPath;
  final String? postDate;
  final String? lastEditDate;
  final String contentHtml;
  final List<ImageRef> images;
  final List<LinkRef> links;
  final DateTime scrapedAt;
  final bool isPlaceholderDetail;

  QbModDetail({
    required this.topicId,
    this.title = '',
    this.category,
    this.gameVersion,
    this.author = '',
    this.authorTitle,
    this.authorPostCount = 0,
    this.authorAvatarPath,
    this.postDate,
    this.lastEditDate,
    this.contentHtml = '',
    this.images = const [],
    this.links = const [],
    DateTime? scrapedAt,
    this.isPlaceholderDetail = false,
  }) : scrapedAt = scrapedAt ?? DateTime.now().toUtc();
}

@MappableClass(ignoreNull: true)
class ImageRef with ImageRefMappable {
  final String originalUrl;
  final String localPath;
  final String? alt;

  ImageRef({
    this.originalUrl = '',
    this.localPath = '',
    this.alt,
  });
}

@MappableClass(ignoreNull: true)
class LinkRef with LinkRefMappable {
  final String url;
  final String text;
  final bool isExternal;
  final bool isDownloadable;

  LinkRef({
    this.url = '',
    this.text = '',
    this.isExternal = false,
    this.isDownloadable = false,
  });
}
