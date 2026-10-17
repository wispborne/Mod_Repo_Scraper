import 'dart:convert';
import 'dart:io';

import 'package:dart_mappable/dart_mappable.dart';
import 'package:html/parser.dart' as html_parser;

import '../bot/scraper/download_link_detector.dart';
import '../bot/scraper/qb/models/mod_detail.dart';
import '../site/discord_markdown.dart';
import 'source_post.dart';

part 'discord_posts.mapper.dart';

/// One picture attached to a Discord message.
@MappableClass(ignoreNull: true)
class DiscordImage with DiscordImageMappable {
  final String url;
  final String? filename;
  final String? description;

  const DiscordImage({required this.url, this.filename, this.description});
}

/// One message of a thread's opening run, as Discord gave it: the markdown
/// text, when it was posted, and its picture attachments.
@MappableClass(ignoreNull: true)
class DiscordOpeningMessage with DiscordOpeningMessageMappable {
  final String id;
  final String content;
  final DateTime? timestamp;
  final DateTime? editedTimestamp;
  final List<DiscordImage> images;

  const DiscordOpeningMessage({
    required this.id,
    this.content = '',
    this.timestamp,
    this.editedTimestamp,
    this.images = const [],
  });
}

/// One Discord thread as the scrape saved it to `discord-posts.json`: its
/// name, who started it, the link to its first message, the forum link the
/// rules found in it, and the author's opening run.
///
/// The opening run starts at the first message with text and keeps each
/// message straight after it by the same author, stopping at the first message
/// by anybody else or after [DiscordThreadPost.maxMessages] messages.
@MappableClass(ignoreNull: true)
class DiscordThreadPost with DiscordThreadPostMappable {
  static const int maxMessages = 10;

  final String threadId;
  final String name;
  final String author;
  final String url;
  final String? forumUrl;
  final List<DiscordOpeningMessage> messages;

  const DiscordThreadPost({
    required this.threadId,
    this.name = '',
    this.author = '',
    this.url = '',
    this.forumUrl,
    this.messages = const [],
  });

  /// The first message's text: what the site shows as the mod's Discord post.
  String? get firstText {
    final text = messages.isEmpty ? null : messages.first.content.trim();
    return text == null || text.isEmpty ? null : text;
  }

  /// The thread as the LLM extractor reads it. Each message's markdown goes
  /// through the site's own Discord renderer and HTML cleaner, so a link stays
  /// where it sat in the words — which is what ties a download to the mod
  /// written beside it. Links are read back out of that HTML; pictures come
  /// from the message's attachments.
  SourcePost toSourcePost() => SourcePost(
        kind: SourceKind.discord,
        id: threadId,
        title: name,
        author: author,
        url: url,
        posts: [
          for (final message in messages)
            QbForumPost(
              contentHtml: discordMarkdownAsHtml(message.content) ?? '',
              links: _linksIn(discordMarkdownAsHtml(message.content)),
              images: [
                for (final image in message.images)
                  ImageRef(originalUrl: image.url, alt: image.description ?? image.filename),
              ],
              postDate: message.timestamp?.toUtc().toIso8601String(),
              lastEditDate: message.editedTimestamp?.toUtc().toIso8601String(),
            ),
        ],
      );

  static List<LinkRef> _linksIn(String? html) {
    if (html == null) return const [];
    final seen = <String>{};
    return [
      for (final a in html_parser.parseFragment(html).querySelectorAll('a[href]'))
        if (a.attributes['href']!.trim() case final url when url.isNotEmpty && seen.add(url))
          LinkRef(
            url: url,
            text: a.text.trim(),
            isExternal: true,
            isDownloadable: isLikelyModDownloadUrl(url),
          ),
    ];
  }
}

/// `discord-posts.json`, read back.
///
/// [threads] is the file as the scrape writes it, keyed by thread id. Before
/// the scrape wrote it, the site build wrote each mod's first message as plain
/// text filed under the link to that message; such a file reads into
/// [legacyTexts] instead, which is enough for the site to show the post until
/// the next Discord scrape replaces it. Old entries are never given to the LLM.
class DiscordPostsFile {
  static const String fileName = 'discord-posts.json';

  final Map<String, DiscordThreadPost> threads;
  final Map<String, String> legacyTexts;

  const DiscordPostsFile({this.threads = const {}, this.legacyTexts = const {}});

  bool get isEmpty => threads.isEmpty && legacyTexts.isEmpty;

  /// Reads [file]. A missing file is an empty one. A file that is not JSON
  /// throws, so the caller decides whether that costs a step or a run.
  static DiscordPostsFile read(File file) {
    if (!file.existsSync()) return const DiscordPostsFile();
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map) return const DiscordPostsFile();

    final threads = <String, DiscordThreadPost>{};
    final legacy = <String, String>{};
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is String) {
        legacy['${entry.key}'] = value;
      } else if (value is Map) {
        threads['${entry.key}'] = DiscordThreadPostMapper.fromMap(Map<String, dynamic>.from(value));
      }
    }
    return DiscordPostsFile(threads: threads, legacyTexts: legacy);
  }

  /// Writes [threads] to [file], keyed by thread id and in id order, so an
  /// unchanged scrape writes an unchanged file.
  static Future<void> write(File file, Map<String, DiscordThreadPost> threads) async {
    final ids = threads.keys.toList()..sort();
    final json = const JsonEncoder.withIndent('  ').convert({
      for (final id in ids) id: threads[id]!.toMap(),
    });
    await file.parent.create(recursive: true);
    // Written beside and moved into place, so a run that dies mid-write leaves
    // the old file whole.
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(json);
    await temp.rename(file.path);
  }

  /// The first message's text for the mod whose Discord link is [discordUrl],
  /// looked up by thread id. Falls back to the old file's link-keyed text.
  String? firstTextFor(String? discordUrl) {
    if (discordUrl == null) return null;
    for (final key in discordPostKeysOf(discordUrl)) {
      final text = threads[key]?.firstText;
      if (text != null) return text;
    }
    return legacyTexts[discordUrl];
  }

  /// The saved thread a mod's Discord link points at, or null.
  DiscordThreadPost? threadFor(String? discordUrl) {
    if (discordUrl == null) return null;
    for (final key in discordPostKeysOf(discordUrl)) {
      final thread = threads[key];
      if (thread != null) return thread;
    }
    return null;
  }
}

/// The keys a Discord link could be filed under in `discord-posts.json`, most
/// likely first.
///
/// A thread's link is `/channels/<server>/<thread>/<message>`, so the thread id
/// is the third part. A post that is not in a thread is linked as
/// `/channels/<server>/<channel>/<message>` and filed under its message id, so
/// the message id is tried second.
List<String> discordPostKeysOf(String discordUrl) {
  final segments = Uri.tryParse(discordUrl)?.pathSegments ?? const [];
  final at = segments.indexOf('channels');
  if (at < 0) return const [];
  final parts = segments.sublist(at + 1).where((s) => s.isNotEmpty).toList();
  return [
    if (parts.length >= 2) parts[1],
    if (parts.length >= 3) parts[2],
  ];
}

/// The thread id a Discord link points at — the key its saved thread and its
/// LLM answer are filed under. For a link to a post that is not in a thread,
/// its message id.
String? discordThreadIdOf(String? discordUrl, {Set<String>? knownThreadIds}) {
  if (discordUrl == null) return null;
  final keys = discordPostKeysOf(discordUrl);
  if (knownThreadIds != null) {
    for (final key in keys) {
      if (knownThreadIds.contains(key)) return key;
    }
  }
  return keys.isEmpty ? null : keys.first;
}
