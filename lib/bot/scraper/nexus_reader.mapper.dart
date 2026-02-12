// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'nexus_reader.dart';

class GameInfoMapper extends ClassMapperBase<GameInfo> {
  GameInfoMapper._();

  static GameInfoMapper? _instance;
  static GameInfoMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = GameInfoMapper._());
      CategoryMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'GameInfo';

  static int? _$id(GameInfo v) => v.id;
  static const Field<GameInfo, int> _f$id = Field('id', _$id, opt: true);
  static String? _$name(GameInfo v) => v.name;
  static const Field<GameInfo, String> _f$name = Field(
    'name',
    _$name,
    opt: true,
  );
  static String? _$forumUrl(GameInfo v) => v.forumUrl;
  static const Field<GameInfo, String> _f$forumUrl = Field(
    'forumUrl',
    _$forumUrl,
    key: r'forum_url',
    opt: true,
  );
  static String? _$nexusmodsUrl(GameInfo v) => v.nexusmodsUrl;
  static const Field<GameInfo, String> _f$nexusmodsUrl = Field(
    'nexusmodsUrl',
    _$nexusmodsUrl,
    key: r'nexusmods_url',
    opt: true,
  );
  static String? _$genre(GameInfo v) => v.genre;
  static const Field<GameInfo, String> _f$genre = Field(
    'genre',
    _$genre,
    opt: true,
  );
  static int? _$fileCount(GameInfo v) => v.fileCount;
  static const Field<GameInfo, int> _f$fileCount = Field(
    'fileCount',
    _$fileCount,
    key: r'file_count',
    opt: true,
  );
  static int? _$downloads(GameInfo v) => v.downloads;
  static const Field<GameInfo, int> _f$downloads = Field(
    'downloads',
    _$downloads,
    opt: true,
  );
  static String? _$domainName(GameInfo v) => v.domainName;
  static const Field<GameInfo, String> _f$domainName = Field(
    'domainName',
    _$domainName,
    key: r'domain_name',
    opt: true,
  );
  static int? _$approvedDate(GameInfo v) => v.approvedDate;
  static const Field<GameInfo, int> _f$approvedDate = Field(
    'approvedDate',
    _$approvedDate,
    key: r'approved_date',
    opt: true,
  );
  static int? _$fileViews(GameInfo v) => v.fileViews;
  static const Field<GameInfo, int> _f$fileViews = Field(
    'fileViews',
    _$fileViews,
    key: r'file_views',
    opt: true,
  );
  static int? _$authors(GameInfo v) => v.authors;
  static const Field<GameInfo, int> _f$authors = Field(
    'authors',
    _$authors,
    opt: true,
  );
  static int? _$fileEndorsements(GameInfo v) => v.fileEndorsements;
  static const Field<GameInfo, int> _f$fileEndorsements = Field(
    'fileEndorsements',
    _$fileEndorsements,
    key: r'file_endorsements',
    opt: true,
  );
  static int? _$mods(GameInfo v) => v.mods;
  static const Field<GameInfo, int> _f$mods = Field('mods', _$mods, opt: true);
  static List<Category> _$categories(GameInfo v) => v.categories;
  static const Field<GameInfo, List<Category>> _f$categories = Field(
    'categories',
    _$categories,
  );

  @override
  final MappableFields<GameInfo> fields = const {
    #id: _f$id,
    #name: _f$name,
    #forumUrl: _f$forumUrl,
    #nexusmodsUrl: _f$nexusmodsUrl,
    #genre: _f$genre,
    #fileCount: _f$fileCount,
    #downloads: _f$downloads,
    #domainName: _f$domainName,
    #approvedDate: _f$approvedDate,
    #fileViews: _f$fileViews,
    #authors: _f$authors,
    #fileEndorsements: _f$fileEndorsements,
    #mods: _f$mods,
    #categories: _f$categories,
  };

  static GameInfo _instantiate(DecodingData data) {
    return GameInfo(
      id: data.dec(_f$id),
      name: data.dec(_f$name),
      forumUrl: data.dec(_f$forumUrl),
      nexusmodsUrl: data.dec(_f$nexusmodsUrl),
      genre: data.dec(_f$genre),
      fileCount: data.dec(_f$fileCount),
      downloads: data.dec(_f$downloads),
      domainName: data.dec(_f$domainName),
      approvedDate: data.dec(_f$approvedDate),
      fileViews: data.dec(_f$fileViews),
      authors: data.dec(_f$authors),
      fileEndorsements: data.dec(_f$fileEndorsements),
      mods: data.dec(_f$mods),
      categories: data.dec(_f$categories),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static GameInfo fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<GameInfo>(map);
  }

  static GameInfo fromJson(String json) {
    return ensureInitialized().decodeJson<GameInfo>(json);
  }
}

mixin GameInfoMappable {
  String toJson() {
    return GameInfoMapper.ensureInitialized().encodeJson<GameInfo>(
      this as GameInfo,
    );
  }

  Map<String, dynamic> toMap() {
    return GameInfoMapper.ensureInitialized().encodeMap<GameInfo>(
      this as GameInfo,
    );
  }

  GameInfoCopyWith<GameInfo, GameInfo, GameInfo> get copyWith =>
      _GameInfoCopyWithImpl<GameInfo, GameInfo>(
        this as GameInfo,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return GameInfoMapper.ensureInitialized().stringifyValue(this as GameInfo);
  }

  @override
  bool operator ==(Object other) {
    return GameInfoMapper.ensureInitialized().equalsValue(
      this as GameInfo,
      other,
    );
  }

  @override
  int get hashCode {
    return GameInfoMapper.ensureInitialized().hashValue(this as GameInfo);
  }
}

extension GameInfoValueCopy<$R, $Out> on ObjectCopyWith<$R, GameInfo, $Out> {
  GameInfoCopyWith<$R, GameInfo, $Out> get $asGameInfo =>
      $base.as((v, t, t2) => _GameInfoCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class GameInfoCopyWith<$R, $In extends GameInfo, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, Category, CategoryCopyWith<$R, Category, Category>>
  get categories;
  $R call({
    int? id,
    String? name,
    String? forumUrl,
    String? nexusmodsUrl,
    String? genre,
    int? fileCount,
    int? downloads,
    String? domainName,
    int? approvedDate,
    int? fileViews,
    int? authors,
    int? fileEndorsements,
    int? mods,
    List<Category>? categories,
  });
  GameInfoCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _GameInfoCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, GameInfo, $Out>
    implements GameInfoCopyWith<$R, GameInfo, $Out> {
  _GameInfoCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<GameInfo> $mapper =
      GameInfoMapper.ensureInitialized();
  @override
  ListCopyWith<$R, Category, CategoryCopyWith<$R, Category, Category>>
  get categories => ListCopyWith(
    $value.categories,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(categories: v),
  );
  @override
  $R call({
    Object? id = $none,
    Object? name = $none,
    Object? forumUrl = $none,
    Object? nexusmodsUrl = $none,
    Object? genre = $none,
    Object? fileCount = $none,
    Object? downloads = $none,
    Object? domainName = $none,
    Object? approvedDate = $none,
    Object? fileViews = $none,
    Object? authors = $none,
    Object? fileEndorsements = $none,
    Object? mods = $none,
    List<Category>? categories,
  }) => $apply(
    FieldCopyWithData({
      if (id != $none) #id: id,
      if (name != $none) #name: name,
      if (forumUrl != $none) #forumUrl: forumUrl,
      if (nexusmodsUrl != $none) #nexusmodsUrl: nexusmodsUrl,
      if (genre != $none) #genre: genre,
      if (fileCount != $none) #fileCount: fileCount,
      if (downloads != $none) #downloads: downloads,
      if (domainName != $none) #domainName: domainName,
      if (approvedDate != $none) #approvedDate: approvedDate,
      if (fileViews != $none) #fileViews: fileViews,
      if (authors != $none) #authors: authors,
      if (fileEndorsements != $none) #fileEndorsements: fileEndorsements,
      if (mods != $none) #mods: mods,
      if (categories != null) #categories: categories,
    }),
  );
  @override
  GameInfo $make(CopyWithData data) => GameInfo(
    id: data.get(#id, or: $value.id),
    name: data.get(#name, or: $value.name),
    forumUrl: data.get(#forumUrl, or: $value.forumUrl),
    nexusmodsUrl: data.get(#nexusmodsUrl, or: $value.nexusmodsUrl),
    genre: data.get(#genre, or: $value.genre),
    fileCount: data.get(#fileCount, or: $value.fileCount),
    downloads: data.get(#downloads, or: $value.downloads),
    domainName: data.get(#domainName, or: $value.domainName),
    approvedDate: data.get(#approvedDate, or: $value.approvedDate),
    fileViews: data.get(#fileViews, or: $value.fileViews),
    authors: data.get(#authors, or: $value.authors),
    fileEndorsements: data.get(#fileEndorsements, or: $value.fileEndorsements),
    mods: data.get(#mods, or: $value.mods),
    categories: data.get(#categories, or: $value.categories),
  );

  @override
  GameInfoCopyWith<$R2, GameInfo, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _GameInfoCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class CategoryMapper extends ClassMapperBase<Category> {
  CategoryMapper._();

  static CategoryMapper? _instance;
  static CategoryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CategoryMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'Category';

  static String? _$categoryId(Category v) => v.categoryId;
  static const Field<Category, String> _f$categoryId = Field(
    'categoryId',
    _$categoryId,
    key: r'category_id',
    opt: true,
  );
  static String? _$name(Category v) => v.name;
  static const Field<Category, String> _f$name = Field(
    'name',
    _$name,
    opt: true,
  );
  static String? _$parentCategory(Category v) => v.parentCategory;
  static const Field<Category, String> _f$parentCategory = Field(
    'parentCategory',
    _$parentCategory,
    key: r'parent_category',
    opt: true,
  );

  @override
  final MappableFields<Category> fields = const {
    #categoryId: _f$categoryId,
    #name: _f$name,
    #parentCategory: _f$parentCategory,
  };

  static Category _instantiate(DecodingData data) {
    return Category(
      categoryId: data.dec(_f$categoryId),
      name: data.dec(_f$name),
      parentCategory: data.dec(_f$parentCategory),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Category fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Category>(map);
  }

  static Category fromJson(String json) {
    return ensureInitialized().decodeJson<Category>(json);
  }
}

mixin CategoryMappable {
  String toJson() {
    return CategoryMapper.ensureInitialized().encodeJson<Category>(
      this as Category,
    );
  }

  Map<String, dynamic> toMap() {
    return CategoryMapper.ensureInitialized().encodeMap<Category>(
      this as Category,
    );
  }

  CategoryCopyWith<Category, Category, Category> get copyWith =>
      _CategoryCopyWithImpl<Category, Category>(
        this as Category,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return CategoryMapper.ensureInitialized().stringifyValue(this as Category);
  }

  @override
  bool operator ==(Object other) {
    return CategoryMapper.ensureInitialized().equalsValue(
      this as Category,
      other,
    );
  }

  @override
  int get hashCode {
    return CategoryMapper.ensureInitialized().hashValue(this as Category);
  }
}

extension CategoryValueCopy<$R, $Out> on ObjectCopyWith<$R, Category, $Out> {
  CategoryCopyWith<$R, Category, $Out> get $asCategory =>
      $base.as((v, t, t2) => _CategoryCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class CategoryCopyWith<$R, $In extends Category, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? categoryId, String? name, String? parentCategory});
  CategoryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _CategoryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, Category, $Out>
    implements CategoryCopyWith<$R, Category, $Out> {
  _CategoryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Category> $mapper =
      CategoryMapper.ensureInitialized();
  @override
  $R call({
    Object? categoryId = $none,
    Object? name = $none,
    Object? parentCategory = $none,
  }) => $apply(
    FieldCopyWithData({
      if (categoryId != $none) #categoryId: categoryId,
      if (name != $none) #name: name,
      if (parentCategory != $none) #parentCategory: parentCategory,
    }),
  );
  @override
  Category $make(CopyWithData data) => Category(
    categoryId: data.get(#categoryId, or: $value.categoryId),
    name: data.get(#name, or: $value.name),
    parentCategory: data.get(#parentCategory, or: $value.parentCategory),
  );

  @override
  CategoryCopyWith<$R2, Category, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _CategoryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class NexusModMapper extends ClassMapperBase<NexusMod> {
  NexusModMapper._();

  static NexusModMapper? _instance;
  static NexusModMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = NexusModMapper._());
      UserMapper.ensureInitialized();
      EndorsementMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'NexusMod';

  static String? _$name(NexusMod v) => v.name;
  static const Field<NexusMod, String> _f$name = Field(
    'name',
    _$name,
    opt: true,
  );
  static String? _$summary(NexusMod v) => v.summary;
  static const Field<NexusMod, String> _f$summary = Field(
    'summary',
    _$summary,
    opt: true,
  );
  static String? _$description(NexusMod v) => v.description;
  static const Field<NexusMod, String> _f$description = Field(
    'description',
    _$description,
    opt: true,
  );
  static String? _$pictureUrl(NexusMod v) => v.pictureUrl;
  static const Field<NexusMod, String> _f$pictureUrl = Field(
    'pictureUrl',
    _$pictureUrl,
    key: r'picture_url',
    opt: true,
  );
  static int? _$modId(NexusMod v) => v.modId;
  static const Field<NexusMod, int> _f$modId = Field(
    'modId',
    _$modId,
    key: r'mod_id',
    opt: true,
  );
  static bool? _$allowRating(NexusMod v) => v.allowRating;
  static const Field<NexusMod, bool> _f$allowRating = Field(
    'allowRating',
    _$allowRating,
    key: r'allow_rating',
    opt: true,
  );
  static String? _$domainName(NexusMod v) => v.domainName;
  static const Field<NexusMod, String> _f$domainName = Field(
    'domainName',
    _$domainName,
    key: r'domain_name',
    opt: true,
  );
  static int? _$categoryId(NexusMod v) => v.categoryId;
  static const Field<NexusMod, int> _f$categoryId = Field(
    'categoryId',
    _$categoryId,
    key: r'category_id',
    opt: true,
  );
  static String? _$version(NexusMod v) => v.version;
  static const Field<NexusMod, String> _f$version = Field(
    'version',
    _$version,
    opt: true,
  );
  static int? _$endorsementCount(NexusMod v) => v.endorsementCount;
  static const Field<NexusMod, int> _f$endorsementCount = Field(
    'endorsementCount',
    _$endorsementCount,
    key: r'endorsement_count',
    opt: true,
  );
  static int? _$createdTimestamp(NexusMod v) => v.createdTimestamp;
  static const Field<NexusMod, int> _f$createdTimestamp = Field(
    'createdTimestamp',
    _$createdTimestamp,
    key: r'created_timestamp',
    opt: true,
  );
  static String? _$createdTime(NexusMod v) => v.createdTime;
  static const Field<NexusMod, String> _f$createdTime = Field(
    'createdTime',
    _$createdTime,
    key: r'created_time',
    opt: true,
  );
  static int? _$updatedTimestamp(NexusMod v) => v.updatedTimestamp;
  static const Field<NexusMod, int> _f$updatedTimestamp = Field(
    'updatedTimestamp',
    _$updatedTimestamp,
    key: r'updated_timestamp',
    opt: true,
  );
  static String? _$updatedTime(NexusMod v) => v.updatedTime;
  static const Field<NexusMod, String> _f$updatedTime = Field(
    'updatedTime',
    _$updatedTime,
    key: r'updated_time',
    opt: true,
  );
  static String? _$author(NexusMod v) => v.author;
  static const Field<NexusMod, String> _f$author = Field(
    'author',
    _$author,
    opt: true,
  );
  static String? _$uploadedBy(NexusMod v) => v.uploadedBy;
  static const Field<NexusMod, String> _f$uploadedBy = Field(
    'uploadedBy',
    _$uploadedBy,
    key: r'uploaded_by',
    opt: true,
  );
  static String? _$uploadedUsersProfileUrl(NexusMod v) =>
      v.uploadedUsersProfileUrl;
  static const Field<NexusMod, String> _f$uploadedUsersProfileUrl = Field(
    'uploadedUsersProfileUrl',
    _$uploadedUsersProfileUrl,
    key: r'uploaded_users_profile_url',
    opt: true,
  );
  static bool? _$containsAdultContent(NexusMod v) => v.containsAdultContent;
  static const Field<NexusMod, bool> _f$containsAdultContent = Field(
    'containsAdultContent',
    _$containsAdultContent,
    key: r'contains_adult_content',
    opt: true,
  );
  static String? _$status(NexusMod v) => v.status;
  static const Field<NexusMod, String> _f$status = Field(
    'status',
    _$status,
    opt: true,
  );
  static bool? _$available(NexusMod v) => v.available;
  static const Field<NexusMod, bool> _f$available = Field(
    'available',
    _$available,
    opt: true,
  );
  static User? _$user(NexusMod v) => v.user;
  static const Field<NexusMod, User> _f$user = Field('user', _$user, opt: true);
  static Endorsement? _$endorsement(NexusMod v) => v.endorsement;
  static const Field<NexusMod, Endorsement> _f$endorsement = Field(
    'endorsement',
    _$endorsement,
    opt: true,
  );

  @override
  final MappableFields<NexusMod> fields = const {
    #name: _f$name,
    #summary: _f$summary,
    #description: _f$description,
    #pictureUrl: _f$pictureUrl,
    #modId: _f$modId,
    #allowRating: _f$allowRating,
    #domainName: _f$domainName,
    #categoryId: _f$categoryId,
    #version: _f$version,
    #endorsementCount: _f$endorsementCount,
    #createdTimestamp: _f$createdTimestamp,
    #createdTime: _f$createdTime,
    #updatedTimestamp: _f$updatedTimestamp,
    #updatedTime: _f$updatedTime,
    #author: _f$author,
    #uploadedBy: _f$uploadedBy,
    #uploadedUsersProfileUrl: _f$uploadedUsersProfileUrl,
    #containsAdultContent: _f$containsAdultContent,
    #status: _f$status,
    #available: _f$available,
    #user: _f$user,
    #endorsement: _f$endorsement,
  };

  static NexusMod _instantiate(DecodingData data) {
    return NexusMod(
      name: data.dec(_f$name),
      summary: data.dec(_f$summary),
      description: data.dec(_f$description),
      pictureUrl: data.dec(_f$pictureUrl),
      modId: data.dec(_f$modId),
      allowRating: data.dec(_f$allowRating),
      domainName: data.dec(_f$domainName),
      categoryId: data.dec(_f$categoryId),
      version: data.dec(_f$version),
      endorsementCount: data.dec(_f$endorsementCount),
      createdTimestamp: data.dec(_f$createdTimestamp),
      createdTime: data.dec(_f$createdTime),
      updatedTimestamp: data.dec(_f$updatedTimestamp),
      updatedTime: data.dec(_f$updatedTime),
      author: data.dec(_f$author),
      uploadedBy: data.dec(_f$uploadedBy),
      uploadedUsersProfileUrl: data.dec(_f$uploadedUsersProfileUrl),
      containsAdultContent: data.dec(_f$containsAdultContent),
      status: data.dec(_f$status),
      available: data.dec(_f$available),
      user: data.dec(_f$user),
      endorsement: data.dec(_f$endorsement),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static NexusMod fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<NexusMod>(map);
  }

  static NexusMod fromJson(String json) {
    return ensureInitialized().decodeJson<NexusMod>(json);
  }
}

mixin NexusModMappable {
  String toJson() {
    return NexusModMapper.ensureInitialized().encodeJson<NexusMod>(
      this as NexusMod,
    );
  }

  Map<String, dynamic> toMap() {
    return NexusModMapper.ensureInitialized().encodeMap<NexusMod>(
      this as NexusMod,
    );
  }

  NexusModCopyWith<NexusMod, NexusMod, NexusMod> get copyWith =>
      _NexusModCopyWithImpl<NexusMod, NexusMod>(
        this as NexusMod,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return NexusModMapper.ensureInitialized().stringifyValue(this as NexusMod);
  }

  @override
  bool operator ==(Object other) {
    return NexusModMapper.ensureInitialized().equalsValue(
      this as NexusMod,
      other,
    );
  }

  @override
  int get hashCode {
    return NexusModMapper.ensureInitialized().hashValue(this as NexusMod);
  }
}

extension NexusModValueCopy<$R, $Out> on ObjectCopyWith<$R, NexusMod, $Out> {
  NexusModCopyWith<$R, NexusMod, $Out> get $asNexusMod =>
      $base.as((v, t, t2) => _NexusModCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class NexusModCopyWith<$R, $In extends NexusMod, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  UserCopyWith<$R, User, User>? get user;
  EndorsementCopyWith<$R, Endorsement, Endorsement>? get endorsement;
  $R call({
    String? name,
    String? summary,
    String? description,
    String? pictureUrl,
    int? modId,
    bool? allowRating,
    String? domainName,
    int? categoryId,
    String? version,
    int? endorsementCount,
    int? createdTimestamp,
    String? createdTime,
    int? updatedTimestamp,
    String? updatedTime,
    String? author,
    String? uploadedBy,
    String? uploadedUsersProfileUrl,
    bool? containsAdultContent,
    String? status,
    bool? available,
    User? user,
    Endorsement? endorsement,
  });
  NexusModCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _NexusModCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, NexusMod, $Out>
    implements NexusModCopyWith<$R, NexusMod, $Out> {
  _NexusModCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<NexusMod> $mapper =
      NexusModMapper.ensureInitialized();
  @override
  UserCopyWith<$R, User, User>? get user =>
      $value.user?.copyWith.$chain((v) => call(user: v));
  @override
  EndorsementCopyWith<$R, Endorsement, Endorsement>? get endorsement =>
      $value.endorsement?.copyWith.$chain((v) => call(endorsement: v));
  @override
  $R call({
    Object? name = $none,
    Object? summary = $none,
    Object? description = $none,
    Object? pictureUrl = $none,
    Object? modId = $none,
    Object? allowRating = $none,
    Object? domainName = $none,
    Object? categoryId = $none,
    Object? version = $none,
    Object? endorsementCount = $none,
    Object? createdTimestamp = $none,
    Object? createdTime = $none,
    Object? updatedTimestamp = $none,
    Object? updatedTime = $none,
    Object? author = $none,
    Object? uploadedBy = $none,
    Object? uploadedUsersProfileUrl = $none,
    Object? containsAdultContent = $none,
    Object? status = $none,
    Object? available = $none,
    Object? user = $none,
    Object? endorsement = $none,
  }) => $apply(
    FieldCopyWithData({
      if (name != $none) #name: name,
      if (summary != $none) #summary: summary,
      if (description != $none) #description: description,
      if (pictureUrl != $none) #pictureUrl: pictureUrl,
      if (modId != $none) #modId: modId,
      if (allowRating != $none) #allowRating: allowRating,
      if (domainName != $none) #domainName: domainName,
      if (categoryId != $none) #categoryId: categoryId,
      if (version != $none) #version: version,
      if (endorsementCount != $none) #endorsementCount: endorsementCount,
      if (createdTimestamp != $none) #createdTimestamp: createdTimestamp,
      if (createdTime != $none) #createdTime: createdTime,
      if (updatedTimestamp != $none) #updatedTimestamp: updatedTimestamp,
      if (updatedTime != $none) #updatedTime: updatedTime,
      if (author != $none) #author: author,
      if (uploadedBy != $none) #uploadedBy: uploadedBy,
      if (uploadedUsersProfileUrl != $none)
        #uploadedUsersProfileUrl: uploadedUsersProfileUrl,
      if (containsAdultContent != $none)
        #containsAdultContent: containsAdultContent,
      if (status != $none) #status: status,
      if (available != $none) #available: available,
      if (user != $none) #user: user,
      if (endorsement != $none) #endorsement: endorsement,
    }),
  );
  @override
  NexusMod $make(CopyWithData data) => NexusMod(
    name: data.get(#name, or: $value.name),
    summary: data.get(#summary, or: $value.summary),
    description: data.get(#description, or: $value.description),
    pictureUrl: data.get(#pictureUrl, or: $value.pictureUrl),
    modId: data.get(#modId, or: $value.modId),
    allowRating: data.get(#allowRating, or: $value.allowRating),
    domainName: data.get(#domainName, or: $value.domainName),
    categoryId: data.get(#categoryId, or: $value.categoryId),
    version: data.get(#version, or: $value.version),
    endorsementCount: data.get(#endorsementCount, or: $value.endorsementCount),
    createdTimestamp: data.get(#createdTimestamp, or: $value.createdTimestamp),
    createdTime: data.get(#createdTime, or: $value.createdTime),
    updatedTimestamp: data.get(#updatedTimestamp, or: $value.updatedTimestamp),
    updatedTime: data.get(#updatedTime, or: $value.updatedTime),
    author: data.get(#author, or: $value.author),
    uploadedBy: data.get(#uploadedBy, or: $value.uploadedBy),
    uploadedUsersProfileUrl: data.get(
      #uploadedUsersProfileUrl,
      or: $value.uploadedUsersProfileUrl,
    ),
    containsAdultContent: data.get(
      #containsAdultContent,
      or: $value.containsAdultContent,
    ),
    status: data.get(#status, or: $value.status),
    available: data.get(#available, or: $value.available),
    user: data.get(#user, or: $value.user),
    endorsement: data.get(#endorsement, or: $value.endorsement),
  );

  @override
  NexusModCopyWith<$R2, NexusMod, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _NexusModCopyWithImpl<$R2, $Out2>($value, $cast, t);
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

  static int? _$memberId(User v) => v.memberId;
  static const Field<User, int> _f$memberId = Field(
    'memberId',
    _$memberId,
    key: r'member_id',
    opt: true,
  );
  static int? _$memberGroupId(User v) => v.memberGroupId;
  static const Field<User, int> _f$memberGroupId = Field(
    'memberGroupId',
    _$memberGroupId,
    key: r'member_group_id',
    opt: true,
  );
  static String? _$name(User v) => v.name;
  static const Field<User, String> _f$name = Field('name', _$name, opt: true);

  @override
  final MappableFields<User> fields = const {
    #memberId: _f$memberId,
    #memberGroupId: _f$memberGroupId,
    #name: _f$name,
  };

  static User _instantiate(DecodingData data) {
    return User(
      memberId: data.dec(_f$memberId),
      memberGroupId: data.dec(_f$memberGroupId),
      name: data.dec(_f$name),
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
  $R call({int? memberId, int? memberGroupId, String? name});
  UserCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _UserCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, User, $Out>
    implements UserCopyWith<$R, User, $Out> {
  _UserCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<User> $mapper = UserMapper.ensureInitialized();
  @override
  $R call({
    Object? memberId = $none,
    Object? memberGroupId = $none,
    Object? name = $none,
  }) => $apply(
    FieldCopyWithData({
      if (memberId != $none) #memberId: memberId,
      if (memberGroupId != $none) #memberGroupId: memberGroupId,
      if (name != $none) #name: name,
    }),
  );
  @override
  User $make(CopyWithData data) => User(
    memberId: data.get(#memberId, or: $value.memberId),
    memberGroupId: data.get(#memberGroupId, or: $value.memberGroupId),
    name: data.get(#name, or: $value.name),
  );

  @override
  UserCopyWith<$R2, User, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _UserCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class EndorsementMapper extends ClassMapperBase<Endorsement> {
  EndorsementMapper._();

  static EndorsementMapper? _instance;
  static EndorsementMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = EndorsementMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'Endorsement';

  static String? _$endorseStatus(Endorsement v) => v.endorseStatus;
  static const Field<Endorsement, String> _f$endorseStatus = Field(
    'endorseStatus',
    _$endorseStatus,
    key: r'endorse_status',
    opt: true,
  );
  static int? _$timestamp(Endorsement v) => v.timestamp;
  static const Field<Endorsement, int> _f$timestamp = Field(
    'timestamp',
    _$timestamp,
    opt: true,
  );
  static String? _$version(Endorsement v) => v.version;
  static const Field<Endorsement, String> _f$version = Field(
    'version',
    _$version,
    opt: true,
  );

  @override
  final MappableFields<Endorsement> fields = const {
    #endorseStatus: _f$endorseStatus,
    #timestamp: _f$timestamp,
    #version: _f$version,
  };

  static Endorsement _instantiate(DecodingData data) {
    return Endorsement(
      endorseStatus: data.dec(_f$endorseStatus),
      timestamp: data.dec(_f$timestamp),
      version: data.dec(_f$version),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Endorsement fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Endorsement>(map);
  }

  static Endorsement fromJson(String json) {
    return ensureInitialized().decodeJson<Endorsement>(json);
  }
}

mixin EndorsementMappable {
  String toJson() {
    return EndorsementMapper.ensureInitialized().encodeJson<Endorsement>(
      this as Endorsement,
    );
  }

  Map<String, dynamic> toMap() {
    return EndorsementMapper.ensureInitialized().encodeMap<Endorsement>(
      this as Endorsement,
    );
  }

  EndorsementCopyWith<Endorsement, Endorsement, Endorsement> get copyWith =>
      _EndorsementCopyWithImpl<Endorsement, Endorsement>(
        this as Endorsement,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return EndorsementMapper.ensureInitialized().stringifyValue(
      this as Endorsement,
    );
  }

  @override
  bool operator ==(Object other) {
    return EndorsementMapper.ensureInitialized().equalsValue(
      this as Endorsement,
      other,
    );
  }

  @override
  int get hashCode {
    return EndorsementMapper.ensureInitialized().hashValue(this as Endorsement);
  }
}

extension EndorsementValueCopy<$R, $Out>
    on ObjectCopyWith<$R, Endorsement, $Out> {
  EndorsementCopyWith<$R, Endorsement, $Out> get $asEndorsement =>
      $base.as((v, t, t2) => _EndorsementCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class EndorsementCopyWith<$R, $In extends Endorsement, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? endorseStatus, int? timestamp, String? version});
  EndorsementCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _EndorsementCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, Endorsement, $Out>
    implements EndorsementCopyWith<$R, Endorsement, $Out> {
  _EndorsementCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Endorsement> $mapper =
      EndorsementMapper.ensureInitialized();
  @override
  $R call({
    Object? endorseStatus = $none,
    Object? timestamp = $none,
    Object? version = $none,
  }) => $apply(
    FieldCopyWithData({
      if (endorseStatus != $none) #endorseStatus: endorseStatus,
      if (timestamp != $none) #timestamp: timestamp,
      if (version != $none) #version: version,
    }),
  );
  @override
  Endorsement $make(CopyWithData data) => Endorsement(
    endorseStatus: data.get(#endorseStatus, or: $value.endorseStatus),
    timestamp: data.get(#timestamp, or: $value.timestamp),
    version: data.get(#version, or: $value.version),
  );

  @override
  EndorsementCopyWith<$R2, Endorsement, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _EndorsementCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

