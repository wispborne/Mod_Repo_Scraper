import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/bot/scraper/qb/models/assumed_download.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/forum_data_bundle.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_summary.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/post_extraction.dart';
import 'package:mod_repo_scraper/bot/scraper/scraped_mod.dart';
import 'package:mod_repo_scraper/catalog/fact_choice.dart';
import 'package:mod_repo_scraper/catalog/listing.dart';
import 'package:mod_repo_scraper/catalog/mod_catalog.dart';
import 'package:mod_repo_scraper/catalog/source_post.dart';
import 'package:mod_repo_scraper/site/fact_sources_file.dart';
import 'package:mod_repo_scraper/site/public_data_builder.dart';
import 'package:mod_repo_scraper/site/public_site_step.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Where each published fact came from: [chooseFactsWithSources], the
/// builder's own choices, and `fact-sources.json`.
void main() {
  const forumRef = SourcePostRef(kind: SourceKind.forum, id: '9175', llmModName: 'Nexerelin');
  const discordRef = SourcePostRef(kind: SourceKind.discord, id: '555', llmModName: 'Nex');

  LlmMod llmMod({String name = 'Nexerelin', List<String> downloads = const [], List<String>? nicknames, LlmExtras? extras}) =>
      LlmMod(
        name: name,
        nicknames: nicknames,
        downloads: [for (final url in downloads) LlmDownload(url: url)],
        extras: extras,
      );

  group('chooseFactsWithSources', () {
    test('names the answer each field was taken from', () {
      final chosen = chooseFactsWithSources([
        FactSource(llmMod(name: 'Nex', downloads: ['https://e/d.zip'], extras: LlmExtras(version: '1.3', license: 'GPL')),
            SourceKind.discord, ref: discordRef),
        FactSource(llmMod(downloads: ['https://e/f.zip'], extras: LlmExtras(version: '1.2', needs: ['LazyLib'])),
            SourceKind.forum, ref: forumRef),
      ])!;

      expect(chosen.facts.extras!.version, '1.3');
      expect(chosen.sources['version'], const FactOrigin.post(discordRef));
      expect(chosen.sources['license'], const FactOrigin.post(discordRef));
      expect(chosen.sources['needs'], const FactOrigin.post(forumRef));
      expect(chosen.sources['downloads'], const FactOrigin.post(forumRef));
      expect(chosen.sources['name'], const FactOrigin.post(forumRef));
      expect(chosen.sources.containsKey('changelog'), isFalse);
    });

    test('nicknames from two answers are merged, and say which', () {
      final chosen = chooseFactsWithSources([
        FactSource(llmMod(nicknames: ['Nex']), SourceKind.forum, ref: forumRef),
        FactSource(llmMod(name: 'Nex', nicknames: ['Nexerelin X']), SourceKind.discord, ref: discordRef),
      ])!;

      final origin = chosen.sources['nicknames']!;
      expect(origin.toJson(), 'merged');
      expect(origin.fromJson(), [
        {'kind': 'forum', 'id': '9175', 'llmName': 'Nexerelin'},
        {'kind': 'discord', 'id': '555', 'llmName': 'Nex'},
      ]);
    });

    test('chooseFacts still gives the same facts', () {
      final sources = [
        FactSource(llmMod(extras: LlmExtras(license: 'MIT')), SourceKind.discord),
        FactSource(llmMod(extras: LlmExtras(needs: ['MagicLib'])), SourceKind.forum),
      ];
      expect(chooseFacts(sources)!.toMap(), chooseFactsWithSources(sources)!.facts.toMap());
    });

    test('a source written out reads back the same', () {
      for (final origin in [
        const FactOrigin.post(forumRef),
        FactOrigin.rules,
        FactOrigin.merged,
        FactOrigin.several([forumRef, discordRef]),
      ]) {
        expect(FactOrigin.read(origin.toJson(), origin.fromJson()), origin);
      }
    });
  });

  group('the website build', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('fact_sources'));
    tearDown(() => dir.deleteSync(recursive: true));

    final mod = ScrapedMod(
      name: 'Nexerelin',
      gameVersionReq: '0.98a',
      authorsList: const ['Histidine'],
      sources: const [ModSource.Index, ModSource.Discord],
      urls: {
        ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=9175.0',
        ModUrlType.Discord: 'https://discord.com/channels/1/555',
      },
    );
    final catalog = ModCatalog(
      generatedAt: DateTime.utc(2026, 11, 5, 12),
      mods: [
        CatalogMod(id: 'nexerelin', mod: mod, sourcePosts: const [
          CatalogSourcePost(kind: SourceKind.forum, id: '9175', llmModName: 'Nexerelin'),
          CatalogSourcePost(kind: SourceKind.discord, id: '555', llmModName: 'Nex', foundBy: ListingOrigin.llm),
        ]),
      ],
    );
    final bundle = ForumDataBundle(
      updatedAt: DateTime.utc(2026, 11, 5),
      index: [
        QbModSummary(
          topicId: 9175,
          title: '[0.98a] Nexerelin',
          llm: LlmThreadData(mods: [
            llmMod(downloads: ['https://e/nex.zip'], extras: LlmExtras(version: '0.12.1', license: 'MIT')),
          ]),
        ),
      ],
      discordThreads: [
        DiscordThreadAnswer(threadId: '555', name: 'Nex', mods: [
          llmMod(name: 'Nex', extras: LlmExtras(version: '0.12.2', needs: ['LazyLib'])),
        ]),
      ],
    );

    test('records each published field by its published name', () {
      final data = PublicDataBuilder(outputPath: p.join(dir.path, 'outputs'))
          .build(mods: catalog.mods, bundle: bundle);
      final sources = data.factSources['nexerelin']!;

      expect(sources['modVersion'], const FactOrigin.post(discordRef));
      expect(sources['license'], const FactOrigin.post(forumRef));
      expect(sources['needs'], const FactOrigin.post(discordRef));
      expect(sources['downloads'], const FactOrigin.post(forumRef));
      expect(sources['gameVersion'], FactOrigin.merged);
      expect(sources['authors'], FactOrigin.merged);
      // Nothing published, nothing recorded.
      expect(sources.containsKey('changelog'), isFalse);
    });

    test('downloads the rules found say so', () {
      final noLlm = ForumDataBundle(
        updatedAt: DateTime.utc(2026, 11, 5),
        index: [QbModSummary(topicId: 9175, title: '[0.98a] Nexerelin')],
        assumedDownloads: {
          '9175': [AssumedDownloadCandidate(originalUrl: 'https://e/rules.zip', resolvedDirectUrl: 'https://e/rules.zip', fileName: 'rules.zip')],
        },
      );
      final data = PublicDataBuilder(outputPath: p.join(dir.path, 'outputs'))
          .build(mods: [
        CatalogMod(id: 'nexerelin', mod: mod, sourcePosts: const [CatalogSourcePost(kind: SourceKind.forum, id: '9175')]),
      ], bundle: noLlm);
      expect(data.factSources['nexerelin']!['downloads'], FactOrigin.rules);
    });

    test('is saved for the viewer under the catalog build time, and not published', () async {
      final outputs = p.join(dir.path, 'outputs');
      final dataPath = p.join(dir.path, 'qb_data');
      Directory(outputs).createSync(recursive: true);
      File(p.join(outputs, 'mod-catalog-details.json')).writeAsStringSync(bundle.toJson());

      await PublicSiteStep(dataPath: dataPath, outputPath: outputs).afterMerge(catalog: catalog);

      final file = FactSourcesFile.fileIn(dataPath);
      expect(file.existsSync(), isTrue);
      final saved = FactSourcesFile.fromMap(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
      expect(saved.builtAt, catalog.generatedAt);
      expect(saved.mods.keys, ['nexerelin']);
      expect(saved.mods['nexerelin']!['modVersion'], const FactOrigin.post(discordRef));
      expect(
        Directory(outputs).listSync(recursive: true).where((f) => p.basename(f.path) == FactSourcesFile.fileName),
        isEmpty,
      );
    });
  });
}
