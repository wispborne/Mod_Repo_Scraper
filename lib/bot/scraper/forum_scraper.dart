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

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../../timber/ktx/timber_kt.dart' as timber;
import '../../utilities/parallel_map.dart';
import 'scraped_mod.dart';
import 'main_repo_scraper.dart';

class ForumScraper {
  static const int postsPerPage = 20;

  static Future<List<ScrapedMod>?> run({
    required int moddingForumPagesToScrape,
    required int modForumPagesToScrape,
  }) async {
    final forumStartTime = DateTime.now();

    final indexMods = await _scrapeModIndexLinks() ?? [];
    final moddingMods = await _scrapeModdingForumLinks(moddingForumPagesToScrape) ?? [];
    final modMods = await _scrapeModForumLinks(modForumPagesToScrape) ?? [];

    final allMods = [...indexMods, ...moddingMods, ...modMods];
    timber.i(message: () => "Forum scraping total: ${allMods.length} mods in ${DateTime.now().difference(forumStartTime).inMilliseconds}ms.");
    return allMods.isEmpty ? null : allMods;
  }

  static Future<List<ScrapedMod>?> _scrapeModIndexLinks() async {
    timber.i(message: () => "Scraping Mod Index...");
    final stepStartTime = DateTime.now();
    try {
      final response = await http.get(Uri.parse("https://fractalsoftworks.com/forum/index.php?topic=177.0"));
      final doc = html_parser.parse(response.body);

      final categories = doc.querySelectorAll("ul.bbc_list");

      final mods = await Future.wait(categories.expand((categoryElement) {
        var category = "";
        var prev = categoryElement.previousElementSibling?.previousElementSibling?.previousElementSibling;
        if (prev != null) {
          category = prev.text.trimRight().replaceAll(RegExp(r':$'), '');
        }

        return categoryElement.querySelectorAll("li").map((modElement) async {
          final link = modElement.querySelector("a.bbc_link");
          if (link == null) {
            return null;
          }

          final forumPostLink = link.attributes["href"]?.trim();
          final cleanedLink = forumPostLink?.isNotEmpty == true ? _cleanForumUrl(forumPostLink!) : null;

          return ScrapedMod(
            name: link.text,
            summary: null,
            description: null,
            modVersion: null,
            gameVersionReq: modElement.querySelector("strong span")?.text ?? "",
            authorsList: [modElement.querySelector("em strong")?.text ?? ""],
            urls: cleanedLink != null ? {ModUrlType.Forum: cleanedLink} : null,
            sources: [ModSource.Index],
            categories: [category],
            images: {},
            dateTimeCreated: null,
            dateTimeEdited: null,
          );
        });
      }).toList());

      final result = mods.whereType<ScrapedMod>().toList();
      timber.i(message: () => "Mod Index scraped: ${result.length} mods in ${DateTime.now().difference(stepStartTime).inMilliseconds}ms.");
      return result;
    } catch (e, stackTrace) {
      timber.w(t: e, message: () => "Error scraping mod index");
      return null;
    }
  }

  static Future<List<ScrapedMod>?> _scrapeModdingForumLinks(int moddingForumPagesToScrape) async {
    timber.i(message: () => "Scraping Modding Forum...");
    final stepStartTime = DateTime.now();
    final result = await _scrapeSubforumLinks(
      forumBaseUrl: MainRepoScraper.forumBaseUrl,
      subforumNumber: 3,
      take: postsPerPage * moddingForumPagesToScrape,
    );
    timber.i(message: () => "Modding Forum scraped: ${result?.length ?? 0} mods in ${DateTime.now().difference(stepStartTime).inMilliseconds}ms.");
    return result;
  }

  static Future<List<ScrapedMod>?> _scrapeModForumLinks(int modForumPagesToScrape) async {
    timber.i(message: () => "Scraping Mod Forum...");
    final stepStartTime = DateTime.now();
    final result = await _scrapeSubforumLinks(
      forumBaseUrl: MainRepoScraper.forumBaseUrl,
      subforumNumber: 8,
      take: postsPerPage * modForumPagesToScrape,
    );
    timber.i(message: () => "Mod Forum scraped: ${result?.length ?? 0} mods in ${DateTime.now().difference(stepStartTime).inMilliseconds}ms.");
    return result;
  }

  static String? _cleanForumUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    final uri = Uri.parse(url);
    final params = Map<String, String>.from(uri.queryParameters);
    params.remove("PHPSESSID");

    return uri.replace(queryParameters: params).toString();
  }

  static final _versionRegex = RegExp(r'[\[{]([^]}]*?\d+?[^]}]*?)[]}]');

  static Future<List<ScrapedMod>?> _scrapeSubforumLinks({
    required String forumBaseUrl,
    required int subforumNumber,
    required int take,
  }) async {
    try {
      final allMods = <ScrapedMod>[];

      for (var page = 0; page < take; page += 20) {
        timber.i(message: () => "Fetching page ${page ~/ postsPerPage} from subforum $subforumNumber.");

        final response = await http.get(Uri.parse("$forumBaseUrl?board=$subforumNumber.$page"));
        final doc = html_parser.parse(response.body);
        final posts = doc.querySelectorAll("#messageindex tr");

        final pageMods = await posts.parallelMap((postElement) async {
          final titleLinkElement = postElement.querySelector("td.subject span a");
          final authorLinkElement = postElement.querySelector("td.starter a");

          if (titleLinkElement == null) return null;

          final forumPostLink = titleLinkElement.attributes["href"]?.trim();
          final cleanedLink = forumPostLink?.isNotEmpty == true ? _cleanForumUrl(forumPostLink!) : null;

          final titleText = titleLinkElement.text;
          final versionMatch = _versionRegex.firstMatch(titleText);
          final gameVersion = versionMatch?.group(1)?.trim() ?? "";
          final cleanName = titleText.replaceAll(_versionRegex, "").trim();

          return ScrapedMod(
            name: cleanName,
            summary: null,
            description: null,
            modVersion: null,
            gameVersionReq: gameVersion,
            authorsList: [authorLinkElement?.text ?? ""],
            urls: cleanedLink != null ? {ModUrlType.Forum: cleanedLink} : null,
            sources: [ModSource.ModdingSubforum],
            categories: [],
            images: {},
            dateTimeCreated: null,
            dateTimeEdited: null,
          );
        });

        final filteredMods = pageMods
            .whereType<ScrapedMod>()
            .where((mod) => mod.gameVersionReq?.isNotEmpty == true)
            .where((mod) => !mod.name.trimLeft().toLowerCase().startsWith("moved"))
            .toList();

        timber.i(message: () => "Found ${filteredMods.length} mods on page ${page ~/ postsPerPage} of subforum $subforumNumber.");
        allMods.addAll(filteredMods);

        await Future.delayed(Duration(milliseconds: 200));
      }

      return allMods;
    } catch (e, stackTrace) {
      timber.w(t: e, message: () => "Error scraping subforum");
      return null;
    }
  }
}
