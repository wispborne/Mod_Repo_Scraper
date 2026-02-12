// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'discord_reader.dart';

class ChannelMapper extends ClassMapperBase<Channel> {
  ChannelMapper._();

  static ChannelMapper? _instance;
  static ChannelMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ChannelMapper._());
      TagMapper.ensureInitialized();
      ThreadMetadataMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'Channel';

  static String _$id(Channel v) => v.id;
  static const Field<Channel, String> _f$id = Field('id', _$id);
  static String? _$parentId(Channel v) => v.parentId;
  static const Field<Channel, String> _f$parentId = Field(
    'parentId',
    _$parentId,
    key: r'parent_id',
    opt: true,
  );
  static String? _$name(Channel v) => v.name;
  static const Field<Channel, String> _f$name = Field(
    'name',
    _$name,
    opt: true,
  );
  static DateTime? _$timestamp(Channel v) => v.timestamp;
  static const Field<Channel, DateTime> _f$timestamp = Field(
    'timestamp',
    _$timestamp,
    opt: true,
  );
  static String? _$lastMessageId(Channel v) => v.lastMessageId;
  static const Field<Channel, String> _f$lastMessageId = Field(
    'lastMessageId',
    _$lastMessageId,
    key: r'last_message_id',
    opt: true,
  );
  static String? _$ownerId(Channel v) => v.ownerId;
  static const Field<Channel, String> _f$ownerId = Field(
    'ownerId',
    _$ownerId,
    key: r'owner_id',
    opt: true,
  );
  static int? _$messageCount(Channel v) => v.messageCount;
  static const Field<Channel, int> _f$messageCount = Field(
    'messageCount',
    _$messageCount,
    key: r'message_count',
    opt: true,
  );
  static List<Tag>? _$availableTags(Channel v) => v.availableTags;
  static const Field<Channel, List<Tag>> _f$availableTags = Field(
    'availableTags',
    _$availableTags,
    key: r'available_tags',
    opt: true,
  );
  static List<String>? _$appliedTags(Channel v) => v.appliedTags;
  static const Field<Channel, List<String>> _f$appliedTags = Field(
    'appliedTags',
    _$appliedTags,
    key: r'applied_tags',
    opt: true,
  );
  static ThreadMetadata? _$threadMetadata(Channel v) => v.threadMetadata;
  static const Field<Channel, ThreadMetadata> _f$threadMetadata = Field(
    'threadMetadata',
    _$threadMetadata,
    key: r'thread_metadata',
    opt: true,
  );

  @override
  final MappableFields<Channel> fields = const {
    #id: _f$id,
    #parentId: _f$parentId,
    #name: _f$name,
    #timestamp: _f$timestamp,
    #lastMessageId: _f$lastMessageId,
    #ownerId: _f$ownerId,
    #messageCount: _f$messageCount,
    #availableTags: _f$availableTags,
    #appliedTags: _f$appliedTags,
    #threadMetadata: _f$threadMetadata,
  };

  static Channel _instantiate(DecodingData data) {
    return Channel(
      id: data.dec(_f$id),
      parentId: data.dec(_f$parentId),
      name: data.dec(_f$name),
      timestamp: data.dec(_f$timestamp),
      lastMessageId: data.dec(_f$lastMessageId),
      ownerId: data.dec(_f$ownerId),
      messageCount: data.dec(_f$messageCount),
      availableTags: data.dec(_f$availableTags),
      appliedTags: data.dec(_f$appliedTags),
      threadMetadata: data.dec(_f$threadMetadata),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Channel fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Channel>(map);
  }

  static Channel fromJson(String json) {
    return ensureInitialized().decodeJson<Channel>(json);
  }
}

mixin ChannelMappable {
  String toJson() {
    return ChannelMapper.ensureInitialized().encodeJson<Channel>(
      this as Channel,
    );
  }

  Map<String, dynamic> toMap() {
    return ChannelMapper.ensureInitialized().encodeMap<Channel>(
      this as Channel,
    );
  }

  ChannelCopyWith<Channel, Channel, Channel> get copyWith =>
      _ChannelCopyWithImpl<Channel, Channel>(
        this as Channel,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ChannelMapper.ensureInitialized().stringifyValue(this as Channel);
  }

  @override
  bool operator ==(Object other) {
    return ChannelMapper.ensureInitialized().equalsValue(
      this as Channel,
      other,
    );
  }

  @override
  int get hashCode {
    return ChannelMapper.ensureInitialized().hashValue(this as Channel);
  }
}

extension ChannelValueCopy<$R, $Out> on ObjectCopyWith<$R, Channel, $Out> {
  ChannelCopyWith<$R, Channel, $Out> get $asChannel =>
      $base.as((v, t, t2) => _ChannelCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ChannelCopyWith<$R, $In extends Channel, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, Tag, TagCopyWith<$R, Tag, Tag>>? get availableTags;
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>? get appliedTags;
  ThreadMetadataCopyWith<$R, ThreadMetadata, ThreadMetadata>?
  get threadMetadata;
  $R call({
    String? id,
    String? parentId,
    String? name,
    DateTime? timestamp,
    String? lastMessageId,
    String? ownerId,
    int? messageCount,
    List<Tag>? availableTags,
    List<String>? appliedTags,
    ThreadMetadata? threadMetadata,
  });
  ChannelCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ChannelCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, Channel, $Out>
    implements ChannelCopyWith<$R, Channel, $Out> {
  _ChannelCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Channel> $mapper =
      ChannelMapper.ensureInitialized();
  @override
  ListCopyWith<$R, Tag, TagCopyWith<$R, Tag, Tag>>? get availableTags =>
      $value.availableTags != null
      ? ListCopyWith(
          $value.availableTags!,
          (v, t) => v.copyWith.$chain(t),
          (v) => call(availableTags: v),
        )
      : null;
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>?
  get appliedTags => $value.appliedTags != null
      ? ListCopyWith(
          $value.appliedTags!,
          (v, t) => ObjectCopyWith(v, $identity, t),
          (v) => call(appliedTags: v),
        )
      : null;
  @override
  ThreadMetadataCopyWith<$R, ThreadMetadata, ThreadMetadata>?
  get threadMetadata =>
      $value.threadMetadata?.copyWith.$chain((v) => call(threadMetadata: v));
  @override
  $R call({
    String? id,
    Object? parentId = $none,
    Object? name = $none,
    Object? timestamp = $none,
    Object? lastMessageId = $none,
    Object? ownerId = $none,
    Object? messageCount = $none,
    Object? availableTags = $none,
    Object? appliedTags = $none,
    Object? threadMetadata = $none,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (parentId != $none) #parentId: parentId,
      if (name != $none) #name: name,
      if (timestamp != $none) #timestamp: timestamp,
      if (lastMessageId != $none) #lastMessageId: lastMessageId,
      if (ownerId != $none) #ownerId: ownerId,
      if (messageCount != $none) #messageCount: messageCount,
      if (availableTags != $none) #availableTags: availableTags,
      if (appliedTags != $none) #appliedTags: appliedTags,
      if (threadMetadata != $none) #threadMetadata: threadMetadata,
    }),
  );
  @override
  Channel $make(CopyWithData data) => Channel(
    id: data.get(#id, or: $value.id),
    parentId: data.get(#parentId, or: $value.parentId),
    name: data.get(#name, or: $value.name),
    timestamp: data.get(#timestamp, or: $value.timestamp),
    lastMessageId: data.get(#lastMessageId, or: $value.lastMessageId),
    ownerId: data.get(#ownerId, or: $value.ownerId),
    messageCount: data.get(#messageCount, or: $value.messageCount),
    availableTags: data.get(#availableTags, or: $value.availableTags),
    appliedTags: data.get(#appliedTags, or: $value.appliedTags),
    threadMetadata: data.get(#threadMetadata, or: $value.threadMetadata),
  );

  @override
  ChannelCopyWith<$R2, Channel, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ChannelCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class TagMapper extends ClassMapperBase<Tag> {
  TagMapper._();

  static TagMapper? _instance;
  static TagMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = TagMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'Tag';

  static String _$id(Tag v) => v.id;
  static const Field<Tag, String> _f$id = Field('id', _$id);
  static String? _$name(Tag v) => v.name;
  static const Field<Tag, String> _f$name = Field('name', _$name, opt: true);

  @override
  final MappableFields<Tag> fields = const {#id: _f$id, #name: _f$name};

  static Tag _instantiate(DecodingData data) {
    return Tag(id: data.dec(_f$id), name: data.dec(_f$name));
  }

  @override
  final Function instantiate = _instantiate;

  static Tag fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Tag>(map);
  }

  static Tag fromJson(String json) {
    return ensureInitialized().decodeJson<Tag>(json);
  }
}

mixin TagMappable {
  String toJson() {
    return TagMapper.ensureInitialized().encodeJson<Tag>(this as Tag);
  }

  Map<String, dynamic> toMap() {
    return TagMapper.ensureInitialized().encodeMap<Tag>(this as Tag);
  }

  TagCopyWith<Tag, Tag, Tag> get copyWith =>
      _TagCopyWithImpl<Tag, Tag>(this as Tag, $identity, $identity);
  @override
  String toString() {
    return TagMapper.ensureInitialized().stringifyValue(this as Tag);
  }

  @override
  bool operator ==(Object other) {
    return TagMapper.ensureInitialized().equalsValue(this as Tag, other);
  }

  @override
  int get hashCode {
    return TagMapper.ensureInitialized().hashValue(this as Tag);
  }
}

extension TagValueCopy<$R, $Out> on ObjectCopyWith<$R, Tag, $Out> {
  TagCopyWith<$R, Tag, $Out> get $asTag =>
      $base.as((v, t, t2) => _TagCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class TagCopyWith<$R, $In extends Tag, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? id, String? name});
  TagCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _TagCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, Tag, $Out>
    implements TagCopyWith<$R, Tag, $Out> {
  _TagCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Tag> $mapper = TagMapper.ensureInitialized();
  @override
  $R call({String? id, Object? name = $none}) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (name != $none) #name: name,
    }),
  );
  @override
  Tag $make(CopyWithData data) => Tag(
    id: data.get(#id, or: $value.id),
    name: data.get(#name, or: $value.name),
  );

  @override
  TagCopyWith<$R2, Tag, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _TagCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ThreadMetadataMapper extends ClassMapperBase<ThreadMetadata> {
  ThreadMetadataMapper._();

  static ThreadMetadataMapper? _instance;
  static ThreadMetadataMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ThreadMetadataMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'ThreadMetadata';

  static bool? _$archived(ThreadMetadata v) => v.archived;
  static const Field<ThreadMetadata, bool> _f$archived = Field(
    'archived',
    _$archived,
    opt: true,
  );
  static DateTime? _$archiveTimestamp(ThreadMetadata v) => v.archiveTimestamp;
  static const Field<ThreadMetadata, DateTime> _f$archiveTimestamp = Field(
    'archiveTimestamp',
    _$archiveTimestamp,
    key: r'archive_timestamp',
    opt: true,
  );
  static bool? _$locked(ThreadMetadata v) => v.locked;
  static const Field<ThreadMetadata, bool> _f$locked = Field(
    'locked',
    _$locked,
    opt: true,
  );

  @override
  final MappableFields<ThreadMetadata> fields = const {
    #archived: _f$archived,
    #archiveTimestamp: _f$archiveTimestamp,
    #locked: _f$locked,
  };

  static ThreadMetadata _instantiate(DecodingData data) {
    return ThreadMetadata(
      archived: data.dec(_f$archived),
      archiveTimestamp: data.dec(_f$archiveTimestamp),
      locked: data.dec(_f$locked),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ThreadMetadata fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ThreadMetadata>(map);
  }

  static ThreadMetadata fromJson(String json) {
    return ensureInitialized().decodeJson<ThreadMetadata>(json);
  }
}

mixin ThreadMetadataMappable {
  String toJson() {
    return ThreadMetadataMapper.ensureInitialized().encodeJson<ThreadMetadata>(
      this as ThreadMetadata,
    );
  }

  Map<String, dynamic> toMap() {
    return ThreadMetadataMapper.ensureInitialized().encodeMap<ThreadMetadata>(
      this as ThreadMetadata,
    );
  }

  ThreadMetadataCopyWith<ThreadMetadata, ThreadMetadata, ThreadMetadata>
  get copyWith => _ThreadMetadataCopyWithImpl<ThreadMetadata, ThreadMetadata>(
    this as ThreadMetadata,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return ThreadMetadataMapper.ensureInitialized().stringifyValue(
      this as ThreadMetadata,
    );
  }

  @override
  bool operator ==(Object other) {
    return ThreadMetadataMapper.ensureInitialized().equalsValue(
      this as ThreadMetadata,
      other,
    );
  }

  @override
  int get hashCode {
    return ThreadMetadataMapper.ensureInitialized().hashValue(
      this as ThreadMetadata,
    );
  }
}

extension ThreadMetadataValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ThreadMetadata, $Out> {
  ThreadMetadataCopyWith<$R, ThreadMetadata, $Out> get $asThreadMetadata =>
      $base.as((v, t, t2) => _ThreadMetadataCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ThreadMetadataCopyWith<$R, $In extends ThreadMetadata, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({bool? archived, DateTime? archiveTimestamp, bool? locked});
  ThreadMetadataCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ThreadMetadataCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ThreadMetadata, $Out>
    implements ThreadMetadataCopyWith<$R, ThreadMetadata, $Out> {
  _ThreadMetadataCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ThreadMetadata> $mapper =
      ThreadMetadataMapper.ensureInitialized();
  @override
  $R call({
    Object? archived = $none,
    Object? archiveTimestamp = $none,
    Object? locked = $none,
  }) => $apply(
    FieldCopyWithData({
      if (archived != $none) #archived: archived,
      if (archiveTimestamp != $none) #archiveTimestamp: archiveTimestamp,
      if (locked != $none) #locked: locked,
    }),
  );
  @override
  ThreadMetadata $make(CopyWithData data) => ThreadMetadata(
    archived: data.get(#archived, or: $value.archived),
    archiveTimestamp: data.get(#archiveTimestamp, or: $value.archiveTimestamp),
    locked: data.get(#locked, or: $value.locked),
  );

  @override
  ThreadMetadataCopyWith<$R2, ThreadMetadata, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ThreadMetadataCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ThreadsMapper extends ClassMapperBase<Threads> {
  ThreadsMapper._();

  static ThreadsMapper? _instance;
  static ThreadsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ThreadsMapper._());
      ChannelMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'Threads';

  static List<Channel> _$threads(Threads v) => v.threads;
  static const Field<Threads, List<Channel>> _f$threads = Field(
    'threads',
    _$threads,
  );
  static bool? _$hasMore(Threads v) => v.hasMore;
  static const Field<Threads, bool> _f$hasMore = Field(
    'hasMore',
    _$hasMore,
    key: r'has_more',
    opt: true,
  );

  @override
  final MappableFields<Threads> fields = const {
    #threads: _f$threads,
    #hasMore: _f$hasMore,
  };

  static Threads _instantiate(DecodingData data) {
    return Threads(
      threads: data.dec(_f$threads),
      hasMore: data.dec(_f$hasMore),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Threads fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Threads>(map);
  }

  static Threads fromJson(String json) {
    return ensureInitialized().decodeJson<Threads>(json);
  }
}

mixin ThreadsMappable {
  String toJson() {
    return ThreadsMapper.ensureInitialized().encodeJson<Threads>(
      this as Threads,
    );
  }

  Map<String, dynamic> toMap() {
    return ThreadsMapper.ensureInitialized().encodeMap<Threads>(
      this as Threads,
    );
  }

  ThreadsCopyWith<Threads, Threads, Threads> get copyWith =>
      _ThreadsCopyWithImpl<Threads, Threads>(
        this as Threads,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ThreadsMapper.ensureInitialized().stringifyValue(this as Threads);
  }

  @override
  bool operator ==(Object other) {
    return ThreadsMapper.ensureInitialized().equalsValue(
      this as Threads,
      other,
    );
  }

  @override
  int get hashCode {
    return ThreadsMapper.ensureInitialized().hashValue(this as Threads);
  }
}

extension ThreadsValueCopy<$R, $Out> on ObjectCopyWith<$R, Threads, $Out> {
  ThreadsCopyWith<$R, Threads, $Out> get $asThreads =>
      $base.as((v, t, t2) => _ThreadsCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ThreadsCopyWith<$R, $In extends Threads, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, Channel, ChannelCopyWith<$R, Channel, Channel>> get threads;
  $R call({List<Channel>? threads, bool? hasMore});
  ThreadsCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ThreadsCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, Threads, $Out>
    implements ThreadsCopyWith<$R, Threads, $Out> {
  _ThreadsCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Threads> $mapper =
      ThreadsMapper.ensureInitialized();
  @override
  ListCopyWith<$R, Channel, ChannelCopyWith<$R, Channel, Channel>>
  get threads => ListCopyWith(
    $value.threads,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(threads: v),
  );
  @override
  $R call({List<Channel>? threads, Object? hasMore = $none}) => $apply(
    FieldCopyWithData({
      if (threads != null) #threads: threads,
      if (hasMore != $none) #hasMore: hasMore,
    }),
  );
  @override
  Threads $make(CopyWithData data) => Threads(
    threads: data.get(#threads, or: $value.threads),
    hasMore: data.get(#hasMore, or: $value.hasMore),
  );

  @override
  ThreadsCopyWith<$R2, Threads, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ThreadsCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class MessageMapper extends ClassMapperBase<Message> {
  MessageMapper._();

  static MessageMapper? _instance;
  static MessageMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = MessageMapper._());
      UserMapper.ensureInitialized();
      AttachmentMapper.ensureInitialized();
      EmbedMapper.ensureInitialized();
      ReactionMapper.ensureInitialized();
      ChannelMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'Message';

  static String _$id(Message v) => v.id;
  static const Field<Message, String> _f$id = Field('id', _$id);
  static User? _$author(Message v) => v.author;
  static const Field<Message, User> _f$author = Field(
    'author',
    _$author,
    opt: true,
  );
  static String? _$content(Message v) => v.content;
  static const Field<Message, String> _f$content = Field(
    'content',
    _$content,
    opt: true,
  );
  static DateTime? _$timestamp(Message v) => v.timestamp;
  static const Field<Message, DateTime> _f$timestamp = Field(
    'timestamp',
    _$timestamp,
    opt: true,
  );
  static DateTime? _$editedTimestamp(Message v) => v.editedTimestamp;
  static const Field<Message, DateTime> _f$editedTimestamp = Field(
    'editedTimestamp',
    _$editedTimestamp,
    key: r'edited_timestamp',
    opt: true,
  );
  static List<Attachment>? _$attachments(Message v) => v.attachments;
  static const Field<Message, List<Attachment>> _f$attachments = Field(
    'attachments',
    _$attachments,
    opt: true,
  );
  static List<Embed>? _$embeds(Message v) => v.embeds;
  static const Field<Message, List<Embed>> _f$embeds = Field(
    'embeds',
    _$embeds,
    opt: true,
  );
  static List<Reaction>? _$reactions(Message v) => v.reactions;
  static const Field<Message, List<Reaction>> _f$reactions = Field(
    'reactions',
    _$reactions,
    opt: true,
  );
  static Channel? _$parentThread(Message v) => v.parentThread;
  static const Field<Message, Channel> _f$parentThread = Field(
    'parentThread',
    _$parentThread,
    key: r'parent_thread',
    opt: true,
  );

  @override
  final MappableFields<Message> fields = const {
    #id: _f$id,
    #author: _f$author,
    #content: _f$content,
    #timestamp: _f$timestamp,
    #editedTimestamp: _f$editedTimestamp,
    #attachments: _f$attachments,
    #embeds: _f$embeds,
    #reactions: _f$reactions,
    #parentThread: _f$parentThread,
  };

  static Message _instantiate(DecodingData data) {
    return Message(
      id: data.dec(_f$id),
      author: data.dec(_f$author),
      content: data.dec(_f$content),
      timestamp: data.dec(_f$timestamp),
      editedTimestamp: data.dec(_f$editedTimestamp),
      attachments: data.dec(_f$attachments),
      embeds: data.dec(_f$embeds),
      reactions: data.dec(_f$reactions),
      parentThread: data.dec(_f$parentThread),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Message fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Message>(map);
  }

  static Message fromJson(String json) {
    return ensureInitialized().decodeJson<Message>(json);
  }
}

mixin MessageMappable {
  String toJson() {
    return MessageMapper.ensureInitialized().encodeJson<Message>(
      this as Message,
    );
  }

  Map<String, dynamic> toMap() {
    return MessageMapper.ensureInitialized().encodeMap<Message>(
      this as Message,
    );
  }

  MessageCopyWith<Message, Message, Message> get copyWith =>
      _MessageCopyWithImpl<Message, Message>(
        this as Message,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return MessageMapper.ensureInitialized().stringifyValue(this as Message);
  }

  @override
  bool operator ==(Object other) {
    return MessageMapper.ensureInitialized().equalsValue(
      this as Message,
      other,
    );
  }

  @override
  int get hashCode {
    return MessageMapper.ensureInitialized().hashValue(this as Message);
  }
}

extension MessageValueCopy<$R, $Out> on ObjectCopyWith<$R, Message, $Out> {
  MessageCopyWith<$R, Message, $Out> get $asMessage =>
      $base.as((v, t, t2) => _MessageCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class MessageCopyWith<$R, $In extends Message, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  UserCopyWith<$R, User, User>? get author;
  ListCopyWith<$R, Attachment, AttachmentCopyWith<$R, Attachment, Attachment>>?
  get attachments;
  ListCopyWith<$R, Embed, EmbedCopyWith<$R, Embed, Embed>>? get embeds;
  ListCopyWith<$R, Reaction, ReactionCopyWith<$R, Reaction, Reaction>>?
  get reactions;
  ChannelCopyWith<$R, Channel, Channel>? get parentThread;
  $R call({
    String? id,
    User? author,
    String? content,
    DateTime? timestamp,
    DateTime? editedTimestamp,
    List<Attachment>? attachments,
    List<Embed>? embeds,
    List<Reaction>? reactions,
    Channel? parentThread,
  });
  MessageCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _MessageCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, Message, $Out>
    implements MessageCopyWith<$R, Message, $Out> {
  _MessageCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Message> $mapper =
      MessageMapper.ensureInitialized();
  @override
  UserCopyWith<$R, User, User>? get author =>
      $value.author?.copyWith.$chain((v) => call(author: v));
  @override
  ListCopyWith<$R, Attachment, AttachmentCopyWith<$R, Attachment, Attachment>>?
  get attachments => $value.attachments != null
      ? ListCopyWith(
          $value.attachments!,
          (v, t) => v.copyWith.$chain(t),
          (v) => call(attachments: v),
        )
      : null;
  @override
  ListCopyWith<$R, Embed, EmbedCopyWith<$R, Embed, Embed>>? get embeds =>
      $value.embeds != null
      ? ListCopyWith(
          $value.embeds!,
          (v, t) => v.copyWith.$chain(t),
          (v) => call(embeds: v),
        )
      : null;
  @override
  ListCopyWith<$R, Reaction, ReactionCopyWith<$R, Reaction, Reaction>>?
  get reactions => $value.reactions != null
      ? ListCopyWith(
          $value.reactions!,
          (v, t) => v.copyWith.$chain(t),
          (v) => call(reactions: v),
        )
      : null;
  @override
  ChannelCopyWith<$R, Channel, Channel>? get parentThread =>
      $value.parentThread?.copyWith.$chain((v) => call(parentThread: v));
  @override
  $R call({
    String? id,
    Object? author = $none,
    Object? content = $none,
    Object? timestamp = $none,
    Object? editedTimestamp = $none,
    Object? attachments = $none,
    Object? embeds = $none,
    Object? reactions = $none,
    Object? parentThread = $none,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (author != $none) #author: author,
      if (content != $none) #content: content,
      if (timestamp != $none) #timestamp: timestamp,
      if (editedTimestamp != $none) #editedTimestamp: editedTimestamp,
      if (attachments != $none) #attachments: attachments,
      if (embeds != $none) #embeds: embeds,
      if (reactions != $none) #reactions: reactions,
      if (parentThread != $none) #parentThread: parentThread,
    }),
  );
  @override
  Message $make(CopyWithData data) => Message(
    id: data.get(#id, or: $value.id),
    author: data.get(#author, or: $value.author),
    content: data.get(#content, or: $value.content),
    timestamp: data.get(#timestamp, or: $value.timestamp),
    editedTimestamp: data.get(#editedTimestamp, or: $value.editedTimestamp),
    attachments: data.get(#attachments, or: $value.attachments),
    embeds: data.get(#embeds, or: $value.embeds),
    reactions: data.get(#reactions, or: $value.reactions),
    parentThread: data.get(#parentThread, or: $value.parentThread),
  );

  @override
  MessageCopyWith<$R2, Message, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _MessageCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class UserMapper extends ClassMapperBase<User> {
  UserMapper._();

  static UserMapper? _instance;
  static UserMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = UserMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'User';

  static String _$id(User v) => v.id;
  static const Field<User, String> _f$id = Field('id', _$id);
  static String? _$username(User v) => v.username;
  static const Field<User, String> _f$username = Field(
    'username',
    _$username,
    opt: true,
  );
  static String? _$discriminator(User v) => v.discriminator;
  static const Field<User, String> _f$discriminator = Field(
    'discriminator',
    _$discriminator,
    opt: true,
  );

  @override
  final MappableFields<User> fields = const {
    #id: _f$id,
    #username: _f$username,
    #discriminator: _f$discriminator,
  };

  static User _instantiate(DecodingData data) {
    return User(
      id: data.dec(_f$id),
      username: data.dec(_f$username),
      discriminator: data.dec(_f$discriminator),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static User fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<User>(map);
  }

  static User fromJson(String json) {
    return ensureInitialized().decodeJson<User>(json);
  }
}

mixin UserMappable {
  String toJson() {
    return UserMapper.ensureInitialized().encodeJson<User>(this as User);
  }

  Map<String, dynamic> toMap() {
    return UserMapper.ensureInitialized().encodeMap<User>(this as User);
  }

  UserCopyWith<User, User, User> get copyWith =>
      _UserCopyWithImpl<User, User>(this as User, $identity, $identity);
  @override
  String toString() {
    return UserMapper.ensureInitialized().stringifyValue(this as User);
  }

  @override
  bool operator ==(Object other) {
    return UserMapper.ensureInitialized().equalsValue(this as User, other);
  }

  @override
  int get hashCode {
    return UserMapper.ensureInitialized().hashValue(this as User);
  }
}

extension UserValueCopy<$R, $Out> on ObjectCopyWith<$R, User, $Out> {
  UserCopyWith<$R, User, $Out> get $asUser =>
      $base.as((v, t, t2) => _UserCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class UserCopyWith<$R, $In extends User, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? id, String? username, String? discriminator});
  UserCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _UserCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, User, $Out>
    implements UserCopyWith<$R, User, $Out> {
  _UserCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<User> $mapper = UserMapper.ensureInitialized();
  @override
  $R call({
    String? id,
    Object? username = $none,
    Object? discriminator = $none,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (username != $none) #username: username,
      if (discriminator != $none) #discriminator: discriminator,
    }),
  );
  @override
  User $make(CopyWithData data) => User(
    id: data.get(#id, or: $value.id),
    username: data.get(#username, or: $value.username),
    discriminator: data.get(#discriminator, or: $value.discriminator),
  );

  @override
  UserCopyWith<$R2, User, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _UserCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class AttachmentMapper extends ClassMapperBase<Attachment> {
  AttachmentMapper._();

  static AttachmentMapper? _instance;
  static AttachmentMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = AttachmentMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'Attachment';

  static String _$id(Attachment v) => v.id;
  static const Field<Attachment, String> _f$id = Field('id', _$id);
  static String? _$filename(Attachment v) => v.filename;
  static const Field<Attachment, String> _f$filename = Field(
    'filename',
    _$filename,
    opt: true,
  );
  static String? _$description(Attachment v) => v.description;
  static const Field<Attachment, String> _f$description = Field(
    'description',
    _$description,
    opt: true,
  );
  static String? _$contentType(Attachment v) => v.contentType;
  static const Field<Attachment, String> _f$contentType = Field(
    'contentType',
    _$contentType,
    key: r'content_type',
    opt: true,
  );
  static int? _$size(Attachment v) => v.size;
  static const Field<Attachment, int> _f$size = Field(
    'size',
    _$size,
    opt: true,
  );
  static String? _$url(Attachment v) => v.url;
  static const Field<Attachment, String> _f$url = Field(
    'url',
    _$url,
    opt: true,
  );
  static String? _$proxyUrl(Attachment v) => v.proxyUrl;
  static const Field<Attachment, String> _f$proxyUrl = Field(
    'proxyUrl',
    _$proxyUrl,
    key: r'proxy_url',
    opt: true,
  );

  @override
  final MappableFields<Attachment> fields = const {
    #id: _f$id,
    #filename: _f$filename,
    #description: _f$description,
    #contentType: _f$contentType,
    #size: _f$size,
    #url: _f$url,
    #proxyUrl: _f$proxyUrl,
  };

  static Attachment _instantiate(DecodingData data) {
    return Attachment(
      id: data.dec(_f$id),
      filename: data.dec(_f$filename),
      description: data.dec(_f$description),
      contentType: data.dec(_f$contentType),
      size: data.dec(_f$size),
      url: data.dec(_f$url),
      proxyUrl: data.dec(_f$proxyUrl),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Attachment fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Attachment>(map);
  }

  static Attachment fromJson(String json) {
    return ensureInitialized().decodeJson<Attachment>(json);
  }
}

mixin AttachmentMappable {
  String toJson() {
    return AttachmentMapper.ensureInitialized().encodeJson<Attachment>(
      this as Attachment,
    );
  }

  Map<String, dynamic> toMap() {
    return AttachmentMapper.ensureInitialized().encodeMap<Attachment>(
      this as Attachment,
    );
  }

  AttachmentCopyWith<Attachment, Attachment, Attachment> get copyWith =>
      _AttachmentCopyWithImpl<Attachment, Attachment>(
        this as Attachment,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return AttachmentMapper.ensureInitialized().stringifyValue(
      this as Attachment,
    );
  }

  @override
  bool operator ==(Object other) {
    return AttachmentMapper.ensureInitialized().equalsValue(
      this as Attachment,
      other,
    );
  }

  @override
  int get hashCode {
    return AttachmentMapper.ensureInitialized().hashValue(this as Attachment);
  }
}

extension AttachmentValueCopy<$R, $Out>
    on ObjectCopyWith<$R, Attachment, $Out> {
  AttachmentCopyWith<$R, Attachment, $Out> get $asAttachment =>
      $base.as((v, t, t2) => _AttachmentCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class AttachmentCopyWith<$R, $In extends Attachment, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? id,
    String? filename,
    String? description,
    String? contentType,
    int? size,
    String? url,
    String? proxyUrl,
  });
  AttachmentCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _AttachmentCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, Attachment, $Out>
    implements AttachmentCopyWith<$R, Attachment, $Out> {
  _AttachmentCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Attachment> $mapper =
      AttachmentMapper.ensureInitialized();
  @override
  $R call({
    String? id,
    Object? filename = $none,
    Object? description = $none,
    Object? contentType = $none,
    Object? size = $none,
    Object? url = $none,
    Object? proxyUrl = $none,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (filename != $none) #filename: filename,
      if (description != $none) #description: description,
      if (contentType != $none) #contentType: contentType,
      if (size != $none) #size: size,
      if (url != $none) #url: url,
      if (proxyUrl != $none) #proxyUrl: proxyUrl,
    }),
  );
  @override
  Attachment $make(CopyWithData data) => Attachment(
    id: data.get(#id, or: $value.id),
    filename: data.get(#filename, or: $value.filename),
    description: data.get(#description, or: $value.description),
    contentType: data.get(#contentType, or: $value.contentType),
    size: data.get(#size, or: $value.size),
    url: data.get(#url, or: $value.url),
    proxyUrl: data.get(#proxyUrl, or: $value.proxyUrl),
  );

  @override
  AttachmentCopyWith<$R2, Attachment, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _AttachmentCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class EmbedMapper extends ClassMapperBase<Embed> {
  EmbedMapper._();

  static EmbedMapper? _instance;
  static EmbedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = EmbedMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'Embed';

  static String? _$title(Embed v) => v.title;
  static const Field<Embed, String> _f$title = Field(
    'title',
    _$title,
    opt: true,
  );
  static String? _$description(Embed v) => v.description;
  static const Field<Embed, String> _f$description = Field(
    'description',
    _$description,
    opt: true,
  );
  static String? _$url(Embed v) => v.url;
  static const Field<Embed, String> _f$url = Field('url', _$url, opt: true);

  @override
  final MappableFields<Embed> fields = const {
    #title: _f$title,
    #description: _f$description,
    #url: _f$url,
  };

  static Embed _instantiate(DecodingData data) {
    return Embed(
      title: data.dec(_f$title),
      description: data.dec(_f$description),
      url: data.dec(_f$url),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Embed fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Embed>(map);
  }

  static Embed fromJson(String json) {
    return ensureInitialized().decodeJson<Embed>(json);
  }
}

mixin EmbedMappable {
  String toJson() {
    return EmbedMapper.ensureInitialized().encodeJson<Embed>(this as Embed);
  }

  Map<String, dynamic> toMap() {
    return EmbedMapper.ensureInitialized().encodeMap<Embed>(this as Embed);
  }

  EmbedCopyWith<Embed, Embed, Embed> get copyWith =>
      _EmbedCopyWithImpl<Embed, Embed>(this as Embed, $identity, $identity);
  @override
  String toString() {
    return EmbedMapper.ensureInitialized().stringifyValue(this as Embed);
  }

  @override
  bool operator ==(Object other) {
    return EmbedMapper.ensureInitialized().equalsValue(this as Embed, other);
  }

  @override
  int get hashCode {
    return EmbedMapper.ensureInitialized().hashValue(this as Embed);
  }
}

extension EmbedValueCopy<$R, $Out> on ObjectCopyWith<$R, Embed, $Out> {
  EmbedCopyWith<$R, Embed, $Out> get $asEmbed =>
      $base.as((v, t, t2) => _EmbedCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class EmbedCopyWith<$R, $In extends Embed, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? title, String? description, String? url});
  EmbedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _EmbedCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, Embed, $Out>
    implements EmbedCopyWith<$R, Embed, $Out> {
  _EmbedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Embed> $mapper = EmbedMapper.ensureInitialized();
  @override
  $R call({
    Object? title = $none,
    Object? description = $none,
    Object? url = $none,
  }) => $apply(
    FieldCopyWithData({
      if (title != $none) #title: title,
      if (description != $none) #description: description,
      if (url != $none) #url: url,
    }),
  );
  @override
  Embed $make(CopyWithData data) => Embed(
    title: data.get(#title, or: $value.title),
    description: data.get(#description, or: $value.description),
    url: data.get(#url, or: $value.url),
  );

  @override
  EmbedCopyWith<$R2, Embed, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _EmbedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ReactionMapper extends ClassMapperBase<Reaction> {
  ReactionMapper._();

  static ReactionMapper? _instance;
  static ReactionMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ReactionMapper._());
      EmojiMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'Reaction';

  static int _$count(Reaction v) => v.count;
  static const Field<Reaction, int> _f$count = Field('count', _$count);
  static Emoji _$emoji(Reaction v) => v.emoji;
  static const Field<Reaction, Emoji> _f$emoji = Field('emoji', _$emoji);

  @override
  final MappableFields<Reaction> fields = const {
    #count: _f$count,
    #emoji: _f$emoji,
  };

  static Reaction _instantiate(DecodingData data) {
    return Reaction(count: data.dec(_f$count), emoji: data.dec(_f$emoji));
  }

  @override
  final Function instantiate = _instantiate;

  static Reaction fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Reaction>(map);
  }

  static Reaction fromJson(String json) {
    return ensureInitialized().decodeJson<Reaction>(json);
  }
}

mixin ReactionMappable {
  String toJson() {
    return ReactionMapper.ensureInitialized().encodeJson<Reaction>(
      this as Reaction,
    );
  }

  Map<String, dynamic> toMap() {
    return ReactionMapper.ensureInitialized().encodeMap<Reaction>(
      this as Reaction,
    );
  }

  ReactionCopyWith<Reaction, Reaction, Reaction> get copyWith =>
      _ReactionCopyWithImpl<Reaction, Reaction>(
        this as Reaction,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ReactionMapper.ensureInitialized().stringifyValue(this as Reaction);
  }

  @override
  bool operator ==(Object other) {
    return ReactionMapper.ensureInitialized().equalsValue(
      this as Reaction,
      other,
    );
  }

  @override
  int get hashCode {
    return ReactionMapper.ensureInitialized().hashValue(this as Reaction);
  }
}

extension ReactionValueCopy<$R, $Out> on ObjectCopyWith<$R, Reaction, $Out> {
  ReactionCopyWith<$R, Reaction, $Out> get $asReaction =>
      $base.as((v, t, t2) => _ReactionCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ReactionCopyWith<$R, $In extends Reaction, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  EmojiCopyWith<$R, Emoji, Emoji> get emoji;
  $R call({int? count, Emoji? emoji});
  ReactionCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ReactionCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, Reaction, $Out>
    implements ReactionCopyWith<$R, Reaction, $Out> {
  _ReactionCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Reaction> $mapper =
      ReactionMapper.ensureInitialized();
  @override
  EmojiCopyWith<$R, Emoji, Emoji> get emoji =>
      $value.emoji.copyWith.$chain((v) => call(emoji: v));
  @override
  $R call({int? count, Emoji? emoji}) => $apply(
    FieldCopyWithData({
      if (count != null) #count: count,
      if (emoji != null) #emoji: emoji,
    }),
  );
  @override
  Reaction $make(CopyWithData data) => Reaction(
    count: data.get(#count, or: $value.count),
    emoji: data.get(#emoji, or: $value.emoji),
  );

  @override
  ReactionCopyWith<$R2, Reaction, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ReactionCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class EmojiMapper extends ClassMapperBase<Emoji> {
  EmojiMapper._();

  static EmojiMapper? _instance;
  static EmojiMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = EmojiMapper._());
      UserMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'Emoji';

  static String? _$id(Emoji v) => v.id;
  static const Field<Emoji, String> _f$id = Field('id', _$id, opt: true);
  static String? _$name(Emoji v) => v.name;
  static const Field<Emoji, String> _f$name = Field('name', _$name, opt: true);
  static User? _$user(Emoji v) => v.user;
  static const Field<Emoji, User> _f$user = Field('user', _$user, opt: true);

  @override
  final MappableFields<Emoji> fields = const {
    #id: _f$id,
    #name: _f$name,
    #user: _f$user,
  };

  static Emoji _instantiate(DecodingData data) {
    return Emoji(
      id: data.dec(_f$id),
      name: data.dec(_f$name),
      user: data.dec(_f$user),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Emoji fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Emoji>(map);
  }

  static Emoji fromJson(String json) {
    return ensureInitialized().decodeJson<Emoji>(json);
  }
}

mixin EmojiMappable {
  String toJson() {
    return EmojiMapper.ensureInitialized().encodeJson<Emoji>(this as Emoji);
  }

  Map<String, dynamic> toMap() {
    return EmojiMapper.ensureInitialized().encodeMap<Emoji>(this as Emoji);
  }

  EmojiCopyWith<Emoji, Emoji, Emoji> get copyWith =>
      _EmojiCopyWithImpl<Emoji, Emoji>(this as Emoji, $identity, $identity);
  @override
  String toString() {
    return EmojiMapper.ensureInitialized().stringifyValue(this as Emoji);
  }

  @override
  bool operator ==(Object other) {
    return EmojiMapper.ensureInitialized().equalsValue(this as Emoji, other);
  }

  @override
  int get hashCode {
    return EmojiMapper.ensureInitialized().hashValue(this as Emoji);
  }
}

extension EmojiValueCopy<$R, $Out> on ObjectCopyWith<$R, Emoji, $Out> {
  EmojiCopyWith<$R, Emoji, $Out> get $asEmoji =>
      $base.as((v, t, t2) => _EmojiCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class EmojiCopyWith<$R, $In extends Emoji, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  UserCopyWith<$R, User, User>? get user;
  $R call({String? id, String? name, User? user});
  EmojiCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _EmojiCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, Emoji, $Out>
    implements EmojiCopyWith<$R, Emoji, $Out> {
  _EmojiCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Emoji> $mapper = EmojiMapper.ensureInitialized();
  @override
  UserCopyWith<$R, User, User>? get user =>
      $value.user?.copyWith.$chain((v) => call(user: v));
  @override
  $R call({Object? id = $none, Object? name = $none, Object? user = $none}) =>
      $apply(
        FieldCopyWithData({
          if (id != $none) #id: id,
          if (name != $none) #name: name,
          if (user != $none) #user: user,
        }),
      );
  @override
  Emoji $make(CopyWithData data) => Emoji(
    id: data.get(#id, or: $value.id),
    name: data.get(#name, or: $value.name),
    user: data.get(#user, or: $value.user),
  );

  @override
  EmojiCopyWith<$R2, Emoji, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _EmojiCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

