// Builds the catalog from a copy of the data and compares it with the
// published site, by permanent id. Run before switching production over.
//
//   dart run bin/compare_catalog.dart --data <copy of qb_data> \
//     [--sources .] [--published outputs/site] [--out <scratch outputs>] [--link]
//
// --data must be a copy: building the catalog links ids to their posts in its
// mod-ids.json. --link first runs the one-time linking step on that copy, from
// the published site's own pages. The report is written to
// <out>/catalog-comparison.md, and the command exits with 1 while a published
// id would stop working.

import 'dart:io';

import 'package:args/args.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/forum_data_bundle.dart';
import 'package:mod_repo_scraper/catalog/catalog_comparison.dart';
import 'package:mod_repo_scraper/catalog/catalog_step.dart';
import 'package:mod_repo_scraper/catalog/discord_posts.dart';
import 'package:mod_repo_scraper/catalog/id_linking.dart';
import 'package:mod_repo_scraper/site/mod_id_store.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('data', mandatory: true, help: 'A copy of qb_data. It is changed.')
    ..addOption('sources', defaultsTo: '.', help: 'The folder holding discord_cache.json and nexus_cache.json.')
    ..addOption('published', defaultsTo: p.join('outputs', 'site'), help: 'The published site to compare with.')
    ..addOption('bundle', defaultsTo: p.join('outputs', 'forum-data-bundle.json'),
        help: 'The published bundle, for the linking step.')
    ..addOption('out', help: 'Where to write the catalog and the report. Defaults to <data>/comparison.')
    ..addFlag('link', help: 'Run the one-time id linking step on the copy first.')
    ..addFlag('help', abbr: 'h', negatable: false);
  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('${e.message}\n${parser.usage}');
    exitCode = 64;
    return;
  }
  if (args['help'] as bool) {
    stdout.writeln(parser.usage);
    return;
  }

  final dataPath = args['data'] as String;
  final outPath = (args['out'] as String?) ?? p.join(dataPath, 'comparison');
  final publishedMods = Directory(p.join(args['published'] as String, 'mods'));
  if (p.equals(p.canonicalize(dataPath), p.canonicalize('qb_data'))) {
    stderr.writeln('--data is the real qb_data. Copy it first: this changes its mod-ids.json.');
    exitCode = 64;
    return;
  }

  if (args['link'] as bool) {
    final ids = ModIdStore(dataPath)..load();
    final bundleFile = File(args['bundle'] as String);
    final report = linkIdsFromPublishedSite(
      ids: ids,
      modsDir: publishedMods,
      bundle: bundleFile.existsSync() ? ForumDataBundleMapper.fromJson(bundleFile.readAsStringSync()) : null,
      discordPosts: DiscordPostsFile.read(File(p.join(dataPath, DiscordPostsFile.fileName))),
    );
    ids.save();
    stdout.writeln('Linked ${report.links} source posts from ${report.pages} published pages.');
  }

  var notMods = const <String>{};
  final catalog = await CatalogStep(
    qbDataPath: dataPath,
    sourceCachePath: args['sources'] as String,
    outputPath: outPath,
  ).run(log: stdout.writeln, onListings: (listings) => notMods = listings.notMods.keys.toSet());

  final comparison = compareCatalog(
    published: readPublishedPages(publishedMods),
    catalog: catalog!,
    notMods: notMods,
  );
  final reportFile = File(p.join(outPath, 'catalog-comparison.md'));
  await reportFile.writeAsString(comparison.toMarkdown());

  stdout.writeln('Missing ids: ${comparison.missing.length} (${comparison.joinedInto.length} joined into another '
      'mod); removed on purpose: ${comparison.removedOnPurpose.length}; becoming Collections: '
      '${comparison.becameCollections.length}; source posts changed: ${comparison.postsChanged.length}; '
      'Discord threads giving several mods: ${comparison.discordThreadsWithSeveral.length}; '
      'new mods: ${comparison.added.length}; names that differ: ${comparison.renamed.length}.');
  stdout.writeln('Report: ${reportFile.path}');
  if (comparison.blocksTheSwitch) exitCode = 1;
}
