// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'common.dart';

class BotConfigMapper extends ClassMapperBase<BotConfig> {
  BotConfigMapper._();

  static BotConfigMapper? _instance;
  static BotConfigMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = BotConfigMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'BotConfig';

  static bool _$lessScraping(BotConfig v) => v.lessScraping;
  static const Field<BotConfig, bool> _f$lessScraping = Field(
    'lessScraping',
    _$lessScraping,
  );
  static bool _$useCached(BotConfig v) => v.useCached;
  static const Field<BotConfig, bool> _f$useCached = Field(
    'useCached',
    _$useCached,
    opt: true,
    def: false,
  );
  static bool _$enableForums(BotConfig v) => v.enableForums;
  static const Field<BotConfig, bool> _f$enableForums = Field(
    'enableForums',
    _$enableForums,
  );
  static bool _$enableDiscord(BotConfig v) => v.enableDiscord;
  static const Field<BotConfig, bool> _f$enableDiscord = Field(
    'enableDiscord',
    _$enableDiscord,
  );
  static bool _$enableNexus(BotConfig v) => v.enableNexus;
  static const Field<BotConfig, bool> _f$enableNexus = Field(
    'enableNexus',
    _$enableNexus,
  );
  static String _$logLevel(BotConfig v) => v.logLevel;
  static const Field<BotConfig, String> _f$logLevel = Field(
    'logLevel',
    _$logLevel,
  );
  static String? _$discordAuthToken(BotConfig v) => v.discordAuthToken;
  static const Field<BotConfig, String> _f$discordAuthToken = Field(
    'discordAuthToken',
    _$discordAuthToken,
    opt: true,
  );
  static String? _$nexusApiToken(BotConfig v) => v.nexusApiToken;
  static const Field<BotConfig, String> _f$nexusApiToken = Field(
    'nexusApiToken',
    _$nexusApiToken,
    opt: true,
  );
  static String? _$discordServerId(BotConfig v) => v.discordServerId;
  static const Field<BotConfig, String> _f$discordServerId = Field(
    'discordServerId',
    _$discordServerId,
    opt: true,
  );
  static Map<String, String>? _$discordForumChannelIdsAndGameVersions(
    BotConfig v,
  ) => v.discordForumChannelIdsAndGameVersions;
  static const Field<BotConfig, Map<String, String>>
  _f$discordForumChannelIdsAndGameVersions = Field(
    'discordForumChannelIdsAndGameVersions',
    _$discordForumChannelIdsAndGameVersions,
    opt: true,
  );
  static bool _$keepAllGameVersionsFromSameSource(BotConfig v) =>
      v.keepAllGameVersionsFromSameSource;
  static const Field<BotConfig, bool> _f$keepAllGameVersionsFromSameSource =
      Field(
        'keepAllGameVersionsFromSameSource',
        _$keepAllGameVersionsFromSameSource,
        opt: true,
        def: false,
      );
  static bool _$generateDebugHtml(BotConfig v) => v.generateDebugHtml;
  static const Field<BotConfig, bool> _f$generateDebugHtml = Field(
    'generateDebugHtml',
    _$generateDebugHtml,
    opt: true,
    def: false,
  );

  @override
  final MappableFields<BotConfig> fields = const {
    #lessScraping: _f$lessScraping,
    #useCached: _f$useCached,
    #enableForums: _f$enableForums,
    #enableDiscord: _f$enableDiscord,
    #enableNexus: _f$enableNexus,
    #logLevel: _f$logLevel,
    #discordAuthToken: _f$discordAuthToken,
    #nexusApiToken: _f$nexusApiToken,
    #discordServerId: _f$discordServerId,
    #discordForumChannelIdsAndGameVersions:
        _f$discordForumChannelIdsAndGameVersions,
    #keepAllGameVersionsFromSameSource: _f$keepAllGameVersionsFromSameSource,
    #generateDebugHtml: _f$generateDebugHtml,
  };

  static BotConfig _instantiate(DecodingData data) {
    return BotConfig(
      lessScraping: data.dec(_f$lessScraping),
      useCached: data.dec(_f$useCached),
      enableForums: data.dec(_f$enableForums),
      enableDiscord: data.dec(_f$enableDiscord),
      enableNexus: data.dec(_f$enableNexus),
      logLevel: data.dec(_f$logLevel),
      discordAuthToken: data.dec(_f$discordAuthToken),
      nexusApiToken: data.dec(_f$nexusApiToken),
      discordServerId: data.dec(_f$discordServerId),
      discordForumChannelIdsAndGameVersions: data.dec(
        _f$discordForumChannelIdsAndGameVersions,
      ),
      keepAllGameVersionsFromSameSource: data.dec(
        _f$keepAllGameVersionsFromSameSource,
      ),
      generateDebugHtml: data.dec(_f$generateDebugHtml),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static BotConfig fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<BotConfig>(map);
  }

  static BotConfig fromJson(String json) {
    return ensureInitialized().decodeJson<BotConfig>(json);
  }
}

mixin BotConfigMappable {
  String toJson() {
    return BotConfigMapper.ensureInitialized().encodeJson<BotConfig>(
      this as BotConfig,
    );
  }

  Map<String, dynamic> toMap() {
    return BotConfigMapper.ensureInitialized().encodeMap<BotConfig>(
      this as BotConfig,
    );
  }

  BotConfigCopyWith<BotConfig, BotConfig, BotConfig> get copyWith =>
      _BotConfigCopyWithImpl<BotConfig, BotConfig>(
        this as BotConfig,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return BotConfigMapper.ensureInitialized().stringifyValue(
      this as BotConfig,
    );
  }

  @override
  bool operator ==(Object other) {
    return BotConfigMapper.ensureInitialized().equalsValue(
      this as BotConfig,
      other,
    );
  }

  @override
  int get hashCode {
    return BotConfigMapper.ensureInitialized().hashValue(this as BotConfig);
  }
}

extension BotConfigValueCopy<$R, $Out> on ObjectCopyWith<$R, BotConfig, $Out> {
  BotConfigCopyWith<$R, BotConfig, $Out> get $asBotConfig =>
      $base.as((v, t, t2) => _BotConfigCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class BotConfigCopyWith<$R, $In extends BotConfig, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  MapCopyWith<$R, String, String, ObjectCopyWith<$R, String, String>>?
  get discordForumChannelIdsAndGameVersions;
  $R call({
    bool? lessScraping,
    bool? useCached,
    bool? enableForums,
    bool? enableDiscord,
    bool? enableNexus,
    String? logLevel,
    String? discordAuthToken,
    String? nexusApiToken,
    String? discordServerId,
    Map<String, String>? discordForumChannelIdsAndGameVersions,
    bool? keepAllGameVersionsFromSameSource,
    bool? generateDebugHtml,
  });
  BotConfigCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _BotConfigCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, BotConfig, $Out>
    implements BotConfigCopyWith<$R, BotConfig, $Out> {
  _BotConfigCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<BotConfig> $mapper =
      BotConfigMapper.ensureInitialized();
  @override
  MapCopyWith<$R, String, String, ObjectCopyWith<$R, String, String>>?
  get discordForumChannelIdsAndGameVersions =>
      $value.discordForumChannelIdsAndGameVersions != null
      ? MapCopyWith(
          $value.discordForumChannelIdsAndGameVersions!,
          (v, t) => ObjectCopyWith(v, $identity, t),
          (v) => call(discordForumChannelIdsAndGameVersions: v),
        )
      : null;
  @override
  $R call({
    bool? lessScraping,
    bool? useCached,
    bool? enableForums,
    bool? enableDiscord,
    bool? enableNexus,
    String? logLevel,
    Object? discordAuthToken = $none,
    Object? nexusApiToken = $none,
    Object? discordServerId = $none,
    Object? discordForumChannelIdsAndGameVersions = $none,
    bool? keepAllGameVersionsFromSameSource,
    bool? generateDebugHtml,
  }) => $apply(
    FieldCopyWithData({
      if (lessScraping != null) #lessScraping: lessScraping,
      if (useCached != null) #useCached: useCached,
      if (enableForums != null) #enableForums: enableForums,
      if (enableDiscord != null) #enableDiscord: enableDiscord,
      if (enableNexus != null) #enableNexus: enableNexus,
      if (logLevel != null) #logLevel: logLevel,
      if (discordAuthToken != $none) #discordAuthToken: discordAuthToken,
      if (nexusApiToken != $none) #nexusApiToken: nexusApiToken,
      if (discordServerId != $none) #discordServerId: discordServerId,
      if (discordForumChannelIdsAndGameVersions != $none)
        #discordForumChannelIdsAndGameVersions:
            discordForumChannelIdsAndGameVersions,
      if (keepAllGameVersionsFromSameSource != null)
        #keepAllGameVersionsFromSameSource: keepAllGameVersionsFromSameSource,
      if (generateDebugHtml != null) #generateDebugHtml: generateDebugHtml,
    }),
  );
  @override
  BotConfig $make(CopyWithData data) => BotConfig(
    lessScraping: data.get(#lessScraping, or: $value.lessScraping),
    useCached: data.get(#useCached, or: $value.useCached),
    enableForums: data.get(#enableForums, or: $value.enableForums),
    enableDiscord: data.get(#enableDiscord, or: $value.enableDiscord),
    enableNexus: data.get(#enableNexus, or: $value.enableNexus),
    logLevel: data.get(#logLevel, or: $value.logLevel),
    discordAuthToken: data.get(#discordAuthToken, or: $value.discordAuthToken),
    nexusApiToken: data.get(#nexusApiToken, or: $value.nexusApiToken),
    discordServerId: data.get(#discordServerId, or: $value.discordServerId),
    discordForumChannelIdsAndGameVersions: data.get(
      #discordForumChannelIdsAndGameVersions,
      or: $value.discordForumChannelIdsAndGameVersions,
    ),
    keepAllGameVersionsFromSameSource: data.get(
      #keepAllGameVersionsFromSameSource,
      or: $value.keepAllGameVersionsFromSameSource,
    ),
    generateDebugHtml: data.get(
      #generateDebugHtml,
      or: $value.generateDebugHtml,
    ),
  );

  @override
  BotConfigCopyWith<$R2, BotConfig, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _BotConfigCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

