/*
 * This file is distributed under the GPLv3. An informal description follows:
 * - Anyone can copy, modify and distribute this software as long as the other points are followed.
 * - You must include the license and copyright notice with each and every distribution.
 * - You may use this software for commercial purposes.
 * - If you modify it, you must indicate changes made to the code.
 * - Any modifications of this code base MUST be distributed with the same license, GPLv3.
 * - This software is provided without warranty.
 * - The software author or license can not be held liable for any damages inflicted by the software.
 * The full license is available from <https://www.gnu.org/licenses/gpl-3.0.txt>.
 */

import 'dart:convert';

import 'package:dart_mappable/dart_mappable.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:mod_repo_scraper/bot/common.dart';
import 'package:mod_repo_scraper/timber/ktx/timber_kt.dart' as timber;
import 'package:mod_repo_scraper/utilities/parallel_map.dart';

import 'scraped_mod.dart';

part 'discord_reader.mapper.dart';

class DiscordReader {
  static const String baseUrl = "https://discord.com/api";
  static const int delayBetweenRequestsMillis = 40; // Allowed to do 50 requests per second
  static int _timestampOfLastHttpCall = 0;
  static final RegExp _urlFinderRegex =
      RegExp(r'(http|ftp|https):\/\/([\w_-]+(?:(?:\.[\w_-]+)+))([\w.,@?^=%&:\/~+#-]*[\w@?^=%&\/~+#-])');

  /// Matches lines like "Forum Link:", "Forum Thread:", "Forum Post:", "Forum:", etc.
  static final RegExp _forumLabelRegex = RegExp(r'forum\s*(link|thread|post|page)?\s*:', caseSensitive: false);

  /// Matches markdown like [Forum Thread](url) or # [Forum Link](url).
  static final RegExp _forumMarkdownRegex = RegExp(r'\[forum\s*(link|thread|post|page)?\]', caseSensitive: false);

  /// Matches lines indicating a dependency, e.g. "Requires ModName:", "Dependencies:".
  static final RegExp _dependencyLabelRegex =
      RegExp(r'(^|\s)(requires|dependencies|dependency)\b', caseSensitive: false);
  static const String noscrapeReaction = "🕸️";
  static int apiCallsLastRun = 0;

  static Future<List<ScrapedMod>?> readAllMessages(BotConfig botConfig, {http.Client? httpClient}) async {
    final client = httpClient ?? http.Client();
    apiCallsLastRun = 0;
    final discordStartTime = DateTime.now();

    final authToken = botConfig.discordAuthToken;
    if (authToken == null || authToken.isEmpty) {
      timber.w(message: () => "No auth token found in config.");
      return null;
    }

    final serverId = botConfig.discordServerId;
    if (serverId == null || serverId.isEmpty) {
      timber.w(message: () => "No discord_serverId found in config.");
      return null;
    }

    final forumChannelIds = botConfig.discordForumChannelIdsAndGameVersions;
    if (forumChannelIds == null || forumChannelIds.isEmpty) {
      timber.w(message: () => "No discord_forumChannelIdsAndGameVersions found in config.");
      return null;
    }

    timber.i(message: () => "Scraping ${forumChannelIds.length} Discord #mod_updates channel(s)...");

    final allMods = <ScrapedMod>[];

    for (final entry in forumChannelIds.entries) {
      final channelId = entry.key;
      final gameVersion = entry.value;
      final channelStartTime = DateTime.now();

      final channelMods = await _readAllThreadsFromForumChannelId(
        serverId: serverId,
        forumChannelId: channelId,
        authToken: authToken,
        client: client,
      );

      timber.i(
          message: () =>
              "Discord channel $channelId scraped: ${channelMods.length} mods in ${DateTime.now().difference(channelStartTime).inMilliseconds}ms.");

      // If there's no game version requirement (which there won't be for
      // Discord mods), set it based on the mod_updates channel it's in.
      allMods.addAll(channelMods.map((mod) => mod.copyWith(
            gameVersionReq: (mod.gameVersionReq?.isNotEmpty == true) ? mod.gameVersionReq : gameVersion,
          )));
    }

    timber.i(message: () => "Found ${allMods.length} Discord mods. API calls used: $apiCallsLastRun.");
    timber.i(
        message: () =>
            "Discord scraping total: ${allMods.length} mods in ${DateTime.now().difference(discordStartTime).inMilliseconds}ms.");

    return allMods;
  }

  static Future<List<ScrapedMod>> _readAllThreadsFromForumChannelId({
    required String serverId,
    required String forumChannelId,
    required String authToken,
    required http.Client client,
  }) async {
    final modUpdatesChannel = await _getChannel(
      serverId: serverId,
      channelId: forumChannelId,
      authToken: authToken,
      client: client,
    );

    final categoriesLookup = <String, String>{};
    for (final tag in modUpdatesChannel.availableTags ?? []) {
      if (tag.name != null) {
        categoriesLookup[tag.id] = tag.name!;
      }
    }

    var stepStartTime = DateTime.now();
    final threads = await _getThreads(
      serverId: serverId,
      channelId: forumChannelId,
      authToken: authToken,
      getFullChannelInfo: true,
      client: client,
    );
    timber.i(
        message: () =>
            "Fetched ${threads.length} threads in ${DateTime.now().difference(stepStartTime).inMilliseconds}ms.");

    // Process threads sequentially to respect Discord rate limits.
    stepStartTime = DateTime.now();
    final allMessages = <List<Message>>[];
    for (final thread in threads) {
      final messages = await _getMessages(
        channelId: thread.id,
        channelName: thread.name,
        authToken: authToken,
        limit: 100,
        client: client,
      );
      allMessages.add(
        messages.map((msg) => msg.copyWith(parentThread: thread)).toList(),
      );
    }
    timber.i(
        message: () =>
            "Fetched messages for ${threads.length} threads in ${DateTime.now().difference(stepStartTime).inMilliseconds}ms.");

    timber.i(message: () => "Checking for mods with $noscrapeReaction reactions.");
    stepStartTime = DateTime.now();

    final filteredMessages = <List<Message>>[];
    for (final msgs in allMessages) {
      var shouldKeep = true;

      for (final msg in msgs) {
        final hasNoscrapeReaction = msg.reactions?.any((r) => r.emoji.name == noscrapeReaction) ?? false;

        if (hasNoscrapeReaction) {
          final reacters = await _getReacters(
            authToken: authToken,
            emoji: noscrapeReaction,
            channelId: msg.parentThread?.id ?? forumChannelId,
            messageId: msg.id,
            client: client,
          );

          timber.i(
              message: () => "$noscrapeReaction reactor(s): ${reacters.map((r) => r.username ?? r.id).join(', ')}");

          final isReactionFromPostAuthor = reacters.any((reacter) => reacter.id == msg.author?.id);

          if (isReactionFromPostAuthor) {
            timber.i(
                message: () =>
                    "Skipping Discord mod '${msg.content?.split('\n').firstOrNull ?? ''}' because of reaction $noscrapeReaction.");
            shouldKeep = false;
            break;
          } else {
            timber.i(
                message: () =>
                    "Not skipping Discord mod '${msg.content?.split('\n').firstOrNull ?? ''}' because no $noscrapeReaction is from the post author.");
          }
        }
      }

      if (shouldKeep) {
        filteredMessages.add(msgs);
      }
    }

    timber.i(
        message: () => "Reaction checking completed in ${DateTime.now().difference(stepStartTime).inMilliseconds}ms.");

    stepStartTime = DateTime.now();
    final mods = await filteredMessages.parallelMap((messages) async {
      if (messages.length == 1 && !messages.first.isInThread()) {
        return parseAsSingleMessage(serverId, forumChannelId, messages.first);
      } else {
        return parseAsThread(serverId, messages, categoriesLookup);
      }
    });

    final cleanedMods =
        mods.whereType<ScrapedMod>().map((mod) => _cleanUpMod(mod)).where((mod) => mod.name.isNotEmpty).toList();

    timber.i(
        message: () =>
            "Message parsing completed (${cleanedMods.length} mods) in ${DateTime.now().difference(stepStartTime).inMilliseconds}ms.");
    timber.i(message: () => "Found ${cleanedMods.length} Discord mods in channel $forumChannelId.");

    return cleanedMods;
  }

  @visibleForTesting
  static Future<ScrapedMod> parseAsSingleMessage(String serverId, String forumChannelId, Message message) async {
    timber.i(message: () => "Parsing message ${message.content?.split('\n').firstOrNull ?? ''}");

    final lines = message.content?.split('\n') ?? [];
    final name = lines.skipWhile((line) => line.trim().isEmpty).firstOrNull?.let((it) => removeMarkdownFromName(it));

    final messageLines =
        lines.skipWhile((line) => line.trim().isEmpty).skip(1).skipWhile((line) => line.trim().isEmpty).toList();

    final (forumUrl, downloadArtifactUrl, downloadPageUrl) = await getUrlsFromMessage(messageLines);

    final urls = <ModUrlType, String>{
      if (forumUrl != null) ModUrlType.Forum: forumUrl,
      ModUrlType.Discord: "https://discord.com/channels/$serverId/$forumChannelId/${message.id}",
      if (downloadArtifactUrl != null) ModUrlType.DirectDownload: downloadArtifactUrl,
      if (downloadPageUrl != null) ModUrlType.DownloadPage: downloadPageUrl,
    };

    return ScrapedMod(
      name: name ?? "",
      summary: messageLines.take(2).join('\n'),
      description: messageLines.join('\n'),
      modVersion: null,
      gameVersionReq: "",
      authorsList: message.author?.username != null ? [message.author!.username!] : const [],
      urls: urls,
      sources: [ModSource.Discord],
      categories: [],
      images: _getImagesFromMessage(message),
      dateTimeCreated: message.timestamp,
      dateTimeEdited: message.editedTimestamp,
    );
  }

  @visibleForTesting
  static Future<ScrapedMod?> parseAsThread(
      String serverId, List<Message> messages, Map<String, String> categoriesLookup) async {
    if (messages.isEmpty) return null;

    try {
      final messagesOrdered = messages.toList()
        ..sort((a, b) => (a.timestamp ?? DateTime(0)).compareTo(b.timestamp ?? DateTime(0)));

      final message = messagesOrdered.firstWhere(
        (msg) => msg.content?.isNotEmpty == true,
        orElse: () => messagesOrdered.first,
      );

      timber.i(message: () => "Parsing message ${message.content?.split('\n').firstOrNull ?? ''}");

      final name = message.parentThread?.name?.let((it) => removeMarkdownFromName(it));

      final messageLines = message.content?.split('\n').skipWhile((line) => line.trim().isEmpty).toList() ?? [];

      // For URL extraction, prefer the first (OP) message since it has the
      // definitive links. Fall back to all OP-author messages if the first
      // message didn't have a download URL.
      // Only OP-author messages are considered; replies from other users can
      // contain URLs for unrelated mods (e.g. a dependency author posting
      // updates in a dependent mod's thread).
      final firstMsgLines = messageLines; // already parsed from `message` above
      var (forumUrl, downloadArtifactUrl, downloadPageUrl) = await getUrlsFromMessage(firstMsgLines);

      if (downloadArtifactUrl == null && downloadPageUrl == null) {
        // First message had no download links; check all OP-author messages.
        final opAuthorId = message.author?.id;
        final allOpLines = messagesOrdered
            .where((m) => opAuthorId != null && m.author?.id == opAuthorId)
            .expand((m) => m.content?.split('\n') ?? <String>[])
            .skipWhile((line) => line.trim().isEmpty)
            .toList();

        final (fallbackForum, fallbackArtifact, fallbackPage) = await getUrlsFromMessage(allOpLines);
        forumUrl ??= fallbackForum;
        downloadArtifactUrl ??= fallbackArtifact;
        downloadPageUrl ??= fallbackPage;
      }

      final urls = <ModUrlType, String>{
        if (forumUrl != null) ModUrlType.Forum: forumUrl,
        ModUrlType.Discord: "https://discord.com/channels/$serverId/${message.parentThread?.id}/${message.id}",
        if (downloadArtifactUrl != null) ModUrlType.DirectDownload: downloadArtifactUrl,
        if (downloadPageUrl != null) ModUrlType.DownloadPage: downloadPageUrl,
      };

      final allImages = messagesOrdered
          .map((m) => _getImagesFromMessage(m))
          .fold<Map<String, Image>?>({}, (acc, images) => {...?acc, ...?images});

      return ScrapedMod(
        name: name ?? "",
        summary: messageLines.take(2).join('\n'),
        description: messageLines.join('\n'),
        modVersion: null,
        gameVersionReq: "",
        authorsList: message.author?.username != null ? [message.author!.username!] : const [],
        urls: urls,
        sources: [ModSource.Discord],
        categories:
            message.parentThread?.appliedTags?.map((tag) => categoriesLookup[tag]).whereType<String>().toList() ?? [],
        images: allImages,
        dateTimeCreated: message.timestamp,
        dateTimeEdited: message.editedTimestamp,
      );
    } catch (e, stackTrace) {
      timber.w(t: e, message: () => "Error parsing thread");
      return null;
    }
  }

  @visibleForTesting
  static Future<(String?, String?, String?)> getUrlsFromMessage(List<String> messageLines) async {
    final forumUrl = getForumUrlFromMessage(messageLines);

    // Exclude URLs from lines labeled as dependencies (e.g. "Requires ModName: <url>").
    final downloadyUrls = messageLines
        .where((line) => !_dependencyLabelRegex.hasMatch(line))
        .expand((line) => _urlFinderRegex.allMatches(line).map((m) => m.group(0)))
        .whereType<String>()
        .where((url) => _thingsThatAreNotDownloady.every((bad) => !url.contains(bad)))
        .toList();

    final downloadyResults = await downloadyUrls.parallelMap((url) async {
      final isDownloadable = _isDefiniteDownloadLink(url) || await Common.isDownloadable(url);
      return (url, isDownloadable);
    });

    final downloadArtifactUrl = downloadyResults
        .where((pair) => pair.$2)
        .map((pair) => pair.$1)
        .toList()
        .let(_getBestPossibleDownloadHost)
        .firstOrNull;

    final downloadPageUrl = downloadyResults
            .where((pair) => !pair.$2)
            .map((pair) => pair.$1)
            .toList()
            .let(_getBestPossibleDownloadHost)
            .firstOrNull ??
        forumUrl;

    return (forumUrl, downloadArtifactUrl, downloadPageUrl);
  }

  /// Finds the forum URL that represents THIS mod, not a dependency.
  ///
  /// Classification per line:
  /// 1. If the line has an explicit forum label ("Forum Link:", "Forum Thread:", etc.)
  ///    → this is the mod's own forum URL.
  /// 2. If the line has a dependency label ("Requires", "Dependencies", etc.)
  ///    → this is a dependency URL, skip it.
  /// 3. Otherwise, the URL is ambiguous.
  ///
  /// Priority: labeled own > last ambiguous > first ambiguous.
  /// "Last ambiguous" is preferred because Discord messages typically list
  /// dependency links first and the mod's own links at the bottom.
  @visibleForTesting
  static String? getForumUrlFromMessage(List<String> messageLines) {
    String? labeledForumUrl;
    String? lastAmbiguousForumUrl;

    for (final line in messageLines) {
      final forumUrls = _urlFinderRegex
          .allMatches(line)
          .map((m) => m.group(0))
          .whereType<String>()
          .where((url) => url.contains("fractalsoftworks"))
          .toList();

      if (forumUrls.isEmpty) continue;

      final hasForumLabel = _forumLabelRegex.hasMatch(line) || _forumMarkdownRegex.hasMatch(line);
      final hasDependencyLabel = _dependencyLabelRegex.hasMatch(line);

      if (hasForumLabel && !hasDependencyLabel) {
        // Explicitly labeled as this mod's forum link.
        labeledForumUrl ??= forumUrls.first;
      } else if (!hasDependencyLabel) {
        // Ambiguous — keep updating so we end up with the last one.
        lastAmbiguousForumUrl = forumUrls.last;
      }
      // If hasDependencyLabel && !hasForumLabel, skip entirely (it's a dependency).
    }

    return labeledForumUrl ?? lastAmbiguousForumUrl;
  }

  static Map<String, Image>? _getImagesFromMessage(Message message) {
    final imageAttachments = message.attachments?.where((a) => a.contentType?.startsWith("image/") ?? false).toList();

    if (imageAttachments == null || imageAttachments.isEmpty) return null;

    return Map.fromEntries(imageAttachments.map((a) => MapEntry(
          a.id,
          Image(
            id: a.id,
            filename: a.filename,
            description: a.description,
            contentType: a.contentType,
            size: a.size,
            url: a.url,
            proxyUrl: a.proxyUrl,
          ),
        )));
  }

  static const List<String> _thingsThatAreNotDownloady = [
    "imgur.com",
    "cdn.discordapp.com",
    "https://fractalsoftworks.com/forum/index.php?topic=",
    "http://fractalsoftworks.com/forum/index.php?topic=",
    "https://www.nexusmods.com/starsector/mods",
    "https://www.patreon.com/posts",
    "https://www.youtube.com"
  ];

  static List<String> _getBestPossibleDownloadHost(List<String> urls) {
    return urls
        .let((list) => _prefer(list, (url) => url.contains("/releases/download")))
        .let((list) => _prefer(list, (url) => url.contains("/releases")))
        .let((list) => _prefer(list, (url) => url.contains("dropbox")))
        .let((list) => _prefer(list, (url) => url.contains("drive.google")))
        .let((list) => _prefer(list, (url) => url.contains("patreon")))
        .let((list) => _prefer(list, (url) => url.contains("bitbucket")))
        .let((list) => _prefer(list, (url) => url.contains("github")))
        .let((list) => _prefer(list, (url) => url.contains("mediafire")))
        .let((list) => _prefer(list, (url) => url.contains("mega.nz")));
  }

  static bool _isDefiniteDownloadLink(String url) {
    return url.contains("drive.google.com") ||
        url.contains("mega.nz") ||
        url.contains("mediafire") ||
        url.contains(".zip") ||
        url.contains(".rar") ||
        url.contains(".7z");
  }

  static List<String> _prefer(List<String> list, bool Function(String) predicate) {
    final preferred = list.where(predicate).toList();
    final rest = list.where((item) => !predicate(item)).toList();
    return [...preferred, ...rest];
  }

  static final List<String> _markdownStyleSymbols = ["_", "*", "~", "`"];
  static final List<RegExp> _surroundingMarkdownRegexes =
      _markdownStyleSymbols.map((symbol) => RegExp('(.*)[$symbol](.*)[$symbol](.*)')).toList();

  @visibleForTesting
  static String removeMarkdownFromName(String str) {
    while (true) {
      var replaced = str;
      for (final regex in _surroundingMarkdownRegexes) {
        final match = regex.firstMatch(replaced);
        if (match != null) {
          replaced = match.groups([1, 2, 3]).whereType<String>().join();
        }
      }

      if (str == replaced) return str;
      str = replaced;
    }
  }

  static Future<Channel> _getChannel({
    required String serverId,
    required String channelId,
    required String authToken,
    required http.Client client,
  }) async {
    final response = await _makeHttpRequestWithRateLimiting(client, () async {
      final res = await client.get(
        Uri.parse("$baseUrl/channels/$channelId"),
        headers: {
          "Authorization": "Bot $authToken",
          "Accept": "application/json",
        },
      );
      timber.v(message: () => res.body);
      return res;
    });

    final channel = ChannelMapper.fromMap(jsonDecode(response.body));
    timber.i(message: () => "Found ${channel.name} in Discord.");
    return channel;
  }

  static Future<List<Channel>> _getThreads({
    required String serverId,
    required String channelId,
    required String authToken,
    bool getFullChannelInfo = false,
    bool includeArchived = true,
    required http.Client client,
  }) async {
    final activeThreadsResponse = await _makeHttpRequestWithRateLimiting(client, () async {
      final res = await client.get(
        Uri.parse("$baseUrl/guilds/$serverId/threads/active"),
        headers: {
          "Authorization": "Bot $authToken",
          "Accept": "application/json",
        },
      );
      timber.v(message: () => res.body);
      return res;
    });

    final activeThreads = ThreadsMapper.fromMap(jsonDecode(activeThreadsResponse.body));

    final archivedThreads = includeArchived
        ? await _getArchivedThreads(channelId: channelId, authToken: authToken, client: client)
        : <Channel>[];

    final allThreads = [...activeThreads.threads, ...archivedThreads].where((t) => t.parentId == channelId).toList()
      ..sort((a, b) => (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)));

    timber.i(message: () => "Found ${allThreads.length} active and archived threads in Discord #mod_updates.");

    if (getFullChannelInfo) {
      timber.i(message: () => "Getting full channel info for ${allThreads.length} threads.");
      final channels = <Channel>[];
      for (final thread in allThreads) {
        try {
          final channel =
              await _getChannel(serverId: serverId, channelId: thread.id, authToken: authToken, client: client);
          channels.add(channel);
        } catch (e, stackTrace) {
          timber.w(t: e, message: () => "Error getting channel info");
        }
      }
      return channels;
    }

    return allThreads;
  }

  static Future<List<Channel>> _getArchivedThreads({
    required String channelId,
    required String authToken,
    required http.Client client,
  }) async {
    String? date;
    final archivedThreads = <Channel>[];
    var hasMore = true;
    var runs = 0;

    while (hasMore) {
      runs++;
      if (runs > 50) {
        timber.e(message: () => "Fetched 'more archives' 50 times, probably an error. Stopping.");
        break;
      }

      final uri = Uri.parse("$baseUrl/channels/$channelId/threads/archived/public").replace(
        queryParameters: {
          "limit": "100",
          if (date != null) "before": date,
        },
      );

      final response = await _makeHttpRequestWithRateLimiting(client, () async {
        final res = await client.get(uri, headers: {
          "Authorization": "Bot $authToken",
          "Accept": "application/json",
        });
        timber.v(message: () => res.body);
        return res;
      });

      final result = ThreadsMapper.fromMap(jsonDecode(response.body));
      archivedThreads.addAll(result.threads);
      hasMore = result.hasMore ?? false;

      final minTimestamp = result.threads
          .map((t) => t.threadMetadata?.archiveTimestamp)
          .whereType<DateTime>()
          .fold<DateTime?>(null, (min, ts) => min == null || ts.isBefore(min) ? ts : min);

      date = minTimestamp?.toIso8601String();
    }

    return archivedThreads;
  }

  static Future<List<Message>> _getMessages({
    required String channelId,
    String? channelName,
    required String authToken,
    int limit = 999999999,
    required http.Client client,
  }) async {
    final messages = <Message>[];
    var runs = 0;
    const perRequestLimit = 100;

    while (messages.length < limit && runs < 25) {
      final uri = Uri.parse("$baseUrl/channels/$channelId/messages").replace(
        queryParameters: {
          "limit": perRequestLimit.toString(),
          if (messages.isNotEmpty) "before": messages.last.id,
        },
      );

      try {
        final response = await _makeHttpRequestWithRateLimiting(client, () async {
          final res = await client.get(uri, headers: {
            "Authorization": "Bot $authToken",
            "Accept": "application/json",
          });
          timber.v(message: () => res.body);
          return res;
        });

        final decoded = jsonDecode(response.body);
        if (decoded is! List) {
          timber.w(
              message: () =>
                  "Expected List from Discord messages API but got ${decoded.runtimeType}: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}");
          break;
        }

        final newMessages = decoded.map((json) => MessageMapper.fromMap(json)).toList()
          ..sort((a, b) => (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)));

        timber.i(message: () => "Found ${newMessages.length} posts in Discord channel $channelName.");
        messages.addAll(newMessages);
        runs++;

        if (newMessages.isEmpty || newMessages.length < perRequestLimit) {
          timber.i(message: () => "Found all ${messages.length} posts in channel $channelName.");
          break;
        }
      } catch (e) {
        timber.w(t: e, message: () => "Error getting messages for $uri, run $runs");
        break;
      }
    }

    return messages;
  }

  static Future<List<User>> _getReacters({
    required String authToken,
    required String emoji,
    required String channelId,
    required String messageId,
    required http.Client client,
  }) async {
    try {
      timber.i(message: () => "Checking to see who reacted to message $messageId with 🕸️.");

      final response = await _makeHttpRequestWithRateLimiting(client, () async {
        return await client.get(
          Uri.parse("$baseUrl/channels/$channelId/messages/$messageId/reactions/$emoji"),
          headers: {
            "Authorization": "Bot $authToken",
            "Accept": "application/json",
          },
        );
      });

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        timber.w(message: () => "Expected List from Discord reactions API but got ${decoded.runtimeType}");
        return [];
      }
      return decoded.map((json) => UserMapper.fromMap(json)).toList();
    } catch (e, stackTrace) {
      timber.e(t: e, message: () => "Error getting reacters");
      return [];
    }
  }

  static Future<http.Response> _makeHttpRequestWithRateLimiting(
      http.Client client, Future<http.Response> Function() call) async {
    // If response is cached, don't rate limit.
    // Edit: nvm, we don't know if the request is cached until making it, and this method doesn't have the url and headers to determine that,
    // so just suffer the rate limit during debugging.

    const maxRetries = 5;

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      apiCallsLastRun++;
      final now = DateTime.now().millisecondsSinceEpoch;
      final delay = (_timestampOfLastHttpCall + delayBetweenRequestsMillis - now).clamp(0, 999999);
      if (delay > 0) {
        await Future.delayed(Duration(milliseconds: delay));
      }
      _timestampOfLastHttpCall = DateTime.now().millisecondsSinceEpoch;

      final response = await call();

      if (response.statusCode == 429) {
        final body = jsonDecode(response.body);
        final retryAfter = ((body['retry_after'] as num?)?.toDouble() ?? 1.0);
        timber.w(
            message: () =>
                "Rate limited by Discord. Retrying after ${retryAfter}s (attempt ${attempt + 1}/$maxRetries).");
        await Future.delayed(Duration(milliseconds: (retryAfter * 1000).ceil()));
        continue;
      }

      return response;
    }

    // If we exhausted retries, make one final call and return whatever we get.
    return await call();
  }

  static final RegExp _discordUnrecognizedEmojiRegex = RegExp(r'(<:.+?:.+?>)');

  static ScrapedMod _cleanUpMod(ScrapedMod mod) {
    return ScrapedMod(
      name: mod.name.replaceAll(_discordUnrecognizedEmojiRegex, '').trim(),
      summary: mod.summary,
      description: mod.description?.replaceAll(_discordUnrecognizedEmojiRegex, '')?.trim(),
      modVersion: mod.modVersion,
      gameVersionReq: mod.gameVersionReq,
      authorsList: mod.authorsList,
      urls: mod.urls,
      sources: mod.sources,
      categories: mod.categories,
      images: mod.images,
      dateTimeCreated: mod.dateTimeCreated,
      dateTimeEdited: mod.dateTimeEdited,
    );
  }
}

@MappableClass(caseStyle: CaseStyle.snakeCase)
class Channel with ChannelMappable {
  final String id;
  final String? parentId;
  final String? name;
  final DateTime? timestamp;
  final String? lastMessageId;
  final String? ownerId;
  final int? messageCount;
  final List<Tag>? availableTags;
  final List<String>? appliedTags;
  final ThreadMetadata? threadMetadata;

  const Channel({
    required this.id,
    this.parentId,
    this.name,
    this.timestamp,
    this.lastMessageId,
    this.ownerId,
    this.messageCount,
    this.availableTags,
    this.appliedTags,
    this.threadMetadata,
  });
}

@MappableClass(caseStyle: CaseStyle.snakeCase)
class ThreadMetadata with ThreadMetadataMappable {
  final bool? archived;
  final DateTime? archiveTimestamp;
  final bool? locked;

  const ThreadMetadata({
    this.archived,
    this.archiveTimestamp,
    this.locked,
  });
}

@MappableClass(caseStyle: CaseStyle.snakeCase)
class Threads with ThreadsMappable {
  final List<Channel> threads;
  final bool? hasMore;

  const Threads({
    required this.threads,
    this.hasMore,
  });
}

@MappableClass(caseStyle: CaseStyle.snakeCase)
class Tag with TagMappable {
  final String id;
  final String? name;

  const Tag({
    required this.id,
    this.name,
  });
}

@MappableClass(caseStyle: CaseStyle.snakeCase)
class Message with MessageMappable {
  final String id;
  final User? author;
  final String? content;
  final DateTime? timestamp;
  final DateTime? editedTimestamp;
  final List<Attachment>? attachments;
  final List<Embed>? embeds;
  final List<Reaction>? reactions;
  final Channel? parentThread;

  const Message({
    required this.id,
    this.author,
    this.content,
    this.timestamp,
    this.editedTimestamp,
    this.attachments,
    this.embeds,
    this.reactions,
    this.parentThread,
  });

  bool isInThread() => parentThread != null;
}

@MappableClass(caseStyle: CaseStyle.snakeCase)
class User with UserMappable {
  final String id;
  final String? username;
  final String? discriminator;

  const User({
    required this.id,
    this.username,
    this.discriminator,
  });
}

@MappableClass(caseStyle: CaseStyle.snakeCase)
class Attachment with AttachmentMappable {
  final String id;
  final String? filename;
  final String? description;
  final String? contentType;
  final int? size;
  final String? url;
  final String? proxyUrl;

  const Attachment({
    required this.id,
    this.filename,
    this.description,
    this.contentType,
    this.size,
    this.url,
    this.proxyUrl,
  });
}

@MappableClass(caseStyle: CaseStyle.snakeCase)
class Embed with EmbedMappable {
  final String? title;
  final String? description;
  final String? url;

  const Embed({
    this.title,
    this.description,
    this.url,
  });
}

@MappableClass(caseStyle: CaseStyle.snakeCase)
class Reaction with ReactionMappable {
  final int count;
  final Emoji emoji;

  const Reaction({
    required this.count,
    required this.emoji,
  });
}

@MappableClass(caseStyle: CaseStyle.snakeCase)
class Emoji with EmojiMappable {
  final String? id;
  final String? name;
  final User? user;

  const Emoji({
    this.id,
    this.name,
    this.user,
  });
}

extension LetExtension<T> on T {
  R let<R>(R Function(T) op) => op(this);
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
