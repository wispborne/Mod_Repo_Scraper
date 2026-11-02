// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'mod_conflict.dart';

class ModConflictListMapper extends ClassMapperBase<ModConflictList> {
  ModConflictListMapper._();

  static ModConflictListMapper? _instance;
  static ModConflictListMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ModConflictListMapper._());
      ModConflictsMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ModConflictList';

  static DateTime _$generatedAt(ModConflictList v) => v.generatedAt;
  static const Field<ModConflictList, DateTime> _f$generatedAt = Field(
    'generatedAt',
    _$generatedAt,
  );
  static List<ModConflicts> _$mods(ModConflictList v) => v.mods;
  static const Field<ModConflictList, List<ModConflicts>> _f$mods = Field(
    'mods',
    _$mods,
    opt: true,
    def: const [],
  );

  @override
  final MappableFields<ModConflictList> fields = const {
    #generatedAt: _f$generatedAt,
    #mods: _f$mods,
  };
  @override
  final bool ignoreNull = true;

  static ModConflictList _instantiate(DecodingData data) {
    return ModConflictList(
      generatedAt: data.dec(_f$generatedAt),
      mods: data.dec(_f$mods),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ModConflictList fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ModConflictList>(map);
  }

  static ModConflictList fromJson(String json) {
    return ensureInitialized().decodeJson<ModConflictList>(json);
  }
}

mixin ModConflictListMappable {
  String toJson() {
    return ModConflictListMapper.ensureInitialized()
        .encodeJson<ModConflictList>(this as ModConflictList);
  }

  Map<String, dynamic> toMap() {
    return ModConflictListMapper.ensureInitialized().encodeMap<ModConflictList>(
      this as ModConflictList,
    );
  }

  ModConflictListCopyWith<ModConflictList, ModConflictList, ModConflictList>
  get copyWith =>
      _ModConflictListCopyWithImpl<ModConflictList, ModConflictList>(
        this as ModConflictList,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ModConflictListMapper.ensureInitialized().stringifyValue(
      this as ModConflictList,
    );
  }

  @override
  bool operator ==(Object other) {
    return ModConflictListMapper.ensureInitialized().equalsValue(
      this as ModConflictList,
      other,
    );
  }

  @override
  int get hashCode {
    return ModConflictListMapper.ensureInitialized().hashValue(
      this as ModConflictList,
    );
  }
}

extension ModConflictListValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ModConflictList, $Out> {
  ModConflictListCopyWith<$R, ModConflictList, $Out> get $asModConflictList =>
      $base.as((v, t, t2) => _ModConflictListCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ModConflictListCopyWith<$R, $In extends ModConflictList, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<
    $R,
    ModConflicts,
    ModConflictsCopyWith<$R, ModConflicts, ModConflicts>
  >
  get mods;
  $R call({DateTime? generatedAt, List<ModConflicts>? mods});
  ModConflictListCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ModConflictListCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ModConflictList, $Out>
    implements ModConflictListCopyWith<$R, ModConflictList, $Out> {
  _ModConflictListCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ModConflictList> $mapper =
      ModConflictListMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    ModConflicts,
    ModConflictsCopyWith<$R, ModConflicts, ModConflicts>
  >
  get mods => ListCopyWith(
    $value.mods,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(mods: v),
  );
  @override
  $R call({DateTime? generatedAt, List<ModConflicts>? mods}) => $apply(
    FieldCopyWithData({
      if (generatedAt != null) #generatedAt: generatedAt,
      if (mods != null) #mods: mods,
    }),
  );
  @override
  ModConflictList $make(CopyWithData data) => ModConflictList(
    generatedAt: data.get(#generatedAt, or: $value.generatedAt),
    mods: data.get(#mods, or: $value.mods),
  );

  @override
  ModConflictListCopyWith<$R2, ModConflictList, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ModConflictListCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ModConflictsMapper extends ClassMapperBase<ModConflicts> {
  ModConflictsMapper._();

  static ModConflictsMapper? _instance;
  static ModConflictsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ModConflictsMapper._());
      PublicConflictMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ModConflicts';

  static String _$modId(ModConflicts v) => v.modId;
  static const Field<ModConflicts, String> _f$modId = Field('modId', _$modId);
  static String _$modName(ModConflicts v) => v.modName;
  static const Field<ModConflicts, String> _f$modName = Field(
    'modName',
    _$modName,
  );
  static List<PublicConflict> _$conflicts(ModConflicts v) => v.conflicts;
  static const Field<ModConflicts, List<PublicConflict>> _f$conflicts = Field(
    'conflicts',
    _$conflicts,
  );

  @override
  final MappableFields<ModConflicts> fields = const {
    #modId: _f$modId,
    #modName: _f$modName,
    #conflicts: _f$conflicts,
  };
  @override
  final bool ignoreNull = true;

  static ModConflicts _instantiate(DecodingData data) {
    return ModConflicts(
      modId: data.dec(_f$modId),
      modName: data.dec(_f$modName),
      conflicts: data.dec(_f$conflicts),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ModConflicts fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ModConflicts>(map);
  }

  static ModConflicts fromJson(String json) {
    return ensureInitialized().decodeJson<ModConflicts>(json);
  }
}

mixin ModConflictsMappable {
  String toJson() {
    return ModConflictsMapper.ensureInitialized().encodeJson<ModConflicts>(
      this as ModConflicts,
    );
  }

  Map<String, dynamic> toMap() {
    return ModConflictsMapper.ensureInitialized().encodeMap<ModConflicts>(
      this as ModConflicts,
    );
  }

  ModConflictsCopyWith<ModConflicts, ModConflicts, ModConflicts> get copyWith =>
      _ModConflictsCopyWithImpl<ModConflicts, ModConflicts>(
        this as ModConflicts,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ModConflictsMapper.ensureInitialized().stringifyValue(
      this as ModConflicts,
    );
  }

  @override
  bool operator ==(Object other) {
    return ModConflictsMapper.ensureInitialized().equalsValue(
      this as ModConflicts,
      other,
    );
  }

  @override
  int get hashCode {
    return ModConflictsMapper.ensureInitialized().hashValue(
      this as ModConflicts,
    );
  }
}

extension ModConflictsValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ModConflicts, $Out> {
  ModConflictsCopyWith<$R, ModConflicts, $Out> get $asModConflicts =>
      $base.as((v, t, t2) => _ModConflictsCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ModConflictsCopyWith<$R, $In extends ModConflicts, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<
    $R,
    PublicConflict,
    PublicConflictCopyWith<$R, PublicConflict, PublicConflict>
  >
  get conflicts;
  $R call({String? modId, String? modName, List<PublicConflict>? conflicts});
  ModConflictsCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ModConflictsCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ModConflicts, $Out>
    implements ModConflictsCopyWith<$R, ModConflicts, $Out> {
  _ModConflictsCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ModConflicts> $mapper =
      ModConflictsMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    PublicConflict,
    PublicConflictCopyWith<$R, PublicConflict, PublicConflict>
  >
  get conflicts => ListCopyWith(
    $value.conflicts,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(conflicts: v),
  );
  @override
  $R call({String? modId, String? modName, List<PublicConflict>? conflicts}) =>
      $apply(
        FieldCopyWithData({
          if (modId != null) #modId: modId,
          if (modName != null) #modName: modName,
          if (conflicts != null) #conflicts: conflicts,
        }),
      );
  @override
  ModConflicts $make(CopyWithData data) => ModConflicts(
    modId: data.get(#modId, or: $value.modId),
    modName: data.get(#modName, or: $value.modName),
    conflicts: data.get(#conflicts, or: $value.conflicts),
  );

  @override
  ModConflictsCopyWith<$R2, ModConflicts, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ModConflictsCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

