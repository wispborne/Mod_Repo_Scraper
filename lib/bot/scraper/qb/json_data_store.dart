import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'models/mod_detail.dart';
import 'models/mod_summary.dart';

class JsonDataStore {
  final String basePath;
  final Logger _log;
  List<QbModSummary>? _indexCache;
  String? _lastSavedIndexJson;

  JsonDataStore(this.basePath, {Logger? logger})
      : _log = logger ?? Logger('JsonDataStore') {
    Directory(basePath).createSync(recursive: true);
  }

  // --- Mods Index ---

  Future<List<QbModSummary>> loadIndex() async {
    if (_indexCache != null) return _indexCache!;

    final path = p.join(basePath, 'mods-index.json');
    final file = File(path);
    if (!file.existsSync()) return [];

    final json = await file.readAsString();
    _lastSavedIndexJson = json;
    final list = jsonDecode(json) as List<dynamic>;
    _indexCache =
        list.map((e) => QbModSummaryMapper.fromMap(e as Map<String, dynamic>)).toList();
    return _indexCache!;
  }

  Future<void> saveIndex(List<QbModSummary> mods) async {
    final path = p.join(basePath, 'mods-index.json');
    final json = const JsonEncoder.withIndent('  ')
        .convert(mods.map((m) => m.toMap()).toList());
    _indexCache = mods;
    if (json == _lastSavedIndexJson) {
      _log.info('Mods index unchanged; skipping write (${mods.length} entries)');
      return;
    }
    await File(path).writeAsString(json);
    _lastSavedIndexJson = json;
    _log.info('Saved mods index with ${mods.length} entries');
  }

  // --- Mod Detail ---

  Future<QbModDetail?> loadDetail(int topicId) async {
    final path = p.join(basePath, 'mods', topicId.toString(), 'detail.json');
    final file = File(path);
    if (!file.existsSync()) return null;

    final json = await file.readAsString();
    return QbModDetailMapper.fromMap(
        jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> saveDetail(QbModDetail detail) async {
    final dir = p.join(basePath, 'mods', detail.topicId.toString());
    Directory(dir).createSync(recursive: true);

    final path = p.join(dir, 'detail.json');
    final json = const JsonEncoder.withIndent('  ')
        .convert(detail.toMap());
    await File(path).writeAsString(json);
    _log.fine('Saved detail for topic ${detail.topicId}');
  }

  // --- Thumbnail ---

  String? pickThumbnail(int topicId, List<ImageRef> images) {
    for (final img in images) {
      final url = img.originalUrl;
      if (url.toLowerCase().contains('shields.io')) continue;
      if (url.toLowerCase().contains('loading.gif')) continue;
      return 'ext:$url';
    }
    return null;
  }
}
