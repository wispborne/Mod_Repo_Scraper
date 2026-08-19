// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'mod_release.dart';

class ModReleaseFeedMapper extends ClassMapperBase<ModReleaseFeed> {
  ModReleaseFeedMapper._();

  static ModReleaseFeedMapper? _instance;
  static ModReleaseFeedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ModReleaseFeedMapper._());
      ModReleaseMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ModReleaseFeed';

  static DateTime _$generatedAt(ModReleaseFeed v) => v.generatedAt;
  static const Field<ModReleaseFeed, DateTime> _f$generatedAt = Field(
    'generatedAt',
    _$generatedAt,
  );
  static List<ModRelease> _$releases(ModReleaseFeed v) => v.releases;
  static const Field<ModReleaseFeed, List<ModRelease>> _f$releases = Field(
    'releases',
    _$releases,
    opt: true,
    def: const [],
  );

  @override
  final MappableFields<ModReleaseFeed> fields = const {
    #generatedAt: _f$generatedAt,
    #releases: _f$releases,
  };
  @override
  final bool ignoreNull = true;

  static ModReleaseFeed _instantiate(DecodingData data) {
    return ModReleaseFeed(
      generatedAt: data.dec(_f$generatedAt),
      releases: data.dec(_f$releases),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ModReleaseFeed fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ModReleaseFeed>(map);
  }

  static ModReleaseFeed fromJson(String json) {
    return ensureInitialized().decodeJson<ModReleaseFeed>(json);
  }
}

mixin ModReleaseFeedMappable {
  String toJson() {
    return ModReleaseFeedMapper.ensureInitialized().encodeJson<ModReleaseFeed>(
      this as ModReleaseFeed,
    );
  }

  Map<String, dynamic> toMap() {
    return ModReleaseFeedMapper.ensureInitialized().encodeMap<ModReleaseFeed>(
      this as ModReleaseFeed,
    );
  }

  ModReleaseFeedCopyWith<ModReleaseFeed, ModReleaseFeed, ModReleaseFeed>
  get copyWith => _ModReleaseFeedCopyWithImpl<ModReleaseFeed, ModReleaseFeed>(
    this as ModReleaseFeed,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return ModReleaseFeedMapper.ensureInitialized().stringifyValue(
      this as ModReleaseFeed,
    );
  }

  @override
  bool operator ==(Object other) {
    return ModReleaseFeedMapper.ensureInitialized().equalsValue(
      this as ModReleaseFeed,
      other,
    );
  }

  @override
  int get hashCode {
    return ModReleaseFeedMapper.ensureInitialized().hashValue(
      this as ModReleaseFeed,
    );
  }
}

extension ModReleaseFeedValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ModReleaseFeed, $Out> {
  ModReleaseFeedCopyWith<$R, ModReleaseFeed, $Out> get $asModReleaseFeed =>
      $base.as((v, t, t2) => _ModReleaseFeedCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ModReleaseFeedCopyWith<$R, $In extends ModReleaseFeed, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, ModRelease, ModReleaseCopyWith<$R, ModRelease, ModRelease>>
  get releases;
  $R call({DateTime? generatedAt, List<ModRelease>? releases});
  ModReleaseFeedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ModReleaseFeedCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ModReleaseFeed, $Out>
    implements ModReleaseFeedCopyWith<$R, ModReleaseFeed, $Out> {
  _ModReleaseFeedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ModReleaseFeed> $mapper =
      ModReleaseFeedMapper.ensureInitialized();
  @override
  ListCopyWith<$R, ModRelease, ModReleaseCopyWith<$R, ModRelease, ModRelease>>
  get releases => ListCopyWith(
    $value.releases,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(releases: v),
  );
  @override
  $R call({DateTime? generatedAt, List<ModRelease>? releases}) => $apply(
    FieldCopyWithData({
      if (generatedAt != null) #generatedAt: generatedAt,
      if (releases != null) #releases: releases,
    }),
  );
  @override
  ModReleaseFeed $make(CopyWithData data) => ModReleaseFeed(
    generatedAt: data.get(#generatedAt, or: $value.generatedAt),
    releases: data.get(#releases, or: $value.releases),
  );

  @override
  ModReleaseFeedCopyWith<$R2, ModReleaseFeed, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ModReleaseFeedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ModReleaseMapper extends ClassMapperBase<ModRelease> {
  ModReleaseMapper._();

  static ModReleaseMapper? _instance;
  static ModReleaseMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ModReleaseMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'ModRelease';

  static String _$modId(ModRelease v) => v.modId;
  static const Field<ModRelease, String> _f$modId = Field('modId', _$modId);
  static String _$modName(ModRelease v) => v.modName;
  static const Field<ModRelease, String> _f$modName = Field(
    'modName',
    _$modName,
  );
  static String _$seenOn(ModRelease v) => v.seenOn;
  static const Field<ModRelease, String> _f$seenOn = Field('seenOn', _$seenOn);
  static String? _$oldVersion(ModRelease v) => v.oldVersion;
  static const Field<ModRelease, String> _f$oldVersion = Field(
    'oldVersion',
    _$oldVersion,
    opt: true,
  );
  static String _$newVersion(ModRelease v) => v.newVersion;
  static const Field<ModRelease, String> _f$newVersion = Field(
    'newVersion',
    _$newVersion,
  );
  static String? _$gameVersion(ModRelease v) => v.gameVersion;
  static const Field<ModRelease, String> _f$gameVersion = Field(
    'gameVersion',
    _$gameVersion,
    opt: true,
  );
  static String? _$changelogNotes(ModRelease v) => v.changelogNotes;
  static const Field<ModRelease, String> _f$changelogNotes = Field(
    'changelogNotes',
    _$changelogNotes,
    opt: true,
  );

  @override
  final MappableFields<ModRelease> fields = const {
    #modId: _f$modId,
    #modName: _f$modName,
    #seenOn: _f$seenOn,
    #oldVersion: _f$oldVersion,
    #newVersion: _f$newVersion,
    #gameVersion: _f$gameVersion,
    #changelogNotes: _f$changelogNotes,
  };
  @override
  final bool ignoreNull = true;

  static ModRelease _instantiate(DecodingData data) {
    return ModRelease(
      modId: data.dec(_f$modId),
      modName: data.dec(_f$modName),
      seenOn: data.dec(_f$seenOn),
      oldVersion: data.dec(_f$oldVersion),
      newVersion: data.dec(_f$newVersion),
      gameVersion: data.dec(_f$gameVersion),
      changelogNotes: data.dec(_f$changelogNotes),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ModRelease fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ModRelease>(map);
  }

  static ModRelease fromJson(String json) {
    return ensureInitialized().decodeJson<ModRelease>(json);
  }
}

mixin ModReleaseMappable {
  String toJson() {
    return ModReleaseMapper.ensureInitialized().encodeJson<ModRelease>(
      this as ModRelease,
    );
  }

  Map<String, dynamic> toMap() {
    return ModReleaseMapper.ensureInitialized().encodeMap<ModRelease>(
      this as ModRelease,
    );
  }

  ModReleaseCopyWith<ModRelease, ModRelease, ModRelease> get copyWith =>
      _ModReleaseCopyWithImpl<ModRelease, ModRelease>(
        this as ModRelease,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ModReleaseMapper.ensureInitialized().stringifyValue(
      this as ModRelease,
    );
  }

  @override
  bool operator ==(Object other) {
    return ModReleaseMapper.ensureInitialized().equalsValue(
      this as ModRelease,
      other,
    );
  }

  @override
  int get hashCode {
    return ModReleaseMapper.ensureInitialized().hashValue(this as ModRelease);
  }
}

extension ModReleaseValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ModRelease, $Out> {
  ModReleaseCopyWith<$R, ModRelease, $Out> get $asModRelease =>
      $base.as((v, t, t2) => _ModReleaseCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ModReleaseCopyWith<$R, $In extends ModRelease, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? modId,
    String? modName,
    String? seenOn,
    String? oldVersion,
    String? newVersion,
    String? gameVersion,
    String? changelogNotes,
  });
  ModReleaseCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ModReleaseCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ModRelease, $Out>
    implements ModReleaseCopyWith<$R, ModRelease, $Out> {
  _ModReleaseCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ModRelease> $mapper =
      ModReleaseMapper.ensureInitialized();
  @override
  $R call({
    String? modId,
    String? modName,
    String? seenOn,
    Object? oldVersion = $none,
    String? newVersion,
    Object? gameVersion = $none,
    Object? changelogNotes = $none,
  }) => $apply(
    FieldCopyWithData({
      if (modId != null) #modId: modId,
      if (modName != null) #modName: modName,
      if (seenOn != null) #seenOn: seenOn,
      if (oldVersion != $none) #oldVersion: oldVersion,
      if (newVersion != null) #newVersion: newVersion,
      if (gameVersion != $none) #gameVersion: gameVersion,
      if (changelogNotes != $none) #changelogNotes: changelogNotes,
    }),
  );
  @override
  ModRelease $make(CopyWithData data) => ModRelease(
    modId: data.get(#modId, or: $value.modId),
    modName: data.get(#modName, or: $value.modName),
    seenOn: data.get(#seenOn, or: $value.seenOn),
    oldVersion: data.get(#oldVersion, or: $value.oldVersion),
    newVersion: data.get(#newVersion, or: $value.newVersion),
    gameVersion: data.get(#gameVersion, or: $value.gameVersion),
    changelogNotes: data.get(#changelogNotes, or: $value.changelogNotes),
  );

  @override
  ModReleaseCopyWith<$R2, ModRelease, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ModReleaseCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

