import 'package:mod_repo_scraper/manager/job.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(JobRequestMapper.ensureInitialized);

  group('merge job requests', () {
    test('a scrape-and-merge request survives the trip through JSON', () {
      final request = JobRequest.scrapeAndMerge(
        sources: {ModSourceKind.forum, ModSourceKind.nexus},
        modForumPages: 3,
        moddingForumPages: 2,
        keepAllGameVersions: true,
        collectMergeDebug: true,
      );

      final copy = JobRequestMapper.fromMap(request.toMap());

      expect(copy.kind, JobKind.scrapeAndMerge);
      expect(copy.modSources, {ModSourceKind.forum, ModSourceKind.nexus});
      expect(copy.modForumPages, 3);
      expect(copy.moddingForumPages, 2);
      expect(copy.keepAllGameVersions, isTrue);
      expect(copy.collectMergeDebug, isTrue);
      expect(copy.isMergeKind, isTrue);
    });

    test('a merge-from-saved-files request asks for no sources work', () {
      final request = JobRequest.mergeModRepo();
      final copy = JobRequestMapper.fromMap(request.toMap());

      expect(copy.kind, JobKind.mergeModRepo);
      expect(copy.isMergeKind, isTrue);
      expect(copy.runLlm, isFalse);
      expect(copy.replayAllowed, isFalse);
    });

    test('the QB kinds are not merge kinds', () {
      expect(JobRequest.fullRun().isMergeKind, isFalse);
      expect(JobRequest.rebuildBundle().isMergeKind, isFalse);
      expect(JobRequest.llmCoveragePass().isMergeKind, isFalse);
    });

    // The whole point of the request/environment split: a request says what to
    // do, never where to do it or with whose key.
    test('a request cannot name a path, a token, or an endpoint', () {
      final fields = JobRequest.scrapeAndMerge().toMap().keys.map(
            (k) => k.toLowerCase(),
          );

      for (final banned in [
        'path',
        'dir',
        'folder',
        'token',
        'key',
        'url',
        'secret'
      ]) {
        expect(fields.where((f) => f.contains(banned)), isEmpty,
            reason: 'no job request field may mention "$banned"');
      }
    });
  });
}
