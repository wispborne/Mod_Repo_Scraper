// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'assumed_download.dart';

class AssumedDownloadCandidateMapper
    extends ClassMapperBase<AssumedDownloadCandidate> {
  AssumedDownloadCandidateMapper._();

  static AssumedDownloadCandidateMapper? _instance;
  static AssumedDownloadCandidateMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = AssumedDownloadCandidateMapper._(),
      );
    }
    return _instance!;
  }

  @override
  final String id = 'AssumedDownloadCandidate';

  static String _$originalUrl(AssumedDownloadCandidate v) => v.originalUrl;
  static const Field<AssumedDownloadCandidate, String> _f$originalUrl = Field(
    'originalUrl',
    _$originalUrl,
    opt: true,
    def: '',
  );
  static String? _$resolvedDirectUrl(AssumedDownloadCandidate v) =>
      v.resolvedDirectUrl;
  static const Field<AssumedDownloadCandidate, String> _f$resolvedDirectUrl =
      Field('resolvedDirectUrl', _$resolvedDirectUrl, opt: true);
  static String _$sourceHost(AssumedDownloadCandidate v) => v.sourceHost;
  static const Field<AssumedDownloadCandidate, String> _f$sourceHost = Field(
    'sourceHost',
    _$sourceHost,
    opt: true,
    def: '',
  );
  static String? _$fileName(AssumedDownloadCandidate v) => v.fileName;
  static const Field<AssumedDownloadCandidate, String> _f$fileName = Field(
    'fileName',
    _$fileName,
    opt: true,
  );
  static String _$confidence(AssumedDownloadCandidate v) => v.confidence;
  static const Field<AssumedDownloadCandidate, String> _f$confidence = Field(
    'confidence',
    _$confidence,
    opt: true,
    def: 'medium',
  );
  static bool _$requiresManualStep(AssumedDownloadCandidate v) =>
      v.requiresManualStep;
  static const Field<AssumedDownloadCandidate, bool> _f$requiresManualStep =
      Field('requiresManualStep', _$requiresManualStep, opt: true, def: false);
  static String? _$linkText(AssumedDownloadCandidate v) => v.linkText;
  static const Field<AssumedDownloadCandidate, String> _f$linkText = Field(
    'linkText',
    _$linkText,
    opt: true,
  );

  @override
  final MappableFields<AssumedDownloadCandidate> fields = const {
    #originalUrl: _f$originalUrl,
    #resolvedDirectUrl: _f$resolvedDirectUrl,
    #sourceHost: _f$sourceHost,
    #fileName: _f$fileName,
    #confidence: _f$confidence,
    #requiresManualStep: _f$requiresManualStep,
    #linkText: _f$linkText,
  };
  @override
  final bool ignoreNull = true;

  static AssumedDownloadCandidate _instantiate(DecodingData data) {
    return AssumedDownloadCandidate(
      originalUrl: data.dec(_f$originalUrl),
      resolvedDirectUrl: data.dec(_f$resolvedDirectUrl),
      sourceHost: data.dec(_f$sourceHost),
      fileName: data.dec(_f$fileName),
      confidence: data.dec(_f$confidence),
      requiresManualStep: data.dec(_f$requiresManualStep),
      linkText: data.dec(_f$linkText),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static AssumedDownloadCandidate fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<AssumedDownloadCandidate>(map);
  }

  static AssumedDownloadCandidate fromJson(String json) {
    return ensureInitialized().decodeJson<AssumedDownloadCandidate>(json);
  }
}

mixin AssumedDownloadCandidateMappable {
  String toJson() {
    return AssumedDownloadCandidateMapper.ensureInitialized()
        .encodeJson<AssumedDownloadCandidate>(this as AssumedDownloadCandidate);
  }

  Map<String, dynamic> toMap() {
    return AssumedDownloadCandidateMapper.ensureInitialized()
        .encodeMap<AssumedDownloadCandidate>(this as AssumedDownloadCandidate);
  }

  AssumedDownloadCandidateCopyWith<
    AssumedDownloadCandidate,
    AssumedDownloadCandidate,
    AssumedDownloadCandidate
  >
  get copyWith =>
      _AssumedDownloadCandidateCopyWithImpl<
        AssumedDownloadCandidate,
        AssumedDownloadCandidate
      >(this as AssumedDownloadCandidate, $identity, $identity);
  @override
  String toString() {
    return AssumedDownloadCandidateMapper.ensureInitialized().stringifyValue(
      this as AssumedDownloadCandidate,
    );
  }

  @override
  bool operator ==(Object other) {
    return AssumedDownloadCandidateMapper.ensureInitialized().equalsValue(
      this as AssumedDownloadCandidate,
      other,
    );
  }

  @override
  int get hashCode {
    return AssumedDownloadCandidateMapper.ensureInitialized().hashValue(
      this as AssumedDownloadCandidate,
    );
  }
}

extension AssumedDownloadCandidateValueCopy<$R, $Out>
    on ObjectCopyWith<$R, AssumedDownloadCandidate, $Out> {
  AssumedDownloadCandidateCopyWith<$R, AssumedDownloadCandidate, $Out>
  get $asAssumedDownloadCandidate => $base.as(
    (v, t, t2) => _AssumedDownloadCandidateCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class AssumedDownloadCandidateCopyWith<
  $R,
  $In extends AssumedDownloadCandidate,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? originalUrl,
    String? resolvedDirectUrl,
    String? sourceHost,
    String? fileName,
    String? confidence,
    bool? requiresManualStep,
    String? linkText,
  });
  AssumedDownloadCandidateCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _AssumedDownloadCandidateCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, AssumedDownloadCandidate, $Out>
    implements
        AssumedDownloadCandidateCopyWith<$R, AssumedDownloadCandidate, $Out> {
  _AssumedDownloadCandidateCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<AssumedDownloadCandidate> $mapper =
      AssumedDownloadCandidateMapper.ensureInitialized();
  @override
  $R call({
    String? originalUrl,
    Object? resolvedDirectUrl = $none,
    String? sourceHost,
    Object? fileName = $none,
    String? confidence,
    bool? requiresManualStep,
    Object? linkText = $none,
  }) => $apply(
    FieldCopyWithData({
      if (originalUrl != null) #originalUrl: originalUrl,
      if (resolvedDirectUrl != $none) #resolvedDirectUrl: resolvedDirectUrl,
      if (sourceHost != null) #sourceHost: sourceHost,
      if (fileName != $none) #fileName: fileName,
      if (confidence != null) #confidence: confidence,
      if (requiresManualStep != null) #requiresManualStep: requiresManualStep,
      if (linkText != $none) #linkText: linkText,
    }),
  );
  @override
  AssumedDownloadCandidate $make(CopyWithData data) => AssumedDownloadCandidate(
    originalUrl: data.get(#originalUrl, or: $value.originalUrl),
    resolvedDirectUrl: data.get(
      #resolvedDirectUrl,
      or: $value.resolvedDirectUrl,
    ),
    sourceHost: data.get(#sourceHost, or: $value.sourceHost),
    fileName: data.get(#fileName, or: $value.fileName),
    confidence: data.get(#confidence, or: $value.confidence),
    requiresManualStep: data.get(
      #requiresManualStep,
      or: $value.requiresManualStep,
    ),
    linkText: data.get(#linkText, or: $value.linkText),
  );

  @override
  AssumedDownloadCandidateCopyWith<$R2, AssumedDownloadCandidate, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _AssumedDownloadCandidateCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

