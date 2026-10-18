// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'listing.dart';

class ListingOriginMapper extends EnumMapper<ListingOrigin> {
  ListingOriginMapper._();

  static ListingOriginMapper? _instance;
  static ListingOriginMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ListingOriginMapper._());
    }
    return _instance!;
  }

  static ListingOrigin fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  ListingOrigin decode(dynamic value) {
    switch (value) {
      case r'rules':
        return ListingOrigin.rules;
      case r'llm':
        return ListingOrigin.llm;
      case r'rulesAndLlm':
        return ListingOrigin.rulesAndLlm;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(ListingOrigin self) {
    switch (self) {
      case ListingOrigin.rules:
        return r'rules';
      case ListingOrigin.llm:
        return r'llm';
      case ListingOrigin.rulesAndLlm:
        return r'rulesAndLlm';
    }
  }
}

extension ListingOriginMapperExtension on ListingOrigin {
  String toValue() {
    ListingOriginMapper.ensureInitialized();
    return MapperContainer.globals.toValue<ListingOrigin>(this) as String;
  }
}

class ListingMapper extends ClassMapperBase<Listing> {
  ListingMapper._();

  static ListingMapper? _instance;
  static ListingMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ListingMapper._());
      ScrapedModMapper.ensureInitialized();
      SourcePostRefMapper.ensureInitialized();
      ListingOriginMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'Listing';

  static ScrapedMod _$mod(Listing v) => v.mod;
  static const Field<Listing, ScrapedMod> _f$mod = Field('mod', _$mod);
  static SourcePostRef _$ref(Listing v) => v.ref;
  static const Field<Listing, SourcePostRef> _f$ref = Field('ref', _$ref);
  static ListingOrigin _$origin(Listing v) => v.origin;
  static const Field<Listing, ListingOrigin> _f$origin = Field(
    'origin',
    _$origin,
    opt: true,
    def: ListingOrigin.rules,
  );
  static List<String> _$otherNames(Listing v) => v.otherNames;
  static const Field<Listing, List<String>> _f$otherNames = Field(
    'otherNames',
    _$otherNames,
    opt: true,
    def: const [],
  );
  static DateTime? _$postedAt(Listing v) => v.postedAt;
  static const Field<Listing, DateTime> _f$postedAt = Field(
    'postedAt',
    _$postedAt,
    opt: true,
  );
  static Set<String> _$downloadKeys(Listing v) => v.downloadKeys;
  static const Field<Listing, Set<String>> _f$downloadKeys = Field(
    'downloadKeys',
    _$downloadKeys,
    opt: true,
    def: const {},
  );

  @override
  final MappableFields<Listing> fields = const {
    #mod: _f$mod,
    #ref: _f$ref,
    #origin: _f$origin,
    #otherNames: _f$otherNames,
    #postedAt: _f$postedAt,
    #downloadKeys: _f$downloadKeys,
  };
  @override
  final bool ignoreNull = true;

  static Listing _instantiate(DecodingData data) {
    return Listing(
      mod: data.dec(_f$mod),
      ref: data.dec(_f$ref),
      origin: data.dec(_f$origin),
      otherNames: data.dec(_f$otherNames),
      postedAt: data.dec(_f$postedAt),
      downloadKeys: data.dec(_f$downloadKeys),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Listing fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Listing>(map);
  }

  static Listing fromJson(String json) {
    return ensureInitialized().decodeJson<Listing>(json);
  }
}

mixin ListingMappable {
  String toJson() {
    return ListingMapper.ensureInitialized().encodeJson<Listing>(
      this as Listing,
    );
  }

  Map<String, dynamic> toMap() {
    return ListingMapper.ensureInitialized().encodeMap<Listing>(
      this as Listing,
    );
  }

  ListingCopyWith<Listing, Listing, Listing> get copyWith =>
      _ListingCopyWithImpl<Listing, Listing>(
        this as Listing,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ListingMapper.ensureInitialized().stringifyValue(this as Listing);
  }

  @override
  bool operator ==(Object other) {
    return ListingMapper.ensureInitialized().equalsValue(
      this as Listing,
      other,
    );
  }

  @override
  int get hashCode {
    return ListingMapper.ensureInitialized().hashValue(this as Listing);
  }
}

extension ListingValueCopy<$R, $Out> on ObjectCopyWith<$R, Listing, $Out> {
  ListingCopyWith<$R, Listing, $Out> get $asListing =>
      $base.as((v, t, t2) => _ListingCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ListingCopyWith<$R, $In extends Listing, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod> get mod;
  SourcePostRefCopyWith<$R, SourcePostRef, SourcePostRef> get ref;
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get otherNames;
  $R call({
    ScrapedMod? mod,
    SourcePostRef? ref,
    ListingOrigin? origin,
    List<String>? otherNames,
    DateTime? postedAt,
    Set<String>? downloadKeys,
  });
  ListingCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ListingCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, Listing, $Out>
    implements ListingCopyWith<$R, Listing, $Out> {
  _ListingCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Listing> $mapper =
      ListingMapper.ensureInitialized();
  @override
  ScrapedModCopyWith<$R, ScrapedMod, ScrapedMod> get mod =>
      $value.mod.copyWith.$chain((v) => call(mod: v));
  @override
  SourcePostRefCopyWith<$R, SourcePostRef, SourcePostRef> get ref =>
      $value.ref.copyWith.$chain((v) => call(ref: v));
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get otherNames =>
      ListCopyWith(
        $value.otherNames,
        (v, t) => ObjectCopyWith(v, $identity, t),
        (v) => call(otherNames: v),
      );
  @override
  $R call({
    ScrapedMod? mod,
    SourcePostRef? ref,
    ListingOrigin? origin,
    List<String>? otherNames,
    Object? postedAt = $none,
    Set<String>? downloadKeys,
  }) => $apply(
    FieldCopyWithData({
      if (mod != null) #mod: mod,
      if (ref != null) #ref: ref,
      if (origin != null) #origin: origin,
      if (otherNames != null) #otherNames: otherNames,
      if (postedAt != $none) #postedAt: postedAt,
      if (downloadKeys != null) #downloadKeys: downloadKeys,
    }),
  );
  @override
  Listing $make(CopyWithData data) => Listing(
    mod: data.get(#mod, or: $value.mod),
    ref: data.get(#ref, or: $value.ref),
    origin: data.get(#origin, or: $value.origin),
    otherNames: data.get(#otherNames, or: $value.otherNames),
    postedAt: data.get(#postedAt, or: $value.postedAt),
    downloadKeys: data.get(#downloadKeys, or: $value.downloadKeys),
  );

  @override
  ListingCopyWith<$R2, Listing, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ListingCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class CatalogSourcePostMapper extends ClassMapperBase<CatalogSourcePost> {
  CatalogSourcePostMapper._();

  static CatalogSourcePostMapper? _instance;
  static CatalogSourcePostMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CatalogSourcePostMapper._());
      SourceKindMapper.ensureInitialized();
      ListingOriginMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'CatalogSourcePost';

  static SourceKind _$kind(CatalogSourcePost v) => v.kind;
  static const Field<CatalogSourcePost, SourceKind> _f$kind = Field(
    'kind',
    _$kind,
  );
  static String _$id(CatalogSourcePost v) => v.id;
  static const Field<CatalogSourcePost, String> _f$id = Field('id', _$id);
  static String? _$llmModName(CatalogSourcePost v) => v.llmModName;
  static const Field<CatalogSourcePost, String> _f$llmModName = Field(
    'llmModName',
    _$llmModName,
    opt: true,
  );
  static ListingOrigin _$foundBy(CatalogSourcePost v) => v.foundBy;
  static const Field<CatalogSourcePost, ListingOrigin> _f$foundBy = Field(
    'foundBy',
    _$foundBy,
    opt: true,
    def: ListingOrigin.rules,
  );

  @override
  final MappableFields<CatalogSourcePost> fields = const {
    #kind: _f$kind,
    #id: _f$id,
    #llmModName: _f$llmModName,
    #foundBy: _f$foundBy,
  };
  @override
  final bool ignoreNull = true;

  static CatalogSourcePost _instantiate(DecodingData data) {
    return CatalogSourcePost(
      kind: data.dec(_f$kind),
      id: data.dec(_f$id),
      llmModName: data.dec(_f$llmModName),
      foundBy: data.dec(_f$foundBy),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static CatalogSourcePost fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CatalogSourcePost>(map);
  }

  static CatalogSourcePost fromJson(String json) {
    return ensureInitialized().decodeJson<CatalogSourcePost>(json);
  }
}

mixin CatalogSourcePostMappable {
  String toJson() {
    return CatalogSourcePostMapper.ensureInitialized()
        .encodeJson<CatalogSourcePost>(this as CatalogSourcePost);
  }

  Map<String, dynamic> toMap() {
    return CatalogSourcePostMapper.ensureInitialized()
        .encodeMap<CatalogSourcePost>(this as CatalogSourcePost);
  }

  CatalogSourcePostCopyWith<
    CatalogSourcePost,
    CatalogSourcePost,
    CatalogSourcePost
  >
  get copyWith =>
      _CatalogSourcePostCopyWithImpl<CatalogSourcePost, CatalogSourcePost>(
        this as CatalogSourcePost,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return CatalogSourcePostMapper.ensureInitialized().stringifyValue(
      this as CatalogSourcePost,
    );
  }

  @override
  bool operator ==(Object other) {
    return CatalogSourcePostMapper.ensureInitialized().equalsValue(
      this as CatalogSourcePost,
      other,
    );
  }

  @override
  int get hashCode {
    return CatalogSourcePostMapper.ensureInitialized().hashValue(
      this as CatalogSourcePost,
    );
  }
}

extension CatalogSourcePostValueCopy<$R, $Out>
    on ObjectCopyWith<$R, CatalogSourcePost, $Out> {
  CatalogSourcePostCopyWith<$R, CatalogSourcePost, $Out>
  get $asCatalogSourcePost => $base.as(
    (v, t, t2) => _CatalogSourcePostCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class CatalogSourcePostCopyWith<
  $R,
  $In extends CatalogSourcePost,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    SourceKind? kind,
    String? id,
    String? llmModName,
    ListingOrigin? foundBy,
  });
  CatalogSourcePostCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _CatalogSourcePostCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, CatalogSourcePost, $Out>
    implements CatalogSourcePostCopyWith<$R, CatalogSourcePost, $Out> {
  _CatalogSourcePostCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<CatalogSourcePost> $mapper =
      CatalogSourcePostMapper.ensureInitialized();
  @override
  $R call({
    SourceKind? kind,
    String? id,
    Object? llmModName = $none,
    ListingOrigin? foundBy,
  }) => $apply(
    FieldCopyWithData({
      if (kind != null) #kind: kind,
      if (id != null) #id: id,
      if (llmModName != $none) #llmModName: llmModName,
      if (foundBy != null) #foundBy: foundBy,
    }),
  );
  @override
  CatalogSourcePost $make(CopyWithData data) => CatalogSourcePost(
    kind: data.get(#kind, or: $value.kind),
    id: data.get(#id, or: $value.id),
    llmModName: data.get(#llmModName, or: $value.llmModName),
    foundBy: data.get(#foundBy, or: $value.foundBy),
  );

  @override
  CatalogSourcePostCopyWith<$R2, CatalogSourcePost, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _CatalogSourcePostCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

