// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'mod_summary.dart';

class QbModSummaryMapper extends ClassMapperBase<QbModSummary> {
  QbModSummaryMapper._();

  static QbModSummaryMapper? _instance;
  static QbModSummaryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = QbModSummaryMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'QbModSummary';

  static int _$topicId(QbModSummary v) => v.topicId;
  static const Field<QbModSummary, int> _f$topicId = Field(
    'topicId',
    _$topicId,
  );
  static String _$title(QbModSummary v) => v.title;
  static const Field<QbModSummary, String> _f$title = Field(
    'title',
    _$title,
    opt: true,
    def: '',
  );
  static String _$category(QbModSummary v) => v.category;
  static const Field<QbModSummary, String> _f$category = Field(
    'category',
    _$category,
    opt: true,
    def: 'uncategorized',
  );
  static bool _$inModIndex(QbModSummary v) => v.inModIndex;
  static const Field<QbModSummary, bool> _f$inModIndex = Field(
    'inModIndex',
    _$inModIndex,
    opt: true,
    def: false,
  );
  static bool _$isArchivedModIndex(QbModSummary v) => v.isArchivedModIndex;
  static const Field<QbModSummary, bool> _f$isArchivedModIndex = Field(
    'isArchivedModIndex',
    _$isArchivedModIndex,
    opt: true,
    def: false,
  );
  static String? _$gameVersion(QbModSummary v) => v.gameVersion;
  static const Field<QbModSummary, String> _f$gameVersion = Field(
    'gameVersion',
    _$gameVersion,
    opt: true,
  );
  static String _$author(QbModSummary v) => v.author;
  static const Field<QbModSummary, String> _f$author = Field(
    'author',
    _$author,
    opt: true,
    def: '',
  );
  static int _$replies(QbModSummary v) => v.replies;
  static const Field<QbModSummary, int> _f$replies = Field(
    'replies',
    _$replies,
    opt: true,
    def: 0,
  );
  static int _$views(QbModSummary v) => v.views;
  static const Field<QbModSummary, int> _f$views = Field(
    'views',
    _$views,
    opt: true,
    def: 0,
  );
  static String? _$createdDate(QbModSummary v) => v.createdDate;
  static const Field<QbModSummary, String> _f$createdDate = Field(
    'createdDate',
    _$createdDate,
    opt: true,
  );
  static String? _$lastPostDate(QbModSummary v) => v.lastPostDate;
  static const Field<QbModSummary, String> _f$lastPostDate = Field(
    'lastPostDate',
    _$lastPostDate,
    opt: true,
  );
  static String? _$lastPostBy(QbModSummary v) => v.lastPostBy;
  static const Field<QbModSummary, String> _f$lastPostBy = Field(
    'lastPostBy',
    _$lastPostBy,
    opt: true,
  );
  static String _$topicUrl(QbModSummary v) => v.topicUrl;
  static const Field<QbModSummary, String> _f$topicUrl = Field(
    'topicUrl',
    _$topicUrl,
    opt: true,
    def: '',
  );
  static String? _$thumbnailPath(QbModSummary v) => v.thumbnailPath;
  static const Field<QbModSummary, String> _f$thumbnailPath = Field(
    'thumbnailPath',
    _$thumbnailPath,
    opt: true,
  );
  static DateTime _$scrapedAt(QbModSummary v) => v.scrapedAt;
  static const Field<QbModSummary, DateTime> _f$scrapedAt = Field(
    'scrapedAt',
    _$scrapedAt,
    opt: true,
  );
  static bool _$isWip(QbModSummary v) => v.isWip;
  static const Field<QbModSummary, bool> _f$isWip = Field(
    'isWip',
    _$isWip,
    opt: true,
    def: false,
  );
  static int? _$sourceBoard(QbModSummary v) => v.sourceBoard;
  static const Field<QbModSummary, int> _f$sourceBoard = Field(
    'sourceBoard',
    _$sourceBoard,
    opt: true,
  );

  @override
  final MappableFields<QbModSummary> fields = const {
    #topicId: _f$topicId,
    #title: _f$title,
    #category: _f$category,
    #inModIndex: _f$inModIndex,
    #isArchivedModIndex: _f$isArchivedModIndex,
    #gameVersion: _f$gameVersion,
    #author: _f$author,
    #replies: _f$replies,
    #views: _f$views,
    #createdDate: _f$createdDate,
    #lastPostDate: _f$lastPostDate,
    #lastPostBy: _f$lastPostBy,
    #topicUrl: _f$topicUrl,
    #thumbnailPath: _f$thumbnailPath,
    #scrapedAt: _f$scrapedAt,
    #isWip: _f$isWip,
    #sourceBoard: _f$sourceBoard,
  };
  @override
  final bool ignoreNull = true;

  static QbModSummary _instantiate(DecodingData data) {
    return QbModSummary(
      topicId: data.dec(_f$topicId),
      title: data.dec(_f$title),
      category: data.dec(_f$category),
      inModIndex: data.dec(_f$inModIndex),
      isArchivedModIndex: data.dec(_f$isArchivedModIndex),
      gameVersion: data.dec(_f$gameVersion),
      author: data.dec(_f$author),
      replies: data.dec(_f$replies),
      views: data.dec(_f$views),
      createdDate: data.dec(_f$createdDate),
      lastPostDate: data.dec(_f$lastPostDate),
      lastPostBy: data.dec(_f$lastPostBy),
      topicUrl: data.dec(_f$topicUrl),
      thumbnailPath: data.dec(_f$thumbnailPath),
      scrapedAt: data.dec(_f$scrapedAt),
      isWip: data.dec(_f$isWip),
      sourceBoard: data.dec(_f$sourceBoard),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static QbModSummary fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<QbModSummary>(map);
  }

  static QbModSummary fromJson(String json) {
    return ensureInitialized().decodeJson<QbModSummary>(json);
  }
}

mixin QbModSummaryMappable {
  String toJson() {
    return QbModSummaryMapper.ensureInitialized().encodeJson<QbModSummary>(
      this as QbModSummary,
    );
  }

  Map<String, dynamic> toMap() {
    return QbModSummaryMapper.ensureInitialized().encodeMap<QbModSummary>(
      this as QbModSummary,
    );
  }

  QbModSummaryCopyWith<QbModSummary, QbModSummary, QbModSummary> get copyWith =>
      _QbModSummaryCopyWithImpl<QbModSummary, QbModSummary>(
        this as QbModSummary,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return QbModSummaryMapper.ensureInitialized().stringifyValue(
      this as QbModSummary,
    );
  }

  @override
  bool operator ==(Object other) {
    return QbModSummaryMapper.ensureInitialized().equalsValue(
      this as QbModSummary,
      other,
    );
  }

  @override
  int get hashCode {
    return QbModSummaryMapper.ensureInitialized().hashValue(
      this as QbModSummary,
    );
  }
}

extension QbModSummaryValueCopy<$R, $Out>
    on ObjectCopyWith<$R, QbModSummary, $Out> {
  QbModSummaryCopyWith<$R, QbModSummary, $Out> get $asQbModSummary =>
      $base.as((v, t, t2) => _QbModSummaryCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class QbModSummaryCopyWith<$R, $In extends QbModSummary, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    int? topicId,
    String? title,
    String? category,
    bool? inModIndex,
    bool? isArchivedModIndex,
    String? gameVersion,
    String? author,
    int? replies,
    int? views,
    String? createdDate,
    String? lastPostDate,
    String? lastPostBy,
    String? topicUrl,
    String? thumbnailPath,
    DateTime? scrapedAt,
    bool? isWip,
    int? sourceBoard,
  });
  QbModSummaryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _QbModSummaryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, QbModSummary, $Out>
    implements QbModSummaryCopyWith<$R, QbModSummary, $Out> {
  _QbModSummaryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<QbModSummary> $mapper =
      QbModSummaryMapper.ensureInitialized();
  @override
  $R call({
    int? topicId,
    String? title,
    String? category,
    bool? inModIndex,
    bool? isArchivedModIndex,
    Object? gameVersion = $none,
    String? author,
    int? replies,
    int? views,
    Object? createdDate = $none,
    Object? lastPostDate = $none,
    Object? lastPostBy = $none,
    String? topicUrl,
    Object? thumbnailPath = $none,
    Object? scrapedAt = $none,
    bool? isWip,
    Object? sourceBoard = $none,
  }) => $apply(
    FieldCopyWithData({
      if (topicId != null) #topicId: topicId,
      if (title != null) #title: title,
      if (category != null) #category: category,
      if (inModIndex != null) #inModIndex: inModIndex,
      if (isArchivedModIndex != null) #isArchivedModIndex: isArchivedModIndex,
      if (gameVersion != $none) #gameVersion: gameVersion,
      if (author != null) #author: author,
      if (replies != null) #replies: replies,
      if (views != null) #views: views,
      if (createdDate != $none) #createdDate: createdDate,
      if (lastPostDate != $none) #lastPostDate: lastPostDate,
      if (lastPostBy != $none) #lastPostBy: lastPostBy,
      if (topicUrl != null) #topicUrl: topicUrl,
      if (thumbnailPath != $none) #thumbnailPath: thumbnailPath,
      if (scrapedAt != $none) #scrapedAt: scrapedAt,
      if (isWip != null) #isWip: isWip,
      if (sourceBoard != $none) #sourceBoard: sourceBoard,
    }),
  );
  @override
  QbModSummary $make(CopyWithData data) => QbModSummary(
    topicId: data.get(#topicId, or: $value.topicId),
    title: data.get(#title, or: $value.title),
    category: data.get(#category, or: $value.category),
    inModIndex: data.get(#inModIndex, or: $value.inModIndex),
    isArchivedModIndex: data.get(
      #isArchivedModIndex,
      or: $value.isArchivedModIndex,
    ),
    gameVersion: data.get(#gameVersion, or: $value.gameVersion),
    author: data.get(#author, or: $value.author),
    replies: data.get(#replies, or: $value.replies),
    views: data.get(#views, or: $value.views),
    createdDate: data.get(#createdDate, or: $value.createdDate),
    lastPostDate: data.get(#lastPostDate, or: $value.lastPostDate),
    lastPostBy: data.get(#lastPostBy, or: $value.lastPostBy),
    topicUrl: data.get(#topicUrl, or: $value.topicUrl),
    thumbnailPath: data.get(#thumbnailPath, or: $value.thumbnailPath),
    scrapedAt: data.get(#scrapedAt, or: $value.scrapedAt),
    isWip: data.get(#isWip, or: $value.isWip),
    sourceBoard: data.get(#sourceBoard, or: $value.sourceBoard),
  );

  @override
  QbModSummaryCopyWith<$R2, QbModSummary, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _QbModSummaryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

