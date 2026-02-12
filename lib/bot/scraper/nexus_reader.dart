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

import '../../timber/ktx/timber_kt.dart' as timber;
import '../common.dart';
import 'scraped_mod.dart';

part 'nexus_reader.mapper.dart';

class NexusReader {
  static const String baseUrl = "https://api.nexusmods.com";
  static const String gameId = "starsector";
  static const String websiteBaseUrl = "https://www.nexusmods.com/$gameId/mods";

  static Future<List<ScrapedMod>?> readAllMessages(BotConfig botConfig) async {
    final nexusStartTime = DateTime.now();

    final authToken = botConfig.nexusApiToken;
    if (authToken == null || authToken.isEmpty) {
      timber.w(message: () => "No NexusMods auth token found in config.");
      return null;
    }

    final gameInfo =
        await _getGameInfo(authToken: authToken).catchError((e, stackTrace) {
      timber.w(t: e, message: () => "Error getting game info");
      return null;
    });

    final mods = <ScrapedMod>[];
    // Once there are over 1000 mods on NexusMods, update this lol.
    // Rate limit is 2,500 requests per 24 hours.
    for (var modId = 1; modId < 1000; modId++) {
      try {
        final mod = await _getModById(
          modId: modId,
          categories: gameInfo?.categories ?? [],
          authToken: authToken,
        );

        if (mod != null) {
          mods.add(mod);
          timber.i(message: () => "NexusMods #$modId: ${mod.name}");
          timber.v(message: () => mod.toString());
        }
      } catch (e, stackTrace) {
        timber.w(t: e, message: () => "Error getting mod $modId");
        break;
      }
    }

    timber.i(message: () => "NexusMods scraping total: ${mods.length} mods in ${DateTime.now().difference(nexusStartTime).inMilliseconds}ms.");
    return mods;
  }

  static Future<GameInfo?> _getGameInfo({required String authToken}) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/v1/games/$gameId.json"),
        headers: {
          "apikey": authToken,
          "Accept": "application/json",
        },
      );

      return GameInfoMapper.fromMap(jsonDecode(response.body));
    } catch (e, stackTrace) {
      timber.w(t: e, message: () => "Error in getGameInfo");
      return null;
    }
  }

  static Future<ScrapedMod?> _getModById({
    required int modId,
    required List<Category> categories,
    required String authToken,
  }) async {
    final response = await http.get(
      Uri.parse("$baseUrl/v1/games/$gameId/mods/$modId.json"),
      headers: {
        "apikey": authToken,
        "Accept": "application/json",
      },
    ).timeout(const Duration(seconds: 5));

    final nexusMod = NexusModMapper.fromMap(jsonDecode(response.body));

    if (nexusMod.available != true) {
      return null;
    }

    final author = nexusMod.author?.trim().isEmpty == false
        ? nexusMod.author
        : nexusMod.uploadedBy?.trim().isEmpty == false
            ? nexusMod.uploadedBy
            : nexusMod.user?.name ?? "";

    final nexusModsUrl = _getWebLinkForModId(modId);

    final pictureUrl = nexusMod.pictureUrl?.trim().isEmpty == false
        ? nexusMod.pictureUrl
        : null;

    var mod = ScrapedMod(
      name: nexusMod.name ?? "(no name)",
      summary: nexusMod.summary,
      description: nexusMod.description,
      modVersion: nexusMod.version,
      gameVersionReq: null,
      authorsList: author != null ? [author] : const [],
      urls: {ModUrlType.NexusMods: nexusModsUrl},
      sources: [ModSource.NexusMods],
      categories: nexusMod.categoryId != null &&
              nexusMod.categoryId! < categories.length
          ? [categories[nexusMod.categoryId!].name].whereType<String>().toList()
          : null,
      images: pictureUrl != null
          ? {
              "banner": Image(
                id: pictureUrl,
                filename: pictureUrl,
                description: null,
                contentType: null,
                size: null,
                url: pictureUrl,
                proxyUrl: null,
              )
            }
          : null,
      dateTimeCreated: nexusMod.createdTime != null
          ? (() {
              try {
                return DateTime.parse(nexusMod.createdTime!);
              } catch (e, stackTrace) {
                timber.w(t: e, message: () => "Error parsing createdTime");
                return null;
              }
            })()
          : null,
      dateTimeEdited: nexusMod.updatedTime != null
          ? (() {
              try {
                return DateTime.parse(nexusMod.updatedTime!);
              } catch (e, stackTrace) {
                timber.w(t: e, message: () => "Error parsing updatedTime");
                return null;
              }
            })()
          : null,
    );

    if (nexusMod.containsAdultContent == true) {
      mod = mod.copyWith(categories: (mod.categories ?? []) + ["NSFW"]);
    }

    return mod;
  }

  static String _getWebLinkForModId(int modId) => "$websiteBaseUrl/$modId";
}

@MappableClass(caseStyle: CaseStyle.snakeCase)
class GameInfo with GameInfoMappable {
  final int? id;
  final String? name;
  final String? forumUrl;
  final String? nexusmodsUrl;
  final String? genre;
  final int? fileCount;
  final int? downloads;
  final String? domainName;
  final int? approvedDate;
  final int? fileViews;
  final int? authors;
  final int? fileEndorsements;
  final int? mods;
  final List<Category> categories;

  const GameInfo({
    this.id,
    this.name,
    this.forumUrl,
    this.nexusmodsUrl,
    this.genre,
    this.fileCount,
    this.downloads,
    this.domainName,
    this.approvedDate,
    this.fileViews,
    this.authors,
    this.fileEndorsements,
    this.mods,
    required this.categories,
  });
}

@MappableClass(caseStyle: CaseStyle.snakeCase)
class Category with CategoryMappable {
  final String? categoryId;
  final String? name;
  final String? parentCategory;

  const Category({
    this.categoryId,
    this.name,
    this.parentCategory,
  });
}

@MappableClass(caseStyle: CaseStyle.snakeCase)
class NexusMod with NexusModMappable {
  final String? name;
  final String? summary;
  final String? description;
  final String? pictureUrl;
  final int? modId;
  final bool? allowRating;
  final String? domainName;
  final int? categoryId;
  final String? version;
  final int? endorsementCount;
  final int? createdTimestamp;
  final String? createdTime;
  final int? updatedTimestamp;
  final String? updatedTime;
  final String? author;
  final String? uploadedBy;
  final String? uploadedUsersProfileUrl;
  final bool? containsAdultContent;
  final String? status;
  final bool? available;
  final User? user;
  final Endorsement? endorsement;

  const NexusMod({
    this.name,
    this.summary,
    this.description,
    this.pictureUrl,
    this.modId,
    this.allowRating,
    this.domainName,
    this.categoryId,
    this.version,
    this.endorsementCount,
    this.createdTimestamp,
    this.createdTime,
    this.updatedTimestamp,
    this.updatedTime,
    this.author,
    this.uploadedBy,
    this.uploadedUsersProfileUrl,
    this.containsAdultContent,
    this.status,
    this.available,
    this.user,
    this.endorsement,
  });
}

@MappableClass(caseStyle: CaseStyle.snakeCase)
class User with UserMappable {
  final int? memberId;
  final int? memberGroupId;
  final String? name;

  const User({
    this.memberId,
    this.memberGroupId,
    this.name,
  });
}

@MappableClass(caseStyle: CaseStyle.snakeCase)
class Endorsement with EndorsementMappable {
  final String? endorseStatus;
  final int? timestamp;
  final String? version;

  const Endorsement({
    this.endorseStatus,
    this.timestamp,
    this.version,
  });
}
