// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'takedowns.dart';

class ModTakedownMapper extends ClassMapperBase<ModTakedown> {
  ModTakedownMapper._();

  static ModTakedownMapper? _instance;
  static ModTakedownMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ModTakedownMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'ModTakedown';

  static String _$id(ModTakedown v) => v.id;
  static const Field<ModTakedown, String> _f$id = Field('id', _$id);
  static String _$name(ModTakedown v) => v.name;
  static const Field<ModTakedown, String> _f$name = Field(
    'name',
    _$name,
    opt: true,
    def: '',
  );
  static List<String> _$posts(ModTakedown v) => v.posts;
  static const Field<ModTakedown, List<String>> _f$posts = Field(
    'posts',
    _$posts,
    opt: true,
    def: const [],
  );
  static String _$on(ModTakedown v) => v.on;
  static const Field<ModTakedown, String> _f$on = Field('on', _$on);

  @override
  final MappableFields<ModTakedown> fields = const {
    #id: _f$id,
    #name: _f$name,
    #posts: _f$posts,
    #on: _f$on,
  };

  static ModTakedown _instantiate(DecodingData data) {
    return ModTakedown(
      id: data.dec(_f$id),
      name: data.dec(_f$name),
      posts: data.dec(_f$posts),
      on: data.dec(_f$on),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ModTakedown fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ModTakedown>(map);
  }

  static ModTakedown fromJson(String json) {
    return ensureInitialized().decodeJson<ModTakedown>(json);
  }
}

mixin ModTakedownMappable {
  String toJson() {
    return ModTakedownMapper.ensureInitialized().encodeJson<ModTakedown>(
      this as ModTakedown,
    );
  }

  Map<String, dynamic> toMap() {
    return ModTakedownMapper.ensureInitialized().encodeMap<ModTakedown>(
      this as ModTakedown,
    );
  }

  ModTakedownCopyWith<ModTakedown, ModTakedown, ModTakedown> get copyWith =>
      _ModTakedownCopyWithImpl<ModTakedown, ModTakedown>(
        this as ModTakedown,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ModTakedownMapper.ensureInitialized().stringifyValue(
      this as ModTakedown,
    );
  }

  @override
  bool operator ==(Object other) {
    return ModTakedownMapper.ensureInitialized().equalsValue(
      this as ModTakedown,
      other,
    );
  }

  @override
  int get hashCode {
    return ModTakedownMapper.ensureInitialized().hashValue(this as ModTakedown);
  }
}

extension ModTakedownValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ModTakedown, $Out> {
  ModTakedownCopyWith<$R, ModTakedown, $Out> get $asModTakedown =>
      $base.as((v, t, t2) => _ModTakedownCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ModTakedownCopyWith<$R, $In extends ModTakedown, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get posts;
  $R call({String? id, String? name, List<String>? posts, String? on});
  ModTakedownCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ModTakedownCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ModTakedown, $Out>
    implements ModTakedownCopyWith<$R, ModTakedown, $Out> {
  _ModTakedownCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ModTakedown> $mapper =
      ModTakedownMapper.ensureInitialized();
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get posts =>
      ListCopyWith(
        $value.posts,
        (v, t) => ObjectCopyWith(v, $identity, t),
        (v) => call(posts: v),
      );
  @override
  $R call({String? id, String? name, List<String>? posts, String? on}) =>
      $apply(
        FieldCopyWithData({
          if (id != null) #id: id,
          if (name != null) #name: name,
          if (posts != null) #posts: posts,
          if (on != null) #on: on,
        }),
      );
  @override
  ModTakedown $make(CopyWithData data) => ModTakedown(
    id: data.get(#id, or: $value.id),
    name: data.get(#name, or: $value.name),
    posts: data.get(#posts, or: $value.posts),
    on: data.get(#on, or: $value.on),
  );

  @override
  ModTakedownCopyWith<$R2, ModTakedown, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ModTakedownCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class AuthorTakedownMapper extends ClassMapperBase<AuthorTakedown> {
  AuthorTakedownMapper._();

  static AuthorTakedownMapper? _instance;
  static AuthorTakedownMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = AuthorTakedownMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'AuthorTakedown';

  static List<String> _$names(AuthorTakedown v) => v.names;
  static const Field<AuthorTakedown, List<String>> _f$names = Field(
    'names',
    _$names,
  );
  static String _$on(AuthorTakedown v) => v.on;
  static const Field<AuthorTakedown, String> _f$on = Field('on', _$on);

  @override
  final MappableFields<AuthorTakedown> fields = const {
    #names: _f$names,
    #on: _f$on,
  };

  static AuthorTakedown _instantiate(DecodingData data) {
    return AuthorTakedown(names: data.dec(_f$names), on: data.dec(_f$on));
  }

  @override
  final Function instantiate = _instantiate;

  static AuthorTakedown fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<AuthorTakedown>(map);
  }

  static AuthorTakedown fromJson(String json) {
    return ensureInitialized().decodeJson<AuthorTakedown>(json);
  }
}

mixin AuthorTakedownMappable {
  String toJson() {
    return AuthorTakedownMapper.ensureInitialized().encodeJson<AuthorTakedown>(
      this as AuthorTakedown,
    );
  }

  Map<String, dynamic> toMap() {
    return AuthorTakedownMapper.ensureInitialized().encodeMap<AuthorTakedown>(
      this as AuthorTakedown,
    );
  }

  AuthorTakedownCopyWith<AuthorTakedown, AuthorTakedown, AuthorTakedown>
  get copyWith => _AuthorTakedownCopyWithImpl<AuthorTakedown, AuthorTakedown>(
    this as AuthorTakedown,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return AuthorTakedownMapper.ensureInitialized().stringifyValue(
      this as AuthorTakedown,
    );
  }

  @override
  bool operator ==(Object other) {
    return AuthorTakedownMapper.ensureInitialized().equalsValue(
      this as AuthorTakedown,
      other,
    );
  }

  @override
  int get hashCode {
    return AuthorTakedownMapper.ensureInitialized().hashValue(
      this as AuthorTakedown,
    );
  }
}

extension AuthorTakedownValueCopy<$R, $Out>
    on ObjectCopyWith<$R, AuthorTakedown, $Out> {
  AuthorTakedownCopyWith<$R, AuthorTakedown, $Out> get $asAuthorTakedown =>
      $base.as((v, t, t2) => _AuthorTakedownCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class AuthorTakedownCopyWith<$R, $In extends AuthorTakedown, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get names;
  $R call({List<String>? names, String? on});
  AuthorTakedownCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _AuthorTakedownCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, AuthorTakedown, $Out>
    implements AuthorTakedownCopyWith<$R, AuthorTakedown, $Out> {
  _AuthorTakedownCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<AuthorTakedown> $mapper =
      AuthorTakedownMapper.ensureInitialized();
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get names =>
      ListCopyWith(
        $value.names,
        (v, t) => ObjectCopyWith(v, $identity, t),
        (v) => call(names: v),
      );
  @override
  $R call({List<String>? names, String? on}) => $apply(
    FieldCopyWithData({
      if (names != null) #names: names,
      if (on != null) #on: on,
    }),
  );
  @override
  AuthorTakedown $make(CopyWithData data) => AuthorTakedown(
    names: data.get(#names, or: $value.names),
    on: data.get(#on, or: $value.on),
  );

  @override
  AuthorTakedownCopyWith<$R2, AuthorTakedown, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _AuthorTakedownCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class TakedownListMapper extends ClassMapperBase<TakedownList> {
  TakedownListMapper._();

  static TakedownListMapper? _instance;
  static TakedownListMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = TakedownListMapper._());
      ModTakedownMapper.ensureInitialized();
      AuthorTakedownMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'TakedownList';

  static List<ModTakedown> _$mods(TakedownList v) => v.mods;
  static const Field<TakedownList, List<ModTakedown>> _f$mods = Field(
    'mods',
    _$mods,
    opt: true,
    def: const [],
  );
  static List<AuthorTakedown> _$authors(TakedownList v) => v.authors;
  static const Field<TakedownList, List<AuthorTakedown>> _f$authors = Field(
    'authors',
    _$authors,
    opt: true,
    def: const [],
  );

  @override
  final MappableFields<TakedownList> fields = const {
    #mods: _f$mods,
    #authors: _f$authors,
  };

  static TakedownList _instantiate(DecodingData data) {
    return TakedownList(mods: data.dec(_f$mods), authors: data.dec(_f$authors));
  }

  @override
  final Function instantiate = _instantiate;

  static TakedownList fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<TakedownList>(map);
  }

  static TakedownList fromJson(String json) {
    return ensureInitialized().decodeJson<TakedownList>(json);
  }
}

mixin TakedownListMappable {
  String toJson() {
    return TakedownListMapper.ensureInitialized().encodeJson<TakedownList>(
      this as TakedownList,
    );
  }

  Map<String, dynamic> toMap() {
    return TakedownListMapper.ensureInitialized().encodeMap<TakedownList>(
      this as TakedownList,
    );
  }

  TakedownListCopyWith<TakedownList, TakedownList, TakedownList> get copyWith =>
      _TakedownListCopyWithImpl<TakedownList, TakedownList>(
        this as TakedownList,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return TakedownListMapper.ensureInitialized().stringifyValue(
      this as TakedownList,
    );
  }

  @override
  bool operator ==(Object other) {
    return TakedownListMapper.ensureInitialized().equalsValue(
      this as TakedownList,
      other,
    );
  }

  @override
  int get hashCode {
    return TakedownListMapper.ensureInitialized().hashValue(
      this as TakedownList,
    );
  }
}

extension TakedownListValueCopy<$R, $Out>
    on ObjectCopyWith<$R, TakedownList, $Out> {
  TakedownListCopyWith<$R, TakedownList, $Out> get $asTakedownList =>
      $base.as((v, t, t2) => _TakedownListCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class TakedownListCopyWith<$R, $In extends TakedownList, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<
    $R,
    ModTakedown,
    ModTakedownCopyWith<$R, ModTakedown, ModTakedown>
  >
  get mods;
  ListCopyWith<
    $R,
    AuthorTakedown,
    AuthorTakedownCopyWith<$R, AuthorTakedown, AuthorTakedown>
  >
  get authors;
  $R call({List<ModTakedown>? mods, List<AuthorTakedown>? authors});
  TakedownListCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _TakedownListCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, TakedownList, $Out>
    implements TakedownListCopyWith<$R, TakedownList, $Out> {
  _TakedownListCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<TakedownList> $mapper =
      TakedownListMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    ModTakedown,
    ModTakedownCopyWith<$R, ModTakedown, ModTakedown>
  >
  get mods => ListCopyWith(
    $value.mods,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(mods: v),
  );
  @override
  ListCopyWith<
    $R,
    AuthorTakedown,
    AuthorTakedownCopyWith<$R, AuthorTakedown, AuthorTakedown>
  >
  get authors => ListCopyWith(
    $value.authors,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(authors: v),
  );
  @override
  $R call({List<ModTakedown>? mods, List<AuthorTakedown>? authors}) => $apply(
    FieldCopyWithData({
      if (mods != null) #mods: mods,
      if (authors != null) #authors: authors,
    }),
  );
  @override
  TakedownList $make(CopyWithData data) => TakedownList(
    mods: data.get(#mods, or: $value.mods),
    authors: data.get(#authors, or: $value.authors),
  );

  @override
  TakedownListCopyWith<$R2, TakedownList, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _TakedownListCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

