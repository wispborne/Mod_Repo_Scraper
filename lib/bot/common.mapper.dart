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
  static bool _$enableModRepo(BotConfig v) => v.enableModRepo;
  static const Field<BotConfig, bool> _f$enableModRepo = Field(
    'enableModRepo',
    _$enableModRepo,
    opt: true,
    def: true,
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
  static bool _$generateMergeDebug(BotConfig v) => v.generateMergeDebug;
  static const Field<BotConfig, bool> _f$generateMergeDebug = Field(
    'generateMergeDebug',
    _$generateMergeDebug,
    opt: true,
    def: false,
  );
  static int _$modRepoMergesToKeep(BotConfig v) => v.modRepoMergesToKeep;
  static const Field<BotConfig, int> _f$modRepoMergesToKeep = Field(
    'modRepoMergesToKeep',
    _$modRepoMergesToKeep,
    opt: true,
    def: 20,
  );
  static bool _$enableQb(BotConfig v) => v.enableQb;
  static const Field<BotConfig, bool> _f$enableQb = Field(
    'enableQb',
    _$enableQb,
    opt: true,
    def: false,
  );
  static bool _$qbUseCached(BotConfig v) => v.qbUseCached;
  static const Field<BotConfig, bool> _f$qbUseCached = Field(
    'qbUseCached',
    _$qbUseCached,
    opt: true,
    def: false,
  );
  static String _$qbDataPath(BotConfig v) => v.qbDataPath;
  static const Field<BotConfig, String> _f$qbDataPath = Field(
    'qbDataPath',
    _$qbDataPath,
    opt: true,
    def: 'qb_data',
  );
  static int _$qbRunsToKeep(BotConfig v) => v.qbRunsToKeep;
  static const Field<BotConfig, int> _f$qbRunsToKeep = Field(
    'qbRunsToKeep',
    _$qbRunsToKeep,
    opt: true,
    def: 100,
  );
  static int _$qbBundlesToKeep(BotConfig v) => v.qbBundlesToKeep;
  static const Field<BotConfig, int> _f$qbBundlesToKeep = Field(
    'qbBundlesToKeep',
    _$qbBundlesToKeep,
    opt: true,
    def: 20,
  );
  static String? _$qbManagerUrl(BotConfig v) => v.qbManagerUrl;
  static const Field<BotConfig, String> _f$qbManagerUrl = Field(
    'qbManagerUrl',
    _$qbManagerUrl,
    opt: true,
  );
  static String _$qbScope(BotConfig v) => v.qbScope;
  static const Field<BotConfig, String> _f$qbScope = Field(
    'qbScope',
    _$qbScope,
    opt: true,
    def: 'newData',
  );
  static Set<String> _$qbBoards(BotConfig v) => v.qbBoards;
  static const Field<BotConfig, Set<String>> _f$qbBoards = Field(
    'qbBoards',
    _$qbBoards,
    opt: true,
    def: const {'main', 'libraries'},
  );
  static int _$qbDelayMs(BotConfig v) => v.qbDelayMs;
  static const Field<BotConfig, int> _f$qbDelayMs = Field(
    'qbDelayMs',
    _$qbDelayMs,
    opt: true,
    def: 1500,
  );
  static int? _$qbMaxPagesMain(BotConfig v) => v.qbMaxPagesMain;
  static const Field<BotConfig, int> _f$qbMaxPagesMain = Field(
    'qbMaxPagesMain',
    _$qbMaxPagesMain,
    opt: true,
  );
  static int _$qbLesserBoardMaxPages(BotConfig v) => v.qbLesserBoardMaxPages;
  static const Field<BotConfig, int> _f$qbLesserBoardMaxPages = Field(
    'qbLesserBoardMaxPages',
    _$qbLesserBoardMaxPages,
    opt: true,
    def: 20,
  );
  static int? _$qbMaxPagesLibraries(BotConfig v) => v.qbMaxPagesLibraries;
  static const Field<BotConfig, int> _f$qbMaxPagesLibraries = Field(
    'qbMaxPagesLibraries',
    _$qbMaxPagesLibraries,
    opt: true,
  );
  static bool _$enableLlm(BotConfig v) => v.enableLlm;
  static const Field<BotConfig, bool> _f$enableLlm = Field(
    'enableLlm',
    _$enableLlm,
    opt: true,
    def: false,
  );
  static String? _$llmApiToken(BotConfig v) => v.llmApiToken;
  static const Field<BotConfig, String> _f$llmApiToken = Field(
    'llmApiToken',
    _$llmApiToken,
    opt: true,
  );
  static String _$llmModel(BotConfig v) => v.llmModel;
  static const Field<BotConfig, String> _f$llmModel = Field(
    'llmModel',
    _$llmModel,
    opt: true,
    def: 'deepseek/deepseek-chat',
  );
  static String _$llmBaseUrl(BotConfig v) => v.llmBaseUrl;
  static const Field<BotConfig, String> _f$llmBaseUrl = Field(
    'llmBaseUrl',
    _$llmBaseUrl,
    opt: true,
    def: 'https://openrouter.ai/api/v1/chat/completions',
  );
  static int _$llmMaxConsecutiveFailures(BotConfig v) =>
      v.llmMaxConsecutiveFailures;
  static const Field<BotConfig, int> _f$llmMaxConsecutiveFailures = Field(
    'llmMaxConsecutiveFailures',
    _$llmMaxConsecutiveFailures,
    opt: true,
    def: 10,
  );
  static int _$llmTimeoutSeconds(BotConfig v) => v.llmTimeoutSeconds;
  static const Field<BotConfig, int> _f$llmTimeoutSeconds = Field(
    'llmTimeoutSeconds',
    _$llmTimeoutSeconds,
    opt: true,
    def: 120,
  );
  static int? _$llmMaxTopics(BotConfig v) => v.llmMaxTopics;
  static const Field<BotConfig, int> _f$llmMaxTopics = Field(
    'llmMaxTopics',
    _$llmMaxTopics,
    opt: true,
  );
  static int? _$llmMaxTokens(BotConfig v) => v.llmMaxTokens;
  static const Field<BotConfig, int> _f$llmMaxTokens = Field(
    'llmMaxTokens',
    _$llmMaxTokens,
    opt: true,
  );
  static int? _$llmMaxInputChars(BotConfig v) => v.llmMaxInputChars;
  static const Field<BotConfig, int> _f$llmMaxInputChars = Field(
    'llmMaxInputChars',
    _$llmMaxInputChars,
    opt: true,
  );
  static bool _$llmDisableThinking(BotConfig v) => v.llmDisableThinking;
  static const Field<BotConfig, bool> _f$llmDisableThinking = Field(
    'llmDisableThinking',
    _$llmDisableThinking,
    opt: true,
    def: false,
  );
  static bool _$llmStructuredOutput(BotConfig v) => v.llmStructuredOutput;
  static const Field<BotConfig, bool> _f$llmStructuredOutput = Field(
    'llmStructuredOutput',
    _$llmStructuredOutput,
    opt: true,
    def: false,
  );
  static bool _$enableLlmSummaries(BotConfig v) => v.enableLlmSummaries;
  static const Field<BotConfig, bool> _f$enableLlmSummaries = Field(
    'enableLlmSummaries',
    _$enableLlmSummaries,
    opt: true,
    def: false,
  );
  static bool _$llmSkipScrapeReprocessOnly(BotConfig v) =>
      v.llmSkipScrapeReprocessOnly;
  static const Field<BotConfig, bool> _f$llmSkipScrapeReprocessOnly = Field(
    'llmSkipScrapeReprocessOnly',
    _$llmSkipScrapeReprocessOnly,
    opt: true,
    def: false,
  );
  static bool _$llmTestMode(BotConfig v) => v.llmTestMode;
  static const Field<BotConfig, bool> _f$llmTestMode = Field(
    'llmTestMode',
    _$llmTestMode,
    opt: true,
    def: false,
  );
  static int _$llmTestLimit(BotConfig v) => v.llmTestLimit;
  static const Field<BotConfig, int> _f$llmTestLimit = Field(
    'llmTestLimit',
    _$llmTestLimit,
    opt: true,
    def: 5,
  );
  static Set<int>? _$llmTestTopicIds(BotConfig v) => v.llmTestTopicIds;
  static const Field<BotConfig, Set<int>> _f$llmTestTopicIds = Field(
    'llmTestTopicIds',
    _$llmTestTopicIds,
    opt: true,
  );
  static String? _$llmFallbackBaseUrl(BotConfig v) => v.llmFallbackBaseUrl;
  static const Field<BotConfig, String> _f$llmFallbackBaseUrl = Field(
    'llmFallbackBaseUrl',
    _$llmFallbackBaseUrl,
    opt: true,
  );
  static String? _$llmFallbackModel(BotConfig v) => v.llmFallbackModel;
  static const Field<BotConfig, String> _f$llmFallbackModel = Field(
    'llmFallbackModel',
    _$llmFallbackModel,
    opt: true,
  );
  static String? _$llmFallbackApiToken(BotConfig v) => v.llmFallbackApiToken;
  static const Field<BotConfig, String> _f$llmFallbackApiToken = Field(
    'llmFallbackApiToken',
    _$llmFallbackApiToken,
    opt: true,
  );
  static bool _$llmFallbackDisableThinking(BotConfig v) =>
      v.llmFallbackDisableThinking;
  static const Field<BotConfig, bool> _f$llmFallbackDisableThinking = Field(
    'llmFallbackDisableThinking',
    _$llmFallbackDisableThinking,
    opt: true,
    def: false,
  );
  static bool _$llmFallbackStructuredOutput(BotConfig v) =>
      v.llmFallbackStructuredOutput;
  static const Field<BotConfig, bool> _f$llmFallbackStructuredOutput = Field(
    'llmFallbackStructuredOutput',
    _$llmFallbackStructuredOutput,
    opt: true,
    def: false,
  );
  static String _$publishRepoUrl(BotConfig v) => v.publishRepoUrl;
  static const Field<BotConfig, String> _f$publishRepoUrl = Field(
    'publishRepoUrl',
    _$publishRepoUrl,
    opt: true,
    def: 'git@github.com:wispborne/StarsectorModRepo.git',
  );
  static String? _$publishCloneDir(BotConfig v) => v.publishCloneDir;
  static const Field<BotConfig, String> _f$publishCloneDir = Field(
    'publishCloneDir',
    _$publishCloneDir,
    opt: true,
  );
  static String _$publishSitePath(BotConfig v) => v.publishSitePath;
  static const Field<BotConfig, String> _f$publishSitePath = Field(
    'publishSitePath',
    _$publishSitePath,
    opt: true,
    def: 'site',
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
    #enableModRepo: _f$enableModRepo,
    #keepAllGameVersionsFromSameSource: _f$keepAllGameVersionsFromSameSource,
    #generateMergeDebug: _f$generateMergeDebug,
    #modRepoMergesToKeep: _f$modRepoMergesToKeep,
    #enableQb: _f$enableQb,
    #qbUseCached: _f$qbUseCached,
    #qbDataPath: _f$qbDataPath,
    #qbRunsToKeep: _f$qbRunsToKeep,
    #qbBundlesToKeep: _f$qbBundlesToKeep,
    #qbManagerUrl: _f$qbManagerUrl,
    #qbScope: _f$qbScope,
    #qbBoards: _f$qbBoards,
    #qbDelayMs: _f$qbDelayMs,
    #qbMaxPagesMain: _f$qbMaxPagesMain,
    #qbLesserBoardMaxPages: _f$qbLesserBoardMaxPages,
    #qbMaxPagesLibraries: _f$qbMaxPagesLibraries,
    #enableLlm: _f$enableLlm,
    #llmApiToken: _f$llmApiToken,
    #llmModel: _f$llmModel,
    #llmBaseUrl: _f$llmBaseUrl,
    #llmMaxConsecutiveFailures: _f$llmMaxConsecutiveFailures,
    #llmTimeoutSeconds: _f$llmTimeoutSeconds,
    #llmMaxTopics: _f$llmMaxTopics,
    #llmMaxTokens: _f$llmMaxTokens,
    #llmMaxInputChars: _f$llmMaxInputChars,
    #llmDisableThinking: _f$llmDisableThinking,
    #llmStructuredOutput: _f$llmStructuredOutput,
    #enableLlmSummaries: _f$enableLlmSummaries,
    #llmSkipScrapeReprocessOnly: _f$llmSkipScrapeReprocessOnly,
    #llmTestMode: _f$llmTestMode,
    #llmTestLimit: _f$llmTestLimit,
    #llmTestTopicIds: _f$llmTestTopicIds,
    #llmFallbackBaseUrl: _f$llmFallbackBaseUrl,
    #llmFallbackModel: _f$llmFallbackModel,
    #llmFallbackApiToken: _f$llmFallbackApiToken,
    #llmFallbackDisableThinking: _f$llmFallbackDisableThinking,
    #llmFallbackStructuredOutput: _f$llmFallbackStructuredOutput,
    #publishRepoUrl: _f$publishRepoUrl,
    #publishCloneDir: _f$publishCloneDir,
    #publishSitePath: _f$publishSitePath,
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
      enableModRepo: data.dec(_f$enableModRepo),
      keepAllGameVersionsFromSameSource: data.dec(
        _f$keepAllGameVersionsFromSameSource,
      ),
      generateMergeDebug: data.dec(_f$generateMergeDebug),
      modRepoMergesToKeep: data.dec(_f$modRepoMergesToKeep),
      enableQb: data.dec(_f$enableQb),
      qbUseCached: data.dec(_f$qbUseCached),
      qbDataPath: data.dec(_f$qbDataPath),
      qbRunsToKeep: data.dec(_f$qbRunsToKeep),
      qbBundlesToKeep: data.dec(_f$qbBundlesToKeep),
      qbManagerUrl: data.dec(_f$qbManagerUrl),
      qbScope: data.dec(_f$qbScope),
      qbBoards: data.dec(_f$qbBoards),
      qbDelayMs: data.dec(_f$qbDelayMs),
      qbMaxPagesMain: data.dec(_f$qbMaxPagesMain),
      qbLesserBoardMaxPages: data.dec(_f$qbLesserBoardMaxPages),
      qbMaxPagesLibraries: data.dec(_f$qbMaxPagesLibraries),
      enableLlm: data.dec(_f$enableLlm),
      llmApiToken: data.dec(_f$llmApiToken),
      llmModel: data.dec(_f$llmModel),
      llmBaseUrl: data.dec(_f$llmBaseUrl),
      llmMaxConsecutiveFailures: data.dec(_f$llmMaxConsecutiveFailures),
      llmTimeoutSeconds: data.dec(_f$llmTimeoutSeconds),
      llmMaxTopics: data.dec(_f$llmMaxTopics),
      llmMaxTokens: data.dec(_f$llmMaxTokens),
      llmMaxInputChars: data.dec(_f$llmMaxInputChars),
      llmDisableThinking: data.dec(_f$llmDisableThinking),
      llmStructuredOutput: data.dec(_f$llmStructuredOutput),
      enableLlmSummaries: data.dec(_f$enableLlmSummaries),
      llmSkipScrapeReprocessOnly: data.dec(_f$llmSkipScrapeReprocessOnly),
      llmTestMode: data.dec(_f$llmTestMode),
      llmTestLimit: data.dec(_f$llmTestLimit),
      llmTestTopicIds: data.dec(_f$llmTestTopicIds),
      llmFallbackBaseUrl: data.dec(_f$llmFallbackBaseUrl),
      llmFallbackModel: data.dec(_f$llmFallbackModel),
      llmFallbackApiToken: data.dec(_f$llmFallbackApiToken),
      llmFallbackDisableThinking: data.dec(_f$llmFallbackDisableThinking),
      llmFallbackStructuredOutput: data.dec(_f$llmFallbackStructuredOutput),
      publishRepoUrl: data.dec(_f$publishRepoUrl),
      publishCloneDir: data.dec(_f$publishCloneDir),
      publishSitePath: data.dec(_f$publishSitePath),
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
    bool? enableModRepo,
    bool? keepAllGameVersionsFromSameSource,
    bool? generateMergeDebug,
    int? modRepoMergesToKeep,
    bool? enableQb,
    bool? qbUseCached,
    String? qbDataPath,
    int? qbRunsToKeep,
    int? qbBundlesToKeep,
    String? qbManagerUrl,
    String? qbScope,
    Set<String>? qbBoards,
    int? qbDelayMs,
    int? qbMaxPagesMain,
    int? qbLesserBoardMaxPages,
    int? qbMaxPagesLibraries,
    bool? enableLlm,
    String? llmApiToken,
    String? llmModel,
    String? llmBaseUrl,
    int? llmMaxConsecutiveFailures,
    int? llmTimeoutSeconds,
    int? llmMaxTopics,
    int? llmMaxTokens,
    int? llmMaxInputChars,
    bool? llmDisableThinking,
    bool? llmStructuredOutput,
    bool? enableLlmSummaries,
    bool? llmSkipScrapeReprocessOnly,
    bool? llmTestMode,
    int? llmTestLimit,
    Set<int>? llmTestTopicIds,
    String? llmFallbackBaseUrl,
    String? llmFallbackModel,
    String? llmFallbackApiToken,
    bool? llmFallbackDisableThinking,
    bool? llmFallbackStructuredOutput,
    String? publishRepoUrl,
    String? publishCloneDir,
    String? publishSitePath,
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
    bool? enableModRepo,
    bool? keepAllGameVersionsFromSameSource,
    bool? generateMergeDebug,
    int? modRepoMergesToKeep,
    bool? enableQb,
    bool? qbUseCached,
    String? qbDataPath,
    int? qbRunsToKeep,
    int? qbBundlesToKeep,
    Object? qbManagerUrl = $none,
    String? qbScope,
    Set<String>? qbBoards,
    int? qbDelayMs,
    Object? qbMaxPagesMain = $none,
    int? qbLesserBoardMaxPages,
    Object? qbMaxPagesLibraries = $none,
    bool? enableLlm,
    Object? llmApiToken = $none,
    String? llmModel,
    String? llmBaseUrl,
    int? llmMaxConsecutiveFailures,
    int? llmTimeoutSeconds,
    Object? llmMaxTopics = $none,
    Object? llmMaxTokens = $none,
    Object? llmMaxInputChars = $none,
    bool? llmDisableThinking,
    bool? llmStructuredOutput,
    bool? enableLlmSummaries,
    bool? llmSkipScrapeReprocessOnly,
    bool? llmTestMode,
    int? llmTestLimit,
    Object? llmTestTopicIds = $none,
    Object? llmFallbackBaseUrl = $none,
    Object? llmFallbackModel = $none,
    Object? llmFallbackApiToken = $none,
    bool? llmFallbackDisableThinking,
    bool? llmFallbackStructuredOutput,
    String? publishRepoUrl,
    Object? publishCloneDir = $none,
    String? publishSitePath,
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
      if (enableModRepo != null) #enableModRepo: enableModRepo,
      if (keepAllGameVersionsFromSameSource != null)
        #keepAllGameVersionsFromSameSource: keepAllGameVersionsFromSameSource,
      if (generateMergeDebug != null) #generateMergeDebug: generateMergeDebug,
      if (modRepoMergesToKeep != null)
        #modRepoMergesToKeep: modRepoMergesToKeep,
      if (enableQb != null) #enableQb: enableQb,
      if (qbUseCached != null) #qbUseCached: qbUseCached,
      if (qbDataPath != null) #qbDataPath: qbDataPath,
      if (qbRunsToKeep != null) #qbRunsToKeep: qbRunsToKeep,
      if (qbBundlesToKeep != null) #qbBundlesToKeep: qbBundlesToKeep,
      if (qbManagerUrl != $none) #qbManagerUrl: qbManagerUrl,
      if (qbScope != null) #qbScope: qbScope,
      if (qbBoards != null) #qbBoards: qbBoards,
      if (qbDelayMs != null) #qbDelayMs: qbDelayMs,
      if (qbMaxPagesMain != $none) #qbMaxPagesMain: qbMaxPagesMain,
      if (qbLesserBoardMaxPages != null)
        #qbLesserBoardMaxPages: qbLesserBoardMaxPages,
      if (qbMaxPagesLibraries != $none)
        #qbMaxPagesLibraries: qbMaxPagesLibraries,
      if (enableLlm != null) #enableLlm: enableLlm,
      if (llmApiToken != $none) #llmApiToken: llmApiToken,
      if (llmModel != null) #llmModel: llmModel,
      if (llmBaseUrl != null) #llmBaseUrl: llmBaseUrl,
      if (llmMaxConsecutiveFailures != null)
        #llmMaxConsecutiveFailures: llmMaxConsecutiveFailures,
      if (llmTimeoutSeconds != null) #llmTimeoutSeconds: llmTimeoutSeconds,
      if (llmMaxTopics != $none) #llmMaxTopics: llmMaxTopics,
      if (llmMaxTokens != $none) #llmMaxTokens: llmMaxTokens,
      if (llmMaxInputChars != $none) #llmMaxInputChars: llmMaxInputChars,
      if (llmDisableThinking != null) #llmDisableThinking: llmDisableThinking,
      if (llmStructuredOutput != null)
        #llmStructuredOutput: llmStructuredOutput,
      if (enableLlmSummaries != null) #enableLlmSummaries: enableLlmSummaries,
      if (llmSkipScrapeReprocessOnly != null)
        #llmSkipScrapeReprocessOnly: llmSkipScrapeReprocessOnly,
      if (llmTestMode != null) #llmTestMode: llmTestMode,
      if (llmTestLimit != null) #llmTestLimit: llmTestLimit,
      if (llmTestTopicIds != $none) #llmTestTopicIds: llmTestTopicIds,
      if (llmFallbackBaseUrl != $none) #llmFallbackBaseUrl: llmFallbackBaseUrl,
      if (llmFallbackModel != $none) #llmFallbackModel: llmFallbackModel,
      if (llmFallbackApiToken != $none)
        #llmFallbackApiToken: llmFallbackApiToken,
      if (llmFallbackDisableThinking != null)
        #llmFallbackDisableThinking: llmFallbackDisableThinking,
      if (llmFallbackStructuredOutput != null)
        #llmFallbackStructuredOutput: llmFallbackStructuredOutput,
      if (publishRepoUrl != null) #publishRepoUrl: publishRepoUrl,
      if (publishCloneDir != $none) #publishCloneDir: publishCloneDir,
      if (publishSitePath != null) #publishSitePath: publishSitePath,
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
    enableModRepo: data.get(#enableModRepo, or: $value.enableModRepo),
    keepAllGameVersionsFromSameSource: data.get(
      #keepAllGameVersionsFromSameSource,
      or: $value.keepAllGameVersionsFromSameSource,
    ),
    generateMergeDebug: data.get(
      #generateMergeDebug,
      or: $value.generateMergeDebug,
    ),
    modRepoMergesToKeep: data.get(
      #modRepoMergesToKeep,
      or: $value.modRepoMergesToKeep,
    ),
    enableQb: data.get(#enableQb, or: $value.enableQb),
    qbUseCached: data.get(#qbUseCached, or: $value.qbUseCached),
    qbDataPath: data.get(#qbDataPath, or: $value.qbDataPath),
    qbRunsToKeep: data.get(#qbRunsToKeep, or: $value.qbRunsToKeep),
    qbBundlesToKeep: data.get(#qbBundlesToKeep, or: $value.qbBundlesToKeep),
    qbManagerUrl: data.get(#qbManagerUrl, or: $value.qbManagerUrl),
    qbScope: data.get(#qbScope, or: $value.qbScope),
    qbBoards: data.get(#qbBoards, or: $value.qbBoards),
    qbDelayMs: data.get(#qbDelayMs, or: $value.qbDelayMs),
    qbMaxPagesMain: data.get(#qbMaxPagesMain, or: $value.qbMaxPagesMain),
    qbLesserBoardMaxPages: data.get(
      #qbLesserBoardMaxPages,
      or: $value.qbLesserBoardMaxPages,
    ),
    qbMaxPagesLibraries: data.get(
      #qbMaxPagesLibraries,
      or: $value.qbMaxPagesLibraries,
    ),
    enableLlm: data.get(#enableLlm, or: $value.enableLlm),
    llmApiToken: data.get(#llmApiToken, or: $value.llmApiToken),
    llmModel: data.get(#llmModel, or: $value.llmModel),
    llmBaseUrl: data.get(#llmBaseUrl, or: $value.llmBaseUrl),
    llmMaxConsecutiveFailures: data.get(
      #llmMaxConsecutiveFailures,
      or: $value.llmMaxConsecutiveFailures,
    ),
    llmTimeoutSeconds: data.get(
      #llmTimeoutSeconds,
      or: $value.llmTimeoutSeconds,
    ),
    llmMaxTopics: data.get(#llmMaxTopics, or: $value.llmMaxTopics),
    llmMaxTokens: data.get(#llmMaxTokens, or: $value.llmMaxTokens),
    llmMaxInputChars: data.get(#llmMaxInputChars, or: $value.llmMaxInputChars),
    llmDisableThinking: data.get(
      #llmDisableThinking,
      or: $value.llmDisableThinking,
    ),
    llmStructuredOutput: data.get(
      #llmStructuredOutput,
      or: $value.llmStructuredOutput,
    ),
    enableLlmSummaries: data.get(
      #enableLlmSummaries,
      or: $value.enableLlmSummaries,
    ),
    llmSkipScrapeReprocessOnly: data.get(
      #llmSkipScrapeReprocessOnly,
      or: $value.llmSkipScrapeReprocessOnly,
    ),
    llmTestMode: data.get(#llmTestMode, or: $value.llmTestMode),
    llmTestLimit: data.get(#llmTestLimit, or: $value.llmTestLimit),
    llmTestTopicIds: data.get(#llmTestTopicIds, or: $value.llmTestTopicIds),
    llmFallbackBaseUrl: data.get(
      #llmFallbackBaseUrl,
      or: $value.llmFallbackBaseUrl,
    ),
    llmFallbackModel: data.get(#llmFallbackModel, or: $value.llmFallbackModel),
    llmFallbackApiToken: data.get(
      #llmFallbackApiToken,
      or: $value.llmFallbackApiToken,
    ),
    llmFallbackDisableThinking: data.get(
      #llmFallbackDisableThinking,
      or: $value.llmFallbackDisableThinking,
    ),
    llmFallbackStructuredOutput: data.get(
      #llmFallbackStructuredOutput,
      or: $value.llmFallbackStructuredOutput,
    ),
    publishRepoUrl: data.get(#publishRepoUrl, or: $value.publishRepoUrl),
    publishCloneDir: data.get(#publishCloneDir, or: $value.publishCloneDir),
    publishSitePath: data.get(#publishSitePath, or: $value.publishSitePath),
  );

  @override
  BotConfigCopyWith<$R2, BotConfig, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _BotConfigCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

