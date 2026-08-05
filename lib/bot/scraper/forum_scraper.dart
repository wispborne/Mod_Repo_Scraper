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

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import '../../timber/ktx/timber_kt.dart' as timber;
import '../../utilities/console_progress_bar.dart';
import '../../utilities/parallel_map.dart';
import 'qb/legacy_category_map.dart';
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

      final result = parseModIndex(doc);
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
      progressLabel: 'Forum: modding board',
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
      progressLabel: 'Forum: mods board',
    );
    timber.i(message: () => "Mod Forum scraped: ${result?.length ?? 0} mods in ${DateTime.now().difference(stepStartTime).inMilliseconds}ms.");
    return result;
  }

  static final _trailingColonRegex = RegExp(r':+$');

  /// Reads the mod index post: a run of lists, each one under a bold heading that names its category.
  ///
  /// Two traps in that page's HTML, both of which used to put a mod name where a category should be:
  ///  - A list can hold a smaller list of add-ons. The forum writes that inner list as a sibling of the
  ///    entries around it, not inside one, so it looks like a list of its own with a mod entry just above it.
  ///    Its mods are already picked up by the list that holds it, so skip it.
  ///  - The number of line breaks between a heading and its list varies, so we look back for the nearest
  ///    bold text rather than counting a fixed number of steps.
  ///
  /// A list with no heading above it is not a list of mods (the "how to get your mod added" steps are
  /// written as one), so it is skipped and counted in the log.
  ///
  /// The index post is followed by one post per past game version, and those still use the category
  /// names of their day, so their headings go through [currentCategoryName] — the same table and rule
  /// the QB scraper uses. A name that table doesn't know is kept as it was written, and logged.
  @visibleForTesting
  static List<ScrapedMod> parseModIndex(Document doc) {
    final areas = _indexPosts(doc);
    // The first post is today's index, so its headings are the category names still in use.
    final categoriesInUse = areas.isEmpty ? <String>{} : _headingsIn(areas.first);

    final mods = <ScrapedMod>[];
    var listsWithoutHeading = 0;
    final oldNamesNotInTheTable = <String>{};

    for (final area in areas) {
      for (final listElement in area.querySelectorAll("ul.bbc_list")) {
        if (_isInsideAnotherList(listElement)) continue;

        final heading = _headingAbove(listElement);
        if (heading == null) {
          listsWithoutHeading++;
          continue;
        }

        var category = currentCategoryName(heading, categoriesInUse);
        if (category == null) {
          oldNamesNotInTheTable.add(heading);
          category = heading;
        }

        for (final modElement in listElement.querySelectorAll("li")) {
          final link = modElement.querySelector("a.bbc_link");
          if (link == null) continue;

          final forumPostLink = link.attributes["href"]?.trim();
          final cleanedLink = forumPostLink?.isNotEmpty == true ? _cleanForumUrl(forumPostLink!) : null;

          mods.add(ScrapedMod(
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
          ));
        }
      }
    }

    if (listsWithoutHeading > 0) {
      timber.i(message: () => "Mod Index: skipped $listsWithoutHeading list(s) with no category heading above them.");
    }
    if (oldNamesNotInTheTable.isNotEmpty) {
      final names = oldNamesNotInTheTable.toList()..sort();
      timber.w(
          message: () => "Mod Index: kept ${names.length} category name(s) the index no longer uses "
              "(add them to lib/bot/scraper/qb/legacy_category_map.dart): ${names.join(', ')}");
    }

    return mods;
  }

  /// The index post and the older posts kept below it. Falls back to the whole page when the forum's
  /// usual wrapper isn't there, so a layout change costs categories rather than every mod.
  static List<Element> _indexPosts(Document doc) {
    final posts = doc.querySelectorAll("#forumposts .post .inner");
    if (posts.isNotEmpty) return posts;

    final wholePage = doc.documentElement;
    return wholePage == null ? [] : [wholePage];
  }

  static Set<String> _headingsIn(Element area) {
    final headings = <String>{};
    for (final listElement in area.querySelectorAll("ul.bbc_list")) {
      if (_isInsideAnotherList(listElement)) continue;
      final heading = _headingAbove(listElement);
      if (heading != null) headings.add(heading);
    }
    return headings;
  }

  static bool _isInsideAnotherList(Element listElement) {
    for (Element? parent = listElement.parent; parent != null; parent = parent.parent) {
      if (parent.localName == 'li') return true;
      if (parent.localName == 'ul' && parent.classes.contains('bbc_list')) return true;
    }
    return false;
  }

  /// The nearest bold text above a list, skipping the line breaks in between. Null if there isn't one.
  static String? _headingAbove(Element listElement) {
    for (Element? previous = listElement.previousElementSibling;
        previous != null;
        previous = previous.previousElementSibling) {
      if (previous.localName == 'br') continue;
      if (previous.localName != 'strong') return null;

      final heading = previous.text.trim().replaceAll(_trailingColonRegex, '').trim();
      return heading.isEmpty ? null : heading;
    }
    return null;
  }

  static String? _cleanForumUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    final uri = Uri.parse(url);
    final params = Map<String, String>.from(uri.queryParameters);
    params.remove("PHPSESSID");

    return uri.replace(queryParameters: params).toString();
  }

  static final _versionRegex = RegExp(r'[\[{]([^\]}]*?\d+?[^\]}]*?)[\]}]');

  static Future<List<ScrapedMod>?> _scrapeSubforumLinks({
    required String forumBaseUrl,
    required int subforumNumber,
    required int take,
    required String progressLabel,
  }) async {
    final totalPages = (take / postsPerPage).ceil();
    final progressBar = ConsoleProgressBar.start(progressLabel, totalPages);
    try {
      final allMods = <ScrapedMod>[];

      for (var page = 0; page < take; page += 20) {
        progressBar.update(page ~/ postsPerPage + 1);
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

        await Future.delayed(const Duration(milliseconds: 200));
      }

      return allMods;
    } catch (e, stackTrace) {
      timber.w(t: e, message: () => "Error scraping subforum");
      return null;
    } finally {
      progressBar.finish();
    }
  }
}
