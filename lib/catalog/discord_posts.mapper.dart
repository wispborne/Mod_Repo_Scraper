// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'discord_posts.dart';

class DiscordImageMapper extends ClassMapperBase<DiscordImage> {
  DiscordImageMapper._();

  static DiscordImageMapper? _instance;
  static DiscordImageMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DiscordImageMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'DiscordImage';

  static String _$url(DiscordImage v) => v.url;
  static const Field<DiscordImage, String> _f$url = Field('url', _$url);
  static String? _$filename(DiscordImage v) => v.filename;
  static const Field<DiscordImage, String> _f$filename = Field(
    'filename',
    _$filename,
    opt: true,
  );
  static String? _$description(DiscordImage v) => v.description;
  static const Field<DiscordImage, String> _f$description = Field(
    'description',
    _$description,
    opt: true,
  );

  @override
  final MappableFields<DiscordImage> fields = const {
    #url: _f$url,
    #filename: _f$filename,
    #description: _f$description,
  };
  @override
  final bool ignoreNull = true;

  static DiscordImage _instantiate(DecodingData data) {
    return DiscordImage(
      url: data.dec(_f$url),
      filename: data.dec(_f$filename),
      description: data.dec(_f$description),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static DiscordImage fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<DiscordImage>(map);
  }

  static DiscordImage fromJson(String json) {
    return ensureInitialized().decodeJson<DiscordImage>(json);
  }
}

mixin DiscordImageMappable {
  String toJson() {
    return DiscordImageMapper.ensureInitialized().encodeJson<DiscordImage>(
      this as DiscordImage,
    );
  }

  Map<String, dynamic> toMap() {
    return DiscordImageMapper.ensureInitialized().encodeMap<DiscordImage>(
      this as DiscordImage,
    );
  }

  DiscordImageCopyWith<DiscordImage, DiscordImage, DiscordImage> get copyWith =>
      _DiscordImageCopyWithImpl<DiscordImage, DiscordImage>(
        this as DiscordImage,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return DiscordImageMapper.ensureInitialized().stringifyValue(
      this as DiscordImage,
    );
  }

  @override
  bool operator ==(Object other) {
    return DiscordImageMapper.ensureInitialized().equalsValue(
      this as DiscordImage,
      other,
    );
  }

  @override
  int get hashCode {
    return DiscordImageMapper.ensureInitialized().hashValue(
      this as DiscordImage,
    );
  }
}

extension DiscordImageValueCopy<$R, $Out>
    on ObjectCopyWith<$R, DiscordImage, $Out> {
  DiscordImageCopyWith<$R, DiscordImage, $Out> get $asDiscordImage =>
      $base.as((v, t, t2) => _DiscordImageCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class DiscordImageCopyWith<$R, $In extends DiscordImage, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? url, String? filename, String? description});
  DiscordImageCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _DiscordImageCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, DiscordImage, $Out>
    implements DiscordImageCopyWith<$R, DiscordImage, $Out> {
  _DiscordImageCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<DiscordImage> $mapper =
      DiscordImageMapper.ensureInitialized();
  @override
  $R call({
    String? url,
    Object? filename = $none,
    Object? description = $none,
  }) => $apply(
    FieldCopyWithData({
      if (url != null) #url: url,
      if (filename != $none) #filename: filename,
      if (description != $none) #description: description,
    }),
  );
  @override
  DiscordImage $make(CopyWithData data) => DiscordImage(
    url: data.get(#url, or: $value.url),
    filename: data.get(#filename, or: $value.filename),
    description: data.get(#description, or: $value.description),
  );

  @override
  DiscordImageCopyWith<$R2, DiscordImage, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _DiscordImageCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class DiscordFileMapper extends ClassMapperBase<DiscordFile> {
  DiscordFileMapper._();

  static DiscordFileMapper? _instance;
  static DiscordFileMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DiscordFileMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'DiscordFile';

  static String _$url(DiscordFile v) => v.url;
  static const Field<DiscordFile, String> _f$url = Field('url', _$url);
  static String? _$filename(DiscordFile v) => v.filename;
  static const Field<DiscordFile, String> _f$filename = Field(
    'filename',
    _$filename,
    opt: true,
  );
  static int? _$size(DiscordFile v) => v.size;
  static const Field<DiscordFile, int> _f$size = Field(
    'size',
    _$size,
    opt: true,
  );
  static String? _$contentType(DiscordFile v) => v.contentType;
  static const Field<DiscordFile, String> _f$contentType = Field(
    'contentType',
    _$contentType,
    opt: true,
  );

  @override
  final MappableFields<DiscordFile> fields = const {
    #url: _f$url,
    #filename: _f$filename,
    #size: _f$size,
    #contentType: _f$contentType,
  };
  @override
  final bool ignoreNull = true;

  static DiscordFile _instantiate(DecodingData data) {
    return DiscordFile(
      url: data.dec(_f$url),
      filename: data.dec(_f$filename),
      size: data.dec(_f$size),
      contentType: data.dec(_f$contentType),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static DiscordFile fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<DiscordFile>(map);
  }

  static DiscordFile fromJson(String json) {
    return ensureInitialized().decodeJson<DiscordFile>(json);
  }
}

mixin DiscordFileMappable {
  String toJson() {
    return DiscordFileMapper.ensureInitialized().encodeJson<DiscordFile>(
      this as DiscordFile,
    );
  }

  Map<String, dynamic> toMap() {
    return DiscordFileMapper.ensureInitialized().encodeMap<DiscordFile>(
      this as DiscordFile,
    );
  }

  DiscordFileCopyWith<DiscordFile, DiscordFile, DiscordFile> get copyWith =>
      _DiscordFileCopyWithImpl<DiscordFile, DiscordFile>(
        this as DiscordFile,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return DiscordFileMapper.ensureInitialized().stringifyValue(
      this as DiscordFile,
    );
  }

  @override
  bool operator ==(Object other) {
    return DiscordFileMapper.ensureInitialized().equalsValue(
      this as DiscordFile,
      other,
    );
  }

  @override
  int get hashCode {
    return DiscordFileMapper.ensureInitialized().hashValue(this as DiscordFile);
  }
}

extension DiscordFileValueCopy<$R, $Out>
    on ObjectCopyWith<$R, DiscordFile, $Out> {
  DiscordFileCopyWith<$R, DiscordFile, $Out> get $asDiscordFile =>
      $base.as((v, t, t2) => _DiscordFileCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class DiscordFileCopyWith<$R, $In extends DiscordFile, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? url, String? filename, int? size, String? contentType});
  DiscordFileCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _DiscordFileCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, DiscordFile, $Out>
    implements DiscordFileCopyWith<$R, DiscordFile, $Out> {
  _DiscordFileCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<DiscordFile> $mapper =
      DiscordFileMapper.ensureInitialized();
  @override
  $R call({
    String? url,
    Object? filename = $none,
    Object? size = $none,
    Object? contentType = $none,
  }) => $apply(
    FieldCopyWithData({
      if (url != null) #url: url,
      if (filename != $none) #filename: filename,
      if (size != $none) #size: size,
      if (contentType != $none) #contentType: contentType,
    }),
  );
  @override
  DiscordFile $make(CopyWithData data) => DiscordFile(
    url: data.get(#url, or: $value.url),
    filename: data.get(#filename, or: $value.filename),
    size: data.get(#size, or: $value.size),
    contentType: data.get(#contentType, or: $value.contentType),
  );

  @override
  DiscordFileCopyWith<$R2, DiscordFile, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _DiscordFileCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class DiscordOpeningMessageMapper
    extends ClassMapperBase<DiscordOpeningMessage> {
  DiscordOpeningMessageMapper._();

  static DiscordOpeningMessageMapper? _instance;
  static DiscordOpeningMessageMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DiscordOpeningMessageMapper._());
      DiscordImageMapper.ensureInitialized();
      DiscordFileMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'DiscordOpeningMessage';

  static String _$id(DiscordOpeningMessage v) => v.id;
  static const Field<DiscordOpeningMessage, String> _f$id = Field('id', _$id);
  static String _$content(DiscordOpeningMessage v) => v.content;
  static const Field<DiscordOpeningMessage, String> _f$content = Field(
    'content',
    _$content,
    opt: true,
    def: '',
  );
  static DateTime? _$timestamp(DiscordOpeningMessage v) => v.timestamp;
  static const Field<DiscordOpeningMessage, DateTime> _f$timestamp = Field(
    'timestamp',
    _$timestamp,
    opt: true,
  );
  static DateTime? _$editedTimestamp(DiscordOpeningMessage v) =>
      v.editedTimestamp;
  static const Field<DiscordOpeningMessage, DateTime> _f$editedTimestamp =
      Field('editedTimestamp', _$editedTimestamp, opt: true);
  static List<DiscordImage> _$images(DiscordOpeningMessage v) => v.images;
  static const Field<DiscordOpeningMessage, List<DiscordImage>> _f$images =
      Field('images', _$images, opt: true, def: const []);
  static List<DiscordFile>? _$files(DiscordOpeningMessage v) => v.files;
  static const Field<DiscordOpeningMessage, List<DiscordFile>> _f$files = Field(
    'files',
    _$files,
    opt: true,
  );

  @override
  final MappableFields<DiscordOpeningMessage> fields = const {
    #id: _f$id,
    #content: _f$content,
    #timestamp: _f$timestamp,
    #editedTimestamp: _f$editedTimestamp,
    #images: _f$images,
    #files: _f$files,
  };
  @override
  final bool ignoreNull = true;

  static DiscordOpeningMessage _instantiate(DecodingData data) {
    return DiscordOpeningMessage(
      id: data.dec(_f$id),
      content: data.dec(_f$content),
      timestamp: data.dec(_f$timestamp),
      editedTimestamp: data.dec(_f$editedTimestamp),
      images: data.dec(_f$images),
      files: data.dec(_f$files),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static DiscordOpeningMessage fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<DiscordOpeningMessage>(map);
  }

  static DiscordOpeningMessage fromJson(String json) {
    return ensureInitialized().decodeJson<DiscordOpeningMessage>(json);
  }
}

mixin DiscordOpeningMessageMappable {
  String toJson() {
    return DiscordOpeningMessageMapper.ensureInitialized()
        .encodeJson<DiscordOpeningMessage>(this as DiscordOpeningMessage);
  }

  Map<String, dynamic> toMap() {
    return DiscordOpeningMessageMapper.ensureInitialized()
        .encodeMap<DiscordOpeningMessage>(this as DiscordOpeningMessage);
  }

  DiscordOpeningMessageCopyWith<
    DiscordOpeningMessage,
    DiscordOpeningMessage,
    DiscordOpeningMessage
  >
  get copyWith =>
      _DiscordOpeningMessageCopyWithImpl<
        DiscordOpeningMessage,
        DiscordOpeningMessage
      >(this as DiscordOpeningMessage, $identity, $identity);
  @override
  String toString() {
    return DiscordOpeningMessageMapper.ensureInitialized().stringifyValue(
      this as DiscordOpeningMessage,
    );
  }

  @override
  bool operator ==(Object other) {
    return DiscordOpeningMessageMapper.ensureInitialized().equalsValue(
      this as DiscordOpeningMessage,
      other,
    );
  }

  @override
  int get hashCode {
    return DiscordOpeningMessageMapper.ensureInitialized().hashValue(
      this as DiscordOpeningMessage,
    );
  }
}

extension DiscordOpeningMessageValueCopy<$R, $Out>
    on ObjectCopyWith<$R, DiscordOpeningMessage, $Out> {
  DiscordOpeningMessageCopyWith<$R, DiscordOpeningMessage, $Out>
  get $asDiscordOpeningMessage => $base.as(
    (v, t, t2) => _DiscordOpeningMessageCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class DiscordOpeningMessageCopyWith<
  $R,
  $In extends DiscordOpeningMessage,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<
    $R,
    DiscordImage,
    DiscordImageCopyWith<$R, DiscordImage, DiscordImage>
  >
  get images;
  ListCopyWith<
    $R,
    DiscordFile,
    DiscordFileCopyWith<$R, DiscordFile, DiscordFile>
  >?
  get files;
  $R call({
    String? id,
    String? content,
    DateTime? timestamp,
    DateTime? editedTimestamp,
    List<DiscordImage>? images,
    List<DiscordFile>? files,
  });
  DiscordOpeningMessageCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _DiscordOpeningMessageCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, DiscordOpeningMessage, $Out>
    implements DiscordOpeningMessageCopyWith<$R, DiscordOpeningMessage, $Out> {
  _DiscordOpeningMessageCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<DiscordOpeningMessage> $mapper =
      DiscordOpeningMessageMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    DiscordImage,
    DiscordImageCopyWith<$R, DiscordImage, DiscordImage>
  >
  get images => ListCopyWith(
    $value.images,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(images: v),
  );
  @override
  ListCopyWith<
    $R,
    DiscordFile,
    DiscordFileCopyWith<$R, DiscordFile, DiscordFile>
  >?
  get files => $value.files != null
      ? ListCopyWith(
          $value.files!,
          (v, t) => v.copyWith.$chain(t),
          (v) => call(files: v),
        )
      : null;
  @override
  $R call({
    String? id,
    String? content,
    Object? timestamp = $none,
    Object? editedTimestamp = $none,
    List<DiscordImage>? images,
    Object? files = $none,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (content != null) #content: content,
      if (timestamp != $none) #timestamp: timestamp,
      if (editedTimestamp != $none) #editedTimestamp: editedTimestamp,
      if (images != null) #images: images,
      if (files != $none) #files: files,
    }),
  );
  @override
  DiscordOpeningMessage $make(CopyWithData data) => DiscordOpeningMessage(
    id: data.get(#id, or: $value.id),
    content: data.get(#content, or: $value.content),
    timestamp: data.get(#timestamp, or: $value.timestamp),
    editedTimestamp: data.get(#editedTimestamp, or: $value.editedTimestamp),
    images: data.get(#images, or: $value.images),
    files: data.get(#files, or: $value.files),
  );

  @override
  DiscordOpeningMessageCopyWith<$R2, DiscordOpeningMessage, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _DiscordOpeningMessageCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class DiscordThreadPostMapper extends ClassMapperBase<DiscordThreadPost> {
  DiscordThreadPostMapper._();

  static DiscordThreadPostMapper? _instance;
  static DiscordThreadPostMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DiscordThreadPostMapper._());
      DiscordOpeningMessageMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'DiscordThreadPost';

  static String _$threadId(DiscordThreadPost v) => v.threadId;
  static const Field<DiscordThreadPost, String> _f$threadId = Field(
    'threadId',
    _$threadId,
  );
  static String _$name(DiscordThreadPost v) => v.name;
  static const Field<DiscordThreadPost, String> _f$name = Field(
    'name',
    _$name,
    opt: true,
    def: '',
  );
  static String _$author(DiscordThreadPost v) => v.author;
  static const Field<DiscordThreadPost, String> _f$author = Field(
    'author',
    _$author,
    opt: true,
    def: '',
  );
  static String _$url(DiscordThreadPost v) => v.url;
  static const Field<DiscordThreadPost, String> _f$url = Field(
    'url',
    _$url,
    opt: true,
    def: '',
  );
  static String? _$forumUrl(DiscordThreadPost v) => v.forumUrl;
  static const Field<DiscordThreadPost, String> _f$forumUrl = Field(
    'forumUrl',
    _$forumUrl,
    opt: true,
  );
  static List<DiscordOpeningMessage> _$messages(DiscordThreadPost v) =>
      v.messages;
  static const Field<DiscordThreadPost, List<DiscordOpeningMessage>>
  _f$messages = Field('messages', _$messages, opt: true, def: const []);

  @override
  final MappableFields<DiscordThreadPost> fields = const {
    #threadId: _f$threadId,
    #name: _f$name,
    #author: _f$author,
    #url: _f$url,
    #forumUrl: _f$forumUrl,
    #messages: _f$messages,
  };
  @override
  final bool ignoreNull = true;

  static DiscordThreadPost _instantiate(DecodingData data) {
    return DiscordThreadPost(
      threadId: data.dec(_f$threadId),
      name: data.dec(_f$name),
      author: data.dec(_f$author),
      url: data.dec(_f$url),
      forumUrl: data.dec(_f$forumUrl),
      messages: data.dec(_f$messages),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static DiscordThreadPost fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<DiscordThreadPost>(map);
  }

  static DiscordThreadPost fromJson(String json) {
    return ensureInitialized().decodeJson<DiscordThreadPost>(json);
  }
}

mixin DiscordThreadPostMappable {
  String toJson() {
    return DiscordThreadPostMapper.ensureInitialized()
        .encodeJson<DiscordThreadPost>(this as DiscordThreadPost);
  }

  Map<String, dynamic> toMap() {
    return DiscordThreadPostMapper.ensureInitialized()
        .encodeMap<DiscordThreadPost>(this as DiscordThreadPost);
  }

  DiscordThreadPostCopyWith<
    DiscordThreadPost,
    DiscordThreadPost,
    DiscordThreadPost
  >
  get copyWith =>
      _DiscordThreadPostCopyWithImpl<DiscordThreadPost, DiscordThreadPost>(
        this as DiscordThreadPost,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return DiscordThreadPostMapper.ensureInitialized().stringifyValue(
      this as DiscordThreadPost,
    );
  }

  @override
  bool operator ==(Object other) {
    return DiscordThreadPostMapper.ensureInitialized().equalsValue(
      this as DiscordThreadPost,
      other,
    );
  }

  @override
  int get hashCode {
    return DiscordThreadPostMapper.ensureInitialized().hashValue(
      this as DiscordThreadPost,
    );
  }
}

extension DiscordThreadPostValueCopy<$R, $Out>
    on ObjectCopyWith<$R, DiscordThreadPost, $Out> {
  DiscordThreadPostCopyWith<$R, DiscordThreadPost, $Out>
  get $asDiscordThreadPost => $base.as(
    (v, t, t2) => _DiscordThreadPostCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class DiscordThreadPostCopyWith<
  $R,
  $In extends DiscordThreadPost,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<
    $R,
    DiscordOpeningMessage,
    DiscordOpeningMessageCopyWith<
      $R,
      DiscordOpeningMessage,
      DiscordOpeningMessage
    >
  >
  get messages;
  $R call({
    String? threadId,
    String? name,
    String? author,
    String? url,
    String? forumUrl,
    List<DiscordOpeningMessage>? messages,
  });
  DiscordThreadPostCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _DiscordThreadPostCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, DiscordThreadPost, $Out>
    implements DiscordThreadPostCopyWith<$R, DiscordThreadPost, $Out> {
  _DiscordThreadPostCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<DiscordThreadPost> $mapper =
      DiscordThreadPostMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    DiscordOpeningMessage,
    DiscordOpeningMessageCopyWith<
      $R,
      DiscordOpeningMessage,
      DiscordOpeningMessage
    >
  >
  get messages => ListCopyWith(
    $value.messages,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(messages: v),
  );
  @override
  $R call({
    String? threadId,
    String? name,
    String? author,
    String? url,
    Object? forumUrl = $none,
    List<DiscordOpeningMessage>? messages,
  }) => $apply(
    FieldCopyWithData({
      if (threadId != null) #threadId: threadId,
      if (name != null) #name: name,
      if (author != null) #author: author,
      if (url != null) #url: url,
      if (forumUrl != $none) #forumUrl: forumUrl,
      if (messages != null) #messages: messages,
    }),
  );
  @override
  DiscordThreadPost $make(CopyWithData data) => DiscordThreadPost(
    threadId: data.get(#threadId, or: $value.threadId),
    name: data.get(#name, or: $value.name),
    author: data.get(#author, or: $value.author),
    url: data.get(#url, or: $value.url),
    forumUrl: data.get(#forumUrl, or: $value.forumUrl),
    messages: data.get(#messages, or: $value.messages),
  );

  @override
  DiscordThreadPostCopyWith<$R2, DiscordThreadPost, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _DiscordThreadPostCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

