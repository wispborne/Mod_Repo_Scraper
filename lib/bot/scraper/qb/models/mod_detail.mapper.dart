// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'mod_detail.dart';

class QbModDetailMapper extends ClassMapperBase<QbModDetail> {
  QbModDetailMapper._();

  static QbModDetailMapper? _instance;
  static QbModDetailMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = QbModDetailMapper._());
      ImageRefMapper.ensureInitialized();
      LinkRefMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'QbModDetail';

  static int _$topicId(QbModDetail v) => v.topicId;
  static const Field<QbModDetail, int> _f$topicId = Field('topicId', _$topicId);
  static String _$title(QbModDetail v) => v.title;
  static const Field<QbModDetail, String> _f$title = Field(
    'title',
    _$title,
    opt: true,
    def: '',
  );
  static String? _$category(QbModDetail v) => v.category;
  static const Field<QbModDetail, String> _f$category = Field(
    'category',
    _$category,
    opt: true,
  );
  static String? _$gameVersion(QbModDetail v) => v.gameVersion;
  static const Field<QbModDetail, String> _f$gameVersion = Field(
    'gameVersion',
    _$gameVersion,
    opt: true,
  );
  static String _$author(QbModDetail v) => v.author;
  static const Field<QbModDetail, String> _f$author = Field(
    'author',
    _$author,
    opt: true,
    def: '',
  );
  static String? _$authorTitle(QbModDetail v) => v.authorTitle;
  static const Field<QbModDetail, String> _f$authorTitle = Field(
    'authorTitle',
    _$authorTitle,
    opt: true,
  );
  static int _$authorPostCount(QbModDetail v) => v.authorPostCount;
  static const Field<QbModDetail, int> _f$authorPostCount = Field(
    'authorPostCount',
    _$authorPostCount,
    opt: true,
    def: 0,
  );
  static String? _$authorAvatarPath(QbModDetail v) => v.authorAvatarPath;
  static const Field<QbModDetail, String> _f$authorAvatarPath = Field(
    'authorAvatarPath',
    _$authorAvatarPath,
    opt: true,
  );
  static String? _$postDate(QbModDetail v) => v.postDate;
  static const Field<QbModDetail, String> _f$postDate = Field(
    'postDate',
    _$postDate,
    opt: true,
  );
  static String? _$lastEditDate(QbModDetail v) => v.lastEditDate;
  static const Field<QbModDetail, String> _f$lastEditDate = Field(
    'lastEditDate',
    _$lastEditDate,
    opt: true,
  );
  static String _$contentHtml(QbModDetail v) => v.contentHtml;
  static const Field<QbModDetail, String> _f$contentHtml = Field(
    'contentHtml',
    _$contentHtml,
    opt: true,
    def: '',
  );
  static List<ImageRef> _$images(QbModDetail v) => v.images;
  static const Field<QbModDetail, List<ImageRef>> _f$images = Field(
    'images',
    _$images,
    opt: true,
    def: const [],
  );
  static List<LinkRef> _$links(QbModDetail v) => v.links;
  static const Field<QbModDetail, List<LinkRef>> _f$links = Field(
    'links',
    _$links,
    opt: true,
    def: const [],
  );
  static DateTime _$scrapedAt(QbModDetail v) => v.scrapedAt;
  static const Field<QbModDetail, DateTime> _f$scrapedAt = Field(
    'scrapedAt',
    _$scrapedAt,
    opt: true,
  );
  static bool _$isPlaceholderDetail(QbModDetail v) => v.isPlaceholderDetail;
  static const Field<QbModDetail, bool> _f$isPlaceholderDetail = Field(
    'isPlaceholderDetail',
    _$isPlaceholderDetail,
    opt: true,
    def: false,
  );

  @override
  final MappableFields<QbModDetail> fields = const {
    #topicId: _f$topicId,
    #title: _f$title,
    #category: _f$category,
    #gameVersion: _f$gameVersion,
    #author: _f$author,
    #authorTitle: _f$authorTitle,
    #authorPostCount: _f$authorPostCount,
    #authorAvatarPath: _f$authorAvatarPath,
    #postDate: _f$postDate,
    #lastEditDate: _f$lastEditDate,
    #contentHtml: _f$contentHtml,
    #images: _f$images,
    #links: _f$links,
    #scrapedAt: _f$scrapedAt,
    #isPlaceholderDetail: _f$isPlaceholderDetail,
  };
  @override
  final bool ignoreNull = true;

  static QbModDetail _instantiate(DecodingData data) {
    return QbModDetail(
      topicId: data.dec(_f$topicId),
      title: data.dec(_f$title),
      category: data.dec(_f$category),
      gameVersion: data.dec(_f$gameVersion),
      author: data.dec(_f$author),
      authorTitle: data.dec(_f$authorTitle),
      authorPostCount: data.dec(_f$authorPostCount),
      authorAvatarPath: data.dec(_f$authorAvatarPath),
      postDate: data.dec(_f$postDate),
      lastEditDate: data.dec(_f$lastEditDate),
      contentHtml: data.dec(_f$contentHtml),
      images: data.dec(_f$images),
      links: data.dec(_f$links),
      scrapedAt: data.dec(_f$scrapedAt),
      isPlaceholderDetail: data.dec(_f$isPlaceholderDetail),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static QbModDetail fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<QbModDetail>(map);
  }

  static QbModDetail fromJson(String json) {
    return ensureInitialized().decodeJson<QbModDetail>(json);
  }
}

mixin QbModDetailMappable {
  String toJson() {
    return QbModDetailMapper.ensureInitialized().encodeJson<QbModDetail>(
      this as QbModDetail,
    );
  }

  Map<String, dynamic> toMap() {
    return QbModDetailMapper.ensureInitialized().encodeMap<QbModDetail>(
      this as QbModDetail,
    );
  }

  QbModDetailCopyWith<QbModDetail, QbModDetail, QbModDetail> get copyWith =>
      _QbModDetailCopyWithImpl<QbModDetail, QbModDetail>(
        this as QbModDetail,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return QbModDetailMapper.ensureInitialized().stringifyValue(
      this as QbModDetail,
    );
  }

  @override
  bool operator ==(Object other) {
    return QbModDetailMapper.ensureInitialized().equalsValue(
      this as QbModDetail,
      other,
    );
  }

  @override
  int get hashCode {
    return QbModDetailMapper.ensureInitialized().hashValue(this as QbModDetail);
  }
}

extension QbModDetailValueCopy<$R, $Out>
    on ObjectCopyWith<$R, QbModDetail, $Out> {
  QbModDetailCopyWith<$R, QbModDetail, $Out> get $asQbModDetail =>
      $base.as((v, t, t2) => _QbModDetailCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class QbModDetailCopyWith<$R, $In extends QbModDetail, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, ImageRef, ImageRefCopyWith<$R, ImageRef, ImageRef>>
  get images;
  ListCopyWith<$R, LinkRef, LinkRefCopyWith<$R, LinkRef, LinkRef>> get links;
  $R call({
    int? topicId,
    String? title,
    String? category,
    String? gameVersion,
    String? author,
    String? authorTitle,
    int? authorPostCount,
    String? authorAvatarPath,
    String? postDate,
    String? lastEditDate,
    String? contentHtml,
    List<ImageRef>? images,
    List<LinkRef>? links,
    DateTime? scrapedAt,
    bool? isPlaceholderDetail,
  });
  QbModDetailCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _QbModDetailCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, QbModDetail, $Out>
    implements QbModDetailCopyWith<$R, QbModDetail, $Out> {
  _QbModDetailCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<QbModDetail> $mapper =
      QbModDetailMapper.ensureInitialized();
  @override
  ListCopyWith<$R, ImageRef, ImageRefCopyWith<$R, ImageRef, ImageRef>>
  get images => ListCopyWith(
    $value.images,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(images: v),
  );
  @override
  ListCopyWith<$R, LinkRef, LinkRefCopyWith<$R, LinkRef, LinkRef>> get links =>
      ListCopyWith(
        $value.links,
        (v, t) => v.copyWith.$chain(t),
        (v) => call(links: v),
      );
  @override
  $R call({
    int? topicId,
    String? title,
    Object? category = $none,
    Object? gameVersion = $none,
    String? author,
    Object? authorTitle = $none,
    int? authorPostCount,
    Object? authorAvatarPath = $none,
    Object? postDate = $none,
    Object? lastEditDate = $none,
    String? contentHtml,
    List<ImageRef>? images,
    List<LinkRef>? links,
    Object? scrapedAt = $none,
    bool? isPlaceholderDetail,
  }) => $apply(
    FieldCopyWithData({
      if (topicId != null) #topicId: topicId,
      if (title != null) #title: title,
      if (category != $none) #category: category,
      if (gameVersion != $none) #gameVersion: gameVersion,
      if (author != null) #author: author,
      if (authorTitle != $none) #authorTitle: authorTitle,
      if (authorPostCount != null) #authorPostCount: authorPostCount,
      if (authorAvatarPath != $none) #authorAvatarPath: authorAvatarPath,
      if (postDate != $none) #postDate: postDate,
      if (lastEditDate != $none) #lastEditDate: lastEditDate,
      if (contentHtml != null) #contentHtml: contentHtml,
      if (images != null) #images: images,
      if (links != null) #links: links,
      if (scrapedAt != $none) #scrapedAt: scrapedAt,
      if (isPlaceholderDetail != null)
        #isPlaceholderDetail: isPlaceholderDetail,
    }),
  );
  @override
  QbModDetail $make(CopyWithData data) => QbModDetail(
    topicId: data.get(#topicId, or: $value.topicId),
    title: data.get(#title, or: $value.title),
    category: data.get(#category, or: $value.category),
    gameVersion: data.get(#gameVersion, or: $value.gameVersion),
    author: data.get(#author, or: $value.author),
    authorTitle: data.get(#authorTitle, or: $value.authorTitle),
    authorPostCount: data.get(#authorPostCount, or: $value.authorPostCount),
    authorAvatarPath: data.get(#authorAvatarPath, or: $value.authorAvatarPath),
    postDate: data.get(#postDate, or: $value.postDate),
    lastEditDate: data.get(#lastEditDate, or: $value.lastEditDate),
    contentHtml: data.get(#contentHtml, or: $value.contentHtml),
    images: data.get(#images, or: $value.images),
    links: data.get(#links, or: $value.links),
    scrapedAt: data.get(#scrapedAt, or: $value.scrapedAt),
    isPlaceholderDetail: data.get(
      #isPlaceholderDetail,
      or: $value.isPlaceholderDetail,
    ),
  );

  @override
  QbModDetailCopyWith<$R2, QbModDetail, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _QbModDetailCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ImageRefMapper extends ClassMapperBase<ImageRef> {
  ImageRefMapper._();

  static ImageRefMapper? _instance;
  static ImageRefMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ImageRefMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'ImageRef';

  static String _$originalUrl(ImageRef v) => v.originalUrl;
  static const Field<ImageRef, String> _f$originalUrl = Field(
    'originalUrl',
    _$originalUrl,
    opt: true,
    def: '',
  );
  static String _$localPath(ImageRef v) => v.localPath;
  static const Field<ImageRef, String> _f$localPath = Field(
    'localPath',
    _$localPath,
    opt: true,
    def: '',
  );
  static String? _$alt(ImageRef v) => v.alt;
  static const Field<ImageRef, String> _f$alt = Field('alt', _$alt, opt: true);

  @override
  final MappableFields<ImageRef> fields = const {
    #originalUrl: _f$originalUrl,
    #localPath: _f$localPath,
    #alt: _f$alt,
  };
  @override
  final bool ignoreNull = true;

  static ImageRef _instantiate(DecodingData data) {
    return ImageRef(
      originalUrl: data.dec(_f$originalUrl),
      localPath: data.dec(_f$localPath),
      alt: data.dec(_f$alt),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ImageRef fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ImageRef>(map);
  }

  static ImageRef fromJson(String json) {
    return ensureInitialized().decodeJson<ImageRef>(json);
  }
}

mixin ImageRefMappable {
  String toJson() {
    return ImageRefMapper.ensureInitialized().encodeJson<ImageRef>(
      this as ImageRef,
    );
  }

  Map<String, dynamic> toMap() {
    return ImageRefMapper.ensureInitialized().encodeMap<ImageRef>(
      this as ImageRef,
    );
  }

  ImageRefCopyWith<ImageRef, ImageRef, ImageRef> get copyWith =>
      _ImageRefCopyWithImpl<ImageRef, ImageRef>(
        this as ImageRef,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ImageRefMapper.ensureInitialized().stringifyValue(this as ImageRef);
  }

  @override
  bool operator ==(Object other) {
    return ImageRefMapper.ensureInitialized().equalsValue(
      this as ImageRef,
      other,
    );
  }

  @override
  int get hashCode {
    return ImageRefMapper.ensureInitialized().hashValue(this as ImageRef);
  }
}

extension ImageRefValueCopy<$R, $Out> on ObjectCopyWith<$R, ImageRef, $Out> {
  ImageRefCopyWith<$R, ImageRef, $Out> get $asImageRef =>
      $base.as((v, t, t2) => _ImageRefCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ImageRefCopyWith<$R, $In extends ImageRef, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? originalUrl, String? localPath, String? alt});
  ImageRefCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ImageRefCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ImageRef, $Out>
    implements ImageRefCopyWith<$R, ImageRef, $Out> {
  _ImageRefCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ImageRef> $mapper =
      ImageRefMapper.ensureInitialized();
  @override
  $R call({String? originalUrl, String? localPath, Object? alt = $none}) =>
      $apply(
        FieldCopyWithData({
          if (originalUrl != null) #originalUrl: originalUrl,
          if (localPath != null) #localPath: localPath,
          if (alt != $none) #alt: alt,
        }),
      );
  @override
  ImageRef $make(CopyWithData data) => ImageRef(
    originalUrl: data.get(#originalUrl, or: $value.originalUrl),
    localPath: data.get(#localPath, or: $value.localPath),
    alt: data.get(#alt, or: $value.alt),
  );

  @override
  ImageRefCopyWith<$R2, ImageRef, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ImageRefCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class LinkRefMapper extends ClassMapperBase<LinkRef> {
  LinkRefMapper._();

  static LinkRefMapper? _instance;
  static LinkRefMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LinkRefMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'LinkRef';

  static String _$url(LinkRef v) => v.url;
  static const Field<LinkRef, String> _f$url = Field(
    'url',
    _$url,
    opt: true,
    def: '',
  );
  static String _$text(LinkRef v) => v.text;
  static const Field<LinkRef, String> _f$text = Field(
    'text',
    _$text,
    opt: true,
    def: '',
  );
  static bool _$isExternal(LinkRef v) => v.isExternal;
  static const Field<LinkRef, bool> _f$isExternal = Field(
    'isExternal',
    _$isExternal,
    opt: true,
    def: false,
  );

  @override
  final MappableFields<LinkRef> fields = const {
    #url: _f$url,
    #text: _f$text,
    #isExternal: _f$isExternal,
  };
  @override
  final bool ignoreNull = true;

  static LinkRef _instantiate(DecodingData data) {
    return LinkRef(
      url: data.dec(_f$url),
      text: data.dec(_f$text),
      isExternal: data.dec(_f$isExternal),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static LinkRef fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<LinkRef>(map);
  }

  static LinkRef fromJson(String json) {
    return ensureInitialized().decodeJson<LinkRef>(json);
  }
}

mixin LinkRefMappable {
  String toJson() {
    return LinkRefMapper.ensureInitialized().encodeJson<LinkRef>(
      this as LinkRef,
    );
  }

  Map<String, dynamic> toMap() {
    return LinkRefMapper.ensureInitialized().encodeMap<LinkRef>(
      this as LinkRef,
    );
  }

  LinkRefCopyWith<LinkRef, LinkRef, LinkRef> get copyWith =>
      _LinkRefCopyWithImpl<LinkRef, LinkRef>(
        this as LinkRef,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return LinkRefMapper.ensureInitialized().stringifyValue(this as LinkRef);
  }

  @override
  bool operator ==(Object other) {
    return LinkRefMapper.ensureInitialized().equalsValue(
      this as LinkRef,
      other,
    );
  }

  @override
  int get hashCode {
    return LinkRefMapper.ensureInitialized().hashValue(this as LinkRef);
  }
}

extension LinkRefValueCopy<$R, $Out> on ObjectCopyWith<$R, LinkRef, $Out> {
  LinkRefCopyWith<$R, LinkRef, $Out> get $asLinkRef =>
      $base.as((v, t, t2) => _LinkRefCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class LinkRefCopyWith<$R, $In extends LinkRef, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? url, String? text, bool? isExternal});
  LinkRefCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _LinkRefCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, LinkRef, $Out>
    implements LinkRefCopyWith<$R, LinkRef, $Out> {
  _LinkRefCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<LinkRef> $mapper =
      LinkRefMapper.ensureInitialized();
  @override
  $R call({String? url, String? text, bool? isExternal}) => $apply(
    FieldCopyWithData({
      if (url != null) #url: url,
      if (text != null) #text: text,
      if (isExternal != null) #isExternal: isExternal,
    }),
  );
  @override
  LinkRef $make(CopyWithData data) => LinkRef(
    url: data.get(#url, or: $value.url),
    text: data.get(#text, or: $value.text),
    isExternal: data.get(#isExternal, or: $value.isExternal),
  );

  @override
  LinkRefCopyWith<$R2, LinkRef, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _LinkRefCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

