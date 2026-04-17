import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/download_resolver.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/json_data_store.dart';

/// Smoke test: resolve downloads for topic 33509 which has a known GitHub
/// releases link (https://github.com/persocom01/HaloDynamicsShipIndustry_EN/releases).
void main() async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.message}');
  });

  final log = Logger('QbDownloadSmokeTest');
  final client = http.Client();
  final store = JsonDataStore('qb_data', logger: log);
  final resolver = QbDownloadResolver(
    client: client,
    dataPath: 'qb_data',
    logger: log,
  );

  try {
    // Load existing detail for topic 33509
    final detail = await store.loadDetail(33509);
    if (detail == null) {
      log.severe('No detail.json found for topic 33509 — run qb_smoke_test first');
      exit(1);
    }

    log.info('Topic ${detail.topicId}: ${detail.title}');
    log.info('Links: ${detail.links.length} total, '
        '${detail.links.where((l) => l.isExternal).length} external');

    // Resolve downloads
    final candidates = await resolver.resolveForTopic(
      detail.topicId,
      detail.links,
    );

    log.info('Resolved ${candidates.length} download candidate(s):');
    for (final c in candidates) {
      log.info('  [${c.confidence.name}] ${c.resolvedUrl}');
      if (c.archiveFilename != null) {
        log.info('    filename: ${c.archiveFilename}');
      }
      if (c.requiresManualStep) {
        log.info('    (requires manual step)');
      }
    }

    if (candidates.isEmpty) {
      log.severe('No candidates produced — smoke test FAILED');
      exit(1);
    }

    // Verify cache works
    final cached = resolver.getCachedCandidates(33509);
    if (cached == null || cached.length != candidates.length) {
      log.severe('Cache mismatch — smoke test FAILED');
      exit(1);
    }

    // Test disk persistence
    await resolver.saveCache();
    final file = File('qb_data/assumed-downloads-cache.json');
    if (!file.existsSync()) {
      log.severe('Cache file not created — smoke test FAILED');
      exit(1);
    }
    log.info('Cache file created (${file.lengthSync()} bytes)');

    // Reload and verify
    final client2 = http.Client();
    final resolver2 = QbDownloadResolver(
      client: client2,
      dataPath: 'qb_data',
      logger: log,
    );
    await resolver2.loadCache();
    final reloaded = resolver2.getCachedCandidates(33509);
    if (reloaded == null || reloaded.length != candidates.length) {
      log.severe('Cache reload mismatch — smoke test FAILED');
      exit(1);
    }

    log.info('Smoke test PASSED!');
  } finally {
    client.close();
  }
}
