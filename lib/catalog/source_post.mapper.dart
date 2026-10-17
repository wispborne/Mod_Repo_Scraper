// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'source_post.dart';

class SourceKindMapper extends EnumMapper<SourceKind> {
  SourceKindMapper._();

  static SourceKindMapper? _instance;
  static SourceKindMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SourceKindMapper._());
    }
    return _instance!;
  }

  static SourceKind fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  SourceKind decode(dynamic value) {
    switch (value) {
      case r'forum':
        return SourceKind.forum;
      case r'discord':
        return SourceKind.discord;
      case r'nexus':
        return SourceKind.nexus;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(SourceKind self) {
    switch (self) {
      case SourceKind.forum:
        return r'forum';
      case SourceKind.discord:
        return r'discord';
      case SourceKind.nexus:
        return r'nexus';
    }
  }
}

extension SourceKindMapperExtension on SourceKind {
  String toValue() {
    SourceKindMapper.ensureInitialized();
    return MapperContainer.globals.toValue<SourceKind>(this) as String;
  }
}

class SourcePostMapper extends ClassMapperBase<SourcePost> {
  SourcePostMapper._();

  static SourcePostMapper? _instance;
  static SourcePostMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SourcePostMapper._());
      SourceKindMapper.ensureInitialized();
      QbForumPostMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'SourcePost';

  static SourceKind _$kind(SourcePost v) => v.kind;
  static const Field<SourcePost, SourceKind> _f$kind = Field('kind', _$kind);
  static String _$id(SourcePost v) => v.id;
  static const Field<SourcePost, String> _f$id = Field('id', _$id);
  static String _$title(SourcePost v) => v.title;
  static const Field<SourcePost, String> _f$title = Field(
    'title',
    _$title,
    opt: true,
    def: '',
  );
  static String _$author(SourcePost v) => v.author;
  static const Field<SourcePost, String> _f$author = Field(
    'author',
    _$author,
    opt: true,
    def: '',
  );
  static String _$url(SourcePost v) => v.url;
  static const Field<SourcePost, String> _f$url = Field(
    'url',
    _$url,
    opt: true,
    def: '',
  );
  static String? _$gameVersion(SourcePost v) => v.gameVersion;
  static const Field<SourcePost, String> _f$gameVersion = Field(
    'gameVersion',
    _$gameVersion,
    opt: true,
  );
  static List<QbForumPost> _$posts(SourcePost v) => v.posts;
  static const Field<SourcePost, List<QbForumPost>> _f$posts = Field(
    'posts',
    _$posts,
    opt: true,
    def: const [],
  );
  static bool _$isPlaceholder(SourcePost v) => v.isPlaceholder;
  static const Field<SourcePost, bool> _f$isPlaceholder = Field(
    'isPlaceholder',
    _$isPlaceholder,
    opt: true,
    def: false,
  );

  @override
  final MappableFields<SourcePost> fields = const {
    #kind: _f$kind,
    #id: _f$id,
    #title: _f$title,
    #author: _f$author,
    #url: _f$url,
    #gameVersion: _f$gameVersion,
    #posts: _f$posts,
    #isPlaceholder: _f$isPlaceholder,
  };
  @override
  final bool ignoreNull = true;

  static SourcePost _instantiate(DecodingData data) {
    return SourcePost(
      kind: data.dec(_f$kind),
      id: data.dec(_f$id),
      title: data.dec(_f$title),
      author: data.dec(_f$author),
      url: data.dec(_f$url),
      gameVersion: data.dec(_f$gameVersion),
      posts: data.dec(_f$posts),
      isPlaceholder: data.dec(_f$isPlaceholder),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static SourcePost fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SourcePost>(map);
  }

  static SourcePost fromJson(String json) {
    return ensureInitialized().decodeJson<SourcePost>(json);
  }
}

mixin SourcePostMappable {
  String toJson() {
    return SourcePostMapper.ensureInitialized().encodeJson<SourcePost>(
      this as SourcePost,
    );
  }

  Map<String, dynamic> toMap() {
    return SourcePostMapper.ensureInitialized().encodeMap<SourcePost>(
      this as SourcePost,
    );
  }

  SourcePostCopyWith<SourcePost, SourcePost, SourcePost> get copyWith =>
      _SourcePostCopyWithImpl<SourcePost, SourcePost>(
        this as SourcePost,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return SourcePostMapper.ensureInitialized().stringifyValue(
      this as SourcePost,
    );
  }

  @override
  bool operator ==(Object other) {
    return SourcePostMapper.ensureInitialized().equalsValue(
      this as SourcePost,
      other,
    );
  }

  @override
  int get hashCode {
    return SourcePostMapper.ensureInitialized().hashValue(this as SourcePost);
  }
}

extension SourcePostValueCopy<$R, $Out>
    on ObjectCopyWith<$R, SourcePost, $Out> {
  SourcePostCopyWith<$R, SourcePost, $Out> get $asSourcePost =>
      $base.as((v, t, t2) => _SourcePostCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class SourcePostCopyWith<$R, $In extends SourcePost, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<
    $R,
    QbForumPost,
    QbForumPostCopyWith<$R, QbForumPost, QbForumPost>
  >
  get posts;
  $R call({
    SourceKind? kind,
    String? id,
    String? title,
    String? author,
    String? url,
    String? gameVersion,
    List<QbForumPost>? posts,
    bool? isPlaceholder,
  });
  SourcePostCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _SourcePostCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, SourcePost, $Out>
    implements SourcePostCopyWith<$R, SourcePost, $Out> {
  _SourcePostCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<SourcePost> $mapper =
      SourcePostMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    QbForumPost,
    QbForumPostCopyWith<$R, QbForumPost, QbForumPost>
  >
  get posts => ListCopyWith(
    $value.posts,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(posts: v),
  );
  @override
  $R call({
    SourceKind? kind,
    String? id,
    String? title,
    String? author,
    String? url,
    Object? gameVersion = $none,
    List<QbForumPost>? posts,
    bool? isPlaceholder,
  }) => $apply(
    FieldCopyWithData({
      if (kind != null) #kind: kind,
      if (id != null) #id: id,
      if (title != null) #title: title,
      if (author != null) #author: author,
      if (url != null) #url: url,
      if (gameVersion != $none) #gameVersion: gameVersion,
      if (posts != null) #posts: posts,
      if (isPlaceholder != null) #isPlaceholder: isPlaceholder,
    }),
  );
  @override
  SourcePost $make(CopyWithData data) => SourcePost(
    kind: data.get(#kind, or: $value.kind),
    id: data.get(#id, or: $value.id),
    title: data.get(#title, or: $value.title),
    author: data.get(#author, or: $value.author),
    url: data.get(#url, or: $value.url),
    gameVersion: data.get(#gameVersion, or: $value.gameVersion),
    posts: data.get(#posts, or: $value.posts),
    isPlaceholder: data.get(#isPlaceholder, or: $value.isPlaceholder),
  );

  @override
  SourcePostCopyWith<$R2, SourcePost, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _SourcePostCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class SourcePostRefMapper extends ClassMapperBase<SourcePostRef> {
  SourcePostRefMapper._();

  static SourcePostRefMapper? _instance;
  static SourcePostRefMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SourcePostRefMapper._());
      SourceKindMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'SourcePostRef';

  static SourceKind _$kind(SourcePostRef v) => v.kind;
  static const Field<SourcePostRef, SourceKind> _f$kind = Field('kind', _$kind);
  static String _$id(SourcePostRef v) => v.id;
  static const Field<SourcePostRef, String> _f$id = Field('id', _$id);
  static String? _$llmModName(SourcePostRef v) => v.llmModName;
  static const Field<SourcePostRef, String> _f$llmModName = Field(
    'llmModName',
    _$llmModName,
    opt: true,
  );

  @override
  final MappableFields<SourcePostRef> fields = const {
    #kind: _f$kind,
    #id: _f$id,
    #llmModName: _f$llmModName,
  };
  @override
  final bool ignoreNull = true;

  static SourcePostRef _instantiate(DecodingData data) {
    return SourcePostRef(
      kind: data.dec(_f$kind),
      id: data.dec(_f$id),
      llmModName: data.dec(_f$llmModName),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static SourcePostRef fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SourcePostRef>(map);
  }

  static SourcePostRef fromJson(String json) {
    return ensureInitialized().decodeJson<SourcePostRef>(json);
  }
}

mixin SourcePostRefMappable {
  String toJson() {
    return SourcePostRefMapper.ensureInitialized().encodeJson<SourcePostRef>(
      this as SourcePostRef,
    );
  }

  Map<String, dynamic> toMap() {
    return SourcePostRefMapper.ensureInitialized().encodeMap<SourcePostRef>(
      this as SourcePostRef,
    );
  }

  SourcePostRefCopyWith<SourcePostRef, SourcePostRef, SourcePostRef>
  get copyWith => _SourcePostRefCopyWithImpl<SourcePostRef, SourcePostRef>(
    this as SourcePostRef,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return SourcePostRefMapper.ensureInitialized().stringifyValue(
      this as SourcePostRef,
    );
  }

  @override
  bool operator ==(Object other) {
    return SourcePostRefMapper.ensureInitialized().equalsValue(
      this as SourcePostRef,
      other,
    );
  }

  @override
  int get hashCode {
    return SourcePostRefMapper.ensureInitialized().hashValue(
      this as SourcePostRef,
    );
  }
}

extension SourcePostRefValueCopy<$R, $Out>
    on ObjectCopyWith<$R, SourcePostRef, $Out> {
  SourcePostRefCopyWith<$R, SourcePostRef, $Out> get $asSourcePostRef =>
      $base.as((v, t, t2) => _SourcePostRefCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class SourcePostRefCopyWith<$R, $In extends SourcePostRef, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({SourceKind? kind, String? id, String? llmModName});
  SourcePostRefCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _SourcePostRefCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, SourcePostRef, $Out>
    implements SourcePostRefCopyWith<$R, SourcePostRef, $Out> {
  _SourcePostRefCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<SourcePostRef> $mapper =
      SourcePostRefMapper.ensureInitialized();
  @override
  $R call({SourceKind? kind, String? id, Object? llmModName = $none}) => $apply(
    FieldCopyWithData({
      if (kind != null) #kind: kind,
      if (id != null) #id: id,
      if (llmModName != $none) #llmModName: llmModName,
    }),
  );
  @override
  SourcePostRef $make(CopyWithData data) => SourcePostRef(
    kind: data.get(#kind, or: $value.kind),
    id: data.get(#id, or: $value.id),
    llmModName: data.get(#llmModName, or: $value.llmModName),
  );

  @override
  SourcePostRefCopyWith<$R2, SourcePostRef, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _SourcePostRefCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

