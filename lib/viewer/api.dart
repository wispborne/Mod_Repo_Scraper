import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../bot/scraper/qb/models/post_extraction.dart';
import 'data_access.dart';

/// The JSON API for the results viewer. Every handler reads through [DataAccess]
/// (mtime-cached, read-only) and returns either a list envelope, a single
/// object, or a "missing file" envelope. Never writes.
class ViewerApi {
  final DataAccess data;

  ViewerApi(this.data);

  Handler get router {
    final r = Router();

    r.get('/topics', _topics);
    r.get('/topics/<id>', _topicDetail);
    r.get('/llm-test', _llmTest);

    r.get('/merge/summary', _mergeSummary);
    r.get('/merge/groups', _mergeGroups);
    r.get('/merge/groups/<id>', _mergeGroupDetail);
    r.get('/merge/removals', _mergeRemovals);

    r.get('/modrepo', _modRepo);
    r.get('/modrepo/<index>', _modRepoDetail);

    r.get('/bundle/meta', _bundleMeta);
    r.get('/bundle/mods', _bundleMods);

    r.get('/files', _files);
    r.get('/files/<id>', _fileSlice);
    r.get('/log', _log);

    return r.call;
  }

  // --- Shared response helpers (1.5) ---

  static const int _maxPageSize = 500;
  static const int _defaultPageSize = 50;

  Response _json(Object? body, {int status = 200}) => Response(
        status,
        body: jsonEncode(body),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  /// HTTP 200 "the backing file is not on disk" envelope, so the UI can show a
  /// friendly message instead of an error.
  Response _missing(String fileId, String hint) =>
      _json({'missing': true, 'file': fileId, 'hint': hint});

  Response _notFound(String message) => _json({'error': message}, status: 404);

  Map<String, dynamic> _listEnvelope(
    List<Object?> items,
    int total,
    int page,
    int pageSize,
  ) =>
      {'items': items, 'total': total, 'page': page, 'pageSize': pageSize};

  int _page(Request req) {
    final v = int.tryParse(req.url.queryParameters['page'] ?? '') ?? 0;
    return v < 0 ? 0 : v;
  }

  int _pageSize(Request req) {
    final v = int.tryParse(req.url.queryParameters['pageSize'] ?? '') ??
        _defaultPageSize;
    if (v < 1) return _defaultPageSize;
    return v > _maxPageSize ? _maxPageSize : v;
  }

  String _q(Request req) =>
      (req.url.queryParameters['q'] ?? '').trim().toLowerCase();

  /// A light URL normalizer for comparing an LLM download's post URL against a
  /// rule candidate's source URL: lowercase, drop the scheme, drop trailing
  /// slashes. Good enough for the "rules missed" filter.
  static String _normUrl(String u) {
    var s = u.trim().toLowerCase();
    s = s.replaceFirst(RegExp(r'^https?://'), '');
    s = s.replaceFirst(RegExp(r'/+$'), '');
    return s;
  }

  /// Slices [rows] to the requested page and wraps them in the list envelope.
  Map<String, dynamic> _paged(
      List<Map<String, dynamic>> rows, int page, int pageSize) {
    final total = rows.length;
    final start = page * pageSize;
    final slice = start >= total
        ? const <Map<String, dynamic>>[]
        : rows.sublist(start, (start + pageSize).clamp(0, total));
    return _listEnvelope(slice, total, page, pageSize);
  }

  // --- Topics (2.1) ---

  Response _topics(Request req) {
    final index = data.index;
    if (index == null) {
      return _missing('mods-index', 'Run the QB scraper.');
    }
    final llm = data.llmCache ?? const {};
    final assumed = data.assumedDownloads ?? const {};
    final placeholders = data.placeholderDetailIds();

    final q = _q(req);
    final requested = (req.url.queryParameters['filters'] ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();

    final rows = <Map<String, dynamic>>[];
    for (final idx in index) {
      final id = idx.topicId;

      if (q.isNotEmpty &&
          !idx.title.toLowerCase().contains(q) &&
          !idx.author.toLowerCase().contains(q)) {
        continue;
      }

      final llmEntry = llm[id];
      final llmMods = llmEntry?.mods ?? const <LlmMod>[];
      final llmDownloads = [for (final m in llmMods) ...m.downloads];
      final assumedCandidates = assumed[id] ?? const [];

      final confidences = <String>[
        ...assumedCandidates.map((c) => c.confidence.name),
        ...llmDownloads.map((d) => d.confidence),
      ];
      // "Downloads the rules missed": an LLM download whose post URL is not in
      // this topic's rule-based assumedDownloads.
      final assumedUrls =
          assumedCandidates.map((c) => _normUrl(c.sourceUrl)).toSet();
      final llmMissedCount =
          llmDownloads.where((d) => !assumedUrls.contains(_normUrl(d.url))).length;

      final flags = <String, bool>{
        'noDownload': assumedCandidates.isEmpty && llmDownloads.isEmpty,
        'lowConfidenceOnly':
            confidences.isNotEmpty && confidences.every((c) => c == 'low'),
        'llmOnlyDownloads': llmMissedCount > 0,
        'multiMod': llmMods.length > 1,
        'placeholderDetail': placeholders.contains(id),
        'missingGameVersion':
            idx.gameVersion == null || idx.gameVersion!.trim().isEmpty,
        'wip': idx.isWip,
        'noLlmExtraction': llmEntry == null,
      };

      if (requested.isNotEmpty &&
          !requested.every((f) => flags[f] == true)) {
        continue;
      }

      final row = idx.toMap();
      row['filters'] = flags;
      row['downloadCounts'] = {
        'rules': assumedCandidates.length,
        'llm': llmDownloads.length,
        'llmMissed': llmMissedCount,
        'mods': llmMods.length,
      };
      rows.add(row);
    }

    _sortTopics(rows, req);

    return _json(_paged(rows, _page(req), _pageSize(req)));
  }

  static const _sortColumns = {
    'title',
    'author',
    'lastPostDate',
    'views',
    'replies',
    'gameVersion',
    'topicId',
  };

  void _sortTopics(List<Map<String, dynamic>> rows, Request req) {
    var sort = req.url.queryParameters['sort'] ?? 'lastPostDate';
    if (!_sortColumns.contains(sort)) sort = 'lastPostDate';
    final desc = (req.url.queryParameters['dir'] ?? 'desc') != 'asc';

    int cmp(Map<String, dynamic> a, Map<String, dynamic> b) {
      switch (sort) {
        case 'views':
        case 'replies':
        case 'topicId':
          return ((a[sort] as int?) ?? 0).compareTo((b[sort] as int?) ?? 0);
        case 'lastPostDate':
          final da = _parseForumDate(a['lastPostDate'] as String?);
          final db = _parseForumDate(b['lastPostDate'] as String?);
          if (da == null && db == null) return 0;
          if (da == null) return -1;
          if (db == null) return 1;
          return da.compareTo(db);
        default:
          return ((a[sort] as String?) ?? '')
              .toLowerCase()
              .compareTo(((b[sort] as String?) ?? '').toLowerCase());
      }
    }

    rows.sort((a, b) => desc ? cmp(b, a) : cmp(a, b));
  }

  static const _months = {
    'January': 1,
    'February': 2,
    'March': 3,
    'April': 4,
    'May': 5,
    'June': 6,
    'July': 7,
    'August': 8,
    'September': 9,
    'October': 10,
    'November': 11,
    'December': 12,
  };

  /// Parses the forum's "May 04, 2014, 01:33:25 AM" date form so the topic list
  /// can sort chronologically. Returns null when the string is missing or odd.
  static DateTime? _parseForumDate(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    final m = RegExp(
            r'^(\w+)\s+(\d{1,2}),\s+(\d{4}),\s+(\d{1,2}):(\d{2}):(\d{2})\s*([AP]M)?')
        .firstMatch(s.trim());
    if (m == null) return null;
    final month = _months[m.group(1)];
    if (month == null) return null;
    var hour = int.parse(m.group(4)!);
    final ampm = m.group(7);
    if (ampm == 'PM' && hour != 12) hour += 12;
    if (ampm == 'AM' && hour == 12) hour = 0;
    return DateTime(int.parse(m.group(3)!), month, int.parse(m.group(2)!), hour,
        int.parse(m.group(5)!), int.parse(m.group(6)!));
  }

  // --- Topic detail (2.2) ---

  Response _topicDetail(Request req, String id) {
    final topicId = int.tryParse(id);
    if (topicId == null) return _notFound('Topic id must be an integer.');

    final index = data.index;
    final idx = index?.where((e) => e.topicId == topicId).firstOrNull;
    final detail = data.loadDetail(topicId);
    final assumed = data.assumedDownloads?[topicId];
    final llm = data.llmCache?[topicId];

    if (idx == null && detail == null && assumed == null && llm == null) {
      return _notFound('No data for topic $topicId.');
    }

    return _json({
      'index': idx?.toMap(),
      'detail': detail?.toMap(),
      'assumedDownloads': assumed?.map((c) => c.toJson()).toList(),
      // The LLM output as its mods list — the same shape it has on the bundle's
      // index item, so the inspector renders both the same way. `isMod` is not
      // published on the bundle, but the viewer still shows it to explain why a
      // non-mod thread was kept, so it is grafted on from the cache entry here.
      'llm': llm == null
          ? null
          : {...llm.toThreadData().toMap(), 'isMod': llm.isMod},
    });
  }

  // --- LLM test report (2.6) ---

  Response _llmTest(Request req) {
    final test = data.llmTest;
    if (test == null) {
      return _missing('llm-test-output',
          'Run the scraper with LLM test mode enabled.');
    }
    return _json(test);
  }

  // --- Merge explorer (3.4) ---

  Map<String, dynamic>? _mergeOrNull() => data.mergeDebug;

  Response _mergeSummary(Request req) {
    final md = _mergeOrNull();
    if (md == null) {
      return _missing('merge-debug',
          'Run the scraper with modrepo_merge_debug enabled.');
    }
    final groups = (md['groups'] as List?) ?? const [];
    final multi = groups
        .where((g) => ((g as Map)['members'] as List?)?.length != null &&
            ((g)['members'] as List).length > 1)
        .length;
    return _json({
      'inputCount': md['inputCount'],
      'afterPreDedupCount': md['afterPreDedupCount'],
      'groupsCreated': md['groupsCreated'],
      'finalCount': md['finalCount'],
      'preDedupCount': (md['preDedupEntries'] as List?)?.length ?? 0,
      'groupCount': groups.length,
      'multiMemberGroupCount': multi,
      'singletonGroupCount': groups.length - multi,
      'sameSourceDedupCount':
          (md['sameSourceDedupEntries'] as List?)?.length ?? 0,
      'mergeDecisionCount': (md['mergeDecisions'] as List?)?.length ?? 0,
      'validationRemovalCount':
          (md['validationRemovalEntries'] as List?)?.length ?? 0,
      'finalOutputCount': (md['finalOutput'] as List?)?.length ?? 0,
      'timings': md['timings'] ?? const [],
    });
  }

  static String _modName(Object? mod) =>
      ((mod as Map?)?['name'] as String?)?.toLowerCase() ?? '';

  static String _modAuthors(Object? mod) =>
      (((mod as Map?)?['authorsList'] as List?)?.join(' ') ?? '')
          .toLowerCase();

  Response _mergeGroups(Request req) {
    final md = _mergeOrNull();
    if (md == null) {
      return _missing('merge-debug',
          'Run the scraper with modrepo_merge_debug enabled.');
    }
    final q = _q(req);
    final multiOnly =
        (req.url.queryParameters['multiOnly'] ?? '').toLowerCase() == 'true';

    final groups = ((md['groups'] as List?) ?? const []).cast<Map>();
    final rows = <Map<String, dynamic>>[];
    for (final g in groups) {
      final members = (g['members'] as List?) ?? const [];
      if (multiOnly && members.length <= 1) continue;
      if (q.isNotEmpty &&
          !members.any((m) =>
              _modName(m).contains(q) || _modAuthors(m).contains(q))) {
        continue;
      }
      rows.add({
        'groupIndex': g['groupIndex'],
        'memberCount': members.length,
        'members': members,
        'matchEntries': g['matchEntries'] ?? const [],
      });
    }

    return _json(_paged(rows, _page(req), _pageSize(req)));
  }

  Response _mergeGroupDetail(Request req, String id) {
    final md = _mergeOrNull();
    if (md == null) {
      return _missing('merge-debug',
          'Run the scraper with modrepo_merge_debug enabled.');
    }
    final groupIndex = int.tryParse(id);
    if (groupIndex == null) return _notFound('Group id must be an integer.');

    final group = ((md['groups'] as List?) ?? const [])
        .cast<Map>()
        .where((g) => g['groupIndex'] == groupIndex)
        .firstOrNull;
    if (group == null) return _notFound('No group $groupIndex.');

    final decision = ((md['mergeDecisions'] as List?) ?? const [])
        .cast<Map>()
        .where((d) => d['groupIndex'] == groupIndex)
        .firstOrNull;

    return _json({'group': group, 'decision': decision});
  }

  Response _mergeRemovals(Request req) {
    final md = _mergeOrNull();
    if (md == null) {
      return _missing('merge-debug',
          'Run the scraper with modrepo_merge_debug enabled.');
    }
    final kind = req.url.queryParameters['kind'] ?? 'preDedup';
    final key = switch (kind) {
      'preDedup' => 'preDedupEntries',
      'sameSource' => 'sameSourceDedupEntries',
      'validation' => 'validationRemovalEntries',
      _ => null,
    };
    if (key == null) {
      return _notFound(
          'kind must be preDedup, sameSource, or validation.');
    }
    final q = _q(req);
    final all = ((md[key] as List?) ?? const []).cast<Map>();
    final rows = <Map<String, dynamic>>[];
    for (final e in all) {
      if (q.isNotEmpty) {
        final hay = [
          _modName(e['kept']),
          _modAuthors(e['kept']),
          _modName(e['discarded']),
          _modAuthors(e['discarded']),
          _modName(e['mod']),
          _modAuthors(e['mod']),
        ].join(' ');
        if (!hay.contains(q)) continue;
      }
      rows.add(Map<String, dynamic>.from(e));
    }
    return _json(_paged(rows, _page(req), _pageSize(req)));
  }

  // --- ModRepo browser (4.1) ---

  Response _modRepo(Request req) {
    final repo = data.modRepo;
    if (repo == null) {
      return _missing('modrepo', 'Run the mod repo merge.');
    }
    final items = ((repo['items'] as List?) ?? const []).cast<Map>();
    final q = _q(req);
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < items.length; i++) {
      final mod = items[i];
      if (q.isNotEmpty) {
        final hay = [
          (mod['name'] as String?) ?? '',
          ((mod['authorsList'] as List?) ?? const []).join(' '),
        ].join(' ').toLowerCase();
        if (!hay.contains(q)) continue;
      }
      rows.add({
        'index': i,
        'name': mod['name'],
        'authorsList': mod['authorsList'] ?? const [],
        'gameVersionReq': mod['gameVersionReq'],
        'urls': mod['urls'],
        'sources': mod['sources'] ?? const [],
      });
    }
    return _json(_paged(rows, _page(req), _pageSize(req)));
  }

  Response _modRepoDetail(Request req, String index) {
    final repo = data.modRepo;
    if (repo == null) {
      return _missing('modrepo', 'Run the mod repo merge.');
    }
    final i = int.tryParse(index);
    final items = ((repo['items'] as List?) ?? const []).cast<Map>();
    if (i == null || i < 0 || i >= items.length) {
      return _notFound('No mod at index $index.');
    }
    return _json(items[i]);
  }

  // --- Bundle browser (4.3) ---

  Response _bundleMeta(Request req) {
    final bundle = data.bundle;
    if (bundle == null) {
      return _missing('forum-data-bundle',
          'Run the QB scraper to publish the bundle.');
    }
    return _json({
      'updatedAt': bundle['updatedAt'],
      'meta': bundle['meta'],
    });
  }

  Response _bundleMods(Request req) {
    final bundle = data.bundle;
    if (bundle == null) {
      return _missing('forum-data-bundle',
          'Run the QB scraper to publish the bundle.');
    }
    final index = ((bundle['index'] as List?) ?? const []).cast<Map>();
    final details = (bundle['details'] as Map?) ?? const {};
    final assumed = (bundle['assumedDownloads'] as Map?) ?? const {};

    final q = _q(req);
    final rows = <Map<String, dynamic>>[];
    for (final row in index) {
      final title = (row['title'] as String?) ?? '';
      final author = (row['author'] as String?) ?? '';
      if (q.isNotEmpty &&
          !title.toLowerCase().contains(q) &&
          !author.toLowerCase().contains(q)) {
        continue;
      }
      final idStr = row['topicId'].toString();
      rows.add({
        'index': row,
        'detail': details[idStr],
        'assumedDownloads': assumed[idStr],
        // The LLM output now lives on the index item as its `llm` field (a mods
        // list), not a separate top-level map.
        'llm': row['llm'],
      });
    }
    return _json(_paged(rows, _page(req), _pageSize(req)));
  }

  // --- Raw files and log (4.6, 4.7) ---

  Response _files(Request req) {
    final items = <Map<String, dynamic>>[];
    for (final entry in data.allowlist) {
      final exists = entry.file.existsSync();
      items.add({
        'id': entry.id,
        'path': entry.file.path,
        'exists': exists,
        'size': exists ? entry.file.lengthSync() : null,
        'mtime': exists
            ? entry.file.statSync().modified.toUtc().toIso8601String()
            : null,
        'hint': entry.hint,
      });
    }
    return _json(_listEnvelope(items, items.length, 0, items.length));
  }

  static const int _defaultSlice = 256 * 1024;

  Response _fileSlice(Request req, String id) {
    final entry = data.allowlistById(id);
    if (entry == null) return _notFound('Unknown file id "$id".');
    if (!entry.file.existsSync()) {
      return _missing(entry.id, entry.hint);
    }

    final totalSize = entry.file.lengthSync();
    var offset = int.tryParse(req.url.queryParameters['offset'] ?? '') ?? 0;
    if (offset < 0) offset = 0;
    if (offset > totalSize) offset = totalSize;
    var length =
        int.tryParse(req.url.queryParameters['length'] ?? '') ?? _defaultSlice;
    if (length < 0) length = 0;
    final end = (offset + length).clamp(0, totalSize);

    final raf = entry.file.openSync();
    String content;
    try {
      raf.setPositionSync(offset);
      final bytes = raf.readSync(end - offset);
      content = utf8.decode(bytes, allowMalformed: true);
    } finally {
      raf.closeSync();
    }

    return _json({
      'content': content,
      'offset': offset,
      'length': end - offset,
      'totalSize': totalSize,
      'eof': end >= totalSize,
    });
  }

  Response _log(Request req) {
    final entry = data.allowlistById('log')!;
    if (!entry.file.existsSync()) {
      return _missing(entry.id, entry.hint);
    }
    final q = _q(req);
    final tail = int.tryParse(req.url.queryParameters['tail'] ?? '') ?? 500;

    final lines = entry.file.readAsLinesSync();
    var selected = lines;
    if (q.isNotEmpty) {
      selected =
          lines.where((l) => l.toLowerCase().contains(q)).toList();
    }
    final total = selected.length;
    if (tail > 0 && selected.length > tail) {
      selected = selected.sublist(selected.length - tail);
    }
    return _json({
      'lines': selected,
      'total': total,
      'returned': selected.length,
      'tail': tail,
    });
  }
}

/// A small extension so handlers can read the first match or null cleanly.
extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
