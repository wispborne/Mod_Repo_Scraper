import '../scraped_mod.dart';

/// Timing information for a merge phase.
class PhaseTiming {
  final String phaseName;
  final int durationMs;

  PhaseTiming(this.phaseName, this.durationMs);
}

/// A single pre-dedup removal decision.
class PreDedupEntry {
  final ScrapedMod kept;
  final ScrapedMod discarded;
  final String reason;
  final int keptRichness;
  final int discardedRichness;

  PreDedupEntry({
    required this.kept,
    required this.discarded,
    required this.reason,
    required this.keptRichness,
    required this.discardedRichness,
  });
}

/// Why two mods were matched during grouping.
enum GroupMatchReason { nameAndAuthor, forumUrl }

/// A single match decision within a group.
class GroupMatchEntry {
  final ScrapedMod outerMod;
  final ScrapedMod innerMod;
  final Set<GroupMatchReason> reasons;
  final int? nameScore;
  final int? authorScore;
  final double? nameLengthRatio;
  final String? matchedForumTopicId;

  GroupMatchEntry({
    required this.outerMod,
    required this.innerMod,
    required this.reasons,
    this.nameScore,
    this.authorScore,
    this.nameLengthRatio,
    this.matchedForumTopicId,
  });
}

/// A complete mod group with its match explanations.
class DebugModGroup {
  final int groupIndex;
  final List<ScrapedMod> members;
  final List<GroupMatchEntry> matchEntries;

  DebugModGroup({
    required this.groupIndex,
    required this.members,
    required this.matchEntries,
  });
}

/// A same-source dedup decision.
class SameSourceDedupEntry {
  final ScrapedMod kept;
  final ScrapedMod discarded;
  final ModSource source;
  final String? keptGameVersion;
  final String? discardedGameVersion;
  final bool wasSafetyBlocked;
  final double? nameLengthRatio;

  SameSourceDedupEntry({
    required this.kept,
    required this.discarded,
    required this.source,
    this.keptGameVersion,
    this.discardedGameVersion,
    this.wasSafetyBlocked = false,
    this.nameLengthRatio,
  });
}

/// Priority reasoning for a merge step.
enum MergePriorityReason { indexSource, higherGameVersion, fallback }

/// A single reduce step during merge.
class MergeStepEntry {
  final ScrapedMod left;
  final ScrapedMod right;
  final MergePriorityReason reason;
  final bool doesRightHavePriority;
  final ScrapedMod result;

  MergeStepEntry({
    required this.left,
    required this.right,
    required this.reason,
    required this.doesRightHavePriority,
    required this.result,
  });
}

/// Full merge decision for a group.
class MergeDecision {
  final int groupIndex;
  final List<ScrapedMod> inputMods;
  final List<MergeStepEntry> steps;
  final ScrapedMod finalResult;

  MergeDecision({
    required this.groupIndex,
    required this.inputMods,
    required this.steps,
    required this.finalResult,
  });
}

/// A validation removal.
class ValidationRemoval {
  final ScrapedMod mod;
  final String reason;

  ValidationRemoval({required this.mod, required this.reason});
}

/// Top-level container for all debug data collected during a merge run.
class MergeDebugData {
  int inputCount = 0;
  int afterPreDedupCount = 0;
  int groupsCreated = 0;
  int finalCount = 0;

  final List<PhaseTiming> timings = [];
  final List<PreDedupEntry> preDedupEntries = [];
  final List<DebugModGroup> groups = [];
  final List<SameSourceDedupEntry> sameSourceDedupEntries = [];
  final List<MergeDecision> mergeDecisions = [];
  final List<ValidationRemoval> validationRemovalEntries = [];
  final List<ScrapedMod> finalOutput = [];
}
