import 'dart:io';

import 'package:mod_repo_scraper/manager/bundle_snapshot_store.dart';
import 'package:mod_repo_scraper/viewer/bundle_views.dart';
import 'package:test/test.dart';

void main() {
  late Directory dataDir;

  setUp(() async {
    dataDir = await Directory.systemTemp.createTemp('bundle_extra_posts');
  });

  tearDown(() async {
    if (await dataDir.exists()) await dataDir.delete(recursive: true);
  });

  /// A bundle holding one thread whose author posted twice.
  Map<String, dynamic> bundleWith({
    String firstPost = '<p>What this is.</p>',
    List<String> laterPosts = const ['<p>Downloads live here.</p>'],
  }) =>
      {
        'updatedAt': '2026-08-25T12:00:00Z',
        'index': [
          {'topicId': 35651, 'title': 'Faction Forks', 'author': 'Computica'},
        ],
        'details': {
          '35651': {
            'topicId': 35651,
            'title': 'Faction Forks',
            'contentHtml': firstPost,
            'images': <dynamic>[],
            'extraPosts': [
              for (final post in laterPosts)
                {
                  'contentHtml': post,
                  'images': <dynamic>[],
                  'links': <dynamic>[],
                  'postDate': 'June 26, 2026, 06:50:19 PM',
                },
            ],
          },
        },
        'assumedDownloads': <String, dynamic>{},
      };

  /// A bundle from before follow-up posts were read at all.
  Map<String, dynamic> oldBundle() => {
        'updatedAt': '2026-08-01T12:00:00Z',
        'index': [
          {'topicId': 35651, 'title': 'Faction Forks', 'author': 'Computica'},
        ],
        'details': {
          '35651': {
            'topicId': 35651,
            'title': 'Faction Forks',
            'contentHtml': '<p>What this is.</p>',
            'images': <dynamic>[],
          },
        },
        'assumedDownloads': <String, dynamic>{},
      };

  Map<dynamic, dynamic> detailOf(Map<String, dynamic> snapshot) =>
      (snapshot['details'] as Map)['35651'] as Map;

  group('a snapshot of a thread with follow-up posts', () {
    test('keeps no post text, only fingerprints', () async {
      final store = BundleSnapshotStore(dataDir.path);
      await store.save('20260825T120000Z-fullRun', bundleWith());

      final detail = detailOf(store.readRaw('20260825T120000Z-fullRun')!);
      expect(detail.containsKey('contentHtml'), isFalse);
      expect(detail[BundleSnapshotStore.fingerprintKey], isNotEmpty);

      final later = (detail['extraPosts'] as List).single as Map;
      expect(later.containsKey('contentHtml'), isFalse,
          reason: 'a follow-up post\'s words are not kept either');
      expect(later[BundleSnapshotStore.fingerprintKey], isNotEmpty);
      expect(later['postDate'], 'June 26, 2026, 06:50:19 PM',
          reason: 'everything but the text stays');
    });

    test('the same post twice fingerprints the same', () async {
      final store = BundleSnapshotStore(dataDir.path);
      await store.save('20260825T120000Z-a', bundleWith());
      await store.save('20260825T130000Z-b', bundleWith());

      final a = (detailOf(store.readRaw('20260825T120000Z-a')!)['extraPosts']
          as List).single as Map;
      final b = (detailOf(store.readRaw('20260825T130000Z-b')!)['extraPosts']
          as List).single as Map;
      expect(a[BundleSnapshotStore.fingerprintKey],
          b[BundleSnapshotStore.fingerprintKey]);
    });
  });

  group('what the diff says', () {
    test('a changed follow-up post is named, without its words', () {
      final before = BundleSnapshotStore.withoutPostText(bundleWith());
      final after = BundleSnapshotStore.withoutPostText(
          bundleWith(laterPosts: const ['<p>Downloads moved to GitHub.</p>']));

      final changes = topicChanges(
          _topicOf(before, 35651)!, _topicOf(after, 35651)!);
      final field = changes.single;
      expect(field['field'], 'the author\'s other posts');

      final item = (field['items'] as List).single as Map;
      expect(item['change'], 'changed');
      expect(item['label'], 'the author\'s post 2');

      final part = (item['parts'] as List).single as Map;
      expect(part['name'], 'post text');
      expect(part['note'], contains('changed'));
      expect(part.containsKey('before'), isFalse,
          reason: 'the words are not kept, so there is nothing to show');
    });

    test('an added follow-up post is reported as added', () {
      final before = BundleSnapshotStore.withoutPostText(
          bundleWith(laterPosts: const []));
      final after = BundleSnapshotStore.withoutPostText(bundleWith());

      final changes =
          topicChanges(_topicOf(before, 35651)!, _topicOf(after, 35651)!);
      final item = (changes.single['items'] as List).single as Map;
      expect(item['change'], 'added');
      expect(item['label'], 'the author\'s post 2');
    });

    test('a thread that gained no posts reads as unchanged at the seam', () {
      // The older snapshot was saved before follow-up posts existed, so it has
      // no such field at all. A thread that still has none must not be reported
      // as changed.
      final before = BundleSnapshotStore.withoutPostText(oldBundle());
      final after = BundleSnapshotStore.withoutPostText(
          bundleWith(laterPosts: const []));

      final changes =
          topicChanges(_topicOf(before, 35651)!, _topicOf(after, 35651)!);
      expect(changes, isEmpty,
          reason: 'nothing about the thread actually moved');
    });

    test('the first post is untouched by a follow-up post changing', () {
      final before = BundleSnapshotStore.withoutPostText(bundleWith());
      final after = BundleSnapshotStore.withoutPostText(
          bundleWith(laterPosts: const ['<p>Different.</p>']));

      final fields =
          topicChanges(_topicOf(before, 35651)!, _topicOf(after, 35651)!)
              .map((c) => c['field'])
              .toList();
      expect(fields, isNot(contains('post text')));
    });
  });
}

Map<String, dynamic>? _topicOf(Map<String, dynamic> snapshot, int topicId) =>
    topicRecordOf(snapshot, topicId);
