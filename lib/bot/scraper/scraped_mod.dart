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

import 'package:dart_mappable/dart_mappable.dart';

import 'mod_repo_utils.dart';

part 'scraped_mod.mapper.dart';

@MappableClass()
class ScrapedMods with ScrapedModsMappable {
  final List<ScrapedMod> items;

  ScrapedMods({required this.items});
}

@MappableClass(ignoreNull: true)
class ScrapedMod with ScrapedModMappable {
  final String name;
  final String? summary;
  final String? description;
  final String? modVersion;
  final String? gameVersionReq;
  final List<String> authorsList;
  final Map<ModUrlType, String>? urls;
  final List<ModSource>? sources;
  final List<String>? categories;
  final Map<String, Image>? images;
  final DateTime? dateTimeCreated;
  final DateTime? dateTimeEdited;

  const ScrapedMod({
    required this.name,
    this.summary,
    this.description,
    this.modVersion,
    this.gameVersionReq,
    this.authorsList = const [],
    this.urls,
    this.sources,
    this.categories,
    this.images,
    this.dateTimeCreated,
    this.dateTimeEdited,
  });

  List<String> getAuthors() => authorsList;

  List<String> authorsWithAliases() => authorsList
      .expand((author) => ModRepoUtils.getOtherMatchingAliases(author))
      .toSet()
      .toList();

  List<String> getCategories() => categories ?? [];

  List<ModSource> getSources() => sources ?? [];

  Map<String, Image> getImages() => images ?? {};

  Map<ModUrlType, String> getUrls() => urls ?? {};
}

@MappableEnum()
enum ModSource {
  Index,
  ModdingSubforum,
  Discord,
  NexusMods,
}

@MappableEnum()
enum ModUrlType {
  Forum,
  Discord,
  NexusMods,
  DirectDownload,
  DownloadPage,
}

@MappableClass(ignoreNull: true)
class Image with ImageMappable {
  final String id;
  final String? filename;
  final String? description;
  final String? contentType;
  final int? size;
  final String? url;
  final String? proxyUrl;

  const Image({
    required this.id,
    this.filename,
    this.description,
    this.contentType,
    this.size,
    this.url,
    this.proxyUrl,
  });
}
