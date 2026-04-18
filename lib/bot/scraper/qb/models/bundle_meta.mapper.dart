// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'bundle_meta.dart';

class BundleMetaMapper extends ClassMapperBase<BundleMeta> {
  BundleMetaMapper._();

  static BundleMetaMapper? _instance;
  static BundleMetaMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = BundleMetaMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'BundleMeta';

  static DateTime _$generatedAt(BundleMeta v) => v.generatedAt;
  static const Field<BundleMeta, DateTime> _f$generatedAt = Field(
    'generatedAt',
    _$generatedAt,
  );
  static int _$totalMods(BundleMeta v) => v.totalMods;
  static const Field<BundleMeta, int> _f$totalMods = Field(
    'totalMods',
    _$totalMods,
    opt: true,
    def: 0,
  );
  static int _$totalDetails(BundleMeta v) => v.totalDetails;
  static const Field<BundleMeta, int> _f$totalDetails = Field(
    'totalDetails',
    _$totalDetails,
    opt: true,
    def: 0,
  );
  static int _$totalAssumedDownloadEntries(BundleMeta v) =>
      v.totalAssumedDownloadEntries;
  static const Field<BundleMeta, int> _f$totalAssumedDownloadEntries = Field(
    'totalAssumedDownloadEntries',
    _$totalAssumedDownloadEntries,
    opt: true,
    def: 0,
  );
  static int _$placeholderDetailCount(BundleMeta v) => v.placeholderDetailCount;
  static const Field<BundleMeta, int> _f$placeholderDetailCount = Field(
    'placeholderDetailCount',
    _$placeholderDetailCount,
    opt: true,
    def: 0,
  );
  static int? _$scrapeDurationSeconds(BundleMeta v) => v.scrapeDurationSeconds;
  static const Field<BundleMeta, int> _f$scrapeDurationSeconds = Field(
    'scrapeDurationSeconds',
    _$scrapeDurationSeconds,
    opt: true,
  );
  static int? _$modsScraped(BundleMeta v) => v.modsScraped;
  static const Field<BundleMeta, int> _f$modsScraped = Field(
    'modsScraped',
    _$modsScraped,
    opt: true,
  );
  static int? _$imagesDownloaded(BundleMeta v) => v.imagesDownloaded;
  static const Field<BundleMeta, int> _f$imagesDownloaded = Field(
    'imagesDownloaded',
    _$imagesDownloaded,
    opt: true,
  );
  static int? _$errors(BundleMeta v) => v.errors;
  static const Field<BundleMeta, int> _f$errors = Field(
    'errors',
    _$errors,
    opt: true,
  );

  @override
  final MappableFields<BundleMeta> fields = const {
    #generatedAt: _f$generatedAt,
    #totalMods: _f$totalMods,
    #totalDetails: _f$totalDetails,
    #totalAssumedDownloadEntries: _f$totalAssumedDownloadEntries,
    #placeholderDetailCount: _f$placeholderDetailCount,
    #scrapeDurationSeconds: _f$scrapeDurationSeconds,
    #modsScraped: _f$modsScraped,
    #imagesDownloaded: _f$imagesDownloaded,
    #errors: _f$errors,
  };
  @override
  final bool ignoreNull = true;

  static BundleMeta _instantiate(DecodingData data) {
    return BundleMeta(
      generatedAt: data.dec(_f$generatedAt),
      totalMods: data.dec(_f$totalMods),
      totalDetails: data.dec(_f$totalDetails),
      totalAssumedDownloadEntries: data.dec(_f$totalAssumedDownloadEntries),
      placeholderDetailCount: data.dec(_f$placeholderDetailCount),
      scrapeDurationSeconds: data.dec(_f$scrapeDurationSeconds),
      modsScraped: data.dec(_f$modsScraped),
      imagesDownloaded: data.dec(_f$imagesDownloaded),
      errors: data.dec(_f$errors),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static BundleMeta fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<BundleMeta>(map);
  }

  static BundleMeta fromJson(String json) {
    return ensureInitialized().decodeJson<BundleMeta>(json);
  }
}

mixin BundleMetaMappable {
  String toJson() {
    return BundleMetaMapper.ensureInitialized().encodeJson<BundleMeta>(
      this as BundleMeta,
    );
  }

  Map<String, dynamic> toMap() {
    return BundleMetaMapper.ensureInitialized().encodeMap<BundleMeta>(
      this as BundleMeta,
    );
  }

  BundleMetaCopyWith<BundleMeta, BundleMeta, BundleMeta> get copyWith =>
      _BundleMetaCopyWithImpl<BundleMeta, BundleMeta>(
        this as BundleMeta,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return BundleMetaMapper.ensureInitialized().stringifyValue(
      this as BundleMeta,
    );
  }

  @override
  bool operator ==(Object other) {
    return BundleMetaMapper.ensureInitialized().equalsValue(
      this as BundleMeta,
      other,
    );
  }

  @override
  int get hashCode {
    return BundleMetaMapper.ensureInitialized().hashValue(this as BundleMeta);
  }
}

extension BundleMetaValueCopy<$R, $Out>
    on ObjectCopyWith<$R, BundleMeta, $Out> {
  BundleMetaCopyWith<$R, BundleMeta, $Out> get $asBundleMeta =>
      $base.as((v, t, t2) => _BundleMetaCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class BundleMetaCopyWith<$R, $In extends BundleMeta, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    DateTime? generatedAt,
    int? totalMods,
    int? totalDetails,
    int? totalAssumedDownloadEntries,
    int? placeholderDetailCount,
    int? scrapeDurationSeconds,
    int? modsScraped,
    int? imagesDownloaded,
    int? errors,
  });
  BundleMetaCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _BundleMetaCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, BundleMeta, $Out>
    implements BundleMetaCopyWith<$R, BundleMeta, $Out> {
  _BundleMetaCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<BundleMeta> $mapper =
      BundleMetaMapper.ensureInitialized();
  @override
  $R call({
    DateTime? generatedAt,
    int? totalMods,
    int? totalDetails,
    int? totalAssumedDownloadEntries,
    int? placeholderDetailCount,
    Object? scrapeDurationSeconds = $none,
    Object? modsScraped = $none,
    Object? imagesDownloaded = $none,
    Object? errors = $none,
  }) => $apply(
    FieldCopyWithData({
      if (generatedAt != null) #generatedAt: generatedAt,
      if (totalMods != null) #totalMods: totalMods,
      if (totalDetails != null) #totalDetails: totalDetails,
      if (totalAssumedDownloadEntries != null)
        #totalAssumedDownloadEntries: totalAssumedDownloadEntries,
      if (placeholderDetailCount != null)
        #placeholderDetailCount: placeholderDetailCount,
      if (scrapeDurationSeconds != $none)
        #scrapeDurationSeconds: scrapeDurationSeconds,
      if (modsScraped != $none) #modsScraped: modsScraped,
      if (imagesDownloaded != $none) #imagesDownloaded: imagesDownloaded,
      if (errors != $none) #errors: errors,
    }),
  );
  @override
  BundleMeta $make(CopyWithData data) => BundleMeta(
    generatedAt: data.get(#generatedAt, or: $value.generatedAt),
    totalMods: data.get(#totalMods, or: $value.totalMods),
    totalDetails: data.get(#totalDetails, or: $value.totalDetails),
    totalAssumedDownloadEntries: data.get(
      #totalAssumedDownloadEntries,
      or: $value.totalAssumedDownloadEntries,
    ),
    placeholderDetailCount: data.get(
      #placeholderDetailCount,
      or: $value.placeholderDetailCount,
    ),
    scrapeDurationSeconds: data.get(
      #scrapeDurationSeconds,
      or: $value.scrapeDurationSeconds,
    ),
    modsScraped: data.get(#modsScraped, or: $value.modsScraped),
    imagesDownloaded: data.get(#imagesDownloaded, or: $value.imagesDownloaded),
    errors: data.get(#errors, or: $value.errors),
  );

  @override
  BundleMetaCopyWith<$R2, BundleMeta, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _BundleMetaCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

