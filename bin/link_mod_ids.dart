// Links every id in mod-ids.json to the source posts its page came from, read
// off the published site's own files. Run once before switching to the catalog
// merge, while outputs/site still holds the pages the old site build made.
//
//   dart run bin/link_mod_ids.dart [--data qb_data] [--outputs outputs]
//
// Back up <data>/mod-ids.json first: it is changed in place. Running it again
// on the same files gives the same file.

import 'dart:io';

import 'package:args/args.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/forum_data_bundle.dart';
import 'package:mod_repo_scraper/catalog/discord_posts.dart';
import 'package:mod_repo_scraper/catalog/id_linking.dart';
import 'package:mod_repo_scraper/site/mod_id_store.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('data', defaultsTo: 'qb_data', help: 'The folder holding mod-ids.json.')
    ..addOption('outputs', defaultsTo: 'outputs', help: 'The folder holding site/ and forum-data-bundle.json.')
    ..addFlag('help', abbr: 'h', negatable: false);
  final args = parser.parse(arguments);
  if (args['help'] as bool) {
    stdout.writeln('Links each permanent id to its source posts.\n${parser.usage}');
    return;
  }

  final dataPath = args['data'] as String;
  final outputsPath = args['outputs'] as String;
  final modsDir = Directory(p.join(outputsPath, 'site', 'mods'));
  if (!modsDir.existsSync()) {
    stderr.writeln('No published mod pages at ${modsDir.path}. Build the site with the old '
        'pipeline first; this reads its pages.');
    exitCode = 1;
    return;
  }

  final ids = ModIdStore(dataPath)..load();
  if (ids.count == 0) {
    stderr.writeln('No ids in ${ids.filePath}, so there is nothing to link.');
    exitCode = 1;
    return;
  }

  final bundleFile = File(p.join(outputsPath, 'forum-data-bundle.json'));
  final bundle = bundleFile.existsSync() ? ForumDataBundleMapper.fromJson(bundleFile.readAsStringSync()) : null;
  if (bundle == null) {
    stdout.writeln('No forum-data-bundle.json in $outputsPath. Mods on shared topics will be '
        'linked to the topic only, without the LLM name that tells them apart.');
  }

  DiscordPostsFile discordPosts;
  try {
    discordPosts = DiscordPostsFile.read(File(p.join(dataPath, DiscordPostsFile.fileName)));
  } catch (e) {
    stdout.writeln('Could not read the saved Discord threads ($e); Discord links are read off '
        'the pages alone.');
    discordPosts = const DiscordPostsFile();
  }

  final report = linkIdsFromPublishedSite(
    ids: ids,
    modsDir: modsDir,
    bundle: bundle,
    discordPosts: discordPosts,
  );
  ids.save();

  stdout.writeln('Read ${report.pages} mod pages and linked ${report.links} source posts in '
      '${ids.filePath}.');
  if (report.unknownIds.isNotEmpty) {
    stdout.writeln('${report.unknownIds.length} page(s) carry an id the file does not have: '
        '${report.unknownIds.join(', ')}');
  }
}
