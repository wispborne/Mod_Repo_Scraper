// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'catalog_extras.dart';

class CatalogExtrasMapper extends ClassMapperBase<CatalogExtras> {
  CatalogExtrasMapper._();

  static CatalogExtrasMapper? _instance;
  static CatalogExtrasMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CatalogExtrasMapper._());
      CatalogExtrasModMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'CatalogExtras';

  static int _$schemaVersion(CatalogExtras v) => v.schemaVersion;
  static const Field<CatalogExtras, int> _f$schemaVersion = Field(
    'schemaVersion',
    _$schemaVersion,
    opt: true,
    def: CatalogExtras.currentSchemaVersion,
  );
  static DateTime _$generatedAt(CatalogExtras v) => v.generatedAt;
  static const Field<CatalogExtras, DateTime> _f$generatedAt = Field(
    'generatedAt',
    _$generatedAt,
  );
  static Map<String, CatalogExtrasMod> _$mods(CatalogExtras v) => v.mods;
  static const Field<CatalogExtras, Map<String, CatalogExtrasMod>> _f$mods =
      Field('mods', _$mods, opt: true, def: const {});

  @override
  final MappableFields<CatalogExtras> fields = const {
    #schemaVersion: _f$schemaVersion,
    #generatedAt: _f$generatedAt,
    #mods: _f$mods,
  };
  @override
  final bool ignoreNull = true;

  static CatalogExtras _instantiate(DecodingData data) {
    return CatalogExtras(
      schemaVersion: data.dec(_f$schemaVersion),
      generatedAt: data.dec(_f$generatedAt),
      mods: data.dec(_f$mods),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static CatalogExtras fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CatalogExtras>(map);
  }

  static CatalogExtras fromJson(String json) {
    return ensureInitialized().decodeJson<CatalogExtras>(json);
  }
}

mixin CatalogExtrasMappable {
  String toJson() {
    return CatalogExtrasMapper.ensureInitialized().encodeJson<CatalogExtras>(
      this as CatalogExtras,
    );
  }

  Map<String, dynamic> toMap() {
    return CatalogExtrasMapper.ensureInitialized().encodeMap<CatalogExtras>(
      this as CatalogExtras,
    );
  }

  CatalogExtrasCopyWith<CatalogExtras, CatalogExtras, CatalogExtras>
  get copyWith => _CatalogExtrasCopyWithImpl<CatalogExtras, CatalogExtras>(
    this as CatalogExtras,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return CatalogExtrasMapper.ensureInitialized().stringifyValue(
      this as CatalogExtras,
    );
  }

  @override
  bool operator ==(Object other) {
    return CatalogExtrasMapper.ensureInitialized().equalsValue(
      this as CatalogExtras,
      other,
    );
  }

  @override
  int get hashCode {
    return CatalogExtrasMapper.ensureInitialized().hashValue(
      this as CatalogExtras,
    );
  }
}

extension CatalogExtrasValueCopy<$R, $Out>
    on ObjectCopyWith<$R, CatalogExtras, $Out> {
  CatalogExtrasCopyWith<$R, CatalogExtras, $Out> get $asCatalogExtras =>
      $base.as((v, t, t2) => _CatalogExtrasCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class CatalogExtrasCopyWith<$R, $In extends CatalogExtras, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  MapCopyWith<
    $R,
    String,
    CatalogExtrasMod,
    CatalogExtrasModCopyWith<$R, CatalogExtrasMod, CatalogExtrasMod>
  >
  get mods;
  $R call({
    int? schemaVersion,
    DateTime? generatedAt,
    Map<String, CatalogExtrasMod>? mods,
  });
  CatalogExtrasCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _CatalogExtrasCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, CatalogExtras, $Out>
    implements CatalogExtrasCopyWith<$R, CatalogExtras, $Out> {
  _CatalogExtrasCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<CatalogExtras> $mapper =
      CatalogExtrasMapper.ensureInitialized();
  @override
  MapCopyWith<
    $R,
    String,
    CatalogExtrasMod,
    CatalogExtrasModCopyWith<$R, CatalogExtrasMod, CatalogExtrasMod>
  >
  get mods => MapCopyWith(
    $value.mods,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(mods: v),
  );
  @override
  $R call({
    int? schemaVersion,
    DateTime? generatedAt,
    Map<String, CatalogExtrasMod>? mods,
  }) => $apply(
    FieldCopyWithData({
      if (schemaVersion != null) #schemaVersion: schemaVersion,
      if (generatedAt != null) #generatedAt: generatedAt,
      if (mods != null) #mods: mods,
    }),
  );
  @override
  CatalogExtras $make(CopyWithData data) => CatalogExtras(
    schemaVersion: data.get(#schemaVersion, or: $value.schemaVersion),
    generatedAt: data.get(#generatedAt, or: $value.generatedAt),
    mods: data.get(#mods, or: $value.mods),
  );

  @override
  CatalogExtrasCopyWith<$R2, CatalogExtras, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _CatalogExtrasCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class CatalogExtrasModMapper extends ClassMapperBase<CatalogExtrasMod> {
  CatalogExtrasModMapper._();

  static CatalogExtrasModMapper? _instance;
  static CatalogExtrasModMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CatalogExtrasModMapper._());
      ModReleaseMapper.ensureInitialized();
      PublicNeededModMapper.ensureInitialized();
      SaveAnswerMapper.ensureInitialized();
      LlmAiUseMapper.ensureInitialized();
      PublicSameNameModMapper.ensureInitialized();
      PublicImageMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'CatalogExtrasMod';

  static String? _$displayName(CatalogExtrasMod v) => v.displayName;
  static const Field<CatalogExtrasMod, String> _f$displayName = Field(
    'displayName',
    _$displayName,
    opt: true,
  );
  static List<String>? _$categories(CatalogExtrasMod v) => v.categories;
  static const Field<CatalogExtrasMod, List<String>> _f$categories = Field(
    'categories',
    _$categories,
    opt: true,
  );
  static List<String>? _$rawCategories(CatalogExtrasMod v) => v.rawCategories;
  static const Field<CatalogExtrasMod, List<String>> _f$rawCategories = Field(
    'rawCategories',
    _$rawCategories,
    opt: true,
  );
  static Map<String, List<String>>? _$otherAuthorNames(CatalogExtrasMod v) =>
      v.otherAuthorNames;
  static const Field<CatalogExtrasMod, Map<String, List<String>>>
  _f$otherAuthorNames = Field(
    'otherAuthorNames',
    _$otherAuthorNames,
    opt: true,
  );
  static String? _$addedOn(CatalogExtrasMod v) => v.addedOn;
  static const Field<CatalogExtrasMod, String> _f$addedOn = Field(
    'addedOn',
    _$addedOn,
    opt: true,
  );
  static String? _$editedOn(CatalogExtrasMod v) => v.editedOn;
  static const Field<CatalogExtrasMod, String> _f$editedOn = Field(
    'editedOn',
    _$editedOn,
    opt: true,
  );
  static DateTime? _$lastReleaseDate(CatalogExtrasMod v) => v.lastReleaseDate;
  static const Field<CatalogExtrasMod, DateTime> _f$lastReleaseDate = Field(
    'lastReleaseDate',
    _$lastReleaseDate,
    opt: true,
  );
  static List<ModRelease>? _$releases(CatalogExtrasMod v) => v.releases;
  static const Field<CatalogExtrasMod, List<ModRelease>> _f$releases = Field(
    'releases',
    _$releases,
    opt: true,
  );
  static List<PublicNeededMod>? _$needs(CatalogExtrasMod v) => v.needs;
  static const Field<CatalogExtrasMod, List<PublicNeededMod>> _f$needs = Field(
    'needs',
    _$needs,
    opt: true,
  );
  static List<PublicNeededMod>? _$optionalNeeds(CatalogExtrasMod v) =>
      v.optionalNeeds;
  static const Field<CatalogExtrasMod, List<PublicNeededMod>> _f$optionalNeeds =
      Field('optionalNeeds', _$optionalNeeds, opt: true);
  static bool? _$isTool(CatalogExtrasMod v) => v.isTool;
  static const Field<CatalogExtrasMod, bool> _f$isTool = Field(
    'isTool',
    _$isTool,
    opt: true,
  );
  static bool? _$saveCompatible(CatalogExtrasMod v) => v.saveCompatible;
  static const Field<CatalogExtrasMod, bool> _f$saveCompatible = Field(
    'saveCompatible',
    _$saveCompatible,
    opt: true,
  );
  static SaveAnswer? _$canAdd(CatalogExtrasMod v) => v.canAdd;
  static const Field<CatalogExtrasMod, SaveAnswer> _f$canAdd = Field(
    'canAdd',
    _$canAdd,
    opt: true,
  );
  static SaveAnswer? _$canUpdate(CatalogExtrasMod v) => v.canUpdate;
  static const Field<CatalogExtrasMod, SaveAnswer> _f$canUpdate = Field(
    'canUpdate',
    _$canUpdate,
    opt: true,
  );
  static SaveAnswer? _$canRemove(CatalogExtrasMod v) => v.canRemove;
  static const Field<CatalogExtrasMod, SaveAnswer> _f$canRemove = Field(
    'canRemove',
    _$canRemove,
    opt: true,
  );
  static String? _$saveCompatibilityText(CatalogExtrasMod v) =>
      v.saveCompatibilityText;
  static const Field<CatalogExtrasMod, String> _f$saveCompatibilityText = Field(
    'saveCompatibilityText',
    _$saveCompatibilityText,
    opt: true,
  );
  static String? _$updateCompatibilityText(CatalogExtrasMod v) =>
      v.updateCompatibilityText;
  static const Field<CatalogExtrasMod, String> _f$updateCompatibilityText =
      Field('updateCompatibilityText', _$updateCompatibilityText, opt: true);
  static String? _$removalCompatibilityText(CatalogExtrasMod v) =>
      v.removalCompatibilityText;
  static const Field<CatalogExtrasMod, String> _f$removalCompatibilityText =
      Field('removalCompatibilityText', _$removalCompatibilityText, opt: true);
  static LlmAiUse? _$aiUse(CatalogExtrasMod v) => v.aiUse;
  static const Field<CatalogExtrasMod, LlmAiUse> _f$aiUse = Field(
    'aiUse',
    _$aiUse,
    opt: true,
  );
  static List<PublicSameNameMod>? _$sameNameMods(CatalogExtrasMod v) =>
      v.sameNameMods;
  static const Field<CatalogExtrasMod, List<PublicSameNameMod>>
  _f$sameNameMods = Field('sameNameMods', _$sameNameMods, opt: true);
  static List<PublicImage>? _$gallery(CatalogExtrasMod v) => v.gallery;
  static const Field<CatalogExtrasMod, List<PublicImage>> _f$gallery = Field(
    'gallery',
    _$gallery,
    opt: true,
  );
  static String? _$discordPostHtml(CatalogExtrasMod v) => v.discordPostHtml;
  static const Field<CatalogExtrasMod, String> _f$discordPostHtml = Field(
    'discordPostHtml',
    _$discordPostHtml,
    opt: true,
  );

  @override
  final MappableFields<CatalogExtrasMod> fields = const {
    #displayName: _f$displayName,
    #categories: _f$categories,
    #rawCategories: _f$rawCategories,
    #otherAuthorNames: _f$otherAuthorNames,
    #addedOn: _f$addedOn,
    #editedOn: _f$editedOn,
    #lastReleaseDate: _f$lastReleaseDate,
    #releases: _f$releases,
    #needs: _f$needs,
    #optionalNeeds: _f$optionalNeeds,
    #isTool: _f$isTool,
    #saveCompatible: _f$saveCompatible,
    #canAdd: _f$canAdd,
    #canUpdate: _f$canUpdate,
    #canRemove: _f$canRemove,
    #saveCompatibilityText: _f$saveCompatibilityText,
    #updateCompatibilityText: _f$updateCompatibilityText,
    #removalCompatibilityText: _f$removalCompatibilityText,
    #aiUse: _f$aiUse,
    #sameNameMods: _f$sameNameMods,
    #gallery: _f$gallery,
    #discordPostHtml: _f$discordPostHtml,
  };
  @override
  final bool ignoreNull = true;

  static CatalogExtrasMod _instantiate(DecodingData data) {
    return CatalogExtrasMod(
      displayName: data.dec(_f$displayName),
      categories: data.dec(_f$categories),
      rawCategories: data.dec(_f$rawCategories),
      otherAuthorNames: data.dec(_f$otherAuthorNames),
      addedOn: data.dec(_f$addedOn),
      editedOn: data.dec(_f$editedOn),
      lastReleaseDate: data.dec(_f$lastReleaseDate),
      releases: data.dec(_f$releases),
      needs: data.dec(_f$needs),
      optionalNeeds: data.dec(_f$optionalNeeds),
      isTool: data.dec(_f$isTool),
      saveCompatible: data.dec(_f$saveCompatible),
      canAdd: data.dec(_f$canAdd),
      canUpdate: data.dec(_f$canUpdate),
      canRemove: data.dec(_f$canRemove),
      saveCompatibilityText: data.dec(_f$saveCompatibilityText),
      updateCompatibilityText: data.dec(_f$updateCompatibilityText),
      removalCompatibilityText: data.dec(_f$removalCompatibilityText),
      aiUse: data.dec(_f$aiUse),
      sameNameMods: data.dec(_f$sameNameMods),
      gallery: data.dec(_f$gallery),
      discordPostHtml: data.dec(_f$discordPostHtml),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static CatalogExtrasMod fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CatalogExtrasMod>(map);
  }

  static CatalogExtrasMod fromJson(String json) {
    return ensureInitialized().decodeJson<CatalogExtrasMod>(json);
  }
}

mixin CatalogExtrasModMappable {
  String toJson() {
    return CatalogExtrasModMapper.ensureInitialized()
        .encodeJson<CatalogExtrasMod>(this as CatalogExtrasMod);
  }

  Map<String, dynamic> toMap() {
    return CatalogExtrasModMapper.ensureInitialized()
        .encodeMap<CatalogExtrasMod>(this as CatalogExtrasMod);
  }

  CatalogExtrasModCopyWith<CatalogExtrasMod, CatalogExtrasMod, CatalogExtrasMod>
  get copyWith =>
      _CatalogExtrasModCopyWithImpl<CatalogExtrasMod, CatalogExtrasMod>(
        this as CatalogExtrasMod,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return CatalogExtrasModMapper.ensureInitialized().stringifyValue(
      this as CatalogExtrasMod,
    );
  }

  @override
  bool operator ==(Object other) {
    return CatalogExtrasModMapper.ensureInitialized().equalsValue(
      this as CatalogExtrasMod,
      other,
    );
  }

  @override
  int get hashCode {
    return CatalogExtrasModMapper.ensureInitialized().hashValue(
      this as CatalogExtrasMod,
    );
  }
}

extension CatalogExtrasModValueCopy<$R, $Out>
    on ObjectCopyWith<$R, CatalogExtrasMod, $Out> {
  CatalogExtrasModCopyWith<$R, CatalogExtrasMod, $Out>
  get $asCatalogExtrasMod =>
      $base.as((v, t, t2) => _CatalogExtrasModCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class CatalogExtrasModCopyWith<$R, $In extends CatalogExtrasMod, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>? get categories;
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>?
  get rawCategories;
  MapCopyWith<
    $R,
    String,
    List<String>,
    ObjectCopyWith<$R, List<String>, List<String>>
  >?
  get otherAuthorNames;
  ListCopyWith<$R, ModRelease, ModReleaseCopyWith<$R, ModRelease, ModRelease>>?
  get releases;
  ListCopyWith<
    $R,
    PublicNeededMod,
    PublicNeededModCopyWith<$R, PublicNeededMod, PublicNeededMod>
  >?
  get needs;
  ListCopyWith<
    $R,
    PublicNeededMod,
    PublicNeededModCopyWith<$R, PublicNeededMod, PublicNeededMod>
  >?
  get optionalNeeds;
  LlmAiUseCopyWith<$R, LlmAiUse, LlmAiUse>? get aiUse;
  ListCopyWith<
    $R,
    PublicSameNameMod,
    PublicSameNameModCopyWith<$R, PublicSameNameMod, PublicSameNameMod>
  >?
  get sameNameMods;
  ListCopyWith<
    $R,
    PublicImage,
    PublicImageCopyWith<$R, PublicImage, PublicImage>
  >?
  get gallery;
  $R call({
    String? displayName,
    List<String>? categories,
    List<String>? rawCategories,
    Map<String, List<String>>? otherAuthorNames,
    String? addedOn,
    String? editedOn,
    DateTime? lastReleaseDate,
    List<ModRelease>? releases,
    List<PublicNeededMod>? needs,
    List<PublicNeededMod>? optionalNeeds,
    bool? isTool,
    bool? saveCompatible,
    SaveAnswer? canAdd,
    SaveAnswer? canUpdate,
    SaveAnswer? canRemove,
    String? saveCompatibilityText,
    String? updateCompatibilityText,
    String? removalCompatibilityText,
    LlmAiUse? aiUse,
    List<PublicSameNameMod>? sameNameMods,
    List<PublicImage>? gallery,
    String? discordPostHtml,
  });
  CatalogExtrasModCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _CatalogExtrasModCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, CatalogExtrasMod, $Out>
    implements CatalogExtrasModCopyWith<$R, CatalogExtrasMod, $Out> {
  _CatalogExtrasModCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<CatalogExtrasMod> $mapper =
      CatalogExtrasModMapper.ensureInitialized();
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>?
  get categories => $value.categories != null
      ? ListCopyWith(
          $value.categories!,
          (v, t) => ObjectCopyWith(v, $identity, t),
          (v) => call(categories: v),
        )
      : null;
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>?
  get rawCategories => $value.rawCategories != null
      ? ListCopyWith(
          $value.rawCategories!,
          (v, t) => ObjectCopyWith(v, $identity, t),
          (v) => call(rawCategories: v),
        )
      : null;
  @override
  MapCopyWith<
    $R,
    String,
    List<String>,
    ObjectCopyWith<$R, List<String>, List<String>>
  >?
  get otherAuthorNames => $value.otherAuthorNames != null
      ? MapCopyWith(
          $value.otherAuthorNames!,
          (v, t) => ObjectCopyWith(v, $identity, t),
          (v) => call(otherAuthorNames: v),
        )
      : null;
  @override
  ListCopyWith<$R, ModRelease, ModReleaseCopyWith<$R, ModRelease, ModRelease>>?
  get releases => $value.releases != null
      ? ListCopyWith(
          $value.releases!,
          (v, t) => v.copyWith.$chain(t),
          (v) => call(releases: v),
        )
      : null;
  @override
  ListCopyWith<
    $R,
    PublicNeededMod,
    PublicNeededModCopyWith<$R, PublicNeededMod, PublicNeededMod>
  >?
  get needs => $value.needs != null
      ? ListCopyWith(
          $value.needs!,
          (v, t) => v.copyWith.$chain(t),
          (v) => call(needs: v),
        )
      : null;
  @override
  ListCopyWith<
    $R,
    PublicNeededMod,
    PublicNeededModCopyWith<$R, PublicNeededMod, PublicNeededMod>
  >?
  get optionalNeeds => $value.optionalNeeds != null
      ? ListCopyWith(
          $value.optionalNeeds!,
          (v, t) => v.copyWith.$chain(t),
          (v) => call(optionalNeeds: v),
        )
      : null;
  @override
  LlmAiUseCopyWith<$R, LlmAiUse, LlmAiUse>? get aiUse =>
      $value.aiUse?.copyWith.$chain((v) => call(aiUse: v));
  @override
  ListCopyWith<
    $R,
    PublicSameNameMod,
    PublicSameNameModCopyWith<$R, PublicSameNameMod, PublicSameNameMod>
  >?
  get sameNameMods => $value.sameNameMods != null
      ? ListCopyWith(
          $value.sameNameMods!,
          (v, t) => v.copyWith.$chain(t),
          (v) => call(sameNameMods: v),
        )
      : null;
  @override
  ListCopyWith<
    $R,
    PublicImage,
    PublicImageCopyWith<$R, PublicImage, PublicImage>
  >?
  get gallery => $value.gallery != null
      ? ListCopyWith(
          $value.gallery!,
          (v, t) => v.copyWith.$chain(t),
          (v) => call(gallery: v),
        )
      : null;
  @override
  $R call({
    Object? displayName = $none,
    Object? categories = $none,
    Object? rawCategories = $none,
    Object? otherAuthorNames = $none,
    Object? addedOn = $none,
    Object? editedOn = $none,
    Object? lastReleaseDate = $none,
    Object? releases = $none,
    Object? needs = $none,
    Object? optionalNeeds = $none,
    Object? isTool = $none,
    Object? saveCompatible = $none,
    Object? canAdd = $none,
    Object? canUpdate = $none,
    Object? canRemove = $none,
    Object? saveCompatibilityText = $none,
    Object? updateCompatibilityText = $none,
    Object? removalCompatibilityText = $none,
    Object? aiUse = $none,
    Object? sameNameMods = $none,
    Object? gallery = $none,
    Object? discordPostHtml = $none,
  }) => $apply(
    FieldCopyWithData({
      if (displayName != $none) #displayName: displayName,
      if (categories != $none) #categories: categories,
      if (rawCategories != $none) #rawCategories: rawCategories,
      if (otherAuthorNames != $none) #otherAuthorNames: otherAuthorNames,
      if (addedOn != $none) #addedOn: addedOn,
      if (editedOn != $none) #editedOn: editedOn,
      if (lastReleaseDate != $none) #lastReleaseDate: lastReleaseDate,
      if (releases != $none) #releases: releases,
      if (needs != $none) #needs: needs,
      if (optionalNeeds != $none) #optionalNeeds: optionalNeeds,
      if (isTool != $none) #isTool: isTool,
      if (saveCompatible != $none) #saveCompatible: saveCompatible,
      if (canAdd != $none) #canAdd: canAdd,
      if (canUpdate != $none) #canUpdate: canUpdate,
      if (canRemove != $none) #canRemove: canRemove,
      if (saveCompatibilityText != $none)
        #saveCompatibilityText: saveCompatibilityText,
      if (updateCompatibilityText != $none)
        #updateCompatibilityText: updateCompatibilityText,
      if (removalCompatibilityText != $none)
        #removalCompatibilityText: removalCompatibilityText,
      if (aiUse != $none) #aiUse: aiUse,
      if (sameNameMods != $none) #sameNameMods: sameNameMods,
      if (gallery != $none) #gallery: gallery,
      if (discordPostHtml != $none) #discordPostHtml: discordPostHtml,
    }),
  );
  @override
  CatalogExtrasMod $make(CopyWithData data) => CatalogExtrasMod(
    displayName: data.get(#displayName, or: $value.displayName),
    categories: data.get(#categories, or: $value.categories),
    rawCategories: data.get(#rawCategories, or: $value.rawCategories),
    otherAuthorNames: data.get(#otherAuthorNames, or: $value.otherAuthorNames),
    addedOn: data.get(#addedOn, or: $value.addedOn),
    editedOn: data.get(#editedOn, or: $value.editedOn),
    lastReleaseDate: data.get(#lastReleaseDate, or: $value.lastReleaseDate),
    releases: data.get(#releases, or: $value.releases),
    needs: data.get(#needs, or: $value.needs),
    optionalNeeds: data.get(#optionalNeeds, or: $value.optionalNeeds),
    isTool: data.get(#isTool, or: $value.isTool),
    saveCompatible: data.get(#saveCompatible, or: $value.saveCompatible),
    canAdd: data.get(#canAdd, or: $value.canAdd),
    canUpdate: data.get(#canUpdate, or: $value.canUpdate),
    canRemove: data.get(#canRemove, or: $value.canRemove),
    saveCompatibilityText: data.get(
      #saveCompatibilityText,
      or: $value.saveCompatibilityText,
    ),
    updateCompatibilityText: data.get(
      #updateCompatibilityText,
      or: $value.updateCompatibilityText,
    ),
    removalCompatibilityText: data.get(
      #removalCompatibilityText,
      or: $value.removalCompatibilityText,
    ),
    aiUse: data.get(#aiUse, or: $value.aiUse),
    sameNameMods: data.get(#sameNameMods, or: $value.sameNameMods),
    gallery: data.get(#gallery, or: $value.gallery),
    discordPostHtml: data.get(#discordPostHtml, or: $value.discordPostHtml),
  );

  @override
  CatalogExtrasModCopyWith<$R2, CatalogExtrasMod, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _CatalogExtrasModCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

