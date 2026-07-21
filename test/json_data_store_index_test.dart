import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:mod_repo_scraper/bot/scraper/qb/json_data_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_summary.dart';

/// The index is what tells the next run "I already have this topic". It used to
/// be written only once the whole scrape had finished, so a run that was
/// interrupted left every detail file it had saved with nothing pointing at
/// them, and the next run scraped them all again. It is now written as the
/// scrape goes along.
void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('jds_index_');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  File indexFile() => File(p.join(tmp.path, 'mods-index.json'));

  List<dynamic> readIndex() =>
      jsonDecode(indexFile().readAsStringSync()) as List<dynamic>;

  QbModSummary summary(int topicId) =>
      QbModSummary(topicId: topicId, title: 'Mod $topicId');

  test('saveIndexIfDue writes once a batch of topics has finished', () async {
    final store = JsonDataStore(tmp.path);
    final mods = <QbModSummary>[];

    // Nine topics is not yet a batch, so nothing is on disk.
    for (var i = 0; i < 9; i++) {
      mods.add(summary(i));
      await store.saveIndexIfDue(List.of(mods));
    }
    expect(indexFile().existsSync(), isFalse,
        reason: 'should not write on every single topic');

    // The tenth completes the batch and triggers the write.
    mods.add(summary(9));
    await store.saveIndexIfDue(List.of(mods));

    expect(indexFile().existsSync(), isTrue);
    expect(readIndex(), hasLength(10));
  });

  test('an interrupted run leaves an index naming the topics it finished',
      () async {
    final store = JsonDataStore(tmp.path);
    final mods = <QbModSummary>[];

    // 25 topics scraped, then the run dies before any final save.
    for (var i = 0; i < 25; i++) {
      mods.add(summary(i));
      await store.saveIndexIfDue(List.of(mods));
    }

    // The last partial batch (21-25) is not written, but the 20 before it are:
    // the next run picks those up instead of re-scraping them.
    final saved = await JsonDataStore(tmp.path).loadIndex();
    expect(saved, hasLength(20));
  });

  test('saveIndex starts the next batch from scratch', () async {
    final store = JsonDataStore(tmp.path);
    final mods = [for (var i = 0; i < 5; i++) summary(i)];

    // A final save part-way through a batch...
    await store.saveIndex(List.of(mods));
    expect(readIndex(), hasLength(5));

    // ...means the next batch needs a full 10 topics of its own, not 5.
    for (var i = 5; i < 14; i++) {
      mods.add(summary(i));
      await store.saveIndexIfDue(List.of(mods));
    }
    expect(readIndex(), hasLength(5), reason: 'batch not full yet');

    mods.add(summary(14));
    await store.saveIndexIfDue(List.of(mods));
    expect(readIndex(), hasLength(15));
  });

  test('the index written as the run goes is the same shape as the final one',
      () async {
    final store = JsonDataStore(tmp.path);
    final mods = <QbModSummary>[];

    for (var i = 0; i < 10; i++) {
      mods.add(summary(i));
      await store.saveIndexIfDue(List.of(mods));
    }

    final reloaded = await JsonDataStore(tmp.path).loadIndex();
    expect(reloaded.map((m) => m.topicId).toSet(),
        mods.map((m) => m.topicId).toSet());
    expect(reloaded.first.title, isNotEmpty);
  });
}
