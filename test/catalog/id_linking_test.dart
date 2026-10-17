import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/bot/scraper/qb/models/bundle_meta.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/forum_data_bundle.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_summary.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/post_extraction.dart';
import 'package:mod_repo_scraper/catalog/id_linking.dart';
import 'package:mod_repo_scraper/site/mod_id_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('id_linking'));
  tearDown(() => dir.deleteSync(recursive: true));

  const hartley = 'https://fractalsoftworks.com/forum/index.php?topic=34161.0';

  void page(String id, String name, {String? forumUrl, String? discordUrl, String? partOfThreadTitle}) {
    final modsDir = Directory(p.join(dir.path, 'site', 'mods'))..createSync(recursive: true);
    File(p.join(modsDir.path, '$id.json')).writeAsStringSync(jsonEncode({
      'listing': {
        'id': id,
        'name': name,
        if (forumUrl != null) 'forumUrl': forumUrl,
        if (discordUrl != null) 'discordUrl': discordUrl,
        if (partOfThreadTitle != null) 'partOfThreadTitle': partOfThreadTitle,
      },
    }));
  }

  ForumDataBundle bundle() => ForumDataBundle(
        updatedAt: DateTime.utc(2026),
        meta: BundleMeta(generatedAt: DateTime.utc(2026)),
        index: [
          QbModSummary(
            topicId: 34161,
            title: "Hartley's Miscellaneous Mods",
            llm: LlmThreadData(mods: [
              for (final name in ['Useful.Tithes', 'Big Pilum Energy', 'Lost.Sector', 'Disco.Balls']) LlmMod(name: name),
            ]),
          ),
        ],
      );

  ModIdStore storeWith(List<String> names) {
    final ids = ModIdStore(dir.path)..load();
    for (final name in names) {
      ids.idFor(name);
    }
    ids.save();
    return ModIdStore(dir.path)..load();
  }

  test("mods sharing a topic each get the LLM's name in their link", () {
    final ids = storeWith(['Useful.Tithes 1.0.a', 'Big Pilum Energy 1.0.d', 'Lost.Sector']);
    // Merged mods, named by the merge.
    page('useful-tithes-1-0-a', 'Useful.Tithes 1.0.a',
        forumUrl: hartley, discordUrl: 'https://discord.com/channels/1/1424047145354268672/1424047145354268672');
    page('big-pilum-energy-1-0-d', 'Big Pilum Energy 1.0.d', forumUrl: hartley);
    // A thread-only mod, published under the LLM's own name.
    page('lost-sector', 'Lost.Sector', forumUrl: hartley, partOfThreadTitle: "Hartley's Miscellaneous Mods");

    linkIdsFromPublishedSite(ids: ids, modsDir: Directory(p.join(dir.path, 'site', 'mods')), bundle: bundle());

    expect(ids.postsOfId('useful-tithes-1-0-a'), containsAll(['forum:34161#Useful.Tithes', 'discord:1424047145354268672']));
    expect(ids.postsOfId('big-pilum-energy-1-0-d'), ['forum:34161#Big Pilum Energy']);
    expect(ids.postsOfId('lost-sector'), ['forum:34161#Lost.Sector']);
  });

  test('running it twice gives the same file', () {
    var ids = storeWith(['Nexerelin', 'Useful.Tithes 1.0.a']);
    page('nexerelin', 'Nexerelin', forumUrl: 'https://fractalsoftworks.com/forum/index.php?topic=9175.0');
    page('useful-tithes-1-0-a', 'Useful.Tithes 1.0.a', forumUrl: hartley);
    final modsDir = Directory(p.join(dir.path, 'site', 'mods'));

    linkIdsFromPublishedSite(ids: ids, modsDir: modsDir, bundle: bundle());
    ids.save();
    final first = File(ids.filePath).readAsStringSync();

    ids = ModIdStore(dir.path)..load();
    linkIdsFromPublishedSite(ids: ids, modsDir: modsDir, bundle: bundle());
    ids.save();
    expect(File(ids.filePath).readAsStringSync(), first);
    expect(ids.postsOfId('nexerelin'), ['forum:9175']);
  });

  test('a page whose id the file does not have is reported, not invented', () {
    final ids = storeWith(['Nexerelin']);
    page('lost-page', 'Lost Page', forumUrl: 'https://fractalsoftworks.com/forum/index.php?topic=1.0');

    final report = linkIdsFromPublishedSite(ids: ids, modsDir: Directory(p.join(dir.path, 'site', 'mods')));
    expect(report.unknownIds, ['lost-page']);
  });
}
