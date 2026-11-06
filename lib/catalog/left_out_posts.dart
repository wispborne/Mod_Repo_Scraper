import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Why the catalog made no listing from a saved forum topic.
enum LeftOutReason {
  /// The LLM said it is not a mod and the rules found nothing to download in
  /// it (`keepThreadInCatalog`).
  notModNoDownload,

  /// The LLM said it is not a mod and its title names no game version
  /// (`keepThreadInBundle`). The bundle leaves it out too.
  notModNoGameVersion,

  /// Only the topic's title was saved, not its post, and the mod index does
  /// not list it.
  noSavedPost;

  /// The reason in one sentence for the viewer.
  String get sentence => switch (this) {
        notModNoDownload => 'The LLM says it is not a mod and nothing can be downloaded.',
        notModNoGameVersion => 'The LLM says it is not a mod and its title has no game version.',
        noSavedPost => 'Only its title was saved, not the post.',
      };
}

/// The forum topics one catalog build left out, with why, and the mods that
/// made no listing because they only point to a forum topic of their own.
/// Saved beside the takedown report in the QB data folder for the viewer, so it
/// can say what became of a post. Never published.
class LeftOutPosts {
  static const String fileName = 'catalog-left-out.json';

  final DateTime builtAt;

  /// By forum topic id.
  final Map<String, LeftOutReason> topics;

  /// The key of the ref each pointing mod would have had
  /// (`forum:36175#Some Mod`) to the key of the topic it links to
  /// (`forum:12345`).
  final Map<String, String> pointers;

  const LeftOutPosts({required this.builtAt, this.topics = const {}, this.pointers = const {}});

  Map<String, dynamic> toMap() => {
        'builtAt': builtAt.toUtc().toIso8601String(),
        'topics': {
          for (final key in topics.keys.toList()..sort()) key: topics[key]!.name,
        },
        'pointers': {
          for (final key in pointers.keys.toList()..sort()) key: pointers[key]!,
        },
      };

  /// Reads the map [toMap] wrote. Unknown reasons are skipped.
  factory LeftOutPosts.fromMap(Map<String, dynamic> map) => LeftOutPosts(
        builtAt: DateTime.tryParse('${map['builtAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
        topics: {
          for (final MapEntry(:key, :value) in ((map['topics'] as Map?) ?? const {}).entries)
            if (LeftOutReason.values.where((r) => r.name == value).firstOrNull case final reason?) '$key': reason,
        },
        pointers: {
          for (final MapEntry(:key, :value) in ((map['pointers'] as Map?) ?? const {}).entries)
            if (value is String) '$key': value,
        },
      );

  /// Writes [fileName] in [dataPath], through a temporary file.
  void write(String dataPath) {
    final file = File(p.join(dataPath, fileName));
    file.parent.createSync(recursive: true);
    final temp = File('${file.path}.tmp');
    temp.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(toMap()));
    temp.renameSync(file.path);
  }
}
