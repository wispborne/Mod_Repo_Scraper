import '../scraped_mod.dart';
import 'merge_debug_data.dart';

/// Collects structured debug data during the merge process.
///
/// When `generate_debug_html` is false, ModMerger holds a null reference
/// to this class, so no collection methods are ever called.
class MergeDebugCollector {
  final MergeDebugData data = MergeDebugData();

  void setInputCount(int count) => data.inputCount = count;

  void setAfterPreDedupCount(int count) => data.afterPreDedupCount = count;

  void setGroupsCreated(int count) => data.groupsCreated = count;

  void setFinalCount(int count) => data.finalCount = count;

  void addTiming(String phase, int durationMs) =>
      data.timings.add(PhaseTiming(phase, durationMs));

  void recordPreDedupRemoval(PreDedupEntry entry) =>
      data.preDedupEntries.add(entry);

  void recordGroup(DebugModGroup group) => data.groups.add(group);

  void recordSameSourceDedup(SameSourceDedupEntry entry) =>
      data.sameSourceDedupEntries.add(entry);

  void recordMergeDecision(MergeDecision decision) =>
      data.mergeDecisions.add(decision);

  void recordValidationRemoval(ValidationRemoval removal) =>
      data.validationRemovalEntries.add(removal);

  void setFinalOutput(List<ScrapedMod> mods) {
    data.finalOutput.clear();
    data.finalOutput.addAll(mods);
  }
}
