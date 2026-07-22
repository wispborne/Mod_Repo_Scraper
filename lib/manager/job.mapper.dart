// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'job.dart';

class JobKindMapper extends EnumMapper<JobKind> {
  JobKindMapper._();

  static JobKindMapper? _instance;
  static JobKindMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = JobKindMapper._());
    }
    return _instance!;
  }

  static JobKind fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  JobKind decode(dynamic value) {
    switch (value) {
      case r'fullRun':
        return JobKind.fullRun;
      case r'rescrapeTopics':
        return JobKind.rescrapeTopics;
      case r'resolveDownloads':
        return JobKind.resolveDownloads;
      case r'extractLlm':
        return JobKind.extractLlm;
      case r'llmCoveragePass':
        return JobKind.llmCoveragePass;
      case r'llmTest':
        return JobKind.llmTest;
      case r'rebuildBundle':
        return JobKind.rebuildBundle;
      case r'mergeModRepo':
        return JobKind.mergeModRepo;
      case r'scrapeAndMerge':
        return JobKind.scrapeAndMerge;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(JobKind self) {
    switch (self) {
      case JobKind.fullRun:
        return r'fullRun';
      case JobKind.rescrapeTopics:
        return r'rescrapeTopics';
      case JobKind.resolveDownloads:
        return r'resolveDownloads';
      case JobKind.extractLlm:
        return r'extractLlm';
      case JobKind.llmCoveragePass:
        return r'llmCoveragePass';
      case JobKind.llmTest:
        return r'llmTest';
      case JobKind.rebuildBundle:
        return r'rebuildBundle';
      case JobKind.mergeModRepo:
        return r'mergeModRepo';
      case JobKind.scrapeAndMerge:
        return r'scrapeAndMerge';
    }
  }
}

extension JobKindMapperExtension on JobKind {
  String toValue() {
    JobKindMapper.ensureInitialized();
    return MapperContainer.globals.toValue<JobKind>(this) as String;
  }
}

class ModSourceKindMapper extends EnumMapper<ModSourceKind> {
  ModSourceKindMapper._();

  static ModSourceKindMapper? _instance;
  static ModSourceKindMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ModSourceKindMapper._());
    }
    return _instance!;
  }

  static ModSourceKind fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  ModSourceKind decode(dynamic value) {
    switch (value) {
      case r'forum':
        return ModSourceKind.forum;
      case r'discord':
        return ModSourceKind.discord;
      case r'nexus':
        return ModSourceKind.nexus;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(ModSourceKind self) {
    switch (self) {
      case ModSourceKind.forum:
        return r'forum';
      case ModSourceKind.discord:
        return r'discord';
      case ModSourceKind.nexus:
        return r'nexus';
    }
  }
}

extension ModSourceKindMapperExtension on ModSourceKind {
  String toValue() {
    ModSourceKindMapper.ensureInitialized();
    return MapperContainer.globals.toValue<ModSourceKind>(this) as String;
  }
}

class RunStateMapper extends EnumMapper<RunState> {
  RunStateMapper._();

  static RunStateMapper? _instance;
  static RunStateMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = RunStateMapper._());
    }
    return _instance!;
  }

  static RunState fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  RunState decode(dynamic value) {
    switch (value) {
      case r'queued':
        return RunState.queued;
      case r'running':
        return RunState.running;
      case r'completed':
        return RunState.completed;
      case r'failed':
        return RunState.failed;
      case r'cancelled':
        return RunState.cancelled;
      case r'interrupted':
        return RunState.interrupted;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(RunState self) {
    switch (self) {
      case RunState.queued:
        return r'queued';
      case RunState.running:
        return r'running';
      case RunState.completed:
        return r'completed';
      case RunState.failed:
        return r'failed';
      case RunState.cancelled:
        return r'cancelled';
      case RunState.interrupted:
        return r'interrupted';
    }
  }
}

extension RunStateMapperExtension on RunState {
  String toValue() {
    RunStateMapper.ensureInitialized();
    return MapperContainer.globals.toValue<RunState>(this) as String;
  }
}

class JobRequestMapper extends ClassMapperBase<JobRequest> {
  JobRequestMapper._();

  static JobRequestMapper? _instance;
  static JobRequestMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = JobRequestMapper._());
      JobKindMapper.ensureInitialized();
      ScopeTypeMapper.ensureInitialized();
      ScrapeBoardMapper.ensureInitialized();
      ModSourceKindMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'JobRequest';

  static JobKind _$kind(JobRequest v) => v.kind;
  static const Field<JobRequest, JobKind> _f$kind = Field('kind', _$kind);
  static List<int> _$topicIds(JobRequest v) => v.topicIds;
  static const Field<JobRequest, List<int>> _f$topicIds = Field(
    'topicIds',
    _$topicIds,
    opt: true,
    def: const [],
  );
  static ScopeType _$scope(JobRequest v) => v.scope;
  static const Field<JobRequest, ScopeType> _f$scope = Field(
    'scope',
    _$scope,
    opt: true,
    def: ScopeType.newData,
  );
  static Set<ScrapeBoard> _$boards(JobRequest v) => v.boards;
  static const Field<JobRequest, Set<ScrapeBoard>> _f$boards = Field(
    'boards',
    _$boards,
    opt: true,
    def: const {ScrapeBoard.main, ScrapeBoard.libraries},
  );
  static int? _$maxPagesMain(JobRequest v) => v.maxPagesMain;
  static const Field<JobRequest, int> _f$maxPagesMain = Field(
    'maxPagesMain',
    _$maxPagesMain,
    opt: true,
  );
  static int? _$maxPagesLesser(JobRequest v) => v.maxPagesLesser;
  static const Field<JobRequest, int> _f$maxPagesLesser = Field(
    'maxPagesLesser',
    _$maxPagesLesser,
    opt: true,
  );
  static int? _$maxPagesLibraries(JobRequest v) => v.maxPagesLibraries;
  static const Field<JobRequest, int> _f$maxPagesLibraries = Field(
    'maxPagesLibraries',
    _$maxPagesLibraries,
    opt: true,
  );
  static bool _$runLlm(JobRequest v) => v.runLlm;
  static const Field<JobRequest, bool> _f$runLlm = Field(
    'runLlm',
    _$runLlm,
    opt: true,
    def: false,
  );
  static bool _$replayAllowed(JobRequest v) => v.replayAllowed;
  static const Field<JobRequest, bool> _f$replayAllowed = Field(
    'replayAllowed',
    _$replayAllowed,
    opt: true,
    def: false,
  );
  static int _$testLimit(JobRequest v) => v.testLimit;
  static const Field<JobRequest, int> _f$testLimit = Field(
    'testLimit',
    _$testLimit,
    opt: true,
    def: 5,
  );
  static Set<ModSourceKind> _$modSources(JobRequest v) => v.modSources;
  static const Field<JobRequest, Set<ModSourceKind>> _f$modSources = Field(
    'modSources',
    _$modSources,
    opt: true,
    def: const {
      ModSourceKind.forum,
      ModSourceKind.discord,
      ModSourceKind.nexus,
    },
  );
  static int? _$modForumPages(JobRequest v) => v.modForumPages;
  static const Field<JobRequest, int> _f$modForumPages = Field(
    'modForumPages',
    _$modForumPages,
    opt: true,
  );
  static int? _$moddingForumPages(JobRequest v) => v.moddingForumPages;
  static const Field<JobRequest, int> _f$moddingForumPages = Field(
    'moddingForumPages',
    _$moddingForumPages,
    opt: true,
  );
  static bool _$keepAllGameVersions(JobRequest v) => v.keepAllGameVersions;
  static const Field<JobRequest, bool> _f$keepAllGameVersions = Field(
    'keepAllGameVersions',
    _$keepAllGameVersions,
    opt: true,
    def: false,
  );
  static bool _$collectMergeDebug(JobRequest v) => v.collectMergeDebug;
  static const Field<JobRequest, bool> _f$collectMergeDebug = Field(
    'collectMergeDebug',
    _$collectMergeDebug,
    opt: true,
    def: false,
  );

  @override
  final MappableFields<JobRequest> fields = const {
    #kind: _f$kind,
    #topicIds: _f$topicIds,
    #scope: _f$scope,
    #boards: _f$boards,
    #maxPagesMain: _f$maxPagesMain,
    #maxPagesLesser: _f$maxPagesLesser,
    #maxPagesLibraries: _f$maxPagesLibraries,
    #runLlm: _f$runLlm,
    #replayAllowed: _f$replayAllowed,
    #testLimit: _f$testLimit,
    #modSources: _f$modSources,
    #modForumPages: _f$modForumPages,
    #moddingForumPages: _f$moddingForumPages,
    #keepAllGameVersions: _f$keepAllGameVersions,
    #collectMergeDebug: _f$collectMergeDebug,
  };

  static JobRequest _instantiate(DecodingData data) {
    return JobRequest(
      kind: data.dec(_f$kind),
      topicIds: data.dec(_f$topicIds),
      scope: data.dec(_f$scope),
      boards: data.dec(_f$boards),
      maxPagesMain: data.dec(_f$maxPagesMain),
      maxPagesLesser: data.dec(_f$maxPagesLesser),
      maxPagesLibraries: data.dec(_f$maxPagesLibraries),
      runLlm: data.dec(_f$runLlm),
      replayAllowed: data.dec(_f$replayAllowed),
      testLimit: data.dec(_f$testLimit),
      modSources: data.dec(_f$modSources),
      modForumPages: data.dec(_f$modForumPages),
      moddingForumPages: data.dec(_f$moddingForumPages),
      keepAllGameVersions: data.dec(_f$keepAllGameVersions),
      collectMergeDebug: data.dec(_f$collectMergeDebug),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static JobRequest fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<JobRequest>(map);
  }

  static JobRequest fromJson(String json) {
    return ensureInitialized().decodeJson<JobRequest>(json);
  }
}

mixin JobRequestMappable {
  String toJson() {
    return JobRequestMapper.ensureInitialized().encodeJson<JobRequest>(
      this as JobRequest,
    );
  }

  Map<String, dynamic> toMap() {
    return JobRequestMapper.ensureInitialized().encodeMap<JobRequest>(
      this as JobRequest,
    );
  }

  JobRequestCopyWith<JobRequest, JobRequest, JobRequest> get copyWith =>
      _JobRequestCopyWithImpl<JobRequest, JobRequest>(
        this as JobRequest,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return JobRequestMapper.ensureInitialized().stringifyValue(
      this as JobRequest,
    );
  }

  @override
  bool operator ==(Object other) {
    return JobRequestMapper.ensureInitialized().equalsValue(
      this as JobRequest,
      other,
    );
  }

  @override
  int get hashCode {
    return JobRequestMapper.ensureInitialized().hashValue(this as JobRequest);
  }
}

extension JobRequestValueCopy<$R, $Out>
    on ObjectCopyWith<$R, JobRequest, $Out> {
  JobRequestCopyWith<$R, JobRequest, $Out> get $asJobRequest =>
      $base.as((v, t, t2) => _JobRequestCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class JobRequestCopyWith<$R, $In extends JobRequest, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, int, ObjectCopyWith<$R, int, int>> get topicIds;
  $R call({
    JobKind? kind,
    List<int>? topicIds,
    ScopeType? scope,
    Set<ScrapeBoard>? boards,
    int? maxPagesMain,
    int? maxPagesLesser,
    int? maxPagesLibraries,
    bool? runLlm,
    bool? replayAllowed,
    int? testLimit,
    Set<ModSourceKind>? modSources,
    int? modForumPages,
    int? moddingForumPages,
    bool? keepAllGameVersions,
    bool? collectMergeDebug,
  });
  JobRequestCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _JobRequestCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, JobRequest, $Out>
    implements JobRequestCopyWith<$R, JobRequest, $Out> {
  _JobRequestCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<JobRequest> $mapper =
      JobRequestMapper.ensureInitialized();
  @override
  ListCopyWith<$R, int, ObjectCopyWith<$R, int, int>> get topicIds =>
      ListCopyWith(
        $value.topicIds,
        (v, t) => ObjectCopyWith(v, $identity, t),
        (v) => call(topicIds: v),
      );
  @override
  $R call({
    JobKind? kind,
    List<int>? topicIds,
    ScopeType? scope,
    Set<ScrapeBoard>? boards,
    Object? maxPagesMain = $none,
    Object? maxPagesLesser = $none,
    Object? maxPagesLibraries = $none,
    bool? runLlm,
    bool? replayAllowed,
    int? testLimit,
    Set<ModSourceKind>? modSources,
    Object? modForumPages = $none,
    Object? moddingForumPages = $none,
    bool? keepAllGameVersions,
    bool? collectMergeDebug,
  }) => $apply(
    FieldCopyWithData({
      if (kind != null) #kind: kind,
      if (topicIds != null) #topicIds: topicIds,
      if (scope != null) #scope: scope,
      if (boards != null) #boards: boards,
      if (maxPagesMain != $none) #maxPagesMain: maxPagesMain,
      if (maxPagesLesser != $none) #maxPagesLesser: maxPagesLesser,
      if (maxPagesLibraries != $none) #maxPagesLibraries: maxPagesLibraries,
      if (runLlm != null) #runLlm: runLlm,
      if (replayAllowed != null) #replayAllowed: replayAllowed,
      if (testLimit != null) #testLimit: testLimit,
      if (modSources != null) #modSources: modSources,
      if (modForumPages != $none) #modForumPages: modForumPages,
      if (moddingForumPages != $none) #moddingForumPages: moddingForumPages,
      if (keepAllGameVersions != null)
        #keepAllGameVersions: keepAllGameVersions,
      if (collectMergeDebug != null) #collectMergeDebug: collectMergeDebug,
    }),
  );
  @override
  JobRequest $make(CopyWithData data) => JobRequest(
    kind: data.get(#kind, or: $value.kind),
    topicIds: data.get(#topicIds, or: $value.topicIds),
    scope: data.get(#scope, or: $value.scope),
    boards: data.get(#boards, or: $value.boards),
    maxPagesMain: data.get(#maxPagesMain, or: $value.maxPagesMain),
    maxPagesLesser: data.get(#maxPagesLesser, or: $value.maxPagesLesser),
    maxPagesLibraries: data.get(
      #maxPagesLibraries,
      or: $value.maxPagesLibraries,
    ),
    runLlm: data.get(#runLlm, or: $value.runLlm),
    replayAllowed: data.get(#replayAllowed, or: $value.replayAllowed),
    testLimit: data.get(#testLimit, or: $value.testLimit),
    modSources: data.get(#modSources, or: $value.modSources),
    modForumPages: data.get(#modForumPages, or: $value.modForumPages),
    moddingForumPages: data.get(
      #moddingForumPages,
      or: $value.moddingForumPages,
    ),
    keepAllGameVersions: data.get(
      #keepAllGameVersions,
      or: $value.keepAllGameVersions,
    ),
    collectMergeDebug: data.get(
      #collectMergeDebug,
      or: $value.collectMergeDebug,
    ),
  );

  @override
  JobRequestCopyWith<$R2, JobRequest, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _JobRequestCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class RunCountersMapper extends ClassMapperBase<RunCounters> {
  RunCountersMapper._();

  static RunCountersMapper? _instance;
  static RunCountersMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = RunCountersMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'RunCounters';

  static int _$itemsDone(RunCounters v) => v.itemsDone;
  static const Field<RunCounters, int> _f$itemsDone = Field(
    'itemsDone',
    _$itemsDone,
    opt: true,
    def: 0,
  );
  static int _$itemsTotal(RunCounters v) => v.itemsTotal;
  static const Field<RunCounters, int> _f$itemsTotal = Field(
    'itemsTotal',
    _$itemsTotal,
    opt: true,
    def: 0,
  );
  static int _$errors(RunCounters v) => v.errors;
  static const Field<RunCounters, int> _f$errors = Field(
    'errors',
    _$errors,
    opt: true,
    def: 0,
  );
  static int _$llmCalls(RunCounters v) => v.llmCalls;
  static const Field<RunCounters, int> _f$llmCalls = Field(
    'llmCalls',
    _$llmCalls,
    opt: true,
    def: 0,
  );

  @override
  final MappableFields<RunCounters> fields = const {
    #itemsDone: _f$itemsDone,
    #itemsTotal: _f$itemsTotal,
    #errors: _f$errors,
    #llmCalls: _f$llmCalls,
  };

  static RunCounters _instantiate(DecodingData data) {
    return RunCounters(
      itemsDone: data.dec(_f$itemsDone),
      itemsTotal: data.dec(_f$itemsTotal),
      errors: data.dec(_f$errors),
      llmCalls: data.dec(_f$llmCalls),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static RunCounters fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<RunCounters>(map);
  }

  static RunCounters fromJson(String json) {
    return ensureInitialized().decodeJson<RunCounters>(json);
  }
}

mixin RunCountersMappable {
  String toJson() {
    return RunCountersMapper.ensureInitialized().encodeJson<RunCounters>(
      this as RunCounters,
    );
  }

  Map<String, dynamic> toMap() {
    return RunCountersMapper.ensureInitialized().encodeMap<RunCounters>(
      this as RunCounters,
    );
  }

  RunCountersCopyWith<RunCounters, RunCounters, RunCounters> get copyWith =>
      _RunCountersCopyWithImpl<RunCounters, RunCounters>(
        this as RunCounters,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return RunCountersMapper.ensureInitialized().stringifyValue(
      this as RunCounters,
    );
  }

  @override
  bool operator ==(Object other) {
    return RunCountersMapper.ensureInitialized().equalsValue(
      this as RunCounters,
      other,
    );
  }

  @override
  int get hashCode {
    return RunCountersMapper.ensureInitialized().hashValue(this as RunCounters);
  }
}

extension RunCountersValueCopy<$R, $Out>
    on ObjectCopyWith<$R, RunCounters, $Out> {
  RunCountersCopyWith<$R, RunCounters, $Out> get $asRunCounters =>
      $base.as((v, t, t2) => _RunCountersCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class RunCountersCopyWith<$R, $In extends RunCounters, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({int? itemsDone, int? itemsTotal, int? errors, int? llmCalls});
  RunCountersCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _RunCountersCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, RunCounters, $Out>
    implements RunCountersCopyWith<$R, RunCounters, $Out> {
  _RunCountersCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<RunCounters> $mapper =
      RunCountersMapper.ensureInitialized();
  @override
  $R call({int? itemsDone, int? itemsTotal, int? errors, int? llmCalls}) =>
      $apply(
        FieldCopyWithData({
          if (itemsDone != null) #itemsDone: itemsDone,
          if (itemsTotal != null) #itemsTotal: itemsTotal,
          if (errors != null) #errors: errors,
          if (llmCalls != null) #llmCalls: llmCalls,
        }),
      );
  @override
  RunCounters $make(CopyWithData data) => RunCounters(
    itemsDone: data.get(#itemsDone, or: $value.itemsDone),
    itemsTotal: data.get(#itemsTotal, or: $value.itemsTotal),
    errors: data.get(#errors, or: $value.errors),
    llmCalls: data.get(#llmCalls, or: $value.llmCalls),
  );

  @override
  RunCountersCopyWith<$R2, RunCounters, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _RunCountersCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class RunRecordMapper extends ClassMapperBase<RunRecord> {
  RunRecordMapper._();

  static RunRecordMapper? _instance;
  static RunRecordMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = RunRecordMapper._());
      JobRequestMapper.ensureInitialized();
      RunStateMapper.ensureInitialized();
      RunCountersMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'RunRecord';

  static String _$id(RunRecord v) => v.id;
  static const Field<RunRecord, String> _f$id = Field('id', _$id);
  static JobRequest _$request(RunRecord v) => v.request;
  static const Field<RunRecord, JobRequest> _f$request = Field(
    'request',
    _$request,
  );
  static RunState _$state(RunRecord v) => v.state;
  static const Field<RunRecord, RunState> _f$state = Field('state', _$state);
  static DateTime? _$startedAt(RunRecord v) => v.startedAt;
  static const Field<RunRecord, DateTime> _f$startedAt = Field(
    'startedAt',
    _$startedAt,
    opt: true,
  );
  static DateTime? _$finishedAt(RunRecord v) => v.finishedAt;
  static const Field<RunRecord, DateTime> _f$finishedAt = Field(
    'finishedAt',
    _$finishedAt,
    opt: true,
  );
  static RunCounters _$counters(RunRecord v) => v.counters;
  static const Field<RunRecord, RunCounters> _f$counters = Field(
    'counters',
    _$counters,
    opt: true,
    def: const RunCounters(),
  );
  static String? _$guardrailStop(RunRecord v) => v.guardrailStop;
  static const Field<RunRecord, String> _f$guardrailStop = Field(
    'guardrailStop',
    _$guardrailStop,
    opt: true,
  );
  static String? _$errorMessage(RunRecord v) => v.errorMessage;
  static const Field<RunRecord, String> _f$errorMessage = Field(
    'errorMessage',
    _$errorMessage,
    opt: true,
  );
  static String _$logFileName(RunRecord v) => v.logFileName;
  static const Field<RunRecord, String> _f$logFileName = Field(
    'logFileName',
    _$logFileName,
  );

  @override
  final MappableFields<RunRecord> fields = const {
    #id: _f$id,
    #request: _f$request,
    #state: _f$state,
    #startedAt: _f$startedAt,
    #finishedAt: _f$finishedAt,
    #counters: _f$counters,
    #guardrailStop: _f$guardrailStop,
    #errorMessage: _f$errorMessage,
    #logFileName: _f$logFileName,
  };

  static RunRecord _instantiate(DecodingData data) {
    return RunRecord(
      id: data.dec(_f$id),
      request: data.dec(_f$request),
      state: data.dec(_f$state),
      startedAt: data.dec(_f$startedAt),
      finishedAt: data.dec(_f$finishedAt),
      counters: data.dec(_f$counters),
      guardrailStop: data.dec(_f$guardrailStop),
      errorMessage: data.dec(_f$errorMessage),
      logFileName: data.dec(_f$logFileName),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static RunRecord fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<RunRecord>(map);
  }

  static RunRecord fromJson(String json) {
    return ensureInitialized().decodeJson<RunRecord>(json);
  }
}

mixin RunRecordMappable {
  String toJson() {
    return RunRecordMapper.ensureInitialized().encodeJson<RunRecord>(
      this as RunRecord,
    );
  }

  Map<String, dynamic> toMap() {
    return RunRecordMapper.ensureInitialized().encodeMap<RunRecord>(
      this as RunRecord,
    );
  }

  RunRecordCopyWith<RunRecord, RunRecord, RunRecord> get copyWith =>
      _RunRecordCopyWithImpl<RunRecord, RunRecord>(
        this as RunRecord,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return RunRecordMapper.ensureInitialized().stringifyValue(
      this as RunRecord,
    );
  }

  @override
  bool operator ==(Object other) {
    return RunRecordMapper.ensureInitialized().equalsValue(
      this as RunRecord,
      other,
    );
  }

  @override
  int get hashCode {
    return RunRecordMapper.ensureInitialized().hashValue(this as RunRecord);
  }
}

extension RunRecordValueCopy<$R, $Out> on ObjectCopyWith<$R, RunRecord, $Out> {
  RunRecordCopyWith<$R, RunRecord, $Out> get $asRunRecord =>
      $base.as((v, t, t2) => _RunRecordCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class RunRecordCopyWith<$R, $In extends RunRecord, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  JobRequestCopyWith<$R, JobRequest, JobRequest> get request;
  RunCountersCopyWith<$R, RunCounters, RunCounters> get counters;
  $R call({
    String? id,
    JobRequest? request,
    RunState? state,
    DateTime? startedAt,
    DateTime? finishedAt,
    RunCounters? counters,
    String? guardrailStop,
    String? errorMessage,
    String? logFileName,
  });
  RunRecordCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _RunRecordCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, RunRecord, $Out>
    implements RunRecordCopyWith<$R, RunRecord, $Out> {
  _RunRecordCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<RunRecord> $mapper =
      RunRecordMapper.ensureInitialized();
  @override
  JobRequestCopyWith<$R, JobRequest, JobRequest> get request =>
      $value.request.copyWith.$chain((v) => call(request: v));
  @override
  RunCountersCopyWith<$R, RunCounters, RunCounters> get counters =>
      $value.counters.copyWith.$chain((v) => call(counters: v));
  @override
  $R call({
    String? id,
    JobRequest? request,
    RunState? state,
    Object? startedAt = $none,
    Object? finishedAt = $none,
    RunCounters? counters,
    Object? guardrailStop = $none,
    Object? errorMessage = $none,
    String? logFileName,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (request != null) #request: request,
      if (state != null) #state: state,
      if (startedAt != $none) #startedAt: startedAt,
      if (finishedAt != $none) #finishedAt: finishedAt,
      if (counters != null) #counters: counters,
      if (guardrailStop != $none) #guardrailStop: guardrailStop,
      if (errorMessage != $none) #errorMessage: errorMessage,
      if (logFileName != null) #logFileName: logFileName,
    }),
  );
  @override
  RunRecord $make(CopyWithData data) => RunRecord(
    id: data.get(#id, or: $value.id),
    request: data.get(#request, or: $value.request),
    state: data.get(#state, or: $value.state),
    startedAt: data.get(#startedAt, or: $value.startedAt),
    finishedAt: data.get(#finishedAt, or: $value.finishedAt),
    counters: data.get(#counters, or: $value.counters),
    guardrailStop: data.get(#guardrailStop, or: $value.guardrailStop),
    errorMessage: data.get(#errorMessage, or: $value.errorMessage),
    logFileName: data.get(#logFileName, or: $value.logFileName),
  );

  @override
  RunRecordCopyWith<$R2, RunRecord, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _RunRecordCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

