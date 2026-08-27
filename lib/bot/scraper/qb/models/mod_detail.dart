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

  /// The rest of the author's opening run: the posts directly after the first
  /// one that are by the same person. Some authors keep the thread's downloads
  /// in a second post of their own, so these are read for downloads and facts
  /// the same way the first post is. The first post is not in here — it stays
  /// in the fields above, which is what every reader of a detail already uses.
  final List<QbForumPost> extraPosts;

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
    this.extraPosts = const [],
    DateTime? scrapedAt,
    this.isPlaceholderDetail = false,
  }) : scrapedAt = scrapedAt ?? DateTime.now().toUtc();

  /// The first post and the author's follow-ups, in the order they were
  /// posted. Anything hunting for a download, a name or a fact reads this
  /// rather than [contentHtml] alone.
  List<QbForumPost> get openingPosts => [
        QbForumPost(
          contentHtml: contentHtml,
          images: images,
          links: links,
          postDate: postDate,
          lastEditDate: lastEditDate,
        ),
        ...extraPosts,
      ];

  /// Every link in the author's opening run, first post first, with the same
  /// URL kept only once.
  List<LinkRef> get allLinks {
    final seen = <String>{};
    return [
      for (final post in openingPosts)
        for (final link in post.links)
          if (seen.add(link.url.trim().toLowerCase())) link,
    ];
  }

  /// Every image in the author's opening run, first post first, with the same
  /// URL kept only once.
  List<ImageRef> get allImages {
    final seen = <String>{};
    return [
      for (final post in openingPosts)
        for (final image in post.images)
          if (seen.add(image.originalUrl.trim().toLowerCase())) image,
    ];
  }
}

/// One post by the thread's author, after the first one.
@MappableClass(ignoreNull: true)
class QbForumPost with QbForumPostMappable {
  final String contentHtml;
  final List<ImageRef> images;
  final List<LinkRef> links;
  final String? postDate;
  final String? lastEditDate;

  QbForumPost({
    this.contentHtml = '',
    this.images = const [],
    this.links = const [],
    this.postDate,
    this.lastEditDate,
  });
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
