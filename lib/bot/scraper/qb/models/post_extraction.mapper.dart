// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'post_extraction.dart';

class LlmChangelogMapper extends ClassMapperBase<LlmChangelog> {
  LlmChangelogMapper._();

  static LlmChangelogMapper? _instance;
  static LlmChangelogMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LlmChangelogMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'LlmChangelog';

  static String? _$link(LlmChangelog v) => v.link;
  static const Field<LlmChangelog, String> _f$link = Field(
    'link',
    _$link,
    opt: true,
  );
  static Map<String, String>? _$entries(LlmChangelog v) => v.entries;
  static const Field<LlmChangelog, Map<String, String>> _f$entries = Field(
    'entries',
    _$entries,
    opt: true,
  );

  @override
  final MappableFields<LlmChangelog> fields = const {
    #link: _f$link,
    #entries: _f$entries,
  };
  @override
  final bool ignoreNull = true;

  static LlmChangelog _instantiate(DecodingData data) {
    return LlmChangelog(link: data.dec(_f$link), entries: data.dec(_f$entries));
  }

  @override
  final Function instantiate = _instantiate;

  static LlmChangelog fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<LlmChangelog>(map);
  }

  static LlmChangelog fromJson(String json) {
    return ensureInitialized().decodeJson<LlmChangelog>(json);
  }
}

mixin LlmChangelogMappable {
  String toJson() {
    return LlmChangelogMapper.ensureInitialized().encodeJson<LlmChangelog>(
      this as LlmChangelog,
    );
  }

  Map<String, dynamic> toMap() {
    return LlmChangelogMapper.ensureInitialized().encodeMap<LlmChangelog>(
      this as LlmChangelog,
    );
  }

  LlmChangelogCopyWith<LlmChangelog, LlmChangelog, LlmChangelog> get copyWith =>
      _LlmChangelogCopyWithImpl<LlmChangelog, LlmChangelog>(
        this as LlmChangelog,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return LlmChangelogMapper.ensureInitialized().stringifyValue(
      this as LlmChangelog,
    );
  }

  @override
  bool operator ==(Object other) {
    return LlmChangelogMapper.ensureInitialized().equalsValue(
      this as LlmChangelog,
      other,
    );
  }

  @override
  int get hashCode {
    return LlmChangelogMapper.ensureInitialized().hashValue(
      this as LlmChangelog,
    );
  }
}

extension LlmChangelogValueCopy<$R, $Out>
    on ObjectCopyWith<$R, LlmChangelog, $Out> {
  LlmChangelogCopyWith<$R, LlmChangelog, $Out> get $asLlmChangelog =>
      $base.as((v, t, t2) => _LlmChangelogCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class LlmChangelogCopyWith<$R, $In extends LlmChangelog, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  MapCopyWith<$R, String, String, ObjectCopyWith<$R, String, String>>?
  get entries;
  $R call({String? link, Map<String, String>? entries});
  LlmChangelogCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _LlmChangelogCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, LlmChangelog, $Out>
    implements LlmChangelogCopyWith<$R, LlmChangelog, $Out> {
  _LlmChangelogCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<LlmChangelog> $mapper =
      LlmChangelogMapper.ensureInitialized();
  @override
  MapCopyWith<$R, String, String, ObjectCopyWith<$R, String, String>>?
  get entries => $value.entries != null
      ? MapCopyWith(
          $value.entries!,
          (v, t) => ObjectCopyWith(v, $identity, t),
          (v) => call(entries: v),
        )
      : null;
  @override
  $R call({Object? link = $none, Object? entries = $none}) => $apply(
    FieldCopyWithData({
      if (link != $none) #link: link,
      if (entries != $none) #entries: entries,
    }),
  );
  @override
  LlmChangelog $make(CopyWithData data) => LlmChangelog(
    link: data.get(#link, or: $value.link),
    entries: data.get(#entries, or: $value.entries),
  );

  @override
  LlmChangelogCopyWith<$R2, LlmChangelog, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _LlmChangelogCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class LlmSupportLinkMapper extends ClassMapperBase<LlmSupportLink> {
  LlmSupportLinkMapper._();

  static LlmSupportLinkMapper? _instance;
  static LlmSupportLinkMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LlmSupportLinkMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'LlmSupportLink';

  static String _$url(LlmSupportLink v) => v.url;
  static const Field<LlmSupportLink, String> _f$url = Field('url', _$url);
  static String _$type(LlmSupportLink v) => v.type;
  static const Field<LlmSupportLink, String> _f$type = Field('type', _$type);

  @override
  final MappableFields<LlmSupportLink> fields = const {
    #url: _f$url,
    #type: _f$type,
  };

  static LlmSupportLink _instantiate(DecodingData data) {
    return LlmSupportLink(url: data.dec(_f$url), type: data.dec(_f$type));
  }

  @override
  final Function instantiate = _instantiate;

  static LlmSupportLink fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<LlmSupportLink>(map);
  }

  static LlmSupportLink fromJson(String json) {
    return ensureInitialized().decodeJson<LlmSupportLink>(json);
  }
}

mixin LlmSupportLinkMappable {
  String toJson() {
    return LlmSupportLinkMapper.ensureInitialized().encodeJson<LlmSupportLink>(
      this as LlmSupportLink,
    );
  }

  Map<String, dynamic> toMap() {
    return LlmSupportLinkMapper.ensureInitialized().encodeMap<LlmSupportLink>(
      this as LlmSupportLink,
    );
  }

  LlmSupportLinkCopyWith<LlmSupportLink, LlmSupportLink, LlmSupportLink>
  get copyWith => _LlmSupportLinkCopyWithImpl<LlmSupportLink, LlmSupportLink>(
    this as LlmSupportLink,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return LlmSupportLinkMapper.ensureInitialized().stringifyValue(
      this as LlmSupportLink,
    );
  }

  @override
  bool operator ==(Object other) {
    return LlmSupportLinkMapper.ensureInitialized().equalsValue(
      this as LlmSupportLink,
      other,
    );
  }

  @override
  int get hashCode {
    return LlmSupportLinkMapper.ensureInitialized().hashValue(
      this as LlmSupportLink,
    );
  }
}

extension LlmSupportLinkValueCopy<$R, $Out>
    on ObjectCopyWith<$R, LlmSupportLink, $Out> {
  LlmSupportLinkCopyWith<$R, LlmSupportLink, $Out> get $asLlmSupportLink =>
      $base.as((v, t, t2) => _LlmSupportLinkCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class LlmSupportLinkCopyWith<$R, $In extends LlmSupportLink, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? url, String? type});
  LlmSupportLinkCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _LlmSupportLinkCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, LlmSupportLink, $Out>
    implements LlmSupportLinkCopyWith<$R, LlmSupportLink, $Out> {
  _LlmSupportLinkCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<LlmSupportLink> $mapper =
      LlmSupportLinkMapper.ensureInitialized();
  @override
  $R call({String? url, String? type}) => $apply(
    FieldCopyWithData({
      if (url != null) #url: url,
      if (type != null) #type: type,
    }),
  );
  @override
  LlmSupportLink $make(CopyWithData data) => LlmSupportLink(
    url: data.get(#url, or: $value.url),
    type: data.get(#type, or: $value.type),
  );

  @override
  LlmSupportLinkCopyWith<$R2, LlmSupportLink, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _LlmSupportLinkCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class LlmModSummaryMapper extends ClassMapperBase<LlmModSummary> {
  LlmModSummaryMapper._();

  static LlmModSummaryMapper? _instance;
  static LlmModSummaryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LlmModSummaryMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'LlmModSummary';

  static String? _$sentence(LlmModSummary v) => v.sentence;
  static const Field<LlmModSummary, String> _f$sentence = Field(
    'sentence',
    _$sentence,
    opt: true,
  );
  static String? _$paragraph(LlmModSummary v) => v.paragraph;
  static const Field<LlmModSummary, String> _f$paragraph = Field(
    'paragraph',
    _$paragraph,
    opt: true,
  );

  @override
  final MappableFields<LlmModSummary> fields = const {
    #sentence: _f$sentence,
    #paragraph: _f$paragraph,
  };
  @override
  final bool ignoreNull = true;

  static LlmModSummary _instantiate(DecodingData data) {
    return LlmModSummary(
      sentence: data.dec(_f$sentence),
      paragraph: data.dec(_f$paragraph),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static LlmModSummary fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<LlmModSummary>(map);
  }

  static LlmModSummary fromJson(String json) {
    return ensureInitialized().decodeJson<LlmModSummary>(json);
  }
}

mixin LlmModSummaryMappable {
  String toJson() {
    return LlmModSummaryMapper.ensureInitialized().encodeJson<LlmModSummary>(
      this as LlmModSummary,
    );
  }

  Map<String, dynamic> toMap() {
    return LlmModSummaryMapper.ensureInitialized().encodeMap<LlmModSummary>(
      this as LlmModSummary,
    );
  }

  LlmModSummaryCopyWith<LlmModSummary, LlmModSummary, LlmModSummary>
  get copyWith => _LlmModSummaryCopyWithImpl<LlmModSummary, LlmModSummary>(
    this as LlmModSummary,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return LlmModSummaryMapper.ensureInitialized().stringifyValue(
      this as LlmModSummary,
    );
  }

  @override
  bool operator ==(Object other) {
    return LlmModSummaryMapper.ensureInitialized().equalsValue(
      this as LlmModSummary,
      other,
    );
  }

  @override
  int get hashCode {
    return LlmModSummaryMapper.ensureInitialized().hashValue(
      this as LlmModSummary,
    );
  }
}

extension LlmModSummaryValueCopy<$R, $Out>
    on ObjectCopyWith<$R, LlmModSummary, $Out> {
  LlmModSummaryCopyWith<$R, LlmModSummary, $Out> get $asLlmModSummary =>
      $base.as((v, t, t2) => _LlmModSummaryCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class LlmModSummaryCopyWith<$R, $In extends LlmModSummary, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? sentence, String? paragraph});
  LlmModSummaryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _LlmModSummaryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, LlmModSummary, $Out>
    implements LlmModSummaryCopyWith<$R, LlmModSummary, $Out> {
  _LlmModSummaryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<LlmModSummary> $mapper =
      LlmModSummaryMapper.ensureInitialized();
  @override
  $R call({Object? sentence = $none, Object? paragraph = $none}) => $apply(
    FieldCopyWithData({
      if (sentence != $none) #sentence: sentence,
      if (paragraph != $none) #paragraph: paragraph,
    }),
  );
  @override
  LlmModSummary $make(CopyWithData data) => LlmModSummary(
    sentence: data.get(#sentence, or: $value.sentence),
    paragraph: data.get(#paragraph, or: $value.paragraph),
  );

  @override
  LlmModSummaryCopyWith<$R2, LlmModSummary, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _LlmModSummaryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class LlmExtrasMapper extends ClassMapperBase<LlmExtras> {
  LlmExtrasMapper._();

  static LlmExtrasMapper? _instance;
  static LlmExtrasMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LlmExtrasMapper._());
      LlmChangelogMapper.ensureInitialized();
      LlmSupportLinkMapper.ensureInitialized();
      LlmModSummaryMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'LlmExtras';

  static String? _$version(LlmExtras v) => v.version;
  static const Field<LlmExtras, String> _f$version = Field(
    'version',
    _$version,
    opt: true,
  );
  static LlmChangelog? _$changelog(LlmExtras v) => v.changelog;
  static const Field<LlmExtras, LlmChangelog> _f$changelog = Field(
    'changelog',
    _$changelog,
    opt: true,
  );
  static List<LlmSupportLink>? _$supportLinks(LlmExtras v) => v.supportLinks;
  static const Field<LlmExtras, List<LlmSupportLink>> _f$supportLinks = Field(
    'supportLinks',
    _$supportLinks,
    opt: true,
  );
  static String? _$license(LlmExtras v) => v.license;
  static const Field<LlmExtras, String> _f$license = Field(
    'license',
    _$license,
    opt: true,
  );
  static String? _$saveCompatibility(LlmExtras v) => v.saveCompatibility;
  static const Field<LlmExtras, String> _f$saveCompatibility = Field(
    'saveCompatibility',
    _$saveCompatibility,
    opt: true,
  );
  static LlmModSummary? _$summary(LlmExtras v) => v.summary;
  static const Field<LlmExtras, LlmModSummary> _f$summary = Field(
    'summary',
    _$summary,
    opt: true,
  );

  @override
  final MappableFields<LlmExtras> fields = const {
    #version: _f$version,
    #changelog: _f$changelog,
    #supportLinks: _f$supportLinks,
    #license: _f$license,
    #saveCompatibility: _f$saveCompatibility,
    #summary: _f$summary,
  };
  @override
  final bool ignoreNull = true;

  static LlmExtras _instantiate(DecodingData data) {
    return LlmExtras(
      version: data.dec(_f$version),
      changelog: data.dec(_f$changelog),
      supportLinks: data.dec(_f$supportLinks),
      license: data.dec(_f$license),
      saveCompatibility: data.dec(_f$saveCompatibility),
      summary: data.dec(_f$summary),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static LlmExtras fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<LlmExtras>(map);
  }

  static LlmExtras fromJson(String json) {
    return ensureInitialized().decodeJson<LlmExtras>(json);
  }
}

mixin LlmExtrasMappable {
  String toJson() {
    return LlmExtrasMapper.ensureInitialized().encodeJson<LlmExtras>(
      this as LlmExtras,
    );
  }

  Map<String, dynamic> toMap() {
    return LlmExtrasMapper.ensureInitialized().encodeMap<LlmExtras>(
      this as LlmExtras,
    );
  }

  LlmExtrasCopyWith<LlmExtras, LlmExtras, LlmExtras> get copyWith =>
      _LlmExtrasCopyWithImpl<LlmExtras, LlmExtras>(
        this as LlmExtras,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return LlmExtrasMapper.ensureInitialized().stringifyValue(
      this as LlmExtras,
    );
  }

  @override
  bool operator ==(Object other) {
    return LlmExtrasMapper.ensureInitialized().equalsValue(
      this as LlmExtras,
      other,
    );
  }

  @override
  int get hashCode {
    return LlmExtrasMapper.ensureInitialized().hashValue(this as LlmExtras);
  }
}

extension LlmExtrasValueCopy<$R, $Out> on ObjectCopyWith<$R, LlmExtras, $Out> {
  LlmExtrasCopyWith<$R, LlmExtras, $Out> get $asLlmExtras =>
      $base.as((v, t, t2) => _LlmExtrasCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class LlmExtrasCopyWith<$R, $In extends LlmExtras, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  LlmChangelogCopyWith<$R, LlmChangelog, LlmChangelog>? get changelog;
  ListCopyWith<
    $R,
    LlmSupportLink,
    LlmSupportLinkCopyWith<$R, LlmSupportLink, LlmSupportLink>
  >?
  get supportLinks;
  LlmModSummaryCopyWith<$R, LlmModSummary, LlmModSummary>? get summary;
  $R call({
    String? version,
    LlmChangelog? changelog,
    List<LlmSupportLink>? supportLinks,
    String? license,
    String? saveCompatibility,
    LlmModSummary? summary,
  });
  LlmExtrasCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _LlmExtrasCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, LlmExtras, $Out>
    implements LlmExtrasCopyWith<$R, LlmExtras, $Out> {
  _LlmExtrasCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<LlmExtras> $mapper =
      LlmExtrasMapper.ensureInitialized();
  @override
  LlmChangelogCopyWith<$R, LlmChangelog, LlmChangelog>? get changelog =>
      $value.changelog?.copyWith.$chain((v) => call(changelog: v));
  @override
  ListCopyWith<
    $R,
    LlmSupportLink,
    LlmSupportLinkCopyWith<$R, LlmSupportLink, LlmSupportLink>
  >?
  get supportLinks => $value.supportLinks != null
      ? ListCopyWith(
          $value.supportLinks!,
          (v, t) => v.copyWith.$chain(t),
          (v) => call(supportLinks: v),
        )
      : null;
  @override
  LlmModSummaryCopyWith<$R, LlmModSummary, LlmModSummary>? get summary =>
      $value.summary?.copyWith.$chain((v) => call(summary: v));
  @override
  $R call({
    Object? version = $none,
    Object? changelog = $none,
    Object? supportLinks = $none,
    Object? license = $none,
    Object? saveCompatibility = $none,
    Object? summary = $none,
  }) => $apply(
    FieldCopyWithData({
      if (version != $none) #version: version,
      if (changelog != $none) #changelog: changelog,
      if (supportLinks != $none) #supportLinks: supportLinks,
      if (license != $none) #license: license,
      if (saveCompatibility != $none) #saveCompatibility: saveCompatibility,
      if (summary != $none) #summary: summary,
    }),
  );
  @override
  LlmExtras $make(CopyWithData data) => LlmExtras(
    version: data.get(#version, or: $value.version),
    changelog: data.get(#changelog, or: $value.changelog),
    supportLinks: data.get(#supportLinks, or: $value.supportLinks),
    license: data.get(#license, or: $value.license),
    saveCompatibility: data.get(
      #saveCompatibility,
      or: $value.saveCompatibility,
    ),
    summary: data.get(#summary, or: $value.summary),
  );

  @override
  LlmExtrasCopyWith<$R2, LlmExtras, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _LlmExtrasCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class LlmDownloadMapper extends ClassMapperBase<LlmDownload> {
  LlmDownloadMapper._();

  static LlmDownloadMapper? _instance;
  static LlmDownloadMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LlmDownloadMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'LlmDownload';

  static String _$url(LlmDownload v) => v.url;
  static const Field<LlmDownload, String> _f$url = Field(
    'url',
    _$url,
    opt: true,
    def: '',
  );
  static String _$label(LlmDownload v) => v.label;
  static const Field<LlmDownload, String> _f$label = Field(
    'label',
    _$label,
    opt: true,
    def: '',
  );
  static String _$kind(LlmDownload v) => v.kind;
  static const Field<LlmDownload, String> _f$kind = Field(
    'kind',
    _$kind,
    opt: true,
    def: LlmDownloadKind.direct,
  );
  static String? _$resolvedDirectUrl(LlmDownload v) => v.resolvedDirectUrl;
  static const Field<LlmDownload, String> _f$resolvedDirectUrl = Field(
    'resolvedDirectUrl',
    _$resolvedDirectUrl,
    opt: true,
  );
  static String _$sourceHost(LlmDownload v) => v.sourceHost;
  static const Field<LlmDownload, String> _f$sourceHost = Field(
    'sourceHost',
    _$sourceHost,
    opt: true,
    def: '',
  );
  static String? _$fileName(LlmDownload v) => v.fileName;
  static const Field<LlmDownload, String> _f$fileName = Field(
    'fileName',
    _$fileName,
    opt: true,
  );
  static String _$confidence(LlmDownload v) => v.confidence;
  static const Field<LlmDownload, String> _f$confidence = Field(
    'confidence',
    _$confidence,
    opt: true,
    def: 'medium',
  );
  static bool _$requiresManualStep(LlmDownload v) => v.requiresManualStep;
  static const Field<LlmDownload, bool> _f$requiresManualStep = Field(
    'requiresManualStep',
    _$requiresManualStep,
    opt: true,
    def: false,
  );

  @override
  final MappableFields<LlmDownload> fields = const {
    #url: _f$url,
    #label: _f$label,
    #kind: _f$kind,
    #resolvedDirectUrl: _f$resolvedDirectUrl,
    #sourceHost: _f$sourceHost,
    #fileName: _f$fileName,
    #confidence: _f$confidence,
    #requiresManualStep: _f$requiresManualStep,
  };
  @override
  final bool ignoreNull = true;

  static LlmDownload _instantiate(DecodingData data) {
    return LlmDownload(
      url: data.dec(_f$url),
      label: data.dec(_f$label),
      kind: data.dec(_f$kind),
      resolvedDirectUrl: data.dec(_f$resolvedDirectUrl),
      sourceHost: data.dec(_f$sourceHost),
      fileName: data.dec(_f$fileName),
      confidence: data.dec(_f$confidence),
      requiresManualStep: data.dec(_f$requiresManualStep),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static LlmDownload fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<LlmDownload>(map);
  }

  static LlmDownload fromJson(String json) {
    return ensureInitialized().decodeJson<LlmDownload>(json);
  }
}

mixin LlmDownloadMappable {
  String toJson() {
    return LlmDownloadMapper.ensureInitialized().encodeJson<LlmDownload>(
      this as LlmDownload,
    );
  }

  Map<String, dynamic> toMap() {
    return LlmDownloadMapper.ensureInitialized().encodeMap<LlmDownload>(
      this as LlmDownload,
    );
  }

  LlmDownloadCopyWith<LlmDownload, LlmDownload, LlmDownload> get copyWith =>
      _LlmDownloadCopyWithImpl<LlmDownload, LlmDownload>(
        this as LlmDownload,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return LlmDownloadMapper.ensureInitialized().stringifyValue(
      this as LlmDownload,
    );
  }

  @override
  bool operator ==(Object other) {
    return LlmDownloadMapper.ensureInitialized().equalsValue(
      this as LlmDownload,
      other,
    );
  }

  @override
  int get hashCode {
    return LlmDownloadMapper.ensureInitialized().hashValue(this as LlmDownload);
  }
}

extension LlmDownloadValueCopy<$R, $Out>
    on ObjectCopyWith<$R, LlmDownload, $Out> {
  LlmDownloadCopyWith<$R, LlmDownload, $Out> get $asLlmDownload =>
      $base.as((v, t, t2) => _LlmDownloadCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class LlmDownloadCopyWith<$R, $In extends LlmDownload, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? url,
    String? label,
    String? kind,
    String? resolvedDirectUrl,
    String? sourceHost,
    String? fileName,
    String? confidence,
    bool? requiresManualStep,
  });
  LlmDownloadCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _LlmDownloadCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, LlmDownload, $Out>
    implements LlmDownloadCopyWith<$R, LlmDownload, $Out> {
  _LlmDownloadCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<LlmDownload> $mapper =
      LlmDownloadMapper.ensureInitialized();
  @override
  $R call({
    String? url,
    String? label,
    String? kind,
    Object? resolvedDirectUrl = $none,
    String? sourceHost,
    Object? fileName = $none,
    String? confidence,
    bool? requiresManualStep,
  }) => $apply(
    FieldCopyWithData({
      if (url != null) #url: url,
      if (label != null) #label: label,
      if (kind != null) #kind: kind,
      if (resolvedDirectUrl != $none) #resolvedDirectUrl: resolvedDirectUrl,
      if (sourceHost != null) #sourceHost: sourceHost,
      if (fileName != $none) #fileName: fileName,
      if (confidence != null) #confidence: confidence,
      if (requiresManualStep != null) #requiresManualStep: requiresManualStep,
    }),
  );
  @override
  LlmDownload $make(CopyWithData data) => LlmDownload(
    url: data.get(#url, or: $value.url),
    label: data.get(#label, or: $value.label),
    kind: data.get(#kind, or: $value.kind),
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
  );

  @override
  LlmDownloadCopyWith<$R2, LlmDownload, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _LlmDownloadCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class LlmModMapper extends ClassMapperBase<LlmMod> {
  LlmModMapper._();

  static LlmModMapper? _instance;
  static LlmModMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LlmModMapper._());
      LlmDownloadMapper.ensureInitialized();
      LlmExtrasMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'LlmMod';

  static String _$name(LlmMod v) => v.name;
  static const Field<LlmMod, String> _f$name = Field(
    'name',
    _$name,
    opt: true,
    def: '',
  );
  static String _$role(LlmMod v) => v.role;
  static const Field<LlmMod, String> _f$role = Field(
    'role',
    _$role,
    opt: true,
    def: LlmModRole.main,
  );
  static String? _$requires(LlmMod v) => v.requires;
  static const Field<LlmMod, String> _f$requires = Field(
    'requires',
    _$requires,
    opt: true,
  );
  static List<LlmDownload> _$downloads(LlmMod v) => v.downloads;
  static const Field<LlmMod, List<LlmDownload>> _f$downloads = Field(
    'downloads',
    _$downloads,
    opt: true,
    def: const [],
  );
  static String? _$image(LlmMod v) => v.image;
  static const Field<LlmMod, String> _f$image = Field(
    'image',
    _$image,
    opt: true,
  );
  static LlmExtras? _$extras(LlmMod v) => v.extras;
  static const Field<LlmMod, LlmExtras> _f$extras = Field(
    'extras',
    _$extras,
    opt: true,
  );

  @override
  final MappableFields<LlmMod> fields = const {
    #name: _f$name,
    #role: _f$role,
    #requires: _f$requires,
    #downloads: _f$downloads,
    #image: _f$image,
    #extras: _f$extras,
  };
  @override
  final bool ignoreNull = true;

  static LlmMod _instantiate(DecodingData data) {
    return LlmMod(
      name: data.dec(_f$name),
      role: data.dec(_f$role),
      requires: data.dec(_f$requires),
      downloads: data.dec(_f$downloads),
      image: data.dec(_f$image),
      extras: data.dec(_f$extras),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static LlmMod fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<LlmMod>(map);
  }

  static LlmMod fromJson(String json) {
    return ensureInitialized().decodeJson<LlmMod>(json);
  }
}

mixin LlmModMappable {
  String toJson() {
    return LlmModMapper.ensureInitialized().encodeJson<LlmMod>(this as LlmMod);
  }

  Map<String, dynamic> toMap() {
    return LlmModMapper.ensureInitialized().encodeMap<LlmMod>(this as LlmMod);
  }

  LlmModCopyWith<LlmMod, LlmMod, LlmMod> get copyWith =>
      _LlmModCopyWithImpl<LlmMod, LlmMod>(this as LlmMod, $identity, $identity);
  @override
  String toString() {
    return LlmModMapper.ensureInitialized().stringifyValue(this as LlmMod);
  }

  @override
  bool operator ==(Object other) {
    return LlmModMapper.ensureInitialized().equalsValue(this as LlmMod, other);
  }

  @override
  int get hashCode {
    return LlmModMapper.ensureInitialized().hashValue(this as LlmMod);
  }
}

extension LlmModValueCopy<$R, $Out> on ObjectCopyWith<$R, LlmMod, $Out> {
  LlmModCopyWith<$R, LlmMod, $Out> get $asLlmMod =>
      $base.as((v, t, t2) => _LlmModCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class LlmModCopyWith<$R, $In extends LlmMod, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<
    $R,
    LlmDownload,
    LlmDownloadCopyWith<$R, LlmDownload, LlmDownload>
  >
  get downloads;
  LlmExtrasCopyWith<$R, LlmExtras, LlmExtras>? get extras;
  $R call({
    String? name,
    String? role,
    String? requires,
    List<LlmDownload>? downloads,
    String? image,
    LlmExtras? extras,
  });
  LlmModCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _LlmModCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, LlmMod, $Out>
    implements LlmModCopyWith<$R, LlmMod, $Out> {
  _LlmModCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<LlmMod> $mapper = LlmModMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    LlmDownload,
    LlmDownloadCopyWith<$R, LlmDownload, LlmDownload>
  >
  get downloads => ListCopyWith(
    $value.downloads,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(downloads: v),
  );
  @override
  LlmExtrasCopyWith<$R, LlmExtras, LlmExtras>? get extras =>
      $value.extras?.copyWith.$chain((v) => call(extras: v));
  @override
  $R call({
    String? name,
    String? role,
    Object? requires = $none,
    List<LlmDownload>? downloads,
    Object? image = $none,
    Object? extras = $none,
  }) => $apply(
    FieldCopyWithData({
      if (name != null) #name: name,
      if (role != null) #role: role,
      if (requires != $none) #requires: requires,
      if (downloads != null) #downloads: downloads,
      if (image != $none) #image: image,
      if (extras != $none) #extras: extras,
    }),
  );
  @override
  LlmMod $make(CopyWithData data) => LlmMod(
    name: data.get(#name, or: $value.name),
    role: data.get(#role, or: $value.role),
    requires: data.get(#requires, or: $value.requires),
    downloads: data.get(#downloads, or: $value.downloads),
    image: data.get(#image, or: $value.image),
    extras: data.get(#extras, or: $value.extras),
  );

  @override
  LlmModCopyWith<$R2, LlmMod, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _LlmModCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class LlmThreadDataMapper extends ClassMapperBase<LlmThreadData> {
  LlmThreadDataMapper._();

  static LlmThreadDataMapper? _instance;
  static LlmThreadDataMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LlmThreadDataMapper._());
      LlmModMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'LlmThreadData';

  static List<LlmMod> _$mods(LlmThreadData v) => v.mods;
  static const Field<LlmThreadData, List<LlmMod>> _f$mods = Field(
    'mods',
    _$mods,
    opt: true,
    def: const [],
  );

  @override
  final MappableFields<LlmThreadData> fields = const {#mods: _f$mods};
  @override
  final bool ignoreNull = true;

  static LlmThreadData _instantiate(DecodingData data) {
    return LlmThreadData(mods: data.dec(_f$mods));
  }

  @override
  final Function instantiate = _instantiate;

  static LlmThreadData fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<LlmThreadData>(map);
  }

  static LlmThreadData fromJson(String json) {
    return ensureInitialized().decodeJson<LlmThreadData>(json);
  }
}

mixin LlmThreadDataMappable {
  String toJson() {
    return LlmThreadDataMapper.ensureInitialized().encodeJson<LlmThreadData>(
      this as LlmThreadData,
    );
  }

  Map<String, dynamic> toMap() {
    return LlmThreadDataMapper.ensureInitialized().encodeMap<LlmThreadData>(
      this as LlmThreadData,
    );
  }

  LlmThreadDataCopyWith<LlmThreadData, LlmThreadData, LlmThreadData>
  get copyWith => _LlmThreadDataCopyWithImpl<LlmThreadData, LlmThreadData>(
    this as LlmThreadData,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return LlmThreadDataMapper.ensureInitialized().stringifyValue(
      this as LlmThreadData,
    );
  }

  @override
  bool operator ==(Object other) {
    return LlmThreadDataMapper.ensureInitialized().equalsValue(
      this as LlmThreadData,
      other,
    );
  }

  @override
  int get hashCode {
    return LlmThreadDataMapper.ensureInitialized().hashValue(
      this as LlmThreadData,
    );
  }
}

extension LlmThreadDataValueCopy<$R, $Out>
    on ObjectCopyWith<$R, LlmThreadData, $Out> {
  LlmThreadDataCopyWith<$R, LlmThreadData, $Out> get $asLlmThreadData =>
      $base.as((v, t, t2) => _LlmThreadDataCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class LlmThreadDataCopyWith<$R, $In extends LlmThreadData, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, LlmMod, LlmModCopyWith<$R, LlmMod, LlmMod>> get mods;
  $R call({List<LlmMod>? mods});
  LlmThreadDataCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _LlmThreadDataCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, LlmThreadData, $Out>
    implements LlmThreadDataCopyWith<$R, LlmThreadData, $Out> {
  _LlmThreadDataCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<LlmThreadData> $mapper =
      LlmThreadDataMapper.ensureInitialized();
  @override
  ListCopyWith<$R, LlmMod, LlmModCopyWith<$R, LlmMod, LlmMod>> get mods =>
      ListCopyWith(
        $value.mods,
        (v, t) => v.copyWith.$chain(t),
        (v) => call(mods: v),
      );
  @override
  $R call({List<LlmMod>? mods}) =>
      $apply(FieldCopyWithData({if (mods != null) #mods: mods}));
  @override
  LlmThreadData $make(CopyWithData data) =>
      LlmThreadData(mods: data.get(#mods, or: $value.mods));

  @override
  LlmThreadDataCopyWith<$R2, LlmThreadData, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _LlmThreadDataCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

