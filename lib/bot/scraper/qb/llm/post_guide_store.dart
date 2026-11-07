import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:synchronized/synchronized.dart';

import 'post_guide_check.dart';

/// One post's saved guide check.
class PostGuideEntry {
  /// Of the prompt the LLM answered. A post whose prompt now gives another
  /// fingerprint is sent again.
  final String fingerprint;

  /// When the LLM answered, in UTC.
  final DateTime checkedAt;

  /// The model and endpoint that answered, when the client said.
  final String? model;
  final String? endpoint;

  /// The LLM's answers, by item id.
  final Map<String, GuideAnswer> llm;

  /// Code's answers, by item id. Worked out again on every run.
  final Map<String, GuideAnswer> rules;

  const PostGuideEntry({
    required this.fingerprint,
    required this.checkedAt,
    this.model,
    this.endpoint,
    required this.llm,
    required this.rules,
  });

  PostGuideEntry copyWith({Map<String, GuideAnswer>? rules}) => PostGuideEntry(
        fingerprint: fingerprint,
        checkedAt: checkedAt,
        model: model,
        endpoint: endpoint,
        llm: llm,
        rules: rules ?? this.rules,
      );

  Map<String, dynamic> toJson() => {
        'fingerprint': fingerprint,
        'checkedAt': checkedAt.toIso8601String(),
        if (model != null) 'model': model,
        if (endpoint != null) 'endpoint': endpoint,
        'llm': {for (final e in llm.entries) e.key: e.value.name},
        'rules': {for (final e in rules.entries) e.key: e.value.name},
      };

  /// Null when [json] is not a saved entry.
  static PostGuideEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final fingerprint = json['fingerprint'];
    final checkedAt = DateTime.tryParse('${json['checkedAt']}');
    if (fingerprint is! String || checkedAt == null) return null;
    Map<String, GuideAnswer> answers(Object? map) => {
          if (map is Map)
            for (final e in map.entries)
              if (GuideAnswer.read(e.value) case final answer?) '${e.key}': answer,
        };
    return PostGuideEntry(
      fingerprint: fingerprint,
      checkedAt: checkedAt.toUtc(),
      model: json['model'] as String?,
      endpoint: json['endpoint'] as String?,
      llm: answers(json['llm']),
      rules: answers(json['rules']),
    );
  }
}

/// The saved guide checks file as read back: every entry, plus what the last
/// pass over the saved posts found.
class PostGuideFile {
  final Map<int, PostGuideEntry> entries;

  /// When the last guide pass finished, in UTC. Null before the first one.
  final DateTime? lastPassAt;

  /// The threads the last pass found in scope: mod threads posted or edited
  /// since the guide. A thread here with no entry has not been checked yet.
  final List<int> lastPassTopics;

  const PostGuideFile(
      {this.entries = const {}, this.lastPassAt, this.lastPassTopics = const []});

  static PostGuideFile read(String text) {
    final decoded = jsonDecode(text);
    if (decoded is! Map) return const PostGuideFile();
    final topics = decoded['topics'];
    final lastPass = decoded['lastPass'];
    return PostGuideFile(
      entries: {
        if (topics is Map)
          for (final e in topics.entries)
            if ((int.tryParse('${e.key}'), PostGuideEntry.fromJson(e.value))
                case (final id?, final entry?))
              id: entry,
      },
      lastPassAt: lastPass is Map ? DateTime.tryParse('${lastPass['at']}')?.toUtc() : null,
      lastPassTopics: [
        if (lastPass is Map && lastPass['topics'] is List)
          for (final id in lastPass['topics'] as List)
            if (id is int) id,
      ],
    );
  }
}

/// The saved guide checks, in `<qb_data_path>/post-guide-checks.json`, keyed
/// by forum topic id. Saved after every check, because each one is a paid call
/// and there are only a few new mod threads a day.
class PostGuideStore {
  static const fileName = 'post-guide-checks.json';

  final String dataPath;
  final Logger _log = Logger('PostGuideStore');
  final Lock _writeLock = Lock();
  final Map<int, PostGuideEntry> _entries = {};
  DateTime? _lastPassAt;
  List<int> _lastPassTopics = const [];

  PostGuideStore(this.dataPath);

  File get _file => File(p.join(dataPath, fileName));

  int get length => _entries.length;

  PostGuideEntry? get(int topicId) => _entries[topicId];

  void put(int topicId, PostGuideEntry entry) => _entries[topicId] = entry;

  /// Records that a pass over the saved posts finished just now, and which
  /// threads it found in scope. Saved with the next [save].
  void finishPass(Iterable<int> topicsInScope) {
    _lastPassAt = DateTime.now().toUtc();
    _lastPassTopics = topicsInScope.toList()..sort();
  }

  /// Reads the saved checks. A file that cannot be read is logged and treated
  /// as empty; the posts are then checked again, which costs a few calls.
  Future<void> load() async {
    _entries.clear();
    final file = _file;
    if (!file.existsSync()) return;
    try {
      final saved = PostGuideFile.read(await file.readAsString());
      _entries.addAll(saved.entries);
      _lastPassAt = saved.lastPassAt;
      _lastPassTopics = saved.lastPassTopics;
    } catch (e) {
      _log.warning('Could not read ${file.path}; posts will be checked against '
          'the post guide again: $e');
    }
  }

  /// Writes every entry, through a `.tmp` file renamed over the old one.
  Future<void> save() => _writeLock.synchronized(() async {
        final file = _file;
        await file.parent.create(recursive: true);
        final ids = _entries.keys.toList()..sort();
        final text = const JsonEncoder.withIndent('  ').convert({
          'guideVersion': postGuideVersion,
          'guide': postGuideUrl,
          if (_lastPassAt != null)
            'lastPass': {
              'at': _lastPassAt!.toIso8601String(),
              'topics': _lastPassTopics,
            },
          'topics': {for (final id in ids) '$id': _entries[id]!.toJson()},
        });
        final temp = File('${file.path}.tmp');
        await temp.writeAsString(text);
        await temp.rename(file.path);
      });
}
