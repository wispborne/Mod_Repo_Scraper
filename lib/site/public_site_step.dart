import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../bot/scraper/qb/models/forum_data_bundle.dart';
import '../bot/scraper/scraped_mod.dart';
import 'mod_id_store.dart';
import 'public_data_builder.dart';
import 'release_detector.dart';
import 'release_state_store.dart';

/// The step at the end of a run that rebuilds the public website's files.
///
/// The website is built from both halves of the scraper: the merged mods from
/// the ModRepo pipeline and the forum data bundle from the QB pipeline. A run
/// usually only produces one of those, so this reads the other half back from
/// the outputs folder. Neither existing output is changed — they are read, and
/// three new files are written beside them.
///
/// It is called from two places, and does slightly different work at each:
///
/// - After the QB pipeline publishes a bundle, [afterBundle] moves the release
///   state on by that one bundle and then rebuilds the files. This is the only
///   place a release can be recorded.
/// - After a merge, [afterMerge] rebuilds the files with the new mod list. It
///   never touches the release state — nothing new has been read about any mod's
///   version.
class PublicSiteStep {
  /// Where the id store and the release state live — the same folder as the
  /// other working files.
  final String dataPath;

  /// Where the existing outputs are written. The website's files go in a `site`
  /// folder under it.
  final String outputPath;

  /// The website's own files, which each mod's page is built out of. The same
  /// folder `publish_site_path` names; both default to `site`.
  final String sitePath;

  final Logger _log;

  PublicSiteStep({
    required this.dataPath,
    required this.outputPath,
    this.sitePath = 'site',
    Logger? logger,
  }) : _log = logger ?? Logger('PublicSiteStep');

  /// Moves the release state on by [bundle], then rebuilds the website's files.
  ///
  /// [bundleId] is the run's own id, which is also what the bundle's snapshot is
  /// named after — so a bundle is never counted twice, whichever way it is
  /// reached.
  Future<void> afterBundle(
    ForumDataBundle bundle, {
    String? bundleId,
    void Function(String message)? log,
  }) async {
    final store = ReleaseStateStore(dataPath);
    final state = store.load();
    final detector = ReleaseDetector(state);

    final found = detector.advance(bundle, bundleId: bundleId);
    store.save(state);
    if (found.isNotEmpty) {
      _say(
          log,
          '${found.length} mods put out a new version: '
          '${found.map((r) => '${r.modName} ${r.newVersion}').join(', ')}');
    }

    await _rebuild(
      mods: _readMergedMods(),
      bundle: bundle,
      releases: state.newestFirst,
      log: log,
    );
  }

  /// Rebuilds the website's files after a merge. The release state is read, not
  /// changed: a merge tells us nothing new about any mod's version.
  Future<void> afterMerge(
    List<ScrapedMod> mods, {
    void Function(String message)? log,
  }) async {
    await _rebuild(
      mods: mods,
      bundle: _readBundle(),
      releases: ReleaseStateStore(dataPath).load().newestFirst,
      log: log,
    );
  }

  // ---------------------------------------------------------------------------

  Future<void> _rebuild({
    required List<ScrapedMod>? mods,
    required ForumDataBundle? bundle,
    required List<ThreadRelease> releases,
    void Function(String message)? log,
  }) async {
    if (mods == null || mods.isEmpty) {
      _say(
          log,
          'No merged mods to build the website from yet, so its files '
          'were left as they were. Run a merge first.');
      return;
    }

    // The ids are loaded before anything is built. A stored id file we cannot
    // read stops the run here, before a single file is written — handing out
    // fresh ids would move every mod's page to a new address.
    final idStore = ModIdStore(dataPath)..load();
    final builder = PublicDataBuilder(
        outputPath: outputPath, idStore: idStore, sitePath: sitePath);

    final data = builder.build(
      mods: mods,
      bundle: bundle,
      threadReleases: releases,
    );
    await builder.write(data);
    idStore.save();

    _say(
        log,
        'Built the website files: ${data.list.mods.length} mods and '
        '${data.feed.releases.length} releases in ${builder.siteDir}.');
  }

  /// The merged mods from `ModRepo.json`, or null when there is no such file
  /// yet.
  List<ScrapedMod>? _readMergedMods() {
    final file = File(p.join(outputPath, 'ModRepo.json'));
    if (!file.existsSync()) return null;

    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map || decoded['items'] is! List) {
      throw StateError('${file.path} is not the shape the merge writes — it '
          'should hold an "items" list of mods.');
    }
    return [
      for (final item in decoded['items'] as List)
        if (item is Map)
          ScrapedModMapper.fromMap(Map<String, dynamic>.from(item)),
    ];
  }

  /// The published bundle, or null when there is no such file yet.
  ForumDataBundle? _readBundle() {
    final file = File(p.join(outputPath, 'forum-data-bundle.json'));
    if (!file.existsSync()) return null;
    try {
      return ForumDataBundleMapper.fromJson(file.readAsStringSync());
    } catch (e) {
      _log.warning('Could not read ${file.path}, so the website was built '
          'without the forum data: $e');
      return null;
    }
  }

  void _say(void Function(String message)? log, String message) {
    _log.info(message);
    log?.call(message);
  }
}
