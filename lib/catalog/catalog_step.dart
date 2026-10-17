import 'dart:io';

import 'package:path/path.dart' as p;

import '../bot/scraper/debug/merge_debug_collector.dart';
import '../bot/scraper/scraped_mod.dart';
import '../site/mod_id_store.dart';
import 'catalog_inputs.dart';
import 'mod_catalog.dart';

/// Builds `ModRepo-v2.json` from saved files: the QB store, the Discord and
/// Nexus results, `discord-posts.json` and the LLM's answers.
///
/// Every job that can change the listings ends here — the ModRepo merge jobs
/// and the QB jobs that scrape, read with the LLM or rebuild the bundle — so a
/// topic the LLM has just found four mods on is four mods in the catalog by
/// the time the job finishes. It makes no network call and never calls the
/// LLM.
class CatalogStep {
  /// Holds the QB store, the LLM's answers, `discord-posts.json` and
  /// `mod-ids.json`.
  final String qbDataPath;

  /// Holds `discord_cache.json` and `nexus_cache.json`.
  final String sourceCachePath;

  /// Where `ModRepo-v2.json` is written.
  final String outputPath;

  const CatalogStep({
    required this.qbDataPath,
    this.sourceCachePath = '.',
    this.outputPath = 'outputs',
  });

  File get outputFile => File(p.join(outputPath, ModCatalog.fileName));

  /// Merges and writes the catalog, and returns it. Returns null, having
  /// written nothing, when [isCancelled] says stop before the file is written:
  /// half a catalog is worse than yesterday's whole one.
  ///
  /// [discordMods] and [nexusMods] are the readers' results when the caller
  /// has them fresh; left out, they are read from the cache files.
  ///
  /// A `mod-ids.json` that is there but cannot be read throws before anything
  /// is written, because fresh ids would move every mod's page.
  Future<ModCatalog?> run({
    List<ScrapedMod>? discordMods,
    List<ScrapedMod>? nexusMods,
    MergeDebugCollector? debugCollector,
    bool keepAllGameVersionsFromSameSource = false,
    bool Function()? isCancelled,
    void Function(String message)? log,
  }) async {
    final started = DateTime.now();
    final inputs = await CatalogInputs.read(
      qbDataPath: qbDataPath,
      discordMods: discordMods ?? _readCache('discord', log),
      nexusMods: nexusMods ?? _readCache('nexus', log),
    );
    log?.call('Catalog listings: ${inputs.listings.length} from '
        '${inputs.forumTopics} forum topics, ${inputs.discordThreads} Discord '
        'threads and ${inputs.nexusPages} Nexus pages; '
        '${inputs.collections.length} Collections.');

    final ids = ModIdStore(qbDataPath)..load();
    final catalog = await ModCatalog.build(
      inputs: inputs,
      ids: ids,
      debugCollector: debugCollector,
      keepAllGameVersionsFromSameSource: keepAllGameVersionsFromSameSource,
      log: log,
    );

    if (isCancelled?.call() ?? false) {
      log?.call('Cancelled before saving. ${ModCatalog.fileName} was left as '
          'it was.');
      return null;
    }

    await catalog.write(outputFile);
    ids.save();
    log?.call('Catalog: ${catalog.mods.length} mods and '
        '${catalog.collections.length} Collection pages, saved to '
        '${outputFile.path} in '
        '${DateTime.now().difference(started).inMilliseconds}ms.');
    return catalog;
  }

  List<ScrapedMod> _readCache(String source, void Function(String message)? log) {
    final file = File(p.join(sourceCachePath, '${source}_cache.json'));
    if (!file.existsSync()) return const [];
    try {
      return ScrapedModsMapper.fromJson(file.readAsStringSync()).items;
    } catch (e) {
      log?.call('Could not read ${file.path}, so its mods are not in the '
          'catalog this time: $e');
      return const [];
    }
  }
}
