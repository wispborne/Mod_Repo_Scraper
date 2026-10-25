import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../bot/scraper/qb/bundle_publisher.dart';
import '../bot/scraper/qb/models/forum_data_bundle.dart';
import '../catalog/discord_posts.dart';
import '../catalog/mod_catalog.dart';
import '../catalog/takedowns.dart';
import '../bot/scraper/qb/llm/picture_caption_store.dart';
import 'mod_id_store.dart';
import 'public_data_builder.dart';
import 'release_detector.dart';
import 'release_state_store.dart';
import 'requirement_asker.dart';
import 'requirement_names.dart';

/// The step at the end of a run that rebuilds the public website's files.
///
/// The website is built from the catalog (`mod-catalog.json`), which says what
/// mods there are, their ids and the source posts each came from, and the
/// bundle (`mod-catalog-details.json`), which holds the posts and the LLM's
/// answers those source posts lead to. A run usually only produces one of
/// those, so this reads the other back from the outputs folder. Neither is
/// changed — they are read, and the website's files are written beside them.
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
  ///
  /// Jobs with the LLM on provide [requirementAsker]. It asks about requirement
  /// names the rules could not match to one of our mods.
  Future<void> afterBundle(
    ForumDataBundle bundle, {
    String? bundleId,
    RequirementAsker? requirementAsker,
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
      catalog: _readCatalog(),
      bundle: bundle,
      releases: state.newestFirst,
      requirementAsker: requirementAsker,
      log: log,
    );
  }

  /// Rebuilds the website's files after a merge. The release state is read, not
  /// changed: a merge tells us nothing new about any mod's version.
  ///
  /// Each mod's Discord post is read from `discord-posts.json`, which the
  /// Discord scrape writes. The site only reads it.
  ///
  /// [catalog] is the catalog the merge has just written; left out, it is read
  /// back from `mod-catalog.json`.
  Future<void> afterMerge({
    ModCatalog? catalog,
    void Function(String message)? log,
  }) async {
    await _rebuild(
      catalog: catalog ?? _readCatalog(),
      bundle: _readBundle(),
      releases: ReleaseStateStore(dataPath).load().newestFirst,
      log: log,
    );
  }

  // ---------------------------------------------------------------------------

  Future<void> _rebuild({
    required ModCatalog? catalog,
    required ForumDataBundle? bundle,
    required List<ThreadRelease> releases,
    RequirementAsker? requirementAsker,
    void Function(String message)? log,
  }) async {
    if (catalog == null || catalog.mods.isEmpty) {
      _say(
          log,
          'No catalog to build the website from yet, so its files were left '
          'as they were. Run a merge first.');
      return;
    }

    // Read for the day each mod was first seen. The ids themselves come from
    // the catalog; this hands none out and writes nothing.
    final idStore = ModIdStore(dataPath)..load();
    // Read, never written: the LLM step saves what it saw in each picture, and
    // the card picture is chosen from that.
    final pictureCaptions = PictureCaptionStore(dataPath);
    await pictureCaptions.load();
    // Saved matches for requirement names the rules could not match.
    final requirementNames = RequirementNameStore(dataPath)..load();
    final builder = PublicDataBuilder(
        outputPath: outputPath,
        idStore: idStore,
        sitePath: sitePath,
        pictureCaptions: pictureCaptions,
        requirementNames: requirementNames);

    final discordPosts = _readDiscordPosts();
    final goneIds = _takenDownIds();
    PublicSiteData buildData() => builder.build(
          mods: catalog.mods,
          collections: catalog.collections,
          movedIds: catalog.movedIds,
          goneIds: goneIds,
          bundle: bundle,
          threadReleases: releases,
          discordPosts: discordPosts,
        );

    var data = buildData();
    if (requirementAsker != null) {
      final matched = await requirementAsker.ask(
        unmatched: data.unmatchedNeeds,
        candidates: data.requiredMods,
        store: requirementNames,
        log: log,
      );
      // Build again only when an answer changes a page. Building takes less time
      // than writing a thousand files. The files are written once either way.
      if (matched > 0) data = buildData();
    }
    await builder.write(data);
    await _writeRequirementReport(data);

    _say(
        log,
        'Built the website files: ${data.list.mods.length} mods and '
        '${data.feed.releases.length} releases in ${builder.siteDir}.');
  }

  /// Saves this build's requirement name matches for the viewer's
  /// Requirement names page. Includes every published mod for choosing a
  /// match. The report is never published.
  Future<void> _writeRequirementReport(PublicSiteData data) async {
    final names = data.requirementNames.entries.toList()
      ..sort((a, b) => b.value.count.compareTo(a.value.count));
    final mods = [
      for (final mod in data.list.mods) {'id': mod.id, 'name': mod.displayName ?? mod.name},
    ]..sort((a, b) => a['name']!.toLowerCase().compareTo(b['name']!.toLowerCase()));
    final file = File(p.join(dataPath, RequirementNameStore.reportFileName));
    try {
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(jsonEncode({
        'builtAt': data.list.generatedAt.toIso8601String(),
        'names': [
          for (final MapEntry(:key, :value) in names) {'key': key, ...value.toJson()},
        ],
        'mods': mods,
      }));
      await temp.rename(file.path);
    } catch (e) {
      _log.warning('Could not save ${file.path}. The viewer\'s Dependency '
          'names page shows the previous build: $e');
    }
  }

  /// The catalog from `mod-catalog.json`, or null when there is no such file
  /// yet.
  ModCatalog? _readCatalog() =>
      ModCatalog.read(File(p.join(outputPath, ModCatalog.fileName)));

  /// Collects mod ids from `takedowns.json`.
  /// Also collects mod and Collection ids from `takedown-matches.json`.
  /// That file includes mods removed by an author entry.
  /// Read failures may leave out not-found files but do not stop the build.
  /// The job has already read the takedown list.
  Set<String> _takenDownIds() {
    final ids = <String>{};
    try {
      ids.addAll(TakedownList.read(dataPath).modIds);
    } catch (e) {
      _log.warning('Could not read the takedown list. Some removed mods may have no not-found page: $e');
    }
    final matchesFile = File(p.join(dataPath, TakedownList.matchesFileName));
    if (matchesFile.existsSync()) {
      try {
        final report = jsonDecode(matchesFile.readAsStringSync()) as Map<String, dynamic>;
        for (final match in (report['matches'] as List?) ?? const []) {
          for (final key in const ['mods', 'collections']) {
            for (final item in ((match as Map)[key] as List?) ?? const []) {
              if ((item as Map)['id'] case final String id) ids.add(id);
            }
          }
        }
      } catch (e) {
        _log.warning('Could not read ${matchesFile.path}. Mods removed by an author entry may have no not-found page: $e');
      }
    }
    return ids;
  }

  File get _discordPostsFile =>
      File(p.join(dataPath, DiscordPostsFile.fileName));

  /// The saved Discord threads, or none when there is no such file yet. A file
  /// that cannot be read costs the pages their Discord posts, not the build.
  DiscordPostsFile _readDiscordPosts() {
    final file = _discordPostsFile;
    try {
      return DiscordPostsFile.read(file);
    } catch (e) {
      _log.warning('Could not read ${file.path}, so the website was built '
          'without Discord posts: $e');
      return const DiscordPostsFile();
    }
  }

  /// The published bundle, or null when there is no such file yet.
  ForumDataBundle? _readBundle() {
    final file = File(p.join(outputPath, BundlePublisher.detailsFileName));
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
