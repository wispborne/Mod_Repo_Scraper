import 'package:dart_mappable/dart_mappable.dart';

import '../scraped_mod.dart';

part 'merge_debug_data.mapper.dart';

/// Timing information for a merge phase.
@MappableClass()
class PhaseTiming with PhaseTimingMappable {
  final String phaseName;
  final int durationMs;

  PhaseTiming(this.phaseName, this.durationMs);
}

/// A single pre-dedup removal decision.
@MappableClass()
class PreDedupEntry with PreDedupEntryMappable {
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
@MappableEnum()
enum GroupMatchReason { nameAndAuthor, forumUrl }

/// A single match decision within a group.
@MappableClass()
class GroupMatchEntry with GroupMatchEntryMappable {
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
@MappableClass()
class DebugModGroup with DebugModGroupMappable {
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
@MappableClass()
class SameSourceDedupEntry with SameSourceDedupEntryMappable {
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
@MappableEnum()
enum MergePriorityReason { indexSource, higherGameVersion, fallback }

/// A single reduce step during merge.
@MappableClass()
class MergeStepEntry with MergeStepEntryMappable {
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
@MappableClass()
class MergeDecision with MergeDecisionMappable {
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
@MappableClass()
class ValidationRemoval with ValidationRemovalMappable {
  final ScrapedMod mod;
  final String reason;

  ValidationRemoval({required this.mod, required this.reason});
}

/// Top-level container for all debug data collected during a merge run.
@MappableClass()
class MergeDebugData with MergeDebugDataMappable {
  int inputCount;
  int afterPreDedupCount;
  int groupsCreated;
  int finalCount;

  final List<PhaseTiming> timings;
  final List<PreDedupEntry> preDedupEntries;
  final List<DebugModGroup> groups;
  final List<SameSourceDedupEntry> sameSourceDedupEntries;
  final List<MergeDecision> mergeDecisions;
  final List<ValidationRemoval> validationRemovalEntries;
  final List<ScrapedMod> finalOutput;

  MergeDebugData({
    this.inputCount = 0,
    this.afterPreDedupCount = 0,
    this.groupsCreated = 0,
    this.finalCount = 0,
    List<PhaseTiming>? timings,
    List<PreDedupEntry>? preDedupEntries,
    List<DebugModGroup>? groups,
    List<SameSourceDedupEntry>? sameSourceDedupEntries,
    List<MergeDecision>? mergeDecisions,
    List<ValidationRemoval>? validationRemovalEntries,
    List<ScrapedMod>? finalOutput,
  })  : timings = timings ?? [],
        preDedupEntries = preDedupEntries ?? [],
        groups = groups ?? [],
        sameSourceDedupEntries = sameSourceDedupEntries ?? [],
        mergeDecisions = mergeDecisions ?? [],
        validationRemovalEntries = validationRemovalEntries ?? [],
        finalOutput = finalOutput ?? [];
}
