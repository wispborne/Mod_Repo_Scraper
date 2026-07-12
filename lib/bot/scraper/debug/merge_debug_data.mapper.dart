// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'merge_debug_data.dart';

class GroupMatchReasonMapper extends EnumMapper<GroupMatchReason> {
  GroupMatchReasonMapper._();

  static GroupMatchReasonMapper? _instance;
  static GroupMatchReasonMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = GroupMatchReasonMapper._());
    }
    return _instance!;
  }

  static GroupMatchReason fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  GroupMatchReason decode(dynamic value) {
    switch (value) {
      case r'nameAndAuthor':
        return GroupMatchReason.nameAndAuthor;
      case r'forumUrl':
        return GroupMatchReason.forumUrl;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(GroupMatchReason self) {
    switch (self) {
      case GroupMatchReason.nameAndAuthor:
        return r'nameAndAuthor';
      case GroupMatchReason.forumUrl:
        return r'forumUrl';
    }
  }
}

extension GroupMatchReasonMapperExtension on GroupMatchReason {
  String toValue() {
    GroupMatchReasonMapper.ensureInitialized();
    return MapperContainer.globals.toValue<GroupMatchReason>(this) as String;
  }
}

class MergePriorityReasonMapper extends EnumMapper<MergePriorityReason> {
  MergePriorityReasonMapper._();

  static MergePriorityReasonMapper? _instance;
  static MergePriorityReasonMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = MergePriorityReasonMapper._());
    }
    return _instance!;
  }

  static MergePriorityReason fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  MergePriorityReason decode(dynamic value) {
    switch (value) {
      case r'indexSource':
        return MergePriorityReason.indexSource;
      case r'higherGameVersion':
        return MergePriorityReason.higherGameVersion;
      case r'fallback':
        return MergePriorityReason.fallback;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(MergePriorityReason self) {
    switch (self) {
      case MergePriorityReason.indexSource:
        return r'indexSource';
      case MergePriorityReason.higherGameVersion:
        return r'higherGameVersion';
      case MergePriorityReason.fallback:
        return r'fallback';
    }
  }
}

extension MergePriorityReasonMapperExtension on MergePriorityReason {
  String toValue() {
    MergePriorityReasonMapper.ensureInitialized();
    return MapperContainer.globals.toValue<MergePriorityReason>(this) as String;
  }
}

class PhaseTimingMapper extends ClassMapperBase<PhaseTiming> {
  PhaseTimingMapper._();

  static PhaseTimingMapper? _instance;
  static PhaseTimingMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PhaseTimingMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'PhaseTiming';

  static String _$phaseName(PhaseTiming v) => v.phaseName;
  static const Field<PhaseTiming, String> _f$phaseName = Field(
    'phaseName',
    _$phaseName,
  );
  static int _$durationMs(PhaseTiming v) => v.durationMs;
  static const Field<PhaseTiming, int> _f$durationMs = Field(
    'durationMs',
    _$durationMs,
  );

  @override
  final MappableFields<PhaseTiming> fields = const {
    #phaseName: _f$phaseName,
    #durationMs: _f$durationMs,
  };

  static PhaseTiming _instantiate(DecodingData data) {
    return PhaseTiming(data.dec(_f$phaseName), data.dec(_f$durationMs));
  }

  @override
  final Function instantiate = _instantiate;

  static PhaseTiming fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PhaseTiming>(map);
  }

  static PhaseTiming fromJson(String json) {
    return ensureInitialized().decodeJson<PhaseTiming>(json);
  }
}

mixin PhaseTimingMappable {
  String toJson() {
    return PhaseTimingMapper.ensureInitialized().encodeJson<PhaseTiming>(
      this as PhaseTiming,
    );
  }

  Map<String, dynamic> toMap() {
    return PhaseTimingMapper.ensureInitialized().encodeMap<PhaseTiming>(
      this as PhaseTiming,
    );
  }

  PhaseTimingCopyWith<PhaseTiming, PhaseTiming, PhaseTiming> get copyWith =>
      _PhaseTimingCopyWithImpl<PhaseTiming, PhaseTiming>(
        this as PhaseTiming,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return PhaseTimingMapper.ensureInitialized().stringifyValue(
      this as PhaseTiming,
    );
  }

  @override
  bool operator ==(Object other) {
    return PhaseTimingMapper.ensureInitialized().equalsValue(
      this as PhaseTiming,
      other,
    );
  }

  @override
  int get hashCode {
    return PhaseTimingMapper.ensureInitialized().hashValue(this as PhaseTiming);
  }
}

extension PhaseTimingValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PhaseTiming, $Out> {
  PhaseTimingCopyWith<$R, PhaseTiming, $Out> get $asPhaseTiming =>
      $base.as((v, t, t2) => _PhaseTimingCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PhaseTimingCopyWith<$R, $In extends PhaseTiming, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? phaseName, int? durationMs});
  PhaseTimingCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _PhaseTimingCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PhaseTiming, $Out>
    implements PhaseTimingCopyWith<$R, PhaseTiming, $Out> {
  _PhaseTimingCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PhaseTiming> $mapper =
      PhaseTimingMapper.ensureInitialized();
  @override
  $R call({String? phaseName, int? durationMs}) => $apply(
    FieldCopyWithData({
      if (phaseName != null) #phaseName: phaseName,
      if (durationMs != null) #durationMs: durationMs,
    }),
  );
  @override
  PhaseTiming $make(CopyWithData data) => PhaseTiming(
    data.get(#phaseName, or: $value.phaseName),
    data.get(#durationMs, or: $value.durationMs),
  );

  @override
  PhaseTimingCopyWith<$R2, PhaseTiming, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PhaseTimingCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class PreDedupEntryMapper extends ClassMapperBase<PreDedupEntry> {
  PreDedupEntryMapper._();

  static PreDedupEntryMapper? _instance;
  static PreDedupEntryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PreDedupEntryMapper._());
      ScrapedModMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'PreDedupEntry';

  static ScrapedMod _$kept(PreDedupEntry v) => v.kept;
  static const Field<PreDedupEntry, ScrapedMod> _f$kept = Field('kept', _$kept);
  static ScrapedMod _$discarded(PreDedupEntry v) => v.discarded;
  static const Field<PreDedupEntry, ScrapedMod> _f$discarded = Field(
    'discarded',
    _$discarded,
  );
  static String _$reason(PreDedupEntry v) => v.reason;
  static const Field<PreDedupEntry, String> _f$reason = Field(
    'reason',
    _$reason,
  );
  static int _$keptRichness(PreDedupEntry v) => v.keptRichness;
  static const Field<PreDedupEntry, int> _f$keptRichness = Field(
    'keptRichness',
    _$keptRichness,
  );
  static int _$discardedRichness(PreDedupEntry v) => v.discardedRichness;
  static const Field<PreDedupEntry, int> _f$discardedRichness = Field(
    'discardedRichness',
    _$discardedRichness,
  );

  @override
  final MappableFields<PreDedupEntry> fields = const {
    #kept: _f$kept,
    #discarded: _f$discarded,
    #reason: _f$reason,
    #keptRichness: _f$keptRichness,
    #discardedRichness: _f$discardedRichness,
  };

  static PreDedupEntry _instantiate(DecodingData data) {
    return PreDedupEntry(
      kept: data.dec(_f$kept),
      discarded: data.dec(_f$discarded),
      reason: data.dec(_f$reason),
      keptRichness: data.dec(_f$keptRichness),
      discardedRichness: data.dec(_f$discardedRichness),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PreDedupEntry fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PreDedupEntry>(map);
  }

  static PreDedupEntry fromJson(String json) {
    return ensureInitialized().decodeJson<PreDedupEntry>(json);
  }
}

mixin PreDedupEntryMappable {
  String toJson() {
    return PreDedupEntryMapper.ensureInitialized().encodeJson<PreDedupEntry>(
      this as PreDedupEntry,
    );
  }

  Map<String, dynamic> toMap() {
    return PreDedupEntryMapper.ensureInitialized().encodeMap<PreDedupEntry>(
      this as PreDedupEntry,
    );
  }

  PreDedupEntryCopyWith<PreDedupEntry, PreDedupEntry, PreDedupEntry>
  get copyWith => _PreDedupEntryCopyWithImpl<PreDedupEntry, PreDedupEntry>(
    this as PreDedupEntry,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return PreDedupEntryMapper.ensureInitialized().stringifyValue(
      this as PreDedupEntry,
    );
  }

  @override
  bool operator ==(Object other) {
    return PreDedupEntryMapper.ensureInitialized().equalsValue(
      this as PreDedupEntry,
      other,
    );
  }

  @override
  int get hashCode {
    return PreDedupEntryMapper.ensureInitialized().hashValue(
      this as PreDedupEntry,
    );
  }
}

extension PreDedupEntryValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PreDedupEntry, $Out> {
  PreDedupEntryCopyWith<$R, PreDedupEntry, $Out> get $asPreDedupEntry =>
      $base.as((v, t, t2) => _PreDedupEntryCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PreDedupEntryCopyWith<$R, $In extends PreDedupEntry, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod> get kept;
  ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod> get discarded;
  $R call({
    ScrapedMod? kept,
    ScrapedMod? discarded,
    String? reason,
    int? keptRichness,
    int? discardedRichness,
  });
  PreDedupEntryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _PreDedupEntryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PreDedupEntry, $Out>
    implements PreDedupEntryCopyWith<$R, PreDedupEntry, $Out> {
  _PreDedupEntryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PreDedupEntry> $mapper =
      PreDedupEntryMapper.ensureInitialized();
  @override
  ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod> get kept =>
      $value.kept.copyWith.$chain((v) => call(kept: v));
  @override
  ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod> get discarded =>
      $value.discarded.copyWith.$chain((v) => call(discarded: v));
  @override
  $R call({
    ScrapedMod? kept,
    ScrapedMod? discarded,
    String? reason,
    int? keptRichness,
    int? discardedRichness,
  }) => $apply(
    FieldCopyWithData({
      if (kept != null) #kept: kept,
      if (discarded != null) #discarded: discarded,
      if (reason != null) #reason: reason,
      if (keptRichness != null) #keptRichness: keptRichness,
      if (discardedRichness != null) #discardedRichness: discardedRichness,
    }),
  );
  @override
  PreDedupEntry $make(CopyWithData data) => PreDedupEntry(
    kept: data.get(#kept, or: $value.kept),
    discarded: data.get(#discarded, or: $value.discarded),
    reason: data.get(#reason, or: $value.reason),
    keptRichness: data.get(#keptRichness, or: $value.keptRichness),
    discardedRichness: data.get(
      #discardedRichness,
      or: $value.discardedRichness,
    ),
  );

  @override
  PreDedupEntryCopyWith<$R2, PreDedupEntry, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PreDedupEntryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class GroupMatchEntryMapper extends ClassMapperBase<GroupMatchEntry> {
  GroupMatchEntryMapper._();

  static GroupMatchEntryMapper? _instance;
  static GroupMatchEntryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = GroupMatchEntryMapper._());
      ScrapedModMapper.ensureInitialized();
      GroupMatchReasonMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'GroupMatchEntry';

  static ScrapedMod _$outerMod(GroupMatchEntry v) => v.outerMod;
  static const Field<GroupMatchEntry, ScrapedMod> _f$outerMod = Field(
    'outerMod',
    _$outerMod,
  );
  static ScrapedMod _$innerMod(GroupMatchEntry v) => v.innerMod;
  static const Field<GroupMatchEntry, ScrapedMod> _f$innerMod = Field(
    'innerMod',
    _$innerMod,
  );
  static Set<GroupMatchReason> _$reasons(GroupMatchEntry v) => v.reasons;
  static const Field<GroupMatchEntry, Set<GroupMatchReason>> _f$reasons = Field(
    'reasons',
    _$reasons,
  );
  static int? _$nameScore(GroupMatchEntry v) => v.nameScore;
  static const Field<GroupMatchEntry, int> _f$nameScore = Field(
    'nameScore',
    _$nameScore,
    opt: true,
  );
  static int? _$authorScore(GroupMatchEntry v) => v.authorScore;
  static const Field<GroupMatchEntry, int> _f$authorScore = Field(
    'authorScore',
    _$authorScore,
    opt: true,
  );
  static double? _$nameLengthRatio(GroupMatchEntry v) => v.nameLengthRatio;
  static const Field<GroupMatchEntry, double> _f$nameLengthRatio = Field(
    'nameLengthRatio',
    _$nameLengthRatio,
    opt: true,
  );
  static String? _$matchedForumTopicId(GroupMatchEntry v) =>
      v.matchedForumTopicId;
  static const Field<GroupMatchEntry, String> _f$matchedForumTopicId = Field(
    'matchedForumTopicId',
    _$matchedForumTopicId,
    opt: true,
  );

  @override
  final MappableFields<GroupMatchEntry> fields = const {
    #outerMod: _f$outerMod,
    #innerMod: _f$innerMod,
    #reasons: _f$reasons,
    #nameScore: _f$nameScore,
    #authorScore: _f$authorScore,
    #nameLengthRatio: _f$nameLengthRatio,
    #matchedForumTopicId: _f$matchedForumTopicId,
  };

  static GroupMatchEntry _instantiate(DecodingData data) {
    return GroupMatchEntry(
      outerMod: data.dec(_f$outerMod),
      innerMod: data.dec(_f$innerMod),
      reasons: data.dec(_f$reasons),
      nameScore: data.dec(_f$nameScore),
      authorScore: data.dec(_f$authorScore),
      nameLengthRatio: data.dec(_f$nameLengthRatio),
      matchedForumTopicId: data.dec(_f$matchedForumTopicId),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static GroupMatchEntry fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<GroupMatchEntry>(map);
  }

  static GroupMatchEntry fromJson(String json) {
    return ensureInitialized().decodeJson<GroupMatchEntry>(json);
  }
}

mixin GroupMatchEntryMappable {
  String toJson() {
    return GroupMatchEntryMapper.ensureInitialized()
        .encodeJson<GroupMatchEntry>(this as GroupMatchEntry);
  }

  Map<String, dynamic> toMap() {
    return GroupMatchEntryMapper.ensureInitialized().encodeMap<GroupMatchEntry>(
      this as GroupMatchEntry,
    );
  }

  GroupMatchEntryCopyWith<GroupMatchEntry, GroupMatchEntry, GroupMatchEntry>
  get copyWith =>
      _GroupMatchEntryCopyWithImpl<GroupMatchEntry, GroupMatchEntry>(
        this as GroupMatchEntry,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return GroupMatchEntryMapper.ensureInitialized().stringifyValue(
      this as GroupMatchEntry,
    );
  }

  @override
  bool operator ==(Object other) {
    return GroupMatchEntryMapper.ensureInitialized().equalsValue(
      this as GroupMatchEntry,
      other,
    );
  }

  @override
  int get hashCode {
    return GroupMatchEntryMapper.ensureInitialized().hashValue(
      this as GroupMatchEntry,
    );
  }
}

extension GroupMatchEntryValueCopy<$R, $Out>
    on ObjectCopyWith<$R, GroupMatchEntry, $Out> {
  GroupMatchEntryCopyWith<$R, GroupMatchEntry, $Out> get $asGroupMatchEntry =>
      $base.as((v, t, t2) => _GroupMatchEntryCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class GroupMatchEntryCopyWith<$R, $In extends GroupMatchEntry, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod> get outerMod;
  ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod> get innerMod;
  $R call({
    ScrapedMod? outerMod,
    ScrapedMod? innerMod,
    Set<GroupMatchReason>? reasons,
    int? nameScore,
    int? authorScore,
    double? nameLengthRatio,
    String? matchedForumTopicId,
  });
  GroupMatchEntryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _GroupMatchEntryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, GroupMatchEntry, $Out>
    implements GroupMatchEntryCopyWith<$R, GroupMatchEntry, $Out> {
  _GroupMatchEntryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<GroupMatchEntry> $mapper =
      GroupMatchEntryMapper.ensureInitialized();
  @override
  ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod> get outerMod =>
      $value.outerMod.copyWith.$chain((v) => call(outerMod: v));
  @override
  ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod> get innerMod =>
      $value.innerMod.copyWith.$chain((v) => call(innerMod: v));
  @override
  $R call({
    ScrapedMod? outerMod,
    ScrapedMod? innerMod,
    Set<GroupMatchReason>? reasons,
    Object? nameScore = $none,
    Object? authorScore = $none,
    Object? nameLengthRatio = $none,
    Object? matchedForumTopicId = $none,
  }) => $apply(
    FieldCopyWithData({
      if (outerMod != null) #outerMod: outerMod,
      if (innerMod != null) #innerMod: innerMod,
      if (reasons != null) #reasons: reasons,
      if (nameScore != $none) #nameScore: nameScore,
      if (authorScore != $none) #authorScore: authorScore,
      if (nameLengthRatio != $none) #nameLengthRatio: nameLengthRatio,
      if (matchedForumTopicId != $none)
        #matchedForumTopicId: matchedForumTopicId,
    }),
  );
  @override
  GroupMatchEntry $make(CopyWithData data) => GroupMatchEntry(
    outerMod: data.get(#outerMod, or: $value.outerMod),
    innerMod: data.get(#innerMod, or: $value.innerMod),
    reasons: data.get(#reasons, or: $value.reasons),
    nameScore: data.get(#nameScore, or: $value.nameScore),
    authorScore: data.get(#authorScore, or: $value.authorScore),
    nameLengthRatio: data.get(#nameLengthRatio, or: $value.nameLengthRatio),
    matchedForumTopicId: data.get(
      #matchedForumTopicId,
      or: $value.matchedForumTopicId,
    ),
  );

  @override
  GroupMatchEntryCopyWith<$R2, GroupMatchEntry, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _GroupMatchEntryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class DebugModGroupMapper extends ClassMapperBase<DebugModGroup> {
  DebugModGroupMapper._();

  static DebugModGroupMapper? _instance;
  static DebugModGroupMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DebugModGroupMapper._());
      ScrapedModMapper.ensureInitialized();
      GroupMatchEntryMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'DebugModGroup';

  static int _$groupIndex(DebugModGroup v) => v.groupIndex;
  static const Field<DebugModGroup, int> _f$groupIndex = Field(
    'groupIndex',
    _$groupIndex,
  );
  static List<ScrapedMod> _$members(DebugModGroup v) => v.members;
  static const Field<DebugModGroup, List<ScrapedMod>> _f$members = Field(
    'members',
    _$members,
  );
  static List<GroupMatchEntry> _$matchEntries(DebugModGroup v) =>
      v.matchEntries;
  static const Field<DebugModGroup, List<GroupMatchEntry>> _f$matchEntries =
      Field('matchEntries', _$matchEntries);

  @override
  final MappableFields<DebugModGroup> fields = const {
    #groupIndex: _f$groupIndex,
    #members: _f$members,
    #matchEntries: _f$matchEntries,
  };

  static DebugModGroup _instantiate(DecodingData data) {
    return DebugModGroup(
      groupIndex: data.dec(_f$groupIndex),
      members: data.dec(_f$members),
      matchEntries: data.dec(_f$matchEntries),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static DebugModGroup fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<DebugModGroup>(map);
  }

  static DebugModGroup fromJson(String json) {
    return ensureInitialized().decodeJson<DebugModGroup>(json);
  }
}

mixin DebugModGroupMappable {
  String toJson() {
    return DebugModGroupMapper.ensureInitialized().encodeJson<DebugModGroup>(
      this as DebugModGroup,
    );
  }

  Map<String, dynamic> toMap() {
    return DebugModGroupMapper.ensureInitialized().encodeMap<DebugModGroup>(
      this as DebugModGroup,
    );
  }

  DebugModGroupCopyWith<DebugModGroup, DebugModGroup, DebugModGroup>
  get copyWith => _DebugModGroupCopyWithImpl<DebugModGroup, DebugModGroup>(
    this as DebugModGroup,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return DebugModGroupMapper.ensureInitialized().stringifyValue(
      this as DebugModGroup,
    );
  }

  @override
  bool operator ==(Object other) {
    return DebugModGroupMapper.ensureInitialized().equalsValue(
      this as DebugModGroup,
      other,
    );
  }

  @override
  int get hashCode {
    return DebugModGroupMapper.ensureInitialized().hashValue(
      this as DebugModGroup,
    );
  }
}

extension DebugModGroupValueCopy<$R, $Out>
    on ObjectCopyWith<$R, DebugModGroup, $Out> {
  DebugModGroupCopyWith<$R, DebugModGroup, $Out> get $asDebugModGroup =>
      $base.as((v, t, t2) => _DebugModGroupCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class DebugModGroupCopyWith<$R, $In extends DebugModGroup, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, ScrapedMod, ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod>>
  get members;
  ListCopyWith<
    $R,
    GroupMatchEntry,
    GroupMatchEntryCopyWith<$R, GroupMatchEntry, GroupMatchEntry>
  >
  get matchEntries;
  $R call({
    int? groupIndex,
    List<ScrapedMod>? members,
    List<GroupMatchEntry>? matchEntries,
  });
  DebugModGroupCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _DebugModGroupCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, DebugModGroup, $Out>
    implements DebugModGroupCopyWith<$R, DebugModGroup, $Out> {
  _DebugModGroupCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<DebugModGroup> $mapper =
      DebugModGroupMapper.ensureInitialized();
  @override
  ListCopyWith<$R, ScrapedMod, ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod>>
  get members => ListCopyWith(
    $value.members,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(members: v),
  );
  @override
  ListCopyWith<
    $R,
    GroupMatchEntry,
    GroupMatchEntryCopyWith<$R, GroupMatchEntry, GroupMatchEntry>
  >
  get matchEntries => ListCopyWith(
    $value.matchEntries,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(matchEntries: v),
  );
  @override
  $R call({
    int? groupIndex,
    List<ScrapedMod>? members,
    List<GroupMatchEntry>? matchEntries,
  }) => $apply(
    FieldCopyWithData({
      if (groupIndex != null) #groupIndex: groupIndex,
      if (members != null) #members: members,
      if (matchEntries != null) #matchEntries: matchEntries,
    }),
  );
  @override
  DebugModGroup $make(CopyWithData data) => DebugModGroup(
    groupIndex: data.get(#groupIndex, or: $value.groupIndex),
    members: data.get(#members, or: $value.members),
    matchEntries: data.get(#matchEntries, or: $value.matchEntries),
  );

  @override
  DebugModGroupCopyWith<$R2, DebugModGroup, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _DebugModGroupCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class SameSourceDedupEntryMapper extends ClassMapperBase<SameSourceDedupEntry> {
  SameSourceDedupEntryMapper._();

  static SameSourceDedupEntryMapper? _instance;
  static SameSourceDedupEntryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SameSourceDedupEntryMapper._());
      ScrapedModMapper.ensureInitialized();
      ModSourceMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'SameSourceDedupEntry';

  static ScrapedMod _$kept(SameSourceDedupEntry v) => v.kept;
  static const Field<SameSourceDedupEntry, ScrapedMod> _f$kept = Field(
    'kept',
    _$kept,
  );
  static ScrapedMod _$discarded(SameSourceDedupEntry v) => v.discarded;
  static const Field<SameSourceDedupEntry, ScrapedMod> _f$discarded = Field(
    'discarded',
    _$discarded,
  );
  static ModSource _$source(SameSourceDedupEntry v) => v.source;
  static const Field<SameSourceDedupEntry, ModSource> _f$source = Field(
    'source',
    _$source,
  );
  static String? _$keptGameVersion(SameSourceDedupEntry v) => v.keptGameVersion;
  static const Field<SameSourceDedupEntry, String> _f$keptGameVersion = Field(
    'keptGameVersion',
    _$keptGameVersion,
    opt: true,
  );
  static String? _$discardedGameVersion(SameSourceDedupEntry v) =>
      v.discardedGameVersion;
  static const Field<SameSourceDedupEntry, String> _f$discardedGameVersion =
      Field('discardedGameVersion', _$discardedGameVersion, opt: true);
  static bool _$wasSafetyBlocked(SameSourceDedupEntry v) => v.wasSafetyBlocked;
  static const Field<SameSourceDedupEntry, bool> _f$wasSafetyBlocked = Field(
    'wasSafetyBlocked',
    _$wasSafetyBlocked,
    opt: true,
    def: false,
  );
  static double? _$nameLengthRatio(SameSourceDedupEntry v) => v.nameLengthRatio;
  static const Field<SameSourceDedupEntry, double> _f$nameLengthRatio = Field(
    'nameLengthRatio',
    _$nameLengthRatio,
    opt: true,
  );

  @override
  final MappableFields<SameSourceDedupEntry> fields = const {
    #kept: _f$kept,
    #discarded: _f$discarded,
    #source: _f$source,
    #keptGameVersion: _f$keptGameVersion,
    #discardedGameVersion: _f$discardedGameVersion,
    #wasSafetyBlocked: _f$wasSafetyBlocked,
    #nameLengthRatio: _f$nameLengthRatio,
  };

  static SameSourceDedupEntry _instantiate(DecodingData data) {
    return SameSourceDedupEntry(
      kept: data.dec(_f$kept),
      discarded: data.dec(_f$discarded),
      source: data.dec(_f$source),
      keptGameVersion: data.dec(_f$keptGameVersion),
      discardedGameVersion: data.dec(_f$discardedGameVersion),
      wasSafetyBlocked: data.dec(_f$wasSafetyBlocked),
      nameLengthRatio: data.dec(_f$nameLengthRatio),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static SameSourceDedupEntry fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SameSourceDedupEntry>(map);
  }

  static SameSourceDedupEntry fromJson(String json) {
    return ensureInitialized().decodeJson<SameSourceDedupEntry>(json);
  }
}

mixin SameSourceDedupEntryMappable {
  String toJson() {
    return SameSourceDedupEntryMapper.ensureInitialized()
        .encodeJson<SameSourceDedupEntry>(this as SameSourceDedupEntry);
  }

  Map<String, dynamic> toMap() {
    return SameSourceDedupEntryMapper.ensureInitialized()
        .encodeMap<SameSourceDedupEntry>(this as SameSourceDedupEntry);
  }

  SameSourceDedupEntryCopyWith<
    SameSourceDedupEntry,
    SameSourceDedupEntry,
    SameSourceDedupEntry
  >
  get copyWith =>
      _SameSourceDedupEntryCopyWithImpl<
        SameSourceDedupEntry,
        SameSourceDedupEntry
      >(this as SameSourceDedupEntry, $identity, $identity);
  @override
  String toString() {
    return SameSourceDedupEntryMapper.ensureInitialized().stringifyValue(
      this as SameSourceDedupEntry,
    );
  }

  @override
  bool operator ==(Object other) {
    return SameSourceDedupEntryMapper.ensureInitialized().equalsValue(
      this as SameSourceDedupEntry,
      other,
    );
  }

  @override
  int get hashCode {
    return SameSourceDedupEntryMapper.ensureInitialized().hashValue(
      this as SameSourceDedupEntry,
    );
  }
}

extension SameSourceDedupEntryValueCopy<$R, $Out>
    on ObjectCopyWith<$R, SameSourceDedupEntry, $Out> {
  SameSourceDedupEntryCopyWith<$R, SameSourceDedupEntry, $Out>
  get $asSameSourceDedupEntry => $base.as(
    (v, t, t2) => _SameSourceDedupEntryCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class SameSourceDedupEntryCopyWith<
  $R,
  $In extends SameSourceDedupEntry,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod> get kept;
  ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod> get discarded;
  $R call({
    ScrapedMod? kept,
    ScrapedMod? discarded,
    ModSource? source,
    String? keptGameVersion,
    String? discardedGameVersion,
    bool? wasSafetyBlocked,
    double? nameLengthRatio,
  });
  SameSourceDedupEntryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _SameSourceDedupEntryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, SameSourceDedupEntry, $Out>
    implements SameSourceDedupEntryCopyWith<$R, SameSourceDedupEntry, $Out> {
  _SameSourceDedupEntryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<SameSourceDedupEntry> $mapper =
      SameSourceDedupEntryMapper.ensureInitialized();
  @override
  ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod> get kept =>
      $value.kept.copyWith.$chain((v) => call(kept: v));
  @override
  ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod> get discarded =>
      $value.discarded.copyWith.$chain((v) => call(discarded: v));
  @override
  $R call({
    ScrapedMod? kept,
    ScrapedMod? discarded,
    ModSource? source,
    Object? keptGameVersion = $none,
    Object? discardedGameVersion = $none,
    bool? wasSafetyBlocked,
    Object? nameLengthRatio = $none,
  }) => $apply(
    FieldCopyWithData({
      if (kept != null) #kept: kept,
      if (discarded != null) #discarded: discarded,
      if (source != null) #source: source,
      if (keptGameVersion != $none) #keptGameVersion: keptGameVersion,
      if (discardedGameVersion != $none)
        #discardedGameVersion: discardedGameVersion,
      if (wasSafetyBlocked != null) #wasSafetyBlocked: wasSafetyBlocked,
      if (nameLengthRatio != $none) #nameLengthRatio: nameLengthRatio,
    }),
  );
  @override
  SameSourceDedupEntry $make(CopyWithData data) => SameSourceDedupEntry(
    kept: data.get(#kept, or: $value.kept),
    discarded: data.get(#discarded, or: $value.discarded),
    source: data.get(#source, or: $value.source),
    keptGameVersion: data.get(#keptGameVersion, or: $value.keptGameVersion),
    discardedGameVersion: data.get(
      #discardedGameVersion,
      or: $value.discardedGameVersion,
    ),
    wasSafetyBlocked: data.get(#wasSafetyBlocked, or: $value.wasSafetyBlocked),
    nameLengthRatio: data.get(#nameLengthRatio, or: $value.nameLengthRatio),
  );

  @override
  SameSourceDedupEntryCopyWith<$R2, SameSourceDedupEntry, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _SameSourceDedupEntryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class MergeStepEntryMapper extends ClassMapperBase<MergeStepEntry> {
  MergeStepEntryMapper._();

  static MergeStepEntryMapper? _instance;
  static MergeStepEntryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = MergeStepEntryMapper._());
      ScrapedModMapper.ensureInitialized();
      MergePriorityReasonMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'MergeStepEntry';

  static ScrapedMod _$left(MergeStepEntry v) => v.left;
  static const Field<MergeStepEntry, ScrapedMod> _f$left = Field(
    'left',
    _$left,
  );
  static ScrapedMod _$right(MergeStepEntry v) => v.right;
  static const Field<MergeStepEntry, ScrapedMod> _f$right = Field(
    'right',
    _$right,
  );
  static MergePriorityReason _$reason(MergeStepEntry v) => v.reason;
  static const Field<MergeStepEntry, MergePriorityReason> _f$reason = Field(
    'reason',
    _$reason,
  );
  static bool _$doesRightHavePriority(MergeStepEntry v) =>
      v.doesRightHavePriority;
  static const Field<MergeStepEntry, bool> _f$doesRightHavePriority = Field(
    'doesRightHavePriority',
    _$doesRightHavePriority,
  );
  static ScrapedMod _$result(MergeStepEntry v) => v.result;
  static const Field<MergeStepEntry, ScrapedMod> _f$result = Field(
    'result',
    _$result,
  );

  @override
  final MappableFields<MergeStepEntry> fields = const {
    #left: _f$left,
    #right: _f$right,
    #reason: _f$reason,
    #doesRightHavePriority: _f$doesRightHavePriority,
    #result: _f$result,
  };

  static MergeStepEntry _instantiate(DecodingData data) {
    return MergeStepEntry(
      left: data.dec(_f$left),
      right: data.dec(_f$right),
      reason: data.dec(_f$reason),
      doesRightHavePriority: data.dec(_f$doesRightHavePriority),
      result: data.dec(_f$result),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static MergeStepEntry fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<MergeStepEntry>(map);
  }

  static MergeStepEntry fromJson(String json) {
    return ensureInitialized().decodeJson<MergeStepEntry>(json);
  }
}

mixin MergeStepEntryMappable {
  String toJson() {
    return MergeStepEntryMapper.ensureInitialized().encodeJson<MergeStepEntry>(
      this as MergeStepEntry,
    );
  }

  Map<String, dynamic> toMap() {
    return MergeStepEntryMapper.ensureInitialized().encodeMap<MergeStepEntry>(
      this as MergeStepEntry,
    );
  }

  MergeStepEntryCopyWith<MergeStepEntry, MergeStepEntry, MergeStepEntry>
  get copyWith => _MergeStepEntryCopyWithImpl<MergeStepEntry, MergeStepEntry>(
    this as MergeStepEntry,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return MergeStepEntryMapper.ensureInitialized().stringifyValue(
      this as MergeStepEntry,
    );
  }

  @override
  bool operator ==(Object other) {
    return MergeStepEntryMapper.ensureInitialized().equalsValue(
      this as MergeStepEntry,
      other,
    );
  }

  @override
  int get hashCode {
    return MergeStepEntryMapper.ensureInitialized().hashValue(
      this as MergeStepEntry,
    );
  }
}

extension MergeStepEntryValueCopy<$R, $Out>
    on ObjectCopyWith<$R, MergeStepEntry, $Out> {
  MergeStepEntryCopyWith<$R, MergeStepEntry, $Out> get $asMergeStepEntry =>
      $base.as((v, t, t2) => _MergeStepEntryCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class MergeStepEntryCopyWith<$R, $In extends MergeStepEntry, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod> get left;
  ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod> get right;
  ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod> get result;
  $R call({
    ScrapedMod? left,
    ScrapedMod? right,
    MergePriorityReason? reason,
    bool? doesRightHavePriority,
    ScrapedMod? result,
  });
  MergeStepEntryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _MergeStepEntryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, MergeStepEntry, $Out>
    implements MergeStepEntryCopyWith<$R, MergeStepEntry, $Out> {
  _MergeStepEntryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<MergeStepEntry> $mapper =
      MergeStepEntryMapper.ensureInitialized();
  @override
  ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod> get left =>
      $value.left.copyWith.$chain((v) => call(left: v));
  @override
  ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod> get right =>
      $value.right.copyWith.$chain((v) => call(right: v));
  @override
  ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod> get result =>
      $value.result.copyWith.$chain((v) => call(result: v));
  @override
  $R call({
    ScrapedMod? left,
    ScrapedMod? right,
    MergePriorityReason? reason,
    bool? doesRightHavePriority,
    ScrapedMod? result,
  }) => $apply(
    FieldCopyWithData({
      if (left != null) #left: left,
      if (right != null) #right: right,
      if (reason != null) #reason: reason,
      if (doesRightHavePriority != null)
        #doesRightHavePriority: doesRightHavePriority,
      if (result != null) #result: result,
    }),
  );
  @override
  MergeStepEntry $make(CopyWithData data) => MergeStepEntry(
    left: data.get(#left, or: $value.left),
    right: data.get(#right, or: $value.right),
    reason: data.get(#reason, or: $value.reason),
    doesRightHavePriority: data.get(
      #doesRightHavePriority,
      or: $value.doesRightHavePriority,
    ),
    result: data.get(#result, or: $value.result),
  );

  @override
  MergeStepEntryCopyWith<$R2, MergeStepEntry, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _MergeStepEntryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class MergeDecisionMapper extends ClassMapperBase<MergeDecision> {
  MergeDecisionMapper._();

  static MergeDecisionMapper? _instance;
  static MergeDecisionMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = MergeDecisionMapper._());
      ScrapedModMapper.ensureInitialized();
      MergeStepEntryMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'MergeDecision';

  static int _$groupIndex(MergeDecision v) => v.groupIndex;
  static const Field<MergeDecision, int> _f$groupIndex = Field(
    'groupIndex',
    _$groupIndex,
  );
  static List<ScrapedMod> _$inputMods(MergeDecision v) => v.inputMods;
  static const Field<MergeDecision, List<ScrapedMod>> _f$inputMods = Field(
    'inputMods',
    _$inputMods,
  );
  static List<MergeStepEntry> _$steps(MergeDecision v) => v.steps;
  static const Field<MergeDecision, List<MergeStepEntry>> _f$steps = Field(
    'steps',
    _$steps,
  );
  static ScrapedMod _$finalResult(MergeDecision v) => v.finalResult;
  static const Field<MergeDecision, ScrapedMod> _f$finalResult = Field(
    'finalResult',
    _$finalResult,
  );

  @override
  final MappableFields<MergeDecision> fields = const {
    #groupIndex: _f$groupIndex,
    #inputMods: _f$inputMods,
    #steps: _f$steps,
    #finalResult: _f$finalResult,
  };

  static MergeDecision _instantiate(DecodingData data) {
    return MergeDecision(
      groupIndex: data.dec(_f$groupIndex),
      inputMods: data.dec(_f$inputMods),
      steps: data.dec(_f$steps),
      finalResult: data.dec(_f$finalResult),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static MergeDecision fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<MergeDecision>(map);
  }

  static MergeDecision fromJson(String json) {
    return ensureInitialized().decodeJson<MergeDecision>(json);
  }
}

mixin MergeDecisionMappable {
  String toJson() {
    return MergeDecisionMapper.ensureInitialized().encodeJson<MergeDecision>(
      this as MergeDecision,
    );
  }

  Map<String, dynamic> toMap() {
    return MergeDecisionMapper.ensureInitialized().encodeMap<MergeDecision>(
      this as MergeDecision,
    );
  }

  MergeDecisionCopyWith<MergeDecision, MergeDecision, MergeDecision>
  get copyWith => _MergeDecisionCopyWithImpl<MergeDecision, MergeDecision>(
    this as MergeDecision,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return MergeDecisionMapper.ensureInitialized().stringifyValue(
      this as MergeDecision,
    );
  }

  @override
  bool operator ==(Object other) {
    return MergeDecisionMapper.ensureInitialized().equalsValue(
      this as MergeDecision,
      other,
    );
  }

  @override
  int get hashCode {
    return MergeDecisionMapper.ensureInitialized().hashValue(
      this as MergeDecision,
    );
  }
}

extension MergeDecisionValueCopy<$R, $Out>
    on ObjectCopyWith<$R, MergeDecision, $Out> {
  MergeDecisionCopyWith<$R, MergeDecision, $Out> get $asMergeDecision =>
      $base.as((v, t, t2) => _MergeDecisionCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class MergeDecisionCopyWith<$R, $In extends MergeDecision, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, ScrapedMod, ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod>>
  get inputMods;
  ListCopyWith<
    $R,
    MergeStepEntry,
    MergeStepEntryCopyWith<$R, MergeStepEntry, MergeStepEntry>
  >
  get steps;
  ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod> get finalResult;
  $R call({
    int? groupIndex,
    List<ScrapedMod>? inputMods,
    List<MergeStepEntry>? steps,
    ScrapedMod? finalResult,
  });
  MergeDecisionCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _MergeDecisionCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, MergeDecision, $Out>
    implements MergeDecisionCopyWith<$R, MergeDecision, $Out> {
  _MergeDecisionCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<MergeDecision> $mapper =
      MergeDecisionMapper.ensureInitialized();
  @override
  ListCopyWith<$R, ScrapedMod, ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod>>
  get inputMods => ListCopyWith(
    $value.inputMods,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(inputMods: v),
  );
  @override
  ListCopyWith<
    $R,
    MergeStepEntry,
    MergeStepEntryCopyWith<$R, MergeStepEntry, MergeStepEntry>
  >
  get steps => ListCopyWith(
    $value.steps,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(steps: v),
  );
  @override
  ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod> get finalResult =>
      $value.finalResult.copyWith.$chain((v) => call(finalResult: v));
  @override
  $R call({
    int? groupIndex,
    List<ScrapedMod>? inputMods,
    List<MergeStepEntry>? steps,
    ScrapedMod? finalResult,
  }) => $apply(
    FieldCopyWithData({
      if (groupIndex != null) #groupIndex: groupIndex,
      if (inputMods != null) #inputMods: inputMods,
      if (steps != null) #steps: steps,
      if (finalResult != null) #finalResult: finalResult,
    }),
  );
  @override
  MergeDecision $make(CopyWithData data) => MergeDecision(
    groupIndex: data.get(#groupIndex, or: $value.groupIndex),
    inputMods: data.get(#inputMods, or: $value.inputMods),
    steps: data.get(#steps, or: $value.steps),
    finalResult: data.get(#finalResult, or: $value.finalResult),
  );

  @override
  MergeDecisionCopyWith<$R2, MergeDecision, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _MergeDecisionCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ValidationRemovalMapper extends ClassMapperBase<ValidationRemoval> {
  ValidationRemovalMapper._();

  static ValidationRemovalMapper? _instance;
  static ValidationRemovalMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ValidationRemovalMapper._());
      ScrapedModMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ValidationRemoval';

  static ScrapedMod _$mod(ValidationRemoval v) => v.mod;
  static const Field<ValidationRemoval, ScrapedMod> _f$mod = Field(
    'mod',
    _$mod,
  );
  static String _$reason(ValidationRemoval v) => v.reason;
  static const Field<ValidationRemoval, String> _f$reason = Field(
    'reason',
    _$reason,
  );

  @override
  final MappableFields<ValidationRemoval> fields = const {
    #mod: _f$mod,
    #reason: _f$reason,
  };

  static ValidationRemoval _instantiate(DecodingData data) {
    return ValidationRemoval(
      mod: data.dec(_f$mod),
      reason: data.dec(_f$reason),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ValidationRemoval fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ValidationRemoval>(map);
  }

  static ValidationRemoval fromJson(String json) {
    return ensureInitialized().decodeJson<ValidationRemoval>(json);
  }
}

mixin ValidationRemovalMappable {
  String toJson() {
    return ValidationRemovalMapper.ensureInitialized()
        .encodeJson<ValidationRemoval>(this as ValidationRemoval);
  }

  Map<String, dynamic> toMap() {
    return ValidationRemovalMapper.ensureInitialized()
        .encodeMap<ValidationRemoval>(this as ValidationRemoval);
  }

  ValidationRemovalCopyWith<
    ValidationRemoval,
    ValidationRemoval,
    ValidationRemoval
  >
  get copyWith =>
      _ValidationRemovalCopyWithImpl<ValidationRemoval, ValidationRemoval>(
        this as ValidationRemoval,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ValidationRemovalMapper.ensureInitialized().stringifyValue(
      this as ValidationRemoval,
    );
  }

  @override
  bool operator ==(Object other) {
    return ValidationRemovalMapper.ensureInitialized().equalsValue(
      this as ValidationRemoval,
      other,
    );
  }

  @override
  int get hashCode {
    return ValidationRemovalMapper.ensureInitialized().hashValue(
      this as ValidationRemoval,
    );
  }
}

extension ValidationRemovalValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ValidationRemoval, $Out> {
  ValidationRemovalCopyWith<$R, ValidationRemoval, $Out>
  get $asValidationRemoval => $base.as(
    (v, t, t2) => _ValidationRemovalCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class ValidationRemovalCopyWith<
  $R,
  $In extends ValidationRemoval,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod> get mod;
  $R call({ScrapedMod? mod, String? reason});
  ValidationRemovalCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ValidationRemovalCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ValidationRemoval, $Out>
    implements ValidationRemovalCopyWith<$R, ValidationRemoval, $Out> {
  _ValidationRemovalCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ValidationRemoval> $mapper =
      ValidationRemovalMapper.ensureInitialized();
  @override
  ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod> get mod =>
      $value.mod.copyWith.$chain((v) => call(mod: v));
  @override
  $R call({ScrapedMod? mod, String? reason}) => $apply(
    FieldCopyWithData({
      if (mod != null) #mod: mod,
      if (reason != null) #reason: reason,
    }),
  );
  @override
  ValidationRemoval $make(CopyWithData data) => ValidationRemoval(
    mod: data.get(#mod, or: $value.mod),
    reason: data.get(#reason, or: $value.reason),
  );

  @override
  ValidationRemovalCopyWith<$R2, ValidationRemoval, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ValidationRemovalCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class MergeDebugDataMapper extends ClassMapperBase<MergeDebugData> {
  MergeDebugDataMapper._();

  static MergeDebugDataMapper? _instance;
  static MergeDebugDataMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = MergeDebugDataMapper._());
      PhaseTimingMapper.ensureInitialized();
      PreDedupEntryMapper.ensureInitialized();
      DebugModGroupMapper.ensureInitialized();
      SameSourceDedupEntryMapper.ensureInitialized();
      MergeDecisionMapper.ensureInitialized();
      ValidationRemovalMapper.ensureInitialized();
      ScrapedModMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'MergeDebugData';

  static int _$inputCount(MergeDebugData v) => v.inputCount;
  static const Field<MergeDebugData, int> _f$inputCount = Field(
    'inputCount',
    _$inputCount,
    opt: true,
    def: 0,
  );
  static int _$afterPreDedupCount(MergeDebugData v) => v.afterPreDedupCount;
  static const Field<MergeDebugData, int> _f$afterPreDedupCount = Field(
    'afterPreDedupCount',
    _$afterPreDedupCount,
    opt: true,
    def: 0,
  );
  static int _$groupsCreated(MergeDebugData v) => v.groupsCreated;
  static const Field<MergeDebugData, int> _f$groupsCreated = Field(
    'groupsCreated',
    _$groupsCreated,
    opt: true,
    def: 0,
  );
  static int _$finalCount(MergeDebugData v) => v.finalCount;
  static const Field<MergeDebugData, int> _f$finalCount = Field(
    'finalCount',
    _$finalCount,
    opt: true,
    def: 0,
  );
  static List<PhaseTiming> _$timings(MergeDebugData v) => v.timings;
  static const Field<MergeDebugData, List<PhaseTiming>> _f$timings = Field(
    'timings',
    _$timings,
    opt: true,
  );
  static List<PreDedupEntry> _$preDedupEntries(MergeDebugData v) =>
      v.preDedupEntries;
  static const Field<MergeDebugData, List<PreDedupEntry>> _f$preDedupEntries =
      Field('preDedupEntries', _$preDedupEntries, opt: true);
  static List<DebugModGroup> _$groups(MergeDebugData v) => v.groups;
  static const Field<MergeDebugData, List<DebugModGroup>> _f$groups = Field(
    'groups',
    _$groups,
    opt: true,
  );
  static List<SameSourceDedupEntry> _$sameSourceDedupEntries(
    MergeDebugData v,
  ) => v.sameSourceDedupEntries;
  static const Field<MergeDebugData, List<SameSourceDedupEntry>>
  _f$sameSourceDedupEntries = Field(
    'sameSourceDedupEntries',
    _$sameSourceDedupEntries,
    opt: true,
  );
  static List<MergeDecision> _$mergeDecisions(MergeDebugData v) =>
      v.mergeDecisions;
  static const Field<MergeDebugData, List<MergeDecision>> _f$mergeDecisions =
      Field('mergeDecisions', _$mergeDecisions, opt: true);
  static List<ValidationRemoval> _$validationRemovalEntries(MergeDebugData v) =>
      v.validationRemovalEntries;
  static const Field<MergeDebugData, List<ValidationRemoval>>
  _f$validationRemovalEntries = Field(
    'validationRemovalEntries',
    _$validationRemovalEntries,
    opt: true,
  );
  static List<ScrapedMod> _$finalOutput(MergeDebugData v) => v.finalOutput;
  static const Field<MergeDebugData, List<ScrapedMod>> _f$finalOutput = Field(
    'finalOutput',
    _$finalOutput,
    opt: true,
  );

  @override
  final MappableFields<MergeDebugData> fields = const {
    #inputCount: _f$inputCount,
    #afterPreDedupCount: _f$afterPreDedupCount,
    #groupsCreated: _f$groupsCreated,
    #finalCount: _f$finalCount,
    #timings: _f$timings,
    #preDedupEntries: _f$preDedupEntries,
    #groups: _f$groups,
    #sameSourceDedupEntries: _f$sameSourceDedupEntries,
    #mergeDecisions: _f$mergeDecisions,
    #validationRemovalEntries: _f$validationRemovalEntries,
    #finalOutput: _f$finalOutput,
  };

  static MergeDebugData _instantiate(DecodingData data) {
    return MergeDebugData(
      inputCount: data.dec(_f$inputCount),
      afterPreDedupCount: data.dec(_f$afterPreDedupCount),
      groupsCreated: data.dec(_f$groupsCreated),
      finalCount: data.dec(_f$finalCount),
      timings: data.dec(_f$timings),
      preDedupEntries: data.dec(_f$preDedupEntries),
      groups: data.dec(_f$groups),
      sameSourceDedupEntries: data.dec(_f$sameSourceDedupEntries),
      mergeDecisions: data.dec(_f$mergeDecisions),
      validationRemovalEntries: data.dec(_f$validationRemovalEntries),
      finalOutput: data.dec(_f$finalOutput),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static MergeDebugData fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<MergeDebugData>(map);
  }

  static MergeDebugData fromJson(String json) {
    return ensureInitialized().decodeJson<MergeDebugData>(json);
  }
}

mixin MergeDebugDataMappable {
  String toJson() {
    return MergeDebugDataMapper.ensureInitialized().encodeJson<MergeDebugData>(
      this as MergeDebugData,
    );
  }

  Map<String, dynamic> toMap() {
    return MergeDebugDataMapper.ensureInitialized().encodeMap<MergeDebugData>(
      this as MergeDebugData,
    );
  }

  MergeDebugDataCopyWith<MergeDebugData, MergeDebugData, MergeDebugData>
  get copyWith => _MergeDebugDataCopyWithImpl<MergeDebugData, MergeDebugData>(
    this as MergeDebugData,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return MergeDebugDataMapper.ensureInitialized().stringifyValue(
      this as MergeDebugData,
    );
  }

  @override
  bool operator ==(Object other) {
    return MergeDebugDataMapper.ensureInitialized().equalsValue(
      this as MergeDebugData,
      other,
    );
  }

  @override
  int get hashCode {
    return MergeDebugDataMapper.ensureInitialized().hashValue(
      this as MergeDebugData,
    );
  }
}

extension MergeDebugDataValueCopy<$R, $Out>
    on ObjectCopyWith<$R, MergeDebugData, $Out> {
  MergeDebugDataCopyWith<$R, MergeDebugData, $Out> get $asMergeDebugData =>
      $base.as((v, t, t2) => _MergeDebugDataCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class MergeDebugDataCopyWith<$R, $In extends MergeDebugData, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<
    $R,
    PhaseTiming,
    PhaseTimingCopyWith<$R, PhaseTiming, PhaseTiming>
  >
  get timings;
  ListCopyWith<
    $R,
    PreDedupEntry,
    PreDedupEntryCopyWith<$R, PreDedupEntry, PreDedupEntry>
  >
  get preDedupEntries;
  ListCopyWith<
    $R,
    DebugModGroup,
    DebugModGroupCopyWith<$R, DebugModGroup, DebugModGroup>
  >
  get groups;
  ListCopyWith<
    $R,
    SameSourceDedupEntry,
    SameSourceDedupEntryCopyWith<$R, SameSourceDedupEntry, SameSourceDedupEntry>
  >
  get sameSourceDedupEntries;
  ListCopyWith<
    $R,
    MergeDecision,
    MergeDecisionCopyWith<$R, MergeDecision, MergeDecision>
  >
  get mergeDecisions;
  ListCopyWith<
    $R,
    ValidationRemoval,
    ValidationRemovalCopyWith<$R, ValidationRemoval, ValidationRemoval>
  >
  get validationRemovalEntries;
  ListCopyWith<$R, ScrapedMod, ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod>>
  get finalOutput;
  $R call({
    int? inputCount,
    int? afterPreDedupCount,
    int? groupsCreated,
    int? finalCount,
    List<PhaseTiming>? timings,
    List<PreDedupEntry>? preDedupEntries,
    List<DebugModGroup>? groups,
    List<SameSourceDedupEntry>? sameSourceDedupEntries,
    List<MergeDecision>? mergeDecisions,
    List<ValidationRemoval>? validationRemovalEntries,
    List<ScrapedMod>? finalOutput,
  });
  MergeDebugDataCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _MergeDebugDataCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, MergeDebugData, $Out>
    implements MergeDebugDataCopyWith<$R, MergeDebugData, $Out> {
  _MergeDebugDataCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<MergeDebugData> $mapper =
      MergeDebugDataMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    PhaseTiming,
    PhaseTimingCopyWith<$R, PhaseTiming, PhaseTiming>
  >
  get timings => ListCopyWith(
    $value.timings,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(timings: v),
  );
  @override
  ListCopyWith<
    $R,
    PreDedupEntry,
    PreDedupEntryCopyWith<$R, PreDedupEntry, PreDedupEntry>
  >
  get preDedupEntries => ListCopyWith(
    $value.preDedupEntries,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(preDedupEntries: v),
  );
  @override
  ListCopyWith<
    $R,
    DebugModGroup,
    DebugModGroupCopyWith<$R, DebugModGroup, DebugModGroup>
  >
  get groups => ListCopyWith(
    $value.groups,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(groups: v),
  );
  @override
  ListCopyWith<
    $R,
    SameSourceDedupEntry,
    SameSourceDedupEntryCopyWith<$R, SameSourceDedupEntry, SameSourceDedupEntry>
  >
  get sameSourceDedupEntries => ListCopyWith(
    $value.sameSourceDedupEntries,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(sameSourceDedupEntries: v),
  );
  @override
  ListCopyWith<
    $R,
    MergeDecision,
    MergeDecisionCopyWith<$R, MergeDecision, MergeDecision>
  >
  get mergeDecisions => ListCopyWith(
    $value.mergeDecisions,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(mergeDecisions: v),
  );
  @override
  ListCopyWith<
    $R,
    ValidationRemoval,
    ValidationRemovalCopyWith<$R, ValidationRemoval, ValidationRemoval>
  >
  get validationRemovalEntries => ListCopyWith(
    $value.validationRemovalEntries,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(validationRemovalEntries: v),
  );
  @override
  ListCopyWith<$R, ScrapedMod, ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod>>
  get finalOutput => ListCopyWith(
    $value.finalOutput,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(finalOutput: v),
  );
  @override
  $R call({
    int? inputCount,
    int? afterPreDedupCount,
    int? groupsCreated,
    int? finalCount,
    Object? timings = $none,
    Object? preDedupEntries = $none,
    Object? groups = $none,
    Object? sameSourceDedupEntries = $none,
    Object? mergeDecisions = $none,
    Object? validationRemovalEntries = $none,
    Object? finalOutput = $none,
  }) => $apply(
    FieldCopyWithData({
      if (inputCount != null) #inputCount: inputCount,
      if (afterPreDedupCount != null) #afterPreDedupCount: afterPreDedupCount,
      if (groupsCreated != null) #groupsCreated: groupsCreated,
      if (finalCount != null) #finalCount: finalCount,
      if (timings != $none) #timings: timings,
      if (preDedupEntries != $none) #preDedupEntries: preDedupEntries,
      if (groups != $none) #groups: groups,
      if (sameSourceDedupEntries != $none)
        #sameSourceDedupEntries: sameSourceDedupEntries,
      if (mergeDecisions != $none) #mergeDecisions: mergeDecisions,
      if (validationRemovalEntries != $none)
        #validationRemovalEntries: validationRemovalEntries,
      if (finalOutput != $none) #finalOutput: finalOutput,
    }),
  );
  @override
  MergeDebugData $make(CopyWithData data) => MergeDebugData(
    inputCount: data.get(#inputCount, or: $value.inputCount),
    afterPreDedupCount: data.get(
      #afterPreDedupCount,
      or: $value.afterPreDedupCount,
    ),
    groupsCreated: data.get(#groupsCreated, or: $value.groupsCreated),
    finalCount: data.get(#finalCount, or: $value.finalCount),
    timings: data.get(#timings, or: $value.timings),
    preDedupEntries: data.get(#preDedupEntries, or: $value.preDedupEntries),
    groups: data.get(#groups, or: $value.groups),
    sameSourceDedupEntries: data.get(
      #sameSourceDedupEntries,
      or: $value.sameSourceDedupEntries,
    ),
    mergeDecisions: data.get(#mergeDecisions, or: $value.mergeDecisions),
    validationRemovalEntries: data.get(
      #validationRemovalEntries,
      or: $value.validationRemovalEntries,
    ),
    finalOutput: data.get(#finalOutput, or: $value.finalOutput),
  );

  @override
  MergeDebugDataCopyWith<$R2, MergeDebugData, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _MergeDebugDataCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

