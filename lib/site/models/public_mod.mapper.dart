// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'public_mod.dart';

class PublicModListMapper extends ClassMapperBase<PublicModList> {
  PublicModListMapper._();

  static PublicModListMapper? _instance;
  static PublicModListMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PublicModListMapper._());
      PublicModMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'PublicModList';

  static DateTime _$generatedAt(PublicModList v) => v.generatedAt;
  static const Field<PublicModList, DateTime> _f$generatedAt = Field(
    'generatedAt',
    _$generatedAt,
  );
  static List<PublicMod> _$mods(PublicModList v) => v.mods;
  static const Field<PublicModList, List<PublicMod>> _f$mods = Field(
    'mods',
    _$mods,
    opt: true,
    def: const [],
  );

  @override
  final MappableFields<PublicModList> fields = const {
    #generatedAt: _f$generatedAt,
    #mods: _f$mods,
  };
  @override
  final bool ignoreNull = true;

  static PublicModList _instantiate(DecodingData data) {
    return PublicModList(
      generatedAt: data.dec(_f$generatedAt),
      mods: data.dec(_f$mods),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PublicModList fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PublicModList>(map);
  }

  static PublicModList fromJson(String json) {
    return ensureInitialized().decodeJson<PublicModList>(json);
  }
}

mixin PublicModListMappable {
  String toJson() {
    return PublicModListMapper.ensureInitialized().encodeJson<PublicModList>(
      this as PublicModList,
    );
  }

  Map<String, dynamic> toMap() {
    return PublicModListMapper.ensureInitialized().encodeMap<PublicModList>(
      this as PublicModList,
    );
  }

  PublicModListCopyWith<PublicModList, PublicModList, PublicModList>
  get copyWith => _PublicModListCopyWithImpl<PublicModList, PublicModList>(
    this as PublicModList,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return PublicModListMapper.ensureInitialized().stringifyValue(
      this as PublicModList,
    );
  }

  @override
  bool operator ==(Object other) {
    return PublicModListMapper.ensureInitialized().equalsValue(
      this as PublicModList,
      other,
    );
  }

  @override
  int get hashCode {
    return PublicModListMapper.ensureInitialized().hashValue(
      this as PublicModList,
    );
  }
}

extension PublicModListValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PublicModList, $Out> {
  PublicModListCopyWith<$R, PublicModList, $Out> get $asPublicModList =>
      $base.as((v, t, t2) => _PublicModListCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PublicModListCopyWith<$R, $In extends PublicModList, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, PublicMod, PublicModCopyWith<$R, PublicMod, PublicMod>>
  get mods;
  $R call({DateTime? generatedAt, List<PublicMod>? mods});
  PublicModListCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _PublicModListCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PublicModList, $Out>
    implements PublicModListCopyWith<$R, PublicModList, $Out> {
  _PublicModListCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PublicModList> $mapper =
      PublicModListMapper.ensureInitialized();
  @override
  ListCopyWith<$R, PublicMod, PublicModCopyWith<$R, PublicMod, PublicMod>>
  get mods => ListCopyWith(
    $value.mods,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(mods: v),
  );
  @override
  $R call({DateTime? generatedAt, List<PublicMod>? mods}) => $apply(
    FieldCopyWithData({
      if (generatedAt != null) #generatedAt: generatedAt,
      if (mods != null) #mods: mods,
    }),
  );
  @override
  PublicModList $make(CopyWithData data) => PublicModList(
    generatedAt: data.get(#generatedAt, or: $value.generatedAt),
    mods: data.get(#mods, or: $value.mods),
  );

  @override
  PublicModListCopyWith<$R2, PublicModList, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PublicModListCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class PublicModMapper extends ClassMapperBase<PublicMod> {
  PublicModMapper._();

  static PublicModMapper? _instance;
  static PublicModMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PublicModMapper._());
      PublicBestDownloadMapper.ensureInitialized();
      PublicNeededModMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'PublicMod';

  static String _$id(PublicMod v) => v.id;
  static const Field<PublicMod, String> _f$id = Field('id', _$id);
  static String _$name(PublicMod v) => v.name;
  static const Field<PublicMod, String> _f$name = Field('name', _$name);
  static String? _$displayName(PublicMod v) => v.displayName;
  static const Field<PublicMod, String> _f$displayName = Field(
    'displayName',
    _$displayName,
    opt: true,
  );
  static List<String> _$authors(PublicMod v) => v.authors;
  static const Field<PublicMod, List<String>> _f$authors = Field(
    'authors',
    _$authors,
    opt: true,
    def: const [],
  );
  static Map<String, List<String>> _$otherAuthorNames(PublicMod v) =>
      v.otherAuthorNames;
  static const Field<PublicMod, Map<String, List<String>>> _f$otherAuthorNames =
      Field('otherAuthorNames', _$otherAuthorNames, opt: true, def: const {});
  static List<String> _$categories(PublicMod v) => v.categories;
  static const Field<PublicMod, List<String>> _f$categories = Field(
    'categories',
    _$categories,
    opt: true,
    def: const [],
  );
  static List<String> _$sources(PublicMod v) => v.sources;
  static const Field<PublicMod, List<String>> _f$sources = Field(
    'sources',
    _$sources,
    opt: true,
    def: const [],
  );
  static String? _$gameVersion(PublicMod v) => v.gameVersion;
  static const Field<PublicMod, String> _f$gameVersion = Field(
    'gameVersion',
    _$gameVersion,
    opt: true,
  );
  static String? _$modVersion(PublicMod v) => v.modVersion;
  static const Field<PublicMod, String> _f$modVersion = Field(
    'modVersion',
    _$modVersion,
    opt: true,
  );
  static String? _$imageUrl(PublicMod v) => v.imageUrl;
  static const Field<PublicMod, String> _f$imageUrl = Field(
    'imageUrl',
    _$imageUrl,
    opt: true,
  );
  static String? _$announcementImageUrl(PublicMod v) => v.announcementImageUrl;
  static const Field<PublicMod, String> _f$announcementImageUrl = Field(
    'announcementImageUrl',
    _$announcementImageUrl,
    opt: true,
  );
  static String? _$summary(PublicMod v) => v.summary;
  static const Field<PublicMod, String> _f$summary = Field(
    'summary',
    _$summary,
    opt: true,
  );
  static bool _$summaryIsGenerated(PublicMod v) => v.summaryIsGenerated;
  static const Field<PublicMod, bool> _f$summaryIsGenerated = Field(
    'summaryIsGenerated',
    _$summaryIsGenerated,
    opt: true,
    def: false,
  );
  static String? _$aiSummary(PublicMod v) => v.aiSummary;
  static const Field<PublicMod, String> _f$aiSummary = Field(
    'aiSummary',
    _$aiSummary,
    opt: true,
  );
  static bool? _$saveCompatible(PublicMod v) => v.saveCompatible;
  static const Field<PublicMod, bool> _f$saveCompatible = Field(
    'saveCompatible',
    _$saveCompatible,
    opt: true,
  );
  static bool _$hasDirectDownload(PublicMod v) => v.hasDirectDownload;
  static const Field<PublicMod, bool> _f$hasDirectDownload = Field(
    'hasDirectDownload',
    _$hasDirectDownload,
    opt: true,
    def: false,
  );
  static PublicBestDownload? _$bestDownload(PublicMod v) => v.bestDownload;
  static const Field<PublicMod, PublicBestDownload> _f$bestDownload = Field(
    'bestDownload',
    _$bestDownload,
    opt: true,
  );
  static int _$downloadCount(PublicMod v) => v.downloadCount;
  static const Field<PublicMod, int> _f$downloadCount = Field(
    'downloadCount',
    _$downloadCount,
    opt: true,
    def: 0,
  );
  static String? _$forumUrl(PublicMod v) => v.forumUrl;
  static const Field<PublicMod, String> _f$forumUrl = Field(
    'forumUrl',
    _$forumUrl,
    opt: true,
  );
  static String? _$discordUrl(PublicMod v) => v.discordUrl;
  static const Field<PublicMod, String> _f$discordUrl = Field(
    'discordUrl',
    _$discordUrl,
    opt: true,
  );
  static String? _$nexusUrl(PublicMod v) => v.nexusUrl;
  static const Field<PublicMod, String> _f$nexusUrl = Field(
    'nexusUrl',
    _$nexusUrl,
    opt: true,
  );
  static bool _$sourceIsPublic(PublicMod v) => v.sourceIsPublic;
  static const Field<PublicMod, bool> _f$sourceIsPublic = Field(
    'sourceIsPublic',
    _$sourceIsPublic,
    opt: true,
    def: false,
  );
  static bool _$isWorkInProgress(PublicMod v) => v.isWorkInProgress;
  static const Field<PublicMod, bool> _f$isWorkInProgress = Field(
    'isWorkInProgress',
    _$isWorkInProgress,
    opt: true,
    def: false,
  );
  static DateTime? _$lastReleaseDate(PublicMod v) => v.lastReleaseDate;
  static const Field<PublicMod, DateTime> _f$lastReleaseDate = Field(
    'lastReleaseDate',
    _$lastReleaseDate,
    opt: true,
  );
  static String? _$addedOn(PublicMod v) => v.addedOn;
  static const Field<PublicMod, String> _f$addedOn = Field(
    'addedOn',
    _$addedOn,
    opt: true,
  );
  static String? _$threadLastPostOn(PublicMod v) => v.threadLastPostOn;
  static const Field<PublicMod, String> _f$threadLastPostOn = Field(
    'threadLastPostOn',
    _$threadLastPostOn,
    opt: true,
  );
  static List<PublicNeededMod> _$needs(PublicMod v) => v.needs;
  static const Field<PublicMod, List<PublicNeededMod>> _f$needs = Field(
    'needs',
    _$needs,
    opt: true,
    def: const [],
  );
  static String? _$partOfThreadTitle(PublicMod v) => v.partOfThreadTitle;
  static const Field<PublicMod, String> _f$partOfThreadTitle = Field(
    'partOfThreadTitle',
    _$partOfThreadTitle,
    opt: true,
  );

  @override
  final MappableFields<PublicMod> fields = const {
    #id: _f$id,
    #name: _f$name,
    #displayName: _f$displayName,
    #authors: _f$authors,
    #otherAuthorNames: _f$otherAuthorNames,
    #categories: _f$categories,
    #sources: _f$sources,
    #gameVersion: _f$gameVersion,
    #modVersion: _f$modVersion,
    #imageUrl: _f$imageUrl,
    #announcementImageUrl: _f$announcementImageUrl,
    #summary: _f$summary,
    #summaryIsGenerated: _f$summaryIsGenerated,
    #aiSummary: _f$aiSummary,
    #saveCompatible: _f$saveCompatible,
    #hasDirectDownload: _f$hasDirectDownload,
    #bestDownload: _f$bestDownload,
    #downloadCount: _f$downloadCount,
    #forumUrl: _f$forumUrl,
    #discordUrl: _f$discordUrl,
    #nexusUrl: _f$nexusUrl,
    #sourceIsPublic: _f$sourceIsPublic,
    #isWorkInProgress: _f$isWorkInProgress,
    #lastReleaseDate: _f$lastReleaseDate,
    #addedOn: _f$addedOn,
    #threadLastPostOn: _f$threadLastPostOn,
    #needs: _f$needs,
    #partOfThreadTitle: _f$partOfThreadTitle,
  };
  @override
  final bool ignoreNull = true;

  static PublicMod _instantiate(DecodingData data) {
    return PublicMod(
      id: data.dec(_f$id),
      name: data.dec(_f$name),
      displayName: data.dec(_f$displayName),
      authors: data.dec(_f$authors),
      otherAuthorNames: data.dec(_f$otherAuthorNames),
      categories: data.dec(_f$categories),
      sources: data.dec(_f$sources),
      gameVersion: data.dec(_f$gameVersion),
      modVersion: data.dec(_f$modVersion),
      imageUrl: data.dec(_f$imageUrl),
      announcementImageUrl: data.dec(_f$announcementImageUrl),
      summary: data.dec(_f$summary),
      summaryIsGenerated: data.dec(_f$summaryIsGenerated),
      aiSummary: data.dec(_f$aiSummary),
      saveCompatible: data.dec(_f$saveCompatible),
      hasDirectDownload: data.dec(_f$hasDirectDownload),
      bestDownload: data.dec(_f$bestDownload),
      downloadCount: data.dec(_f$downloadCount),
      forumUrl: data.dec(_f$forumUrl),
      discordUrl: data.dec(_f$discordUrl),
      nexusUrl: data.dec(_f$nexusUrl),
      sourceIsPublic: data.dec(_f$sourceIsPublic),
      isWorkInProgress: data.dec(_f$isWorkInProgress),
      lastReleaseDate: data.dec(_f$lastReleaseDate),
      addedOn: data.dec(_f$addedOn),
      threadLastPostOn: data.dec(_f$threadLastPostOn),
      needs: data.dec(_f$needs),
      partOfThreadTitle: data.dec(_f$partOfThreadTitle),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PublicMod fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PublicMod>(map);
  }

  static PublicMod fromJson(String json) {
    return ensureInitialized().decodeJson<PublicMod>(json);
  }
}

mixin PublicModMappable {
  String toJson() {
    return PublicModMapper.ensureInitialized().encodeJson<PublicMod>(
      this as PublicMod,
    );
  }

  Map<String, dynamic> toMap() {
    return PublicModMapper.ensureInitialized().encodeMap<PublicMod>(
      this as PublicMod,
    );
  }

  PublicModCopyWith<PublicMod, PublicMod, PublicMod> get copyWith =>
      _PublicModCopyWithImpl<PublicMod, PublicMod>(
        this as PublicMod,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return PublicModMapper.ensureInitialized().stringifyValue(
      this as PublicMod,
    );
  }

  @override
  bool operator ==(Object other) {
    return PublicModMapper.ensureInitialized().equalsValue(
      this as PublicMod,
      other,
    );
  }

  @override
  int get hashCode {
    return PublicModMapper.ensureInitialized().hashValue(this as PublicMod);
  }
}

extension PublicModValueCopy<$R, $Out> on ObjectCopyWith<$R, PublicMod, $Out> {
  PublicModCopyWith<$R, PublicMod, $Out> get $asPublicMod =>
      $base.as((v, t, t2) => _PublicModCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PublicModCopyWith<$R, $In extends PublicMod, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get authors;
  MapCopyWith<
    $R,
    String,
    List<String>,
    ObjectCopyWith<$R, List<String>, List<String>>
  >
  get otherAuthorNames;
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get categories;
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get sources;
  PublicBestDownloadCopyWith<$R, PublicBestDownload, PublicBestDownload>?
  get bestDownload;
  ListCopyWith<
    $R,
    PublicNeededMod,
    PublicNeededModCopyWith<$R, PublicNeededMod, PublicNeededMod>
  >
  get needs;
  $R call({
    String? id,
    String? name,
    String? displayName,
    List<String>? authors,
    Map<String, List<String>>? otherAuthorNames,
    List<String>? categories,
    List<String>? sources,
    String? gameVersion,
    String? modVersion,
    String? imageUrl,
    String? announcementImageUrl,
    String? summary,
    bool? summaryIsGenerated,
    String? aiSummary,
    bool? saveCompatible,
    bool? hasDirectDownload,
    PublicBestDownload? bestDownload,
    int? downloadCount,
    String? forumUrl,
    String? discordUrl,
    String? nexusUrl,
    bool? sourceIsPublic,
    bool? isWorkInProgress,
    DateTime? lastReleaseDate,
    String? addedOn,
    String? threadLastPostOn,
    List<PublicNeededMod>? needs,
    String? partOfThreadTitle,
  });
  PublicModCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _PublicModCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PublicMod, $Out>
    implements PublicModCopyWith<$R, PublicMod, $Out> {
  _PublicModCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PublicMod> $mapper =
      PublicModMapper.ensureInitialized();
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get authors =>
      ListCopyWith(
        $value.authors,
        (v, t) => ObjectCopyWith(v, $identity, t),
        (v) => call(authors: v),
      );
  @override
  MapCopyWith<
    $R,
    String,
    List<String>,
    ObjectCopyWith<$R, List<String>, List<String>>
  >
  get otherAuthorNames => MapCopyWith(
    $value.otherAuthorNames,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(otherAuthorNames: v),
  );
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get categories =>
      ListCopyWith(
        $value.categories,
        (v, t) => ObjectCopyWith(v, $identity, t),
        (v) => call(categories: v),
      );
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get sources =>
      ListCopyWith(
        $value.sources,
        (v, t) => ObjectCopyWith(v, $identity, t),
        (v) => call(sources: v),
      );
  @override
  PublicBestDownloadCopyWith<$R, PublicBestDownload, PublicBestDownload>?
  get bestDownload =>
      $value.bestDownload?.copyWith.$chain((v) => call(bestDownload: v));
  @override
  ListCopyWith<
    $R,
    PublicNeededMod,
    PublicNeededModCopyWith<$R, PublicNeededMod, PublicNeededMod>
  >
  get needs => ListCopyWith(
    $value.needs,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(needs: v),
  );
  @override
  $R call({
    String? id,
    String? name,
    Object? displayName = $none,
    List<String>? authors,
    Map<String, List<String>>? otherAuthorNames,
    List<String>? categories,
    List<String>? sources,
    Object? gameVersion = $none,
    Object? modVersion = $none,
    Object? imageUrl = $none,
    Object? announcementImageUrl = $none,
    Object? summary = $none,
    bool? summaryIsGenerated,
    Object? aiSummary = $none,
    Object? saveCompatible = $none,
    bool? hasDirectDownload,
    Object? bestDownload = $none,
    int? downloadCount,
    Object? forumUrl = $none,
    Object? discordUrl = $none,
    Object? nexusUrl = $none,
    bool? sourceIsPublic,
    bool? isWorkInProgress,
    Object? lastReleaseDate = $none,
    Object? addedOn = $none,
    Object? threadLastPostOn = $none,
    List<PublicNeededMod>? needs,
    Object? partOfThreadTitle = $none,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (name != null) #name: name,
      if (displayName != $none) #displayName: displayName,
      if (authors != null) #authors: authors,
      if (otherAuthorNames != null) #otherAuthorNames: otherAuthorNames,
      if (categories != null) #categories: categories,
      if (sources != null) #sources: sources,
      if (gameVersion != $none) #gameVersion: gameVersion,
      if (modVersion != $none) #modVersion: modVersion,
      if (imageUrl != $none) #imageUrl: imageUrl,
      if (announcementImageUrl != $none)
        #announcementImageUrl: announcementImageUrl,
      if (summary != $none) #summary: summary,
      if (summaryIsGenerated != null) #summaryIsGenerated: summaryIsGenerated,
      if (aiSummary != $none) #aiSummary: aiSummary,
      if (saveCompatible != $none) #saveCompatible: saveCompatible,
      if (hasDirectDownload != null) #hasDirectDownload: hasDirectDownload,
      if (bestDownload != $none) #bestDownload: bestDownload,
      if (downloadCount != null) #downloadCount: downloadCount,
      if (forumUrl != $none) #forumUrl: forumUrl,
      if (discordUrl != $none) #discordUrl: discordUrl,
      if (nexusUrl != $none) #nexusUrl: nexusUrl,
      if (sourceIsPublic != null) #sourceIsPublic: sourceIsPublic,
      if (isWorkInProgress != null) #isWorkInProgress: isWorkInProgress,
      if (lastReleaseDate != $none) #lastReleaseDate: lastReleaseDate,
      if (addedOn != $none) #addedOn: addedOn,
      if (threadLastPostOn != $none) #threadLastPostOn: threadLastPostOn,
      if (needs != null) #needs: needs,
      if (partOfThreadTitle != $none) #partOfThreadTitle: partOfThreadTitle,
    }),
  );
  @override
  PublicMod $make(CopyWithData data) => PublicMod(
    id: data.get(#id, or: $value.id),
    name: data.get(#name, or: $value.name),
    displayName: data.get(#displayName, or: $value.displayName),
    authors: data.get(#authors, or: $value.authors),
    otherAuthorNames: data.get(#otherAuthorNames, or: $value.otherAuthorNames),
    categories: data.get(#categories, or: $value.categories),
    sources: data.get(#sources, or: $value.sources),
    gameVersion: data.get(#gameVersion, or: $value.gameVersion),
    modVersion: data.get(#modVersion, or: $value.modVersion),
    imageUrl: data.get(#imageUrl, or: $value.imageUrl),
    announcementImageUrl: data.get(
      #announcementImageUrl,
      or: $value.announcementImageUrl,
    ),
    summary: data.get(#summary, or: $value.summary),
    summaryIsGenerated: data.get(
      #summaryIsGenerated,
      or: $value.summaryIsGenerated,
    ),
    aiSummary: data.get(#aiSummary, or: $value.aiSummary),
    saveCompatible: data.get(#saveCompatible, or: $value.saveCompatible),
    hasDirectDownload: data.get(
      #hasDirectDownload,
      or: $value.hasDirectDownload,
    ),
    bestDownload: data.get(#bestDownload, or: $value.bestDownload),
    downloadCount: data.get(#downloadCount, or: $value.downloadCount),
    forumUrl: data.get(#forumUrl, or: $value.forumUrl),
    discordUrl: data.get(#discordUrl, or: $value.discordUrl),
    nexusUrl: data.get(#nexusUrl, or: $value.nexusUrl),
    sourceIsPublic: data.get(#sourceIsPublic, or: $value.sourceIsPublic),
    isWorkInProgress: data.get(#isWorkInProgress, or: $value.isWorkInProgress),
    lastReleaseDate: data.get(#lastReleaseDate, or: $value.lastReleaseDate),
    addedOn: data.get(#addedOn, or: $value.addedOn),
    threadLastPostOn: data.get(#threadLastPostOn, or: $value.threadLastPostOn),
    needs: data.get(#needs, or: $value.needs),
    partOfThreadTitle: data.get(
      #partOfThreadTitle,
      or: $value.partOfThreadTitle,
    ),
  );

  @override
  PublicModCopyWith<$R2, PublicMod, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PublicModCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class PublicBestDownloadMapper extends ClassMapperBase<PublicBestDownload> {
  PublicBestDownloadMapper._();

  static PublicBestDownloadMapper? _instance;
  static PublicBestDownloadMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PublicBestDownloadMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'PublicBestDownload';

  static String _$url(PublicBestDownload v) => v.url;
  static const Field<PublicBestDownload, String> _f$url = Field('url', _$url);
  static String _$kind(PublicBestDownload v) => v.kind;
  static const Field<PublicBestDownload, String> _f$kind = Field(
    'kind',
    _$kind,
    opt: true,
    def: 'direct',
  );
  static bool _$needsAnotherStep(PublicBestDownload v) => v.needsAnotherStep;
  static const Field<PublicBestDownload, bool> _f$needsAnotherStep = Field(
    'needsAnotherStep',
    _$needsAnotherStep,
    opt: true,
    def: false,
  );

  @override
  final MappableFields<PublicBestDownload> fields = const {
    #url: _f$url,
    #kind: _f$kind,
    #needsAnotherStep: _f$needsAnotherStep,
  };
  @override
  final bool ignoreNull = true;

  static PublicBestDownload _instantiate(DecodingData data) {
    return PublicBestDownload(
      url: data.dec(_f$url),
      kind: data.dec(_f$kind),
      needsAnotherStep: data.dec(_f$needsAnotherStep),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PublicBestDownload fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PublicBestDownload>(map);
  }

  static PublicBestDownload fromJson(String json) {
    return ensureInitialized().decodeJson<PublicBestDownload>(json);
  }
}

mixin PublicBestDownloadMappable {
  String toJson() {
    return PublicBestDownloadMapper.ensureInitialized()
        .encodeJson<PublicBestDownload>(this as PublicBestDownload);
  }

  Map<String, dynamic> toMap() {
    return PublicBestDownloadMapper.ensureInitialized()
        .encodeMap<PublicBestDownload>(this as PublicBestDownload);
  }

  PublicBestDownloadCopyWith<
    PublicBestDownload,
    PublicBestDownload,
    PublicBestDownload
  >
  get copyWith =>
      _PublicBestDownloadCopyWithImpl<PublicBestDownload, PublicBestDownload>(
        this as PublicBestDownload,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return PublicBestDownloadMapper.ensureInitialized().stringifyValue(
      this as PublicBestDownload,
    );
  }

  @override
  bool operator ==(Object other) {
    return PublicBestDownloadMapper.ensureInitialized().equalsValue(
      this as PublicBestDownload,
      other,
    );
  }

  @override
  int get hashCode {
    return PublicBestDownloadMapper.ensureInitialized().hashValue(
      this as PublicBestDownload,
    );
  }
}

extension PublicBestDownloadValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PublicBestDownload, $Out> {
  PublicBestDownloadCopyWith<$R, PublicBestDownload, $Out>
  get $asPublicBestDownload => $base.as(
    (v, t, t2) => _PublicBestDownloadCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class PublicBestDownloadCopyWith<
  $R,
  $In extends PublicBestDownload,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? url, String? kind, bool? needsAnotherStep});
  PublicBestDownloadCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _PublicBestDownloadCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PublicBestDownload, $Out>
    implements PublicBestDownloadCopyWith<$R, PublicBestDownload, $Out> {
  _PublicBestDownloadCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PublicBestDownload> $mapper =
      PublicBestDownloadMapper.ensureInitialized();
  @override
  $R call({String? url, String? kind, bool? needsAnotherStep}) => $apply(
    FieldCopyWithData({
      if (url != null) #url: url,
      if (kind != null) #kind: kind,
      if (needsAnotherStep != null) #needsAnotherStep: needsAnotherStep,
    }),
  );
  @override
  PublicBestDownload $make(CopyWithData data) => PublicBestDownload(
    url: data.get(#url, or: $value.url),
    kind: data.get(#kind, or: $value.kind),
    needsAnotherStep: data.get(#needsAnotherStep, or: $value.needsAnotherStep),
  );

  @override
  PublicBestDownloadCopyWith<$R2, PublicBestDownload, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PublicBestDownloadCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class PublicNeededModMapper extends ClassMapperBase<PublicNeededMod> {
  PublicNeededModMapper._();

  static PublicNeededModMapper? _instance;
  static PublicNeededModMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PublicNeededModMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'PublicNeededMod';

  static String _$name(PublicNeededMod v) => v.name;
  static const Field<PublicNeededMod, String> _f$name = Field('name', _$name);
  static String? _$id(PublicNeededMod v) => v.id;
  static const Field<PublicNeededMod, String> _f$id = Field(
    'id',
    _$id,
    opt: true,
  );

  @override
  final MappableFields<PublicNeededMod> fields = const {
    #name: _f$name,
    #id: _f$id,
  };
  @override
  final bool ignoreNull = true;

  static PublicNeededMod _instantiate(DecodingData data) {
    return PublicNeededMod(name: data.dec(_f$name), id: data.dec(_f$id));
  }

  @override
  final Function instantiate = _instantiate;

  static PublicNeededMod fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PublicNeededMod>(map);
  }

  static PublicNeededMod fromJson(String json) {
    return ensureInitialized().decodeJson<PublicNeededMod>(json);
  }
}

mixin PublicNeededModMappable {
  String toJson() {
    return PublicNeededModMapper.ensureInitialized()
        .encodeJson<PublicNeededMod>(this as PublicNeededMod);
  }

  Map<String, dynamic> toMap() {
    return PublicNeededModMapper.ensureInitialized().encodeMap<PublicNeededMod>(
      this as PublicNeededMod,
    );
  }

  PublicNeededModCopyWith<PublicNeededMod, PublicNeededMod, PublicNeededMod>
  get copyWith =>
      _PublicNeededModCopyWithImpl<PublicNeededMod, PublicNeededMod>(
        this as PublicNeededMod,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return PublicNeededModMapper.ensureInitialized().stringifyValue(
      this as PublicNeededMod,
    );
  }

  @override
  bool operator ==(Object other) {
    return PublicNeededModMapper.ensureInitialized().equalsValue(
      this as PublicNeededMod,
      other,
    );
  }

  @override
  int get hashCode {
    return PublicNeededModMapper.ensureInitialized().hashValue(
      this as PublicNeededMod,
    );
  }
}

extension PublicNeededModValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PublicNeededMod, $Out> {
  PublicNeededModCopyWith<$R, PublicNeededMod, $Out> get $asPublicNeededMod =>
      $base.as((v, t, t2) => _PublicNeededModCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PublicNeededModCopyWith<$R, $In extends PublicNeededMod, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? name, String? id});
  PublicNeededModCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _PublicNeededModCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PublicNeededMod, $Out>
    implements PublicNeededModCopyWith<$R, PublicNeededMod, $Out> {
  _PublicNeededModCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PublicNeededMod> $mapper =
      PublicNeededModMapper.ensureInitialized();
  @override
  $R call({String? name, Object? id = $none}) => $apply(
    FieldCopyWithData({
      if (name != null) #name: name,
      if (id != $none) #id: id,
    }),
  );
  @override
  PublicNeededMod $make(CopyWithData data) => PublicNeededMod(
    name: data.get(#name, or: $value.name),
    id: data.get(#id, or: $value.id),
  );

  @override
  PublicNeededModCopyWith<$R2, PublicNeededMod, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PublicNeededModCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

