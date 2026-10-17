import 'package:dart_mappable/dart_mappable.dart';

import '../bot/scraper/qb/models/mod_detail.dart';

part 'source_post.mapper.dart';

/// Where a source post was published.
@MappableEnum()
enum SourceKind { forum, discord, nexus }

/// One thing a source published that might describe mods: a forum topic, a
/// Discord thread or a Nexus page. This is what the LLM extractor reads, for
/// the forum and Discord alike.
///
/// [posts] is the author's opening run: the first post, then each post straight
/// after it by the same person, stopping at the first reply by anybody else.
/// Each post carries its own HTML, links, images and date. The forum's posts
/// are [QbForumPost]s already; a Discord message is turned into one.
@MappableClass(ignoreNull: true)
class SourcePost with SourcePostMappable {
  final SourceKind kind;

  /// The forum topic id, the Discord thread id or the Nexus id, as text.
  final String id;
  final String title;
  final String author;

  /// The address of the post itself.
  final String url;

  /// The game version the post states, when it states one. The forum reads it
  /// out of the title; Discord leaves it empty.
  final String? gameVersion;
  final List<QbForumPost> posts;

  /// A stand-in post the scraper saved because it could not read the real one.
  /// Never sent to the LLM.
  final bool isPlaceholder;

  SourcePost({
    required this.kind,
    required this.id,
    this.title = '',
    this.author = '',
    this.url = '',
    this.gameVersion,
    this.posts = const [],
    this.isPlaceholder = false,
  });

  /// A forum topic as the extractor reads it. Built from exactly the fields it
  /// read before [SourcePost] existed, so the prompt sent for a forum topic is
  /// unchanged.
  factory SourcePost.fromForumDetail(QbModDetail detail) => SourcePost(
        kind: SourceKind.forum,
        id: '${detail.topicId}',
        title: detail.title,
        author: detail.author,
        url: 'https://fractalsoftworks.com/forum/index.php?topic=${detail.topicId}.0',
        gameVersion: detail.gameVersion,
        posts: detail.openingPosts,
        isPlaceholder: detail.isPlaceholderDetail,
      );

  /// The key this post's LLM answer is stored under. A forum topic keeps its
  /// bare topic id, which is what every answer saved before Discord was read
  /// is filed under; a Discord thread is `discord:<thread id>`.
  String get storeKey => storeKeyFor(kind, id);

  static String storeKeyFor(SourceKind kind, String id) => switch (kind) {
        SourceKind.forum => id,
        SourceKind.discord => 'discord:$id',
        SourceKind.nexus => 'nexus:$id',
      };

  /// How this post is named in the log: "topic 123" or "Discord thread 456".
  String get label => switch (kind) {
        SourceKind.forum => 'topic $id',
        SourceKind.discord => 'Discord thread $id',
        SourceKind.nexus => 'Nexus page $id',
      };

  /// Every link in the opening run, first post first, with the same URL kept
  /// only once.
  List<LinkRef> get allLinks {
    final seen = <String>{};
    return [
      for (final post in posts)
        for (final link in post.links)
          if (seen.add(link.url.trim().toLowerCase())) link,
    ];
  }

  /// Every image in the opening run, first post first, with the same URL kept
  /// only once.
  List<ImageRef> get allImages {
    final seen = <String>{};
    return [
      for (final post in posts)
        for (final image in post.images)
          if (seen.add(image.originalUrl.trim().toLowerCase())) image,
    ];
  }
}

/// Which source post a listing came from: its kind and id, and — for a listing
/// the LLM found — the name the LLM gave that mod. The name is what tells two
/// mods on one forum topic apart.
@MappableClass(ignoreNull: true)
class SourcePostRef with SourcePostRefMappable {
  final SourceKind kind;
  final String id;
  final String? llmModName;

  const SourcePostRef({required this.kind, required this.id, this.llmModName});

  /// The same post, without the LLM name. Two refs to one post with different
  /// names are two different mods; this is what they have in common.
  SourcePostRef get post => SourcePostRef(kind: kind, id: id);

  /// One line for keys and logs: `forum:34161`, `forum:34161#Useful.Tithes`.
  String get key => llmModName == null ? '${kind.name}:$id' : '${kind.name}:$id#$llmModName';

  @override
  String toString() => key;
}
