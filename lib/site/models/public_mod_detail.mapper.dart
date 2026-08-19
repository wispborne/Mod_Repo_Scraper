// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'public_mod_detail.dart';

class PublicModDetailMapper extends ClassMapperBase<PublicModDetail> {
  PublicModDetailMapper._();

  static PublicModDetailMapper? _instance;
  static PublicModDetailMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PublicModDetailMapper._());
      PublicModMapper.ensureInitialized();
      PublicImageMapper.ensureInitialized();
      PublicDownloadMapper.ensureInitialized();
      PublicSupportLinkMapper.ensureInitialized();
      ModReleaseMapper.ensureInitialized();
      PublicOlderVersionMapper.ensureInitialized();
      PublicAddonMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'PublicModDetail';

  static DateTime _$generatedAt(PublicModDetail v) => v.generatedAt;
  static const Field<PublicModDetail, DateTime> _f$generatedAt = Field(
    'generatedAt',
    _$generatedAt,
  );
  static PublicMod _$listing(PublicModDetail v) => v.listing;
  static const Field<PublicModDetail, PublicMod> _f$listing = Field(
    'listing',
    _$listing,
  );
  static String? _$description(PublicModDetail v) => v.description;
  static const Field<PublicModDetail, String> _f$description = Field(
    'description',
    _$description,
    opt: true,
  );
  static String? _$descriptionHtml(PublicModDetail v) => v.descriptionHtml;
  static const Field<PublicModDetail, String> _f$descriptionHtml = Field(
    'descriptionHtml',
    _$descriptionHtml,
    opt: true,
  );
  static bool _$descriptionIsGenerated(PublicModDetail v) =>
      v.descriptionIsGenerated;
  static const Field<PublicModDetail, bool> _f$descriptionIsGenerated = Field(
    'descriptionIsGenerated',
    _$descriptionIsGenerated,
    opt: true,
    def: false,
  );
  static String? _$saveCompatibilityText(PublicModDetail v) =>
      v.saveCompatibilityText;
  static const Field<PublicModDetail, String> _f$saveCompatibilityText = Field(
    'saveCompatibilityText',
    _$saveCompatibilityText,
    opt: true,
  );
  static List<PublicImage> _$gallery(PublicModDetail v) => v.gallery;
  static const Field<PublicModDetail, List<PublicImage>> _f$gallery = Field(
    'gallery',
    _$gallery,
    opt: true,
    def: const [],
  );
  static List<PublicDownload> _$downloads(PublicModDetail v) => v.downloads;
  static const Field<PublicModDetail, List<PublicDownload>> _f$downloads =
      Field('downloads', _$downloads, opt: true, def: const []);
  static Map<String, String> _$changelog(PublicModDetail v) => v.changelog;
  static const Field<PublicModDetail, Map<String, String>> _f$changelog = Field(
    'changelog',
    _$changelog,
    opt: true,
    def: const {},
  );
  static String? _$changelogUrl(PublicModDetail v) => v.changelogUrl;
  static const Field<PublicModDetail, String> _f$changelogUrl = Field(
    'changelogUrl',
    _$changelogUrl,
    opt: true,
  );
  static String? _$license(PublicModDetail v) => v.license;
  static const Field<PublicModDetail, String> _f$license = Field(
    'license',
    _$license,
    opt: true,
  );
  static String? _$sourceCodeUrl(PublicModDetail v) => v.sourceCodeUrl;
  static const Field<PublicModDetail, String> _f$sourceCodeUrl = Field(
    'sourceCodeUrl',
    _$sourceCodeUrl,
    opt: true,
  );
  static List<PublicSupportLink> _$supportLinks(PublicModDetail v) =>
      v.supportLinks;
  static const Field<PublicModDetail, List<PublicSupportLink>> _f$supportLinks =
      Field('supportLinks', _$supportLinks, opt: true, def: const []);
  static String? _$forumUrl(PublicModDetail v) => v.forumUrl;
  static const Field<PublicModDetail, String> _f$forumUrl = Field(
    'forumUrl',
    _$forumUrl,
    opt: true,
  );
  static String? _$discordUrl(PublicModDetail v) => v.discordUrl;
  static const Field<PublicModDetail, String> _f$discordUrl = Field(
    'discordUrl',
    _$discordUrl,
    opt: true,
  );
  static String? _$nexusUrl(PublicModDetail v) => v.nexusUrl;
  static const Field<PublicModDetail, String> _f$nexusUrl = Field(
    'nexusUrl',
    _$nexusUrl,
    opt: true,
  );
  static List<ModRelease> _$releases(PublicModDetail v) => v.releases;
  static const Field<PublicModDetail, List<ModRelease>> _f$releases = Field(
    'releases',
    _$releases,
    opt: true,
    def: const [],
  );
  static List<PublicOlderVersion> _$olderVersions(PublicModDetail v) =>
      v.olderVersions;
  static const Field<PublicModDetail, List<PublicOlderVersion>>
  _f$olderVersions = Field(
    'olderVersions',
    _$olderVersions,
    opt: true,
    def: const [],
  );
  static List<PublicAddon> _$addons(PublicModDetail v) => v.addons;
  static const Field<PublicModDetail, List<PublicAddon>> _f$addons = Field(
    'addons',
    _$addons,
    opt: true,
    def: const [],
  );

  @override
  final MappableFields<PublicModDetail> fields = const {
    #generatedAt: _f$generatedAt,
    #listing: _f$listing,
    #description: _f$description,
    #descriptionHtml: _f$descriptionHtml,
    #descriptionIsGenerated: _f$descriptionIsGenerated,
    #saveCompatibilityText: _f$saveCompatibilityText,
    #gallery: _f$gallery,
    #downloads: _f$downloads,
    #changelog: _f$changelog,
    #changelogUrl: _f$changelogUrl,
    #license: _f$license,
    #sourceCodeUrl: _f$sourceCodeUrl,
    #supportLinks: _f$supportLinks,
    #forumUrl: _f$forumUrl,
    #discordUrl: _f$discordUrl,
    #nexusUrl: _f$nexusUrl,
    #releases: _f$releases,
    #olderVersions: _f$olderVersions,
    #addons: _f$addons,
  };
  @override
  final bool ignoreNull = true;

  static PublicModDetail _instantiate(DecodingData data) {
    return PublicModDetail(
      generatedAt: data.dec(_f$generatedAt),
      listing: data.dec(_f$listing),
      description: data.dec(_f$description),
      descriptionHtml: data.dec(_f$descriptionHtml),
      descriptionIsGenerated: data.dec(_f$descriptionIsGenerated),
      saveCompatibilityText: data.dec(_f$saveCompatibilityText),
      gallery: data.dec(_f$gallery),
      downloads: data.dec(_f$downloads),
      changelog: data.dec(_f$changelog),
      changelogUrl: data.dec(_f$changelogUrl),
      license: data.dec(_f$license),
      sourceCodeUrl: data.dec(_f$sourceCodeUrl),
      supportLinks: data.dec(_f$supportLinks),
      forumUrl: data.dec(_f$forumUrl),
      discordUrl: data.dec(_f$discordUrl),
      nexusUrl: data.dec(_f$nexusUrl),
      releases: data.dec(_f$releases),
      olderVersions: data.dec(_f$olderVersions),
      addons: data.dec(_f$addons),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PublicModDetail fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PublicModDetail>(map);
  }

  static PublicModDetail fromJson(String json) {
    return ensureInitialized().decodeJson<PublicModDetail>(json);
  }
}

mixin PublicModDetailMappable {
  String toJson() {
    return PublicModDetailMapper.ensureInitialized()
        .encodeJson<PublicModDetail>(this as PublicModDetail);
  }

  Map<String, dynamic> toMap() {
    return PublicModDetailMapper.ensureInitialized().encodeMap<PublicModDetail>(
      this as PublicModDetail,
    );
  }

  PublicModDetailCopyWith<PublicModDetail, PublicModDetail, PublicModDetail>
  get copyWith =>
      _PublicModDetailCopyWithImpl<PublicModDetail, PublicModDetail>(
        this as PublicModDetail,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return PublicModDetailMapper.ensureInitialized().stringifyValue(
      this as PublicModDetail,
    );
  }

  @override
  bool operator ==(Object other) {
    return PublicModDetailMapper.ensureInitialized().equalsValue(
      this as PublicModDetail,
      other,
    );
  }

  @override
  int get hashCode {
    return PublicModDetailMapper.ensureInitialized().hashValue(
      this as PublicModDetail,
    );
  }
}

extension PublicModDetailValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PublicModDetail, $Out> {
  PublicModDetailCopyWith<$R, PublicModDetail, $Out> get $asPublicModDetail =>
      $base.as((v, t, t2) => _PublicModDetailCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PublicModDetailCopyWith<$R, $In extends PublicModDetail, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  PublicModCopyWith<$R, PublicMod, PublicMod> get listing;
  ListCopyWith<
    $R,
    PublicImage,
    PublicImageCopyWith<$R, PublicImage, PublicImage>
  >
  get gallery;
  ListCopyWith<
    $R,
    PublicDownload,
    PublicDownloadCopyWith<$R, PublicDownload, PublicDownload>
  >
  get downloads;
  MapCopyWith<$R, String, String, ObjectCopyWith<$R, String, String>>
  get changelog;
  ListCopyWith<
    $R,
    PublicSupportLink,
    PublicSupportLinkCopyWith<$R, PublicSupportLink, PublicSupportLink>
  >
  get supportLinks;
  ListCopyWith<$R, ModRelease, ModReleaseCopyWith<$R, ModRelease, ModRelease>>
  get releases;
  ListCopyWith<
    $R,
    PublicOlderVersion,
    PublicOlderVersionCopyWith<$R, PublicOlderVersion, PublicOlderVersion>
  >
  get olderVersions;
  ListCopyWith<
    $R,
    PublicAddon,
    PublicAddonCopyWith<$R, PublicAddon, PublicAddon>
  >
  get addons;
  $R call({
    DateTime? generatedAt,
    PublicMod? listing,
    String? description,
    String? descriptionHtml,
    bool? descriptionIsGenerated,
    String? saveCompatibilityText,
    List<PublicImage>? gallery,
    List<PublicDownload>? downloads,
    Map<String, String>? changelog,
    String? changelogUrl,
    String? license,
    String? sourceCodeUrl,
    List<PublicSupportLink>? supportLinks,
    String? forumUrl,
    String? discordUrl,
    String? nexusUrl,
    List<ModRelease>? releases,
    List<PublicOlderVersion>? olderVersions,
    List<PublicAddon>? addons,
  });
  PublicModDetailCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _PublicModDetailCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PublicModDetail, $Out>
    implements PublicModDetailCopyWith<$R, PublicModDetail, $Out> {
  _PublicModDetailCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PublicModDetail> $mapper =
      PublicModDetailMapper.ensureInitialized();
  @override
  PublicModCopyWith<$R, PublicMod, PublicMod> get listing =>
      $value.listing.copyWith.$chain((v) => call(listing: v));
  @override
  ListCopyWith<
    $R,
    PublicImage,
    PublicImageCopyWith<$R, PublicImage, PublicImage>
  >
  get gallery => ListCopyWith(
    $value.gallery,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(gallery: v),
  );
  @override
  ListCopyWith<
    $R,
    PublicDownload,
    PublicDownloadCopyWith<$R, PublicDownload, PublicDownload>
  >
  get downloads => ListCopyWith(
    $value.downloads,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(downloads: v),
  );
  @override
  MapCopyWith<$R, String, String, ObjectCopyWith<$R, String, String>>
  get changelog => MapCopyWith(
    $value.changelog,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(changelog: v),
  );
  @override
  ListCopyWith<
    $R,
    PublicSupportLink,
    PublicSupportLinkCopyWith<$R, PublicSupportLink, PublicSupportLink>
  >
  get supportLinks => ListCopyWith(
    $value.supportLinks,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(supportLinks: v),
  );
  @override
  ListCopyWith<$R, ModRelease, ModReleaseCopyWith<$R, ModRelease, ModRelease>>
  get releases => ListCopyWith(
    $value.releases,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(releases: v),
  );
  @override
  ListCopyWith<
    $R,
    PublicOlderVersion,
    PublicOlderVersionCopyWith<$R, PublicOlderVersion, PublicOlderVersion>
  >
  get olderVersions => ListCopyWith(
    $value.olderVersions,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(olderVersions: v),
  );
  @override
  ListCopyWith<
    $R,
    PublicAddon,
    PublicAddonCopyWith<$R, PublicAddon, PublicAddon>
  >
  get addons => ListCopyWith(
    $value.addons,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(addons: v),
  );
  @override
  $R call({
    DateTime? generatedAt,
    PublicMod? listing,
    Object? description = $none,
    Object? descriptionHtml = $none,
    bool? descriptionIsGenerated,
    Object? saveCompatibilityText = $none,
    List<PublicImage>? gallery,
    List<PublicDownload>? downloads,
    Map<String, String>? changelog,
    Object? changelogUrl = $none,
    Object? license = $none,
    Object? sourceCodeUrl = $none,
    List<PublicSupportLink>? supportLinks,
    Object? forumUrl = $none,
    Object? discordUrl = $none,
    Object? nexusUrl = $none,
    List<ModRelease>? releases,
    List<PublicOlderVersion>? olderVersions,
    List<PublicAddon>? addons,
  }) => $apply(
    FieldCopyWithData({
      if (generatedAt != null) #generatedAt: generatedAt,
      if (listing != null) #listing: listing,
      if (description != $none) #description: description,
      if (descriptionHtml != $none) #descriptionHtml: descriptionHtml,
      if (descriptionIsGenerated != null)
        #descriptionIsGenerated: descriptionIsGenerated,
      if (saveCompatibilityText != $none)
        #saveCompatibilityText: saveCompatibilityText,
      if (gallery != null) #gallery: gallery,
      if (downloads != null) #downloads: downloads,
      if (changelog != null) #changelog: changelog,
      if (changelogUrl != $none) #changelogUrl: changelogUrl,
      if (license != $none) #license: license,
      if (sourceCodeUrl != $none) #sourceCodeUrl: sourceCodeUrl,
      if (supportLinks != null) #supportLinks: supportLinks,
      if (forumUrl != $none) #forumUrl: forumUrl,
      if (discordUrl != $none) #discordUrl: discordUrl,
      if (nexusUrl != $none) #nexusUrl: nexusUrl,
      if (releases != null) #releases: releases,
      if (olderVersions != null) #olderVersions: olderVersions,
      if (addons != null) #addons: addons,
    }),
  );
  @override
  PublicModDetail $make(CopyWithData data) => PublicModDetail(
    generatedAt: data.get(#generatedAt, or: $value.generatedAt),
    listing: data.get(#listing, or: $value.listing),
    description: data.get(#description, or: $value.description),
    descriptionHtml: data.get(#descriptionHtml, or: $value.descriptionHtml),
    descriptionIsGenerated: data.get(
      #descriptionIsGenerated,
      or: $value.descriptionIsGenerated,
    ),
    saveCompatibilityText: data.get(
      #saveCompatibilityText,
      or: $value.saveCompatibilityText,
    ),
    gallery: data.get(#gallery, or: $value.gallery),
    downloads: data.get(#downloads, or: $value.downloads),
    changelog: data.get(#changelog, or: $value.changelog),
    changelogUrl: data.get(#changelogUrl, or: $value.changelogUrl),
    license: data.get(#license, or: $value.license),
    sourceCodeUrl: data.get(#sourceCodeUrl, or: $value.sourceCodeUrl),
    supportLinks: data.get(#supportLinks, or: $value.supportLinks),
    forumUrl: data.get(#forumUrl, or: $value.forumUrl),
    discordUrl: data.get(#discordUrl, or: $value.discordUrl),
    nexusUrl: data.get(#nexusUrl, or: $value.nexusUrl),
    releases: data.get(#releases, or: $value.releases),
    olderVersions: data.get(#olderVersions, or: $value.olderVersions),
    addons: data.get(#addons, or: $value.addons),
  );

  @override
  PublicModDetailCopyWith<$R2, PublicModDetail, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PublicModDetailCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class PublicImageMapper extends ClassMapperBase<PublicImage> {
  PublicImageMapper._();

  static PublicImageMapper? _instance;
  static PublicImageMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PublicImageMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'PublicImage';

  static String _$url(PublicImage v) => v.url;
  static const Field<PublicImage, String> _f$url = Field('url', _$url);
  static String? _$caption(PublicImage v) => v.caption;
  static const Field<PublicImage, String> _f$caption = Field(
    'caption',
    _$caption,
    opt: true,
  );

  @override
  final MappableFields<PublicImage> fields = const {
    #url: _f$url,
    #caption: _f$caption,
  };
  @override
  final bool ignoreNull = true;

  static PublicImage _instantiate(DecodingData data) {
    return PublicImage(url: data.dec(_f$url), caption: data.dec(_f$caption));
  }

  @override
  final Function instantiate = _instantiate;

  static PublicImage fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PublicImage>(map);
  }

  static PublicImage fromJson(String json) {
    return ensureInitialized().decodeJson<PublicImage>(json);
  }
}

mixin PublicImageMappable {
  String toJson() {
    return PublicImageMapper.ensureInitialized().encodeJson<PublicImage>(
      this as PublicImage,
    );
  }

  Map<String, dynamic> toMap() {
    return PublicImageMapper.ensureInitialized().encodeMap<PublicImage>(
      this as PublicImage,
    );
  }

  PublicImageCopyWith<PublicImage, PublicImage, PublicImage> get copyWith =>
      _PublicImageCopyWithImpl<PublicImage, PublicImage>(
        this as PublicImage,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return PublicImageMapper.ensureInitialized().stringifyValue(
      this as PublicImage,
    );
  }

  @override
  bool operator ==(Object other) {
    return PublicImageMapper.ensureInitialized().equalsValue(
      this as PublicImage,
      other,
    );
  }

  @override
  int get hashCode {
    return PublicImageMapper.ensureInitialized().hashValue(this as PublicImage);
  }
}

extension PublicImageValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PublicImage, $Out> {
  PublicImageCopyWith<$R, PublicImage, $Out> get $asPublicImage =>
      $base.as((v, t, t2) => _PublicImageCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PublicImageCopyWith<$R, $In extends PublicImage, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? url, String? caption});
  PublicImageCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _PublicImageCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PublicImage, $Out>
    implements PublicImageCopyWith<$R, PublicImage, $Out> {
  _PublicImageCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PublicImage> $mapper =
      PublicImageMapper.ensureInitialized();
  @override
  $R call({String? url, Object? caption = $none}) => $apply(
    FieldCopyWithData({
      if (url != null) #url: url,
      if (caption != $none) #caption: caption,
    }),
  );
  @override
  PublicImage $make(CopyWithData data) => PublicImage(
    url: data.get(#url, or: $value.url),
    caption: data.get(#caption, or: $value.caption),
  );

  @override
  PublicImageCopyWith<$R2, PublicImage, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PublicImageCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class PublicDownloadMapper extends ClassMapperBase<PublicDownload> {
  PublicDownloadMapper._();

  static PublicDownloadMapper? _instance;
  static PublicDownloadMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PublicDownloadMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'PublicDownload';

  static String _$url(PublicDownload v) => v.url;
  static const Field<PublicDownload, String> _f$url = Field('url', _$url);
  static String? _$directUrl(PublicDownload v) => v.directUrl;
  static const Field<PublicDownload, String> _f$directUrl = Field(
    'directUrl',
    _$directUrl,
    opt: true,
  );
  static String? _$fileName(PublicDownload v) => v.fileName;
  static const Field<PublicDownload, String> _f$fileName = Field(
    'fileName',
    _$fileName,
    opt: true,
  );
  static String _$kind(PublicDownload v) => v.kind;
  static const Field<PublicDownload, String> _f$kind = Field(
    'kind',
    _$kind,
    opt: true,
    def: 'direct',
  );
  static String _$label(PublicDownload v) => v.label;
  static const Field<PublicDownload, String> _f$label = Field(
    'label',
    _$label,
    opt: true,
    def: '',
  );
  static String? _$host(PublicDownload v) => v.host;
  static const Field<PublicDownload, String> _f$host = Field(
    'host',
    _$host,
    opt: true,
  );
  static bool _$needsAnotherStep(PublicDownload v) => v.needsAnotherStep;
  static const Field<PublicDownload, bool> _f$needsAnotherStep = Field(
    'needsAnotherStep',
    _$needsAnotherStep,
    opt: true,
    def: false,
  );

  @override
  final MappableFields<PublicDownload> fields = const {
    #url: _f$url,
    #directUrl: _f$directUrl,
    #fileName: _f$fileName,
    #kind: _f$kind,
    #label: _f$label,
    #host: _f$host,
    #needsAnotherStep: _f$needsAnotherStep,
  };
  @override
  final bool ignoreNull = true;

  static PublicDownload _instantiate(DecodingData data) {
    return PublicDownload(
      url: data.dec(_f$url),
      directUrl: data.dec(_f$directUrl),
      fileName: data.dec(_f$fileName),
      kind: data.dec(_f$kind),
      label: data.dec(_f$label),
      host: data.dec(_f$host),
      needsAnotherStep: data.dec(_f$needsAnotherStep),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PublicDownload fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PublicDownload>(map);
  }

  static PublicDownload fromJson(String json) {
    return ensureInitialized().decodeJson<PublicDownload>(json);
  }
}

mixin PublicDownloadMappable {
  String toJson() {
    return PublicDownloadMapper.ensureInitialized().encodeJson<PublicDownload>(
      this as PublicDownload,
    );
  }

  Map<String, dynamic> toMap() {
    return PublicDownloadMapper.ensureInitialized().encodeMap<PublicDownload>(
      this as PublicDownload,
    );
  }

  PublicDownloadCopyWith<PublicDownload, PublicDownload, PublicDownload>
  get copyWith => _PublicDownloadCopyWithImpl<PublicDownload, PublicDownload>(
    this as PublicDownload,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return PublicDownloadMapper.ensureInitialized().stringifyValue(
      this as PublicDownload,
    );
  }

  @override
  bool operator ==(Object other) {
    return PublicDownloadMapper.ensureInitialized().equalsValue(
      this as PublicDownload,
      other,
    );
  }

  @override
  int get hashCode {
    return PublicDownloadMapper.ensureInitialized().hashValue(
      this as PublicDownload,
    );
  }
}

extension PublicDownloadValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PublicDownload, $Out> {
  PublicDownloadCopyWith<$R, PublicDownload, $Out> get $asPublicDownload =>
      $base.as((v, t, t2) => _PublicDownloadCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PublicDownloadCopyWith<$R, $In extends PublicDownload, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? url,
    String? directUrl,
    String? fileName,
    String? kind,
    String? label,
    String? host,
    bool? needsAnotherStep,
  });
  PublicDownloadCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _PublicDownloadCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PublicDownload, $Out>
    implements PublicDownloadCopyWith<$R, PublicDownload, $Out> {
  _PublicDownloadCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PublicDownload> $mapper =
      PublicDownloadMapper.ensureInitialized();
  @override
  $R call({
    String? url,
    Object? directUrl = $none,
    Object? fileName = $none,
    String? kind,
    String? label,
    Object? host = $none,
    bool? needsAnotherStep,
  }) => $apply(
    FieldCopyWithData({
      if (url != null) #url: url,
      if (directUrl != $none) #directUrl: directUrl,
      if (fileName != $none) #fileName: fileName,
      if (kind != null) #kind: kind,
      if (label != null) #label: label,
      if (host != $none) #host: host,
      if (needsAnotherStep != null) #needsAnotherStep: needsAnotherStep,
    }),
  );
  @override
  PublicDownload $make(CopyWithData data) => PublicDownload(
    url: data.get(#url, or: $value.url),
    directUrl: data.get(#directUrl, or: $value.directUrl),
    fileName: data.get(#fileName, or: $value.fileName),
    kind: data.get(#kind, or: $value.kind),
    label: data.get(#label, or: $value.label),
    host: data.get(#host, or: $value.host),
    needsAnotherStep: data.get(#needsAnotherStep, or: $value.needsAnotherStep),
  );

  @override
  PublicDownloadCopyWith<$R2, PublicDownload, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PublicDownloadCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class PublicSupportLinkMapper extends ClassMapperBase<PublicSupportLink> {
  PublicSupportLinkMapper._();

  static PublicSupportLinkMapper? _instance;
  static PublicSupportLinkMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PublicSupportLinkMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'PublicSupportLink';

  static String _$url(PublicSupportLink v) => v.url;
  static const Field<PublicSupportLink, String> _f$url = Field('url', _$url);
  static String _$type(PublicSupportLink v) => v.type;
  static const Field<PublicSupportLink, String> _f$type = Field('type', _$type);

  @override
  final MappableFields<PublicSupportLink> fields = const {
    #url: _f$url,
    #type: _f$type,
  };
  @override
  final bool ignoreNull = true;

  static PublicSupportLink _instantiate(DecodingData data) {
    return PublicSupportLink(url: data.dec(_f$url), type: data.dec(_f$type));
  }

  @override
  final Function instantiate = _instantiate;

  static PublicSupportLink fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PublicSupportLink>(map);
  }

  static PublicSupportLink fromJson(String json) {
    return ensureInitialized().decodeJson<PublicSupportLink>(json);
  }
}

mixin PublicSupportLinkMappable {
  String toJson() {
    return PublicSupportLinkMapper.ensureInitialized()
        .encodeJson<PublicSupportLink>(this as PublicSupportLink);
  }

  Map<String, dynamic> toMap() {
    return PublicSupportLinkMapper.ensureInitialized()
        .encodeMap<PublicSupportLink>(this as PublicSupportLink);
  }

  PublicSupportLinkCopyWith<
    PublicSupportLink,
    PublicSupportLink,
    PublicSupportLink
  >
  get copyWith =>
      _PublicSupportLinkCopyWithImpl<PublicSupportLink, PublicSupportLink>(
        this as PublicSupportLink,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return PublicSupportLinkMapper.ensureInitialized().stringifyValue(
      this as PublicSupportLink,
    );
  }

  @override
  bool operator ==(Object other) {
    return PublicSupportLinkMapper.ensureInitialized().equalsValue(
      this as PublicSupportLink,
      other,
    );
  }

  @override
  int get hashCode {
    return PublicSupportLinkMapper.ensureInitialized().hashValue(
      this as PublicSupportLink,
    );
  }
}

extension PublicSupportLinkValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PublicSupportLink, $Out> {
  PublicSupportLinkCopyWith<$R, PublicSupportLink, $Out>
  get $asPublicSupportLink => $base.as(
    (v, t, t2) => _PublicSupportLinkCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class PublicSupportLinkCopyWith<
  $R,
  $In extends PublicSupportLink,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? url, String? type});
  PublicSupportLinkCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _PublicSupportLinkCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PublicSupportLink, $Out>
    implements PublicSupportLinkCopyWith<$R, PublicSupportLink, $Out> {
  _PublicSupportLinkCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PublicSupportLink> $mapper =
      PublicSupportLinkMapper.ensureInitialized();
  @override
  $R call({String? url, String? type}) => $apply(
    FieldCopyWithData({
      if (url != null) #url: url,
      if (type != null) #type: type,
    }),
  );
  @override
  PublicSupportLink $make(CopyWithData data) => PublicSupportLink(
    url: data.get(#url, or: $value.url),
    type: data.get(#type, or: $value.type),
  );

  @override
  PublicSupportLinkCopyWith<$R2, PublicSupportLink, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PublicSupportLinkCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class PublicOlderVersionMapper extends ClassMapperBase<PublicOlderVersion> {
  PublicOlderVersionMapper._();

  static PublicOlderVersionMapper? _instance;
  static PublicOlderVersionMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PublicOlderVersionMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'PublicOlderVersion';

  static String _$title(PublicOlderVersion v) => v.title;
  static const Field<PublicOlderVersion, String> _f$title = Field(
    'title',
    _$title,
  );
  static String _$url(PublicOlderVersion v) => v.url;
  static const Field<PublicOlderVersion, String> _f$url = Field('url', _$url);
  static String? _$gameVersion(PublicOlderVersion v) => v.gameVersion;
  static const Field<PublicOlderVersion, String> _f$gameVersion = Field(
    'gameVersion',
    _$gameVersion,
    opt: true,
  );
  static String? _$modVersion(PublicOlderVersion v) => v.modVersion;
  static const Field<PublicOlderVersion, String> _f$modVersion = Field(
    'modVersion',
    _$modVersion,
    opt: true,
  );

  @override
  final MappableFields<PublicOlderVersion> fields = const {
    #title: _f$title,
    #url: _f$url,
    #gameVersion: _f$gameVersion,
    #modVersion: _f$modVersion,
  };
  @override
  final bool ignoreNull = true;

  static PublicOlderVersion _instantiate(DecodingData data) {
    return PublicOlderVersion(
      title: data.dec(_f$title),
      url: data.dec(_f$url),
      gameVersion: data.dec(_f$gameVersion),
      modVersion: data.dec(_f$modVersion),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PublicOlderVersion fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PublicOlderVersion>(map);
  }

  static PublicOlderVersion fromJson(String json) {
    return ensureInitialized().decodeJson<PublicOlderVersion>(json);
  }
}

mixin PublicOlderVersionMappable {
  String toJson() {
    return PublicOlderVersionMapper.ensureInitialized()
        .encodeJson<PublicOlderVersion>(this as PublicOlderVersion);
  }

  Map<String, dynamic> toMap() {
    return PublicOlderVersionMapper.ensureInitialized()
        .encodeMap<PublicOlderVersion>(this as PublicOlderVersion);
  }

  PublicOlderVersionCopyWith<
    PublicOlderVersion,
    PublicOlderVersion,
    PublicOlderVersion
  >
  get copyWith =>
      _PublicOlderVersionCopyWithImpl<PublicOlderVersion, PublicOlderVersion>(
        this as PublicOlderVersion,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return PublicOlderVersionMapper.ensureInitialized().stringifyValue(
      this as PublicOlderVersion,
    );
  }

  @override
  bool operator ==(Object other) {
    return PublicOlderVersionMapper.ensureInitialized().equalsValue(
      this as PublicOlderVersion,
      other,
    );
  }

  @override
  int get hashCode {
    return PublicOlderVersionMapper.ensureInitialized().hashValue(
      this as PublicOlderVersion,
    );
  }
}

extension PublicOlderVersionValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PublicOlderVersion, $Out> {
  PublicOlderVersionCopyWith<$R, PublicOlderVersion, $Out>
  get $asPublicOlderVersion => $base.as(
    (v, t, t2) => _PublicOlderVersionCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class PublicOlderVersionCopyWith<
  $R,
  $In extends PublicOlderVersion,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? title,
    String? url,
    String? gameVersion,
    String? modVersion,
  });
  PublicOlderVersionCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _PublicOlderVersionCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PublicOlderVersion, $Out>
    implements PublicOlderVersionCopyWith<$R, PublicOlderVersion, $Out> {
  _PublicOlderVersionCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PublicOlderVersion> $mapper =
      PublicOlderVersionMapper.ensureInitialized();
  @override
  $R call({
    String? title,
    String? url,
    Object? gameVersion = $none,
    Object? modVersion = $none,
  }) => $apply(
    FieldCopyWithData({
      if (title != null) #title: title,
      if (url != null) #url: url,
      if (gameVersion != $none) #gameVersion: gameVersion,
      if (modVersion != $none) #modVersion: modVersion,
    }),
  );
  @override
  PublicOlderVersion $make(CopyWithData data) => PublicOlderVersion(
    title: data.get(#title, or: $value.title),
    url: data.get(#url, or: $value.url),
    gameVersion: data.get(#gameVersion, or: $value.gameVersion),
    modVersion: data.get(#modVersion, or: $value.modVersion),
  );

  @override
  PublicOlderVersionCopyWith<$R2, PublicOlderVersion, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PublicOlderVersionCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class PublicAddonMapper extends ClassMapperBase<PublicAddon> {
  PublicAddonMapper._();

  static PublicAddonMapper? _instance;
  static PublicAddonMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PublicAddonMapper._());
      PublicDownloadMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'PublicAddon';

  static String _$name(PublicAddon v) => v.name;
  static const Field<PublicAddon, String> _f$name = Field('name', _$name);
  static String? _$requires(PublicAddon v) => v.requires;
  static const Field<PublicAddon, String> _f$requires = Field(
    'requires',
    _$requires,
    opt: true,
  );
  static List<PublicDownload> _$downloads(PublicAddon v) => v.downloads;
  static const Field<PublicAddon, List<PublicDownload>> _f$downloads = Field(
    'downloads',
    _$downloads,
    opt: true,
    def: const [],
  );

  @override
  final MappableFields<PublicAddon> fields = const {
    #name: _f$name,
    #requires: _f$requires,
    #downloads: _f$downloads,
  };
  @override
  final bool ignoreNull = true;

  static PublicAddon _instantiate(DecodingData data) {
    return PublicAddon(
      name: data.dec(_f$name),
      requires: data.dec(_f$requires),
      downloads: data.dec(_f$downloads),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PublicAddon fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PublicAddon>(map);
  }

  static PublicAddon fromJson(String json) {
    return ensureInitialized().decodeJson<PublicAddon>(json);
  }
}

mixin PublicAddonMappable {
  String toJson() {
    return PublicAddonMapper.ensureInitialized().encodeJson<PublicAddon>(
      this as PublicAddon,
    );
  }

  Map<String, dynamic> toMap() {
    return PublicAddonMapper.ensureInitialized().encodeMap<PublicAddon>(
      this as PublicAddon,
    );
  }

  PublicAddonCopyWith<PublicAddon, PublicAddon, PublicAddon> get copyWith =>
      _PublicAddonCopyWithImpl<PublicAddon, PublicAddon>(
        this as PublicAddon,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return PublicAddonMapper.ensureInitialized().stringifyValue(
      this as PublicAddon,
    );
  }

  @override
  bool operator ==(Object other) {
    return PublicAddonMapper.ensureInitialized().equalsValue(
      this as PublicAddon,
      other,
    );
  }

  @override
  int get hashCode {
    return PublicAddonMapper.ensureInitialized().hashValue(this as PublicAddon);
  }
}

extension PublicAddonValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PublicAddon, $Out> {
  PublicAddonCopyWith<$R, PublicAddon, $Out> get $asPublicAddon =>
      $base.as((v, t, t2) => _PublicAddonCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PublicAddonCopyWith<$R, $In extends PublicAddon, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<
    $R,
    PublicDownload,
    PublicDownloadCopyWith<$R, PublicDownload, PublicDownload>
  >
  get downloads;
  $R call({String? name, String? requires, List<PublicDownload>? downloads});
  PublicAddonCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _PublicAddonCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PublicAddon, $Out>
    implements PublicAddonCopyWith<$R, PublicAddon, $Out> {
  _PublicAddonCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PublicAddon> $mapper =
      PublicAddonMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    PublicDownload,
    PublicDownloadCopyWith<$R, PublicDownload, PublicDownload>
  >
  get downloads => ListCopyWith(
    $value.downloads,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(downloads: v),
  );
  @override
  $R call({
    String? name,
    Object? requires = $none,
    List<PublicDownload>? downloads,
  }) => $apply(
    FieldCopyWithData({
      if (name != null) #name: name,
      if (requires != $none) #requires: requires,
      if (downloads != null) #downloads: downloads,
    }),
  );
  @override
  PublicAddon $make(CopyWithData data) => PublicAddon(
    name: data.get(#name, or: $value.name),
    requires: data.get(#requires, or: $value.requires),
    downloads: data.get(#downloads, or: $value.downloads),
  );

  @override
  PublicAddonCopyWith<$R2, PublicAddon, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PublicAddonCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

