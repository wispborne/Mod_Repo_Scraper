import 'package:mod_repo_scraper/bot/scraper/debug/merge_debug_data.dart';
import 'package:mod_repo_scraper/bot/scraper/scraped_mod.dart';
import 'package:test/test.dart';

/// Verifies the newly annotated MergeDebugData survives a JSON round-trip with
/// every section populated (5.2), so the viewer's merge endpoints read the same
/// shape the scraper writes.
void main() {
  setUpAll(MergeDebugDataMapper.ensureInitialized);

  ScrapedMod mod(String name, String author, String version, ModSource source) =>
      ScrapedMod(
        name: name,
        authorsList: [author],
        gameVersionReq: version,
        sources: [source],
        urls: {ModUrlType.Forum: 'https://example/$name'},
      );

  test('all sections round-trip through toMap/fromMap', () {
    final a = mod('Alpha', 'Ann', '0.98a', ModSource.Index);
    final b = mod('Alpha Mod', 'Ann', '0.97a', ModSource.Discord);
    final merged = mod('Alpha', 'Ann', '0.98a', ModSource.Index);

    final data = MergeDebugData(
      inputCount: 3,
      afterPreDedupCount: 2,
      groupsCreated: 1,
      finalCount: 1,
    )
      ..timings.add(PhaseTiming('grouping', 42))
      ..preDedupEntries.add(PreDedupEntry(
        kept: a,
        discarded: b,
        reason: 'exact-duplicate',
        keptRichness: 5,
        discardedRichness: 3,
      ))
      ..groups.add(DebugModGroup(
        groupIndex: 0,
        members: [a, b],
        matchEntries: [
          GroupMatchEntry(
            outerMod: a,
            innerMod: b,
            reasons: {GroupMatchReason.nameAndAuthor, GroupMatchReason.forumUrl},
            nameScore: 90,
            authorScore: 100,
            nameLengthRatio: 0.8,
            matchedForumTopicId: '7958',
          ),
        ],
      ))
      ..sameSourceDedupEntries.add(SameSourceDedupEntry(
        kept: a,
        discarded: b,
        source: ModSource.Discord,
        keptGameVersion: '0.98a',
        discardedGameVersion: '0.97a',
        wasSafetyBlocked: true,
        nameLengthRatio: 0.9,
      ))
      ..mergeDecisions.add(MergeDecision(
        groupIndex: 0,
        inputMods: [a, b],
        steps: [
          MergeStepEntry(
            left: a,
            right: b,
            reason: MergePriorityReason.higherGameVersion,
            doesRightHavePriority: false,
            result: merged,
          ),
        ],
        finalResult: merged,
      ))
      ..validationRemovalEntries
          .add(ValidationRemoval(mod: b, reason: 'empty-name'))
      ..finalOutput.add(merged);

    final map = data.toMap();
    final restored = MergeDebugDataMapper.fromMap(map);

    expect(restored.inputCount, 3);
    expect(restored.afterPreDedupCount, 2);
    expect(restored.groupsCreated, 1);
    expect(restored.finalCount, 1);

    expect(restored.timings.single.phaseName, 'grouping');
    expect(restored.timings.single.durationMs, 42);

    expect(restored.preDedupEntries.single.reason, 'exact-duplicate');
    expect(restored.preDedupEntries.single.kept.name, 'Alpha');

    final group = restored.groups.single;
    expect(group.members, hasLength(2));
    final match = group.matchEntries.single;
    expect(match.reasons,
        containsAll([GroupMatchReason.nameAndAuthor, GroupMatchReason.forumUrl]));
    expect(match.matchedForumTopicId, '7958');

    final dedup = restored.sameSourceDedupEntries.single;
    expect(dedup.source, ModSource.Discord);
    expect(dedup.wasSafetyBlocked, isTrue);

    final decision = restored.mergeDecisions.single;
    expect(decision.steps.single.reason, MergePriorityReason.higherGameVersion);
    expect(decision.finalResult.name, 'Alpha');

    expect(restored.validationRemovalEntries.single.reason, 'empty-name');
    expect(restored.finalOutput.single.name, 'Alpha');
  });
}
