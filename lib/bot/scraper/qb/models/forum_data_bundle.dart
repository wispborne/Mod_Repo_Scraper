import 'package:dart_mappable/dart_mappable.dart';

import 'assumed_download.dart';
import 'bundle_meta.dart';
import 'mod_detail.dart';
import 'mod_summary.dart';
import 'post_extraction.dart';

part 'forum_data_bundle.mapper.dart';

@MappableClass(ignoreNull: true)
class ForumDataBundle with ForumDataBundleMappable {
  final DateTime updatedAt;
  final BundleMeta? meta;
  final List<QbModSummary> index;
  final Map<String, QbModDetail> details;

  /// The rules-only download list, keyed by topicId. This is what a client shows
  /// when LLM data is turned off; the LLM never writes into it. The LLM's own
  /// output lives on each `index` item's `llm` field instead.
  final Map<String, List<AssumedDownloadCandidate>> assumedDownloads;

  /// The LLM's answers for Discord threads, in `forum-data-bundle-v2.json`
  /// only. Each holds the thread's id, link and name and the mods read off it,
  /// in the same shape as a forum topic's `llm` mods. No message text is
  /// published. Null in the old `forum-data-bundle.json`, which never carries
  /// the field.
  final List<DiscordThreadAnswer>? discordThreads;

  ForumDataBundle({
    required this.updatedAt,
    this.meta,
    this.index = const [],
    this.details = const {},
    this.assumedDownloads = const {},
    this.discordThreads,
  });
}

/// One Discord thread's LLM answer, as the bundle publishes it.
@MappableClass(ignoreNull: true)
class DiscordThreadAnswer with DiscordThreadAnswerMappable {
  final String threadId;
  final String url;
  final String name;
  final List<LlmMod> mods;

  DiscordThreadAnswer({
    required this.threadId,
    this.url = '',
    this.name = '',
    this.mods = const [],
  });
}
