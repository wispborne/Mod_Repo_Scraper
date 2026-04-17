import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:logging/logging.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/board_scraper.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/bundle_publisher.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/download_resolver.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/json_data_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/mod_index_scraper.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/throttled_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/topic_scraper.dart';

void main() async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.message}');
  });

  final log = Logger('QbSmokeTest');
  final client = ThrottledClient(delayMs: 1500);
  final store = JsonDataStore('qb_data', logger: log);
  final boardScraper = QbBoardScraper(client, logger: log);
  final topicScraper = QbTopicScraper(client, logger: log);
  final modIndexScraper = QbModIndexScraper(client, logger: log);

  final http.Client downloadClient = IOClient(
    HttpClient()..connectionTimeout = const Duration(seconds: 30),
  );
  final resolver = QbDownloadResolver(
    client: downloadClient,
    dataPath: 'qb_data',
    logger: log,
  );
  final publisher = BundlePublisher(
    store: store,
    resolver: resolver,
    dataPath: 'qb_data',
    logger: log,
  );

  try {
    log.info('Scraping mod index (topic=177)...');
    final modIndex = await modIndexScraper.scrape();
    log.info(
        'Mod index: ${modIndex.mainTopicCategoryMap.length} main, '
        '${modIndex.archivedTopicCategoryMap.length} archived, '
        '${modIndex.mainCategories.length} distinct main categories');

    log.info('Scraping 1 page from board 8...');
    final mods = await boardScraper.scrapeAllPages(maxPages: 1);
    log.info('Found ${mods.length} topics on page 1');

    if (mods.isEmpty) {
      log.severe('No topics found — smoke test failed');
      exit(1);
    }

    // Apply main-index category to summaries so the bundle backfill has
    // something to fill from.
    for (var i = 0; i < mods.length; i++) {
      final m = mods[i];
      final cat = modIndex.mainTopicCategoryMap[m.topicId] ??
          modIndex.archivedTopicCategoryMap[m.topicId];
      if (cat != null) {
        mods[i] = m.copyWith(category: cat, inModIndex: true);
      }
    }

    // Scrape first 2 topics for detail
    final toScrape = mods.take(2).toList();
    for (final mod in toScrape) {
      log.info('Scraping detail for topic ${mod.topicId}: ${mod.title}');
      final detail = await topicScraper.scrapeTopic(mod.topicId);
      if (detail != null) {
        await store.saveDetail(detail);
        log.info('  Author: ${detail.author}');
        log.info('  Images: ${detail.images.length}');
        log.info('  Links: ${detail.links.length}');
        log.info('  Content length: ${detail.contentHtml.length}');
      } else {
        log.warning('  Failed to scrape detail');
      }
    }

    await store.saveIndex(mods);
    log.info('Saved mods-index.json');

    // Verify files exist
    final indexFile = File('qb_data/mods-index.json');
    if (indexFile.existsSync()) {
      log.info('mods-index.json exists (${indexFile.lengthSync()} bytes)');
    } else {
      log.severe('mods-index.json not created!');
      exit(1);
    }

    for (final mod in toScrape) {
      final detailFile =
          File('qb_data/mods/${mod.topicId}/detail.json');
      if (detailFile.existsSync()) {
        log.info(
            'detail.json for topic ${mod.topicId} exists (${detailFile.lengthSync()} bytes)');
      } else {
        log.warning('detail.json for topic ${mod.topicId} not created');
      }
    }

    // Build and write the forum data bundle, then report category backfill.
    log.info('Creating forum data bundle...');
    final bundle = await publisher.createBundle();
    await publisher.writeLocal(bundle);

    final bundleFile = File('qb_data/forum-data-bundle.json');
    if (bundleFile.existsSync()) {
      log.info('forum-data-bundle.json exists (${bundleFile.lengthSync()} bytes)');
    } else {
      log.severe('forum-data-bundle.json not created!');
      exit(1);
    }

    final summaryById = {
      for (final s in bundle.index) s.topicId.toString(): s,
    };
    var nullCats = 0;
    var matchingCats = 0;
    for (final entry in bundle.details.entries) {
      final detail = entry.value;
      final summary = summaryById[entry.key] ??
          (throw StateError('no summary for ${entry.key}'));
      if (detail.category == null) {
        nullCats++;
      } else if (detail.category == summary.category) {
        matchingCats++;
      }
      log.info(
          'Bundle topic ${entry.key}: detail.category=${detail.category} index.category=${summary.category}');
    }
    log.info(
        'Bundle category summary: ${bundle.details.length} details, '
        '$matchingCats match index, $nullCats still null');

    log.info('Smoke test passed!');
  } finally {
    client.close();
    downloadClient.close();
  }
}
