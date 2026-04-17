import 'dart:io';

import 'package:logging/logging.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/board_scraper.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/json_data_store.dart';
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

  try {
    log.info('Scraping 1 page from board 8...');
    final mods = await boardScraper.scrapeAllPages(maxPages: 1);
    log.info('Found ${mods.length} topics on page 1');

    if (mods.isEmpty) {
      log.severe('No topics found — smoke test failed');
      exit(1);
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

    log.info('Smoke test passed!');
  } finally {
    client.close();
  }
}
