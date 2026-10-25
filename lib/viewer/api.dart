import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../bot/scraper/mod_repo_utils.dart';
import '../bot/scraper/qb/llm/picture_caption_store.dart';
import '../bot/scraper/qb/models/forum_date.dart';
import '../bot/scraper/qb/models/mod_detail.dart';
import '../bot/scraper/qb/models/post_extraction.dart';
import '../catalog/discord_posts.dart';
import '../catalog/mod_catalog.dart';
import '../catalog/takedowns.dart';
import 'bundle_views.dart';
import 'data_access.dart';
import 'merge_views.dart';
import 'site_version.dart';

/// Comparison side for current on-disk data; this is not a saved run id.
const String workingSideId = 'working';

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
    r.get('/topics/<id>/history', _topicHistory);
    r.get('/llm-test', _llmTest);

    r.get('/merge/runs', _mergeRuns);
    r.get('/merge/summary', _mergeSummary);
    r.get('/merge/groups', _mergeGroups);
    r.get('/merge/groups/<id>', _mergeGroupDetail);
    r.get('/merge/groups/<id>/fields', _mergeGroupFields);
    r.get('/merge/removals', _mergeRemovals);
    r.get('/merge/compare', _mergeCompare);

    r.get('/modrepo', _modRepo);
    r.get('/modrepo/<index>', _modRepoDetail);
    r.get('/discord/<threadId>', _discordThread);

    r.get('/bundle/meta', _bundleMeta);
    r.get('/bundle/mods', _bundleMods);
    r.get('/bundle/runs', _bundleRuns);
    r.get('/bundle/compare', _bundleCompare);

    r.get('/files', _files);
    r.get('/files/<id>', _fileSlice);
    r.get('/log', _log);

    r.get('/version', _version);

    r.get('/takedowns', _takedowns);
    r.get('/takedowns/preview', _takedownPreview);
    r.get('/takedowns/authors', _takedownAuthors);
    r.get('/takedowns/mods', _takedownMods);

    return r.call;
  }

  // --- Shared response helpers ---

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

  /// Defaults to 50 rows. An explicit `pageSize=0` requests every row.
  int _pageSize(Request req) {
    final asked = req.url.queryParameters['pageSize'];
    if (asked == null || asked.trim().isEmpty) return _defaultPageSize;
    final v = int.tryParse(asked.trim());
    if (v == null) return _defaultPageSize;
    if (v == 0) return 0;
    if (v < 0) return _defaultPageSize;
    return v > _maxPageSize ? _maxPageSize : v;
  }

  String _q(Request req) =>
      (req.url.queryParameters['q'] ?? '').trim().toLowerCase();

  /// Matches LLM and rule download URLs ignoring case, scheme and trailing slashes.
  static String _normUrl(String u) {
    var s = u.trim().toLowerCase();
    s = s.replaceFirst(RegExp(r'^https?://'), '');
    s = s.replaceFirst(RegExp(r'/+$'), '');
    return s;
  }

  /// Slices [rows] to the requested page and wraps them in the list envelope.
  /// A page size of 0 means every row, on one page.
  Map<String, dynamic> _paged(
      List<Map<String, dynamic>> rows, int page, int pageSize) {
    final total = rows.length;
    if (pageSize == 0) return _listEnvelope(rows, total, 0, 0);
    final start = page * pageSize;
    final slice = start >= total
        ? const <Map<String, dynamic>>[]
        : rows.sublist(start, (start + pageSize).clamp(0, total));
    return _listEnvelope(slice, total, page, pageSize);
  }

  // --- Topics ---

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
          !idx.author.toLowerCase().contains(q) &&
          !id.toString().contains(q)) {
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
      final llmMissedCount = llmDownloads
          .where((d) => !assumedUrls.contains(_normUrl(d.url)))
          .length;

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

      if (requested.isNotEmpty && !requested.every((f) => flags[f] == true)) {
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
          final da = parseForumDate(a['lastPostDate'] as String?);
          final db = parseForumDate(b['lastPostDate'] as String?);
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

  // --- Topic detail ---

  /// The Discord threads of every catalog mod that came from forum topic
  /// [topicId].
  List<String> _discordThreadIdsFor(int topicId) {
    final items = (data.modRepo?['items'] as List?) ?? const [];
    final ids = <String>[];
    for (final mod in items.whereType<Map>()) {
      final posts = ((mod['sourcePosts'] as List?) ?? const []).whereType<Map>();
      if (!posts.any((p) => p['kind'] == 'forum' && p['id'] == '$topicId')) continue;
      for (final post in posts) {
        final id = post['id'];
        if (post['kind'] == 'discord' && id is String && !ids.contains(id)) ids.add(id);
      }
    }
    return ids;
  }

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

    final discordThreads = [
      for (final threadId in _discordThreadIdsFor(topicId))
        if (data.discordPosts?.threads[threadId] case final thread?) thread,
    ];
    final pictureUrls = [
      for (final image in detail?.allImages ?? const <ImageRef>[]) image.originalUrl,
      for (final thread in discordThreads)
        for (final message in thread.messages)
          for (final image in message.images) image.url,
    ];

    return _json({
      'index': idx?.toMap(),
      'detail': detail?.toMap(),
      // The Discord threads the catalog joined to this topic, with each
      // message's pictures.
      'discordThreads': [
        for (final thread in discordThreads)
          {
            'threadId': thread.threadId,
            'name': thread.name,
            'images': [
              for (final message in thread.messages)
                for (final image in message.images) image.toMap(),
            ],
          },
      ],
      // What the model saw in each picture, by address: the whole saved
      // entry, plus whether it was made with today's caption prompt. The
      // endpoint is saved with its user name, password and query already cut
      // off.
      'pictureCaptions': {
        for (final url in pictureUrls)
          if (data.pictureCaption(url) case final seen?) url: _pictureSeen(seen),
      },
      'assumedDownloads': assumed?.map((c) => c.toJson()).toList(),
      // Use the bundle's LLM shape, with viewer-only classification and model
      // metadata from the cache. These extra fields are not published.
      'llm': llm == null
          ? null
          : {
              ...llm.toThreadData().toMap(),
              'isMod': llm.isMod,
              if (llm.model != null) 'model': llm.model,
              if (llm.endpoint != null) 'endpoint': llm.endpoint,
            },
    });
  }

  // --- One topic's history across the saved bundles ---

  /// Cached per-topic histories, invalidated when the snapshot ids change.
  final Map<int, Map<String, dynamic>> _topicHistoryCache = {};
  String _topicHistoryFor = '';

  Response _topicHistory(Request req, String id) {
    final topicId = int.tryParse(id);
    if (topicId == null) return _notFound('Topic id must be an integer.');

    // Newest first, as the list comes; the walk wants them the other way round.
    final saved = data.bundleRuns();
    if (saved.isEmpty) {
      return _missing('bundle-runs',
          'No snapshots have been saved yet. Run the scraper to save one.');
    }

    final stamp = saved.map((s) => s.id).join('|');
    if (stamp != _topicHistoryFor) {
      _topicHistoryCache.clear();
      _topicHistoryFor = stamp;
    }

    final held = _topicHistoryCache[topicId];
    if (held != null) return _json(held);

    final worked = topicHistory(
      topicId: topicId,
      snapshots: [
        for (final snapshot in saved.reversed)
          HistorySnapshot(snapshot.id, snapshot.savedAt,
              () => data.bundleRunUncached(snapshot.id)),
      ],
    );
    _topicHistoryCache[topicId] = worked;
    return _json(worked);
  }

  // --- LLM test report ---

  Response _llmTest(Request req) {
    final test = data.llmTest;
    if (test == null) {
      return _missing(
          'llm-test-output', 'Run the scraper with LLM test mode enabled.');
    }
    return _json(test);
  }

  // --- Merge explorer ---

  static const String _noMergeHint =
      'Run a merge, or a scrape with modrepo_merge_debug enabled.';

  /// The merge a request is about: the one named by `?run=`, the newest saved
  /// one, or — when no merges have been saved — the latest `merge-debug.json`.
  Map<String, dynamic>? _mergeOrNull([Request? req]) {
    final asked = req?.url.queryParameters['run']?.trim() ?? '';
    if (asked.isNotEmpty) return data.mergeRun(asked);

    final newest = data.mergeSnapshots.newestId;
    if (newest != null) {
      final saved = data.mergeRun(newest);
      if (saved != null) return saved;
    }
    return data.mergeDebug;
  }

  /// Which merge the answer came from, so the page can say so.
  String? _mergeSourceId(Request req) {
    final asked = req.url.queryParameters['run']?.trim() ?? '';
    if (asked.isNotEmpty) return asked;
    return data.mergeSnapshots.newestId;
  }

  Response _mergeRuns(Request req) {
    final runs = data.mergeRuns().map((s) => s.toMap()).toList();
    return _json({
      'items': runs,
      'total': runs.length,
      // True when there is a `merge-debug.json` to fall back on, so the picker
      // can offer "latest" even before any merge saved a snapshot.
      'hasLatestFile': data.mergeDebugExists,
    });
  }

  Response _mergeSummary(Request req) {
    final md = _mergeOrNull(req);
    if (md == null) {
      return _missing('merge-debug', _noMergeHint);
    }
    final groups = (md['groups'] as List?) ?? const [];
    final multi = groups
        .where((g) =>
            ((g as Map)['members'] as List?)?.length != null &&
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
      'runId': _mergeSourceId(req),
    });
  }

  static String _modName(Object? mod) =>
      ((mod as Map?)?['name'] as String?)?.toLowerCase() ?? '';

  static String _modAuthors(Object? mod) =>
      (((mod as Map?)?['authorsList'] as List?)?.join(' ') ?? '').toLowerCase();

  Response _mergeGroups(Request req) {
    final md = _mergeOrNull(req);
    if (md == null) {
      return _missing('merge-debug', _noMergeHint);
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
          !members.any(
              (m) => _modName(m).contains(q) || _modAuthors(m).contains(q))) {
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
    final md = _mergeOrNull(req);
    if (md == null) {
      return _missing('merge-debug', _noMergeHint);
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

  /// Before and after for one group: what each member had, field by field, and
  /// which of them the merged mod's value came from.
  Response _mergeGroupFields(Request req, String id) {
    final md = _mergeOrNull(req);
    if (md == null) {
      return _missing('merge-debug', _noMergeHint);
    }
    final groupIndex = int.tryParse(id);
    if (groupIndex == null) {
      return _notFound('Group id must be a whole number.');
    }

    final group = ((md['groups'] as List?) ?? const [])
        .cast<Map>()
        .where((g) => g['groupIndex'] == groupIndex)
        .firstOrNull;
    if (group == null) return _notFound('No group $groupIndex.');

    final decision = ((md['mergeDecisions'] as List?) ?? const [])
        .cast<Map>()
        .where((d) => d['groupIndex'] == groupIndex)
        .firstOrNull;

    return _json({
      'runId': _mergeSourceId(req),
      ...fieldsForGroup(group: group, decision: decision),
    });
  }

  /// What changed between two saved merges. The rows are worked out once and
  /// held, since a saved merge never changes.
  final Map<String, Map<String, dynamic>> _compareCache = {};

  Response _mergeCompare(Request req) {
    final a = req.url.queryParameters['a']?.trim() ?? '';
    final b = req.url.queryParameters['b']?.trim() ?? '';
    if (a.isEmpty || b.isEmpty) {
      return _notFound('Name two merges to compare, as a= and b=.');
    }

    final held = _compareCache['$a|$b'];
    final comparison = held ??
        () {
          final older = data.mergeRun(a);
          final newer = data.mergeRun(b);
          if (older == null || newer == null) return null;
          final worked = compareMerges(
            olderOutput: (older['finalOutput'] as List?) ?? const [],
            newerOutput: (newer['finalOutput'] as List?) ?? const [],
          );
          // Retain up to two comparisons for paging without recomputation.
          if (_compareCache.length >= 2) _compareCache.clear();
          _compareCache['$a|$b'] = worked;
          return worked;
        }();

    if (comparison == null) {
      return _missing('merge-debug',
          'One of those merges is no longer kept. Pick another.');
    }

    final q = _q(req);
    final kind = req.url.queryParameters['kind']?.trim() ?? '';
    var rows = (comparison['rows'] as List).cast<Map<String, dynamic>>();
    if (kind.isNotEmpty) {
      rows = rows.where((r) => r['kind'] == kind).toList();
    }
    if (q.isNotEmpty) {
      rows = rows
          .where((r) =>
              (r['name'] as String).toLowerCase().contains(q) ||
              (r['authors'] as String).toLowerCase().contains(q))
          .toList();
    }

    return _json({
      'a': a,
      'b': b,
      'sameCount': comparison['sameCount'],
      'addedCount': comparison['addedCount'],
      'goneCount': comparison['goneCount'],
      'changedCount': comparison['changedCount'],
      ..._paged(rows, _page(req), _pageSize(req)),
    });
  }

  Response _mergeRemovals(Request req) {
    final md = _mergeOrNull(req);
    if (md == null) {
      return _missing('merge-debug', _noMergeHint);
    }
    final kind = req.url.queryParameters['kind'] ?? 'preDedup';
    final key = switch (kind) {
      'preDedup' => 'preDedupEntries',
      'sameSource' => 'sameSourceDedupEntries',
      'validation' => 'validationRemovalEntries',
      _ => null,
    };
    if (key == null) {
      return _notFound('kind must be preDedup, sameSource, or validation.');
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

  // --- Saved bundles, and what changed between two of them ---

  Response _bundleRuns(Request req) {
    final runs = data.bundleRuns().map((s) => s.toMap()).toList();
    return _json({
      'items': runs,
      'total': runs.length,
      // Null without a mods index; the picker then omits the working side.
      'working': _workingSide(),
    });
  }

  /// What the picker shows for the working data on disk.
  Map<String, dynamic>? _workingSide() {
    final working = data.workingBundle();
    if (working == null) return null;
    return {
      'id': workingSideId,
      'updatedAt': data.workingLastWrittenAt?.toUtc().toIso8601String(),
      'indexCount': (working['index'] as List?)?.length,
    };
  }

  /// What changed between two saved bundles. Worked out once and held, since a
  /// saved bundle never changes.
  final Map<String, Map<String, dynamic>> _bundleCompareCache = {};

  /// Cache for a working-data comparison. [DataAccess.workingBundle] returns
  /// the same map until a file changes, so map identity detects invalidation.
  String? _workingCompareOlder;
  Map<String, dynamic>? _workingCompareFrom;
  Map<String, dynamic>? _workingCompareResult;

  Response _bundleCompare(Request req) {
    var a = req.url.queryParameters['a']?.trim() ?? '';
    final b = req.url.queryParameters['b']?.trim() ?? '';
    if (b.isEmpty) {
      return _notFound('Name two bundles to compare, as a= and b=.');
    }
    if (a == workingSideId) {
      return _notFound('The data on disk is always the newer of the two. '
          'Ask for it as b=$workingSideId.');
    }
    // An omitted older side uses the preceding snapshot, or the newest saved
    // snapshot when comparing working data.
    if (a.isEmpty) {
      final before = b == workingSideId
          ? data.bundleSnapshots.newestId
          : data.bundleRunBefore(b);
      if (before == null) {
        return _missing(
            'bundle-runs',
            b == workingSideId
                ? 'No snapshot has been saved yet. Publish the mod details to '
                    'compare them with the data on disk.'
                : 'That is the oldest snapshot still kept, so there is nothing to '
                    'compare it against.');
      }
      a = before;
    }

    final comparison =
        b == workingSideId ? _compareWithWorking(a) : _compareSaved(a, b);

    if (comparison == null) {
      return _missing(
          'bundle-runs',
          b == workingSideId
              ? 'There is no scraped data on disk to compare against yet.'
              : 'One of those snapshots is no longer kept. Pick another.');
    }

    final q = _q(req);
    final kind = req.url.queryParameters['kind']?.trim() ?? '';
    var rows = (comparison['rows'] as List).cast<Map<String, dynamic>>();
    if (kind.isNotEmpty) {
      rows = rows.where((r) => r['kind'] == kind).toList();
    }
    if (q.isNotEmpty) {
      rows = rows
          .where((r) =>
              (r['name'] as String).toLowerCase().contains(q) ||
              (r['authors'] as String).toLowerCase().contains(q))
          .toList();
    }

    return _json({
      'a': a,
      'b': b,
      if (b == workingSideId)
        'workingUpdatedAt':
            data.workingLastWrittenAt?.toUtc().toIso8601String(),
      'sameCount': comparison['sameCount'],
      'addedCount': comparison['addedCount'],
      'goneCount': comparison['goneCount'],
      'changedCount': comparison['changedCount'],
      ..._paged(rows, _page(req), _pageSize(req)),
    });
  }

  Map<String, dynamic>? _compareSaved(String a, String b) {
    final held = _bundleCompareCache['$a|$b'];
    if (held != null) return held;

    final older = data.bundleRun(a);
    final newer = data.bundleRun(b);
    if (older == null || newer == null) return null;
    final worked = compareBundles(older: older, newer: newer);
    // Retain up to two comparisons for paging without recomputation.
    if (_bundleCompareCache.length >= 2) _bundleCompareCache.clear();
    _bundleCompareCache['$a|$b'] = worked;
    return worked;
  }

  /// A saved bundle against the data on disk right now.
  Map<String, dynamic>? _compareWithWorking(String a) {
    final working = data.workingBundle();
    if (working == null) return null;

    if (_workingCompareOlder == a &&
        identical(_workingCompareFrom, working) &&
        _workingCompareResult != null) {
      return _workingCompareResult;
    }

    final older = data.bundleRun(a);
    if (older == null) return null;
    final worked = compareBundles(older: older, newer: working);
    _workingCompareOlder = a;
    _workingCompareFrom = working;
    _workingCompareResult = worked;
    return worked;
  }

  // --- ModRepo browser ---

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
    final mod = items[i];
    // The catalog records which Discord thread the mod came from; a record
    // without source posts falls back to reading it off the link.
    String? threadId;
    for (final post in (mod['sourcePosts'] as List?) ?? const []) {
      if (post is Map && post['kind'] == 'discord') {
        threadId = post['id'] as String?;
        break;
      }
    }
    if (threadId == null) {
      final urls = mod['urls'];
      final discordUrl = urls is Map ? urls['Discord'] as String? : null;
      final threads = data.discordPosts?.threads ?? const {};
      threadId = discordThreadIdOf(discordUrl,
          knownThreadIds: {...threads.keys, ...?data.discordLlmCache?.keys});
    }
    return _json({
      ...Map<String, dynamic>.from(mod),
      // Where the page can open the LLM's answer for the mod's Discord thread.
      if (threadId != null) 'discordThreadId': threadId,
    });
  }

  /// One saved Discord thread: the author's opening messages as the scrape
  /// saved them, the download rules' answer, and the LLM's answer.
  /// One saved picture entry as the viewer shows it: everything saved, plus
  /// whether it was made with today's caption prompt.
  static Map<String, dynamic> _pictureSeen(Map<String, dynamic> seen) => {
        ...seen,
        'current': seen['v'] == PictureCaptionStore.captionVersion,
      };

  Response _discordThread(Request req, String threadId) {
    final thread = data.discordPosts?.threads[threadId];
    final llm = data.discordLlmCache?[threadId];
    if (thread == null && llm == null) {
      return _notFound('No saved Discord thread or LLM answer for $threadId.');
    }
    return _json({
      'threadId': threadId,
      if (thread != null) 'thread': thread.toMap(),
      // Keyed by the address as the thread saved it, signature and all.
      'pictureCaptions': {
        for (final message in thread?.messages ?? const <DiscordOpeningMessage>[])
          for (final image in message.images)
            if (data.pictureCaption(image.url) case final seen?)
              image.url: _pictureSeen(seen),
      },
      'ruleDownloads': [
        for (final c in data.discordAssumedDownloads?[threadId] ?? const [])
          c.toJson(),
      ],
      if (llm != null)
        'llm': {
          'isMod': llm.isMod,
          'promptVersion': llm.promptVersion,
          'model': llm.model,
          'endpoint': llm.endpoint,
          'mods': [for (final m in llm.mods) m.toMap()],
        },
    });
  }

  // --- Bundle browser ---

  Response _bundleMeta(Request req) {
    final bundle = data.bundle;
    if (bundle == null) {
      return _missing(
          'forum-data-bundle', 'Run the QB scraper to publish the mod details.');
    }
    return _json({
      'updatedAt': bundle['updatedAt'],
      'meta': bundle['meta'],
    });
  }

  Response _bundleMods(Request req) {
    final bundle = data.bundle;
    if (bundle == null) {
      return _missing(
          'forum-data-bundle', 'Run the QB scraper to publish the mod details.');
    }
    final index = ((bundle['index'] as List?) ?? const []).cast<Map>();
    final details = (bundle['details'] as Map?) ?? const {};
    final assumed = (bundle['assumedDownloads'] as Map?) ?? const {};

    final q = _q(req);
    final rows = <Map<String, dynamic>>[];
    for (final row in index) {
      final title = (row['title'] as String?) ?? '';
      final author = (row['author'] as String?) ?? '';
      final idStr = row['topicId'].toString();
      if (q.isNotEmpty &&
          !title.toLowerCase().contains(q) &&
          !author.toLowerCase().contains(q) &&
          !idStr.contains(q)) {
        continue;
      }
      rows.add({
        'index': row,
        'detail': details[idStr],
        'assumedDownloads': assumed[idStr],
        'llm': row['llm'],
      });
    }
    return _json(_paged(rows, _page(req), _pageSize(req)));
  }

  // --- Raw files and log ---

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
      selected = lines.where((l) => l.toLowerCase().contains(q)).toList();
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

  // --- Which version is running ---

  /// An empty response omits the sidebar version when no build data is available.
  Response _version(Request req) =>
      _json(SiteVersion(data.rootDir).read() ?? const {});

  // --- Takedowns (read only: every change goes through a manager job) ---

  /// The takedown list, and what each entry left out of the last build.
  Response _takedowns(Request req) {
    final TakedownList list;
    try {
      list = TakedownList.read(data.dataDir);
    } on StateError catch (e) {
      // Said on the page, the way a missing file is.
      return _json({'error': e.message});
    }
    final matchesFile = File(p.join(data.dataDir, TakedownList.matchesFileName));
    Object? matches;
    if (matchesFile.existsSync()) {
      try {
        matches = jsonDecode(matchesFile.readAsStringSync());
      } catch (_) {
        matches = null;
      }
    }
    return _json({'list': list.toMap(), 'matches': matches});
  }

  /// Every person credited in the current catalog, most mods first, for the
  /// author box's suggestions. Spellings a takedown would treat as one person
  /// (`ModRepoUtils.samePerson`) are one suggestion: `name` is the spelling
  /// on the most mods, `others` the rest, `mods` how many mods credit any of
  /// them.
  Response _takedownAuthors(Request req) {
    final repo = data.modRepo;
    if (repo == null) return _missing('modrepo', 'Build the catalog first.');
    final modsByName = <String, Set<int>>{};
    final items = (repo['items'] as List?) ?? const [];
    for (var i = 0; i < items.length; i++) {
      for (final name in ((items[i] as Map)['authorsList'] as List?) ?? const []) {
        final clean = '$name'.trim();
        if (clean.isNotEmpty) modsByName.putIfAbsent(clean, () => {}).add(i);
      }
    }

    final names = modsByName.keys.toList()
      ..sort((a, b) => modsByName[b]!.length.compareTo(modsByName[a]!.length));
    final people = <List<String>>[];
    for (final name in names) {
      final person = people.where((p) => p.any((other) => ModRepoUtils.samePerson(name, other))).firstOrNull;
      if (person != null) {
        person.add(name);
      } else {
        people.add([name]);
      }
    }

    final rows = [
      for (final person in people)
        {
          'name': person.first,
          'others': person.skip(1).toList(),
          'mods': {for (final name in person) ...modsByName[name]!}.length,
        },
    ]..sort((a, b) {
        final byCount = (b['mods'] as int).compareTo(a['mods'] as int);
        return byCount != 0
            ? byCount
            : (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase());
      });
    return _json({'authors': rows});
  }

  /// Every mod and Collection page in the current catalog, for the mod box's
  /// suggestions: id, name, credited authors and source post keys
  /// (`forum:34161`), so a pasted thread link finds its mods too. Collection
  /// pages carry `collection: true`.
  Response _takedownMods(Request req) {
    final repo = data.modRepo;
    if (repo == null) return _missing('modrepo', 'Build the catalog first.');
    final catalog = ModCatalog.fromMap(repo);
    return _json({
      'mods': [
        for (final mod in catalog.mods)
          {
            'id': mod.id,
            'name': mod.mod.name,
            'authors': mod.mod.getAuthors(),
            'posts': [for (final post in mod.sourcePosts) if (post.id.isNotEmpty) post.ref.post.key],
          },
        for (final c in catalog.collections)
          {
            'id': c.id,
            'name': c.name,
            'authors': const <String>[],
            'posts': [c.post.post.key],
            'collection': true,
          },
      ],
    });
  }

  /// What a takedown would leave out: `mod=<id>`, or `author=<name>` given
  /// once per name. `post=<key>` lists the catalog's mods from one source
  /// post instead, for the thread page. Writes nothing.
  Response _takedownPreview(Request req) {
    final repo = data.modRepo;
    if (repo == null) return _missing('modrepo', 'Build the catalog first.');
    final catalog = ModCatalog.fromMap(repo);
    final query = req.url.queryParametersAll;
    final post = query['post']?.firstOrNull;
    if (post != null) return _json({'post': post, 'mods': catalogModsOnPost(catalog, post)});

    TakedownList current;
    try {
      current = TakedownList.read(data.dataDir);
    } on StateError {
      current = const TakedownList();
    }
    final preview = previewTakedown(
      catalog,
      modId: query['mod']?.firstOrNull,
      authors: query['author'] ?? const [],
      current: current,
    );
    return _json(preview, status: preview.containsKey('error') ? 400 : 200);
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
