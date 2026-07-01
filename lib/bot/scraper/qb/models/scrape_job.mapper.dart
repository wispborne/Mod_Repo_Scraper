// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'scrape_job.dart';

class ScrapeStateMapper extends EnumMapper<ScrapeState> {
  ScrapeStateMapper._();

  static ScrapeStateMapper? _instance;
  static ScrapeStateMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ScrapeStateMapper._());
    }
    return _instance!;
  }

  static ScrapeState fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  ScrapeState decode(dynamic value) {
    switch (value) {
      case r'idle':
        return ScrapeState.idle;
      case r'scraping':
        return ScrapeState.scraping;
      case r'completed':
        return ScrapeState.completed;
      case r'failed':
        return ScrapeState.failed;
      case r'cancelled':
        return ScrapeState.cancelled;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(ScrapeState self) {
    switch (self) {
      case ScrapeState.idle:
        return r'idle';
      case ScrapeState.scraping:
        return r'scraping';
      case ScrapeState.completed:
        return r'completed';
      case ScrapeState.failed:
        return r'failed';
      case ScrapeState.cancelled:
        return r'cancelled';
    }
  }
}

extension ScrapeStateMapperExtension on ScrapeState {
  String toValue() {
    ScrapeStateMapper.ensureInitialized();
    return MapperContainer.globals.toValue<ScrapeState>(this) as String;
  }
}

class ScopeTypeMapper extends EnumMapper<ScopeType> {
  ScopeTypeMapper._();

  static ScopeTypeMapper? _instance;
  static ScopeTypeMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ScopeTypeMapper._());
    }
    return _instance!;
  }

  static ScopeType fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  ScopeType decode(dynamic value) {
    switch (value) {
      case r'newData':
        return ScopeType.newData;
      case r'all':
        return ScopeType.all;
      case r'pages':
        return ScopeType.pages;
      case r'topics':
        return ScopeType.topics;
      case r'librariesOnly':
        return ScopeType.librariesOnly;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(ScopeType self) {
    switch (self) {
      case ScopeType.newData:
        return r'newData';
      case ScopeType.all:
        return r'all';
      case ScopeType.pages:
        return r'pages';
      case ScopeType.topics:
        return r'topics';
      case ScopeType.librariesOnly:
        return r'librariesOnly';
    }
  }
}

extension ScopeTypeMapperExtension on ScopeType {
  String toValue() {
    ScopeTypeMapper.ensureInitialized();
    return MapperContainer.globals.toValue<ScopeType>(this) as String;
  }
}

class ScrapeBoardMapper extends EnumMapper<ScrapeBoard> {
  ScrapeBoardMapper._();

  static ScrapeBoardMapper? _instance;
  static ScrapeBoardMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ScrapeBoardMapper._());
    }
    return _instance!;
  }

  static ScrapeBoard fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  ScrapeBoard decode(dynamic value) {
    switch (value) {
      case r'main':
        return ScrapeBoard.main;
      case r'lesser':
        return ScrapeBoard.lesser;
      case r'libraries':
        return ScrapeBoard.libraries;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(ScrapeBoard self) {
    switch (self) {
      case ScrapeBoard.main:
        return r'main';
      case ScrapeBoard.lesser:
        return r'lesser';
      case ScrapeBoard.libraries:
        return r'libraries';
    }
  }
}

extension ScrapeBoardMapperExtension on ScrapeBoard {
  String toValue() {
    ScrapeBoardMapper.ensureInitialized();
    return MapperContainer.globals.toValue<ScrapeBoard>(this) as String;
  }
}

class ScrapeScopeMapper extends ClassMapperBase<ScrapeScope> {
  ScrapeScopeMapper._();

  static ScrapeScopeMapper? _instance;
  static ScrapeScopeMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ScrapeScopeMapper._());
      ScopeTypeMapper.ensureInitialized();
      ScrapeBoardMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ScrapeScope';

  static ScopeType _$type(ScrapeScope v) => v.type;
  static const Field<ScrapeScope, ScopeType> _f$type = Field(
    'type',
    _$type,
    opt: true,
    def: ScopeType.all,
  );
  static int? _$maxPagesMain(ScrapeScope v) => v.maxPagesMain;
  static const Field<ScrapeScope, int> _f$maxPagesMain = Field(
    'maxPagesMain',
    _$maxPagesMain,
    opt: true,
  );
  static int? _$maxPagesLesser(ScrapeScope v) => v.maxPagesLesser;
  static const Field<ScrapeScope, int> _f$maxPagesLesser = Field(
    'maxPagesLesser',
    _$maxPagesLesser,
    opt: true,
  );
  static int? _$maxPagesLibraries(ScrapeScope v) => v.maxPagesLibraries;
  static const Field<ScrapeScope, int> _f$maxPagesLibraries = Field(
    'maxPagesLibraries',
    _$maxPagesLibraries,
    opt: true,
  );
  static List<int>? _$topicIds(ScrapeScope v) => v.topicIds;
  static const Field<ScrapeScope, List<int>> _f$topicIds = Field(
    'topicIds',
    _$topicIds,
    opt: true,
  );
  static Set<ScrapeBoard> _$boards(ScrapeScope v) => v.boards;
  static const Field<ScrapeScope, Set<ScrapeBoard>> _f$boards = Field(
    'boards',
    _$boards,
    opt: true,
  );

  @override
  final MappableFields<ScrapeScope> fields = const {
    #type: _f$type,
    #maxPagesMain: _f$maxPagesMain,
    #maxPagesLesser: _f$maxPagesLesser,
    #maxPagesLibraries: _f$maxPagesLibraries,
    #topicIds: _f$topicIds,
    #boards: _f$boards,
  };

  static ScrapeScope _instantiate(DecodingData data) {
    return ScrapeScope(
      type: data.dec(_f$type),
      maxPagesMain: data.dec(_f$maxPagesMain),
      maxPagesLesser: data.dec(_f$maxPagesLesser),
      maxPagesLibraries: data.dec(_f$maxPagesLibraries),
      topicIds: data.dec(_f$topicIds),
      boards: data.dec(_f$boards),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ScrapeScope fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ScrapeScope>(map);
  }

  static ScrapeScope fromJson(String json) {
    return ensureInitialized().decodeJson<ScrapeScope>(json);
  }
}

mixin ScrapeScopeMappable {
  String toJson() {
    return ScrapeScopeMapper.ensureInitialized().encodeJson<ScrapeScope>(
      this as ScrapeScope,
    );
  }

  Map<String, dynamic> toMap() {
    return ScrapeScopeMapper.ensureInitialized().encodeMap<ScrapeScope>(
      this as ScrapeScope,
    );
  }

  ScrapeScopeCopyWith<ScrapeScope, ScrapeScope, ScrapeScope> get copyWith =>
      _ScrapeScopeCopyWithImpl<ScrapeScope, ScrapeScope>(
        this as ScrapeScope,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ScrapeScopeMapper.ensureInitialized().stringifyValue(
      this as ScrapeScope,
    );
  }

  @override
  bool operator ==(Object other) {
    return ScrapeScopeMapper.ensureInitialized().equalsValue(
      this as ScrapeScope,
      other,
    );
  }

  @override
  int get hashCode {
    return ScrapeScopeMapper.ensureInitialized().hashValue(this as ScrapeScope);
  }
}

extension ScrapeScopeValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ScrapeScope, $Out> {
  ScrapeScopeCopyWith<$R, ScrapeScope, $Out> get $asScrapeScope =>
      $base.as((v, t, t2) => _ScrapeScopeCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ScrapeScopeCopyWith<$R, $In extends ScrapeScope, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, int, ObjectCopyWith<$R, int, int>>? get topicIds;
  $R call({
    ScopeType? type,
    int? maxPagesMain,
    int? maxPagesLesser,
    int? maxPagesLibraries,
    List<int>? topicIds,
    Set<ScrapeBoard>? boards,
  });
  ScrapeScopeCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ScrapeScopeCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ScrapeScope, $Out>
    implements ScrapeScopeCopyWith<$R, ScrapeScope, $Out> {
  _ScrapeScopeCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ScrapeScope> $mapper =
      ScrapeScopeMapper.ensureInitialized();
  @override
  ListCopyWith<$R, int, ObjectCopyWith<$R, int, int>>? get topicIds =>
      $value.topicIds != null
      ? ListCopyWith(
          $value.topicIds!,
          (v, t) => ObjectCopyWith(v, $identity, t),
          (v) => call(topicIds: v),
        )
      : null;
  @override
  $R call({
    ScopeType? type,
    Object? maxPagesMain = $none,
    Object? maxPagesLesser = $none,
    Object? maxPagesLibraries = $none,
    Object? topicIds = $none,
    Object? boards = $none,
  }) => $apply(
    FieldCopyWithData({
      if (type != null) #type: type,
      if (maxPagesMain != $none) #maxPagesMain: maxPagesMain,
      if (maxPagesLesser != $none) #maxPagesLesser: maxPagesLesser,
      if (maxPagesLibraries != $none) #maxPagesLibraries: maxPagesLibraries,
      if (topicIds != $none) #topicIds: topicIds,
      if (boards != $none) #boards: boards,
    }),
  );
  @override
  ScrapeScope $make(CopyWithData data) => ScrapeScope(
    type: data.get(#type, or: $value.type),
    maxPagesMain: data.get(#maxPagesMain, or: $value.maxPagesMain),
    maxPagesLesser: data.get(#maxPagesLesser, or: $value.maxPagesLesser),
    maxPagesLibraries: data.get(
      #maxPagesLibraries,
      or: $value.maxPagesLibraries,
    ),
    topicIds: data.get(#topicIds, or: $value.topicIds),
    boards: data.get(#boards, or: $value.boards),
  );

  @override
  ScrapeScopeCopyWith<$R2, ScrapeScope, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ScrapeScopeCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ScrapeResultMapper extends ClassMapperBase<ScrapeResult> {
  ScrapeResultMapper._();

  static ScrapeResultMapper? _instance;
  static ScrapeResultMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ScrapeResultMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'ScrapeResult';

  static bool _$success(ScrapeResult v) => v.success;
  static const Field<ScrapeResult, bool> _f$success = Field(
    'success',
    _$success,
    opt: true,
    def: true,
  );
  static int _$modsScraped(ScrapeResult v) => v.modsScraped;
  static const Field<ScrapeResult, int> _f$modsScraped = Field(
    'modsScraped',
    _$modsScraped,
    opt: true,
    def: 0,
  );
  static int _$imagesDownloaded(ScrapeResult v) => v.imagesDownloaded;
  static const Field<ScrapeResult, int> _f$imagesDownloaded = Field(
    'imagesDownloaded',
    _$imagesDownloaded,
    opt: true,
    def: 0,
  );
  static int _$errors(ScrapeResult v) => v.errors;
  static const Field<ScrapeResult, int> _f$errors = Field(
    'errors',
    _$errors,
    opt: true,
    def: 0,
  );
  static Duration _$duration(ScrapeResult v) => v.duration;
  static const Field<ScrapeResult, Duration> _f$duration = Field(
    'duration',
    _$duration,
    opt: true,
    def: Duration.zero,
  );
  static String? _$errorMessage(ScrapeResult v) => v.errorMessage;
  static const Field<ScrapeResult, String> _f$errorMessage = Field(
    'errorMessage',
    _$errorMessage,
    opt: true,
  );

  @override
  final MappableFields<ScrapeResult> fields = const {
    #success: _f$success,
    #modsScraped: _f$modsScraped,
    #imagesDownloaded: _f$imagesDownloaded,
    #errors: _f$errors,
    #duration: _f$duration,
    #errorMessage: _f$errorMessage,
  };

  static ScrapeResult _instantiate(DecodingData data) {
    return ScrapeResult(
      success: data.dec(_f$success),
      modsScraped: data.dec(_f$modsScraped),
      imagesDownloaded: data.dec(_f$imagesDownloaded),
      errors: data.dec(_f$errors),
      duration: data.dec(_f$duration),
      errorMessage: data.dec(_f$errorMessage),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ScrapeResult fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ScrapeResult>(map);
  }

  static ScrapeResult fromJson(String json) {
    return ensureInitialized().decodeJson<ScrapeResult>(json);
  }
}

mixin ScrapeResultMappable {
  String toJson() {
    return ScrapeResultMapper.ensureInitialized().encodeJson<ScrapeResult>(
      this as ScrapeResult,
    );
  }

  Map<String, dynamic> toMap() {
    return ScrapeResultMapper.ensureInitialized().encodeMap<ScrapeResult>(
      this as ScrapeResult,
    );
  }

  ScrapeResultCopyWith<ScrapeResult, ScrapeResult, ScrapeResult> get copyWith =>
      _ScrapeResultCopyWithImpl<ScrapeResult, ScrapeResult>(
        this as ScrapeResult,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ScrapeResultMapper.ensureInitialized().stringifyValue(
      this as ScrapeResult,
    );
  }

  @override
  bool operator ==(Object other) {
    return ScrapeResultMapper.ensureInitialized().equalsValue(
      this as ScrapeResult,
      other,
    );
  }

  @override
  int get hashCode {
    return ScrapeResultMapper.ensureInitialized().hashValue(
      this as ScrapeResult,
    );
  }
}

extension ScrapeResultValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ScrapeResult, $Out> {
  ScrapeResultCopyWith<$R, ScrapeResult, $Out> get $asScrapeResult =>
      $base.as((v, t, t2) => _ScrapeResultCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ScrapeResultCopyWith<$R, $In extends ScrapeResult, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    bool? success,
    int? modsScraped,
    int? imagesDownloaded,
    int? errors,
    Duration? duration,
    String? errorMessage,
  });
  ScrapeResultCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ScrapeResultCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ScrapeResult, $Out>
    implements ScrapeResultCopyWith<$R, ScrapeResult, $Out> {
  _ScrapeResultCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ScrapeResult> $mapper =
      ScrapeResultMapper.ensureInitialized();
  @override
  $R call({
    bool? success,
    int? modsScraped,
    int? imagesDownloaded,
    int? errors,
    Duration? duration,
    Object? errorMessage = $none,
  }) => $apply(
    FieldCopyWithData({
      if (success != null) #success: success,
      if (modsScraped != null) #modsScraped: modsScraped,
      if (imagesDownloaded != null) #imagesDownloaded: imagesDownloaded,
      if (errors != null) #errors: errors,
      if (duration != null) #duration: duration,
      if (errorMessage != $none) #errorMessage: errorMessage,
    }),
  );
  @override
  ScrapeResult $make(CopyWithData data) => ScrapeResult(
    success: data.get(#success, or: $value.success),
    modsScraped: data.get(#modsScraped, or: $value.modsScraped),
    imagesDownloaded: data.get(#imagesDownloaded, or: $value.imagesDownloaded),
    errors: data.get(#errors, or: $value.errors),
    duration: data.get(#duration, or: $value.duration),
    errorMessage: data.get(#errorMessage, or: $value.errorMessage),
  );

  @override
  ScrapeResultCopyWith<$R2, ScrapeResult, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ScrapeResultCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

