import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'job.dart';
import 'job_manager.dart';

/// The HTTP face of the manager core: start a job, watch it, stop it, and read
/// what past runs did.
///
/// Requests and answers use the core's own shapes, so there is no second set of
/// models to keep in step. Nothing from `config.properties` is ever sent — every
/// answer here is built by hand from the short list of fields below, and the
/// data folder is the only setting that ever leaves the process (the CLI needs
/// it to check both sides mean the same folder).
class ManagerApi {
  /// The kinds that only make sense for named topics.
  static const Set<JobKind> perTopicKinds = {
    JobKind.rescrapeTopics,
    JobKind.resolveDownloads,
    JobKind.extractLlm,
  };

  static const int _maxPageSize = 500;
  static const int _defaultPageSize = 50;
  static const int _defaultLogTail = 200;

  final JobManager manager;

  /// The folder the manager writes to, as an absolute path.
  final String dataPath;

  ManagerApi({required this.manager, required String dataPath})
      : dataPath = p.normalize(p.absolute(dataPath));

  Handler get router {
    final r = Router();

    r.get('/status', _status);
    r.post('/jobs', _submitJob);
    r.post('/jobs/cancel', _cancelJob);
    r.get('/runs', _runs);
    r.get('/runs/<id>', _run);
    r.get('/runs/<id>/log', _runLog);

    return r.call;
  }

  /// The handler to mount when there is no manager — every route says so, in
  /// plain words, rather than looking broken.
  static Handler offHandler(String reason) => (Request request) => _json(
        {'managerOn': false, 'error': reason},
        status: HttpStatus.serviceUnavailable,
      );

  // --- Status ---

  Response _status(Request req) {
    final current = manager.currentRun;
    final live = manager.liveStatus;
    return _json({
      'managerOn': true,
      'dataPath': dataPath,
      'current': current == null
          ? null
          : {
              'record': current.toMap(),
              'phase': live?.phase,
              'item': live?.item,
              'itemsDone': live?.itemsDone ?? current.counters.itemsDone,
              'itemsTotal': live?.itemsTotal ?? current.counters.itemsTotal,
            },
      'queued': [for (final r in manager.queuedRuns) r.toMap()],
    });
  }

  // --- Jobs ---

  Future<Response> _submitJob(Request req) async {
    final body = await req.readAsString();
    final JobRequest request;
    try {
      request = _parseJobRequest(body);
    } on _BadRequest catch (e) {
      return _error(e.message, status: HttpStatus.badRequest);
    }

    // Answers as soon as the job is on the queue. A scrape can take an hour;
    // nobody should hold a connection open for it.
    final record = await manager.enqueue(request);
    return _json(record.toMap());
  }

  /// Reads a job request, or throws [_BadRequest] with something a person can
  /// act on.
  JobRequest _parseJobRequest(String body) {
    if (body.trim().isEmpty) {
      throw _BadRequest('Send a job to run, as a JSON object with a "kind".');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw _BadRequest('The job could not be read: the body is not JSON.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw _BadRequest('The job must be a JSON object, not a '
          '${decoded.runtimeType}.');
    }

    final kindName = decoded['kind'];
    final kinds = JobKind.values.map((k) => k.name).join(', ');
    if (kindName is! String || kindName.trim().isEmpty) {
      throw _BadRequest('The job needs a "kind". The kinds are: $kinds.');
    }
    if (!JobKind.values.any((k) => k.name == kindName)) {
      throw _BadRequest('"$kindName" is not a kind of job. The kinds are: '
          '$kinds.');
    }

    final JobRequest request;
    try {
      request = JobRequestMapper.fromMap(decoded);
    } catch (e) {
      throw _BadRequest('The job could not be read: $e');
    }

    if (perTopicKinds.contains(request.kind) && request.topicIds.isEmpty) {
      throw _BadRequest('A "${request.kind.name}" job needs at least one topic '
          'id in "topicIds".');
    }
    return request;
  }

  Future<Response> _cancelJob(Request req) async {
    String? expectedRunId;
    final body = await req.readAsString();
    if (body.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic> && decoded['runId'] is String) {
          expectedRunId = decoded['runId'] as String;
        }
      } catch (_) {
        return _error(
            'The stop request could not be read: the body is not JSON.',
            status: HttpStatus.badRequest);
      }
    }

    final current = manager.currentRun;
    if (current == null) {
      return _json({
        'cancelled': false,
        'message': 'Nothing is running, so there was nothing to stop.',
      });
    }
    if (expectedRunId != null && current.id != expectedRunId) {
      return _error(
        'Run $expectedRunId is no longer running, so nothing was stopped.',
        status: HttpStatus.conflict,
      );
    }
    manager.cancelCurrent();
    return _json({
      'cancelled': true,
      'runId': current.id,
      'message': 'Asked run ${current.id} to stop. It stops between topics and '
          'keeps everything it has already saved.',
    });
  }

  // --- Run history ---

  Response _runs(Request req) {
    // The store already keeps them newest first.
    final all = manager.history.records;
    final page = _page(req);
    final pageSize = _pageSize(req);
    final start = pageSize == 0 ? 0 : page * pageSize;
    final List<RunRecord> slice;
    if (pageSize == 0) {
      slice = all;
    } else if (start >= all.length) {
      slice = const [];
    } else {
      slice = all.sublist(start, (start + pageSize).clamp(0, all.length));
    }
    return _json({
      'items': [for (final r in slice) r.toMap()],
      'total': all.length,
      'page': pageSize == 0 ? 0 : page,
      'pageSize': pageSize,
    });
  }

  Response _run(Request req, String id) {
    final record = manager.history.byId(id);
    if (record == null) return _error('No run called "$id".');
    return _json(record.toMap());
  }

  Response _runLog(Request req, String id) {
    final record = manager.history.byId(id);
    if (record == null) return _error('No run called "$id".');

    // Only this run's own log file, named by its record — never a path from the
    // request.
    final file = File(p.join(manager.history.runsPath, record.logFileName));
    if (!file.existsSync()) {
      return _json({
        'runId': id,
        'lines': const <String>[],
        'total': 0,
        'returned': 0,
        'missing': true,
      });
    }

    final tail =
        int.tryParse(req.url.queryParameters['tail'] ?? '') ?? _defaultLogTail;
    final lines = file.readAsLinesSync();
    final selected = (tail > 0 && lines.length > tail)
        ? lines.sublist(lines.length - tail)
        : lines;
    return _json({
      'runId': id,
      'lines': selected,
      'total': lines.length,
      'returned': selected.length,
      'tail': tail,
    });
  }

  // --- Small helpers ---

  static Response _json(Object? body, {int status = 200}) => Response(
        status,
        body: jsonEncode(body),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  static Response _error(String message, {int status = HttpStatus.notFound}) =>
      _json({'error': message}, status: status);

  int _page(Request req) {
    final v = int.tryParse(req.url.queryParameters['page'] ?? '') ?? 0;
    return v < 0 ? 0 : v;
  }

  /// How many runs one page holds. `pageSize=0` means "all of them on one
  /// page", which somebody has to ask for on purpose.
  int _pageSize(Request req) {
    final asked = req.url.queryParameters['pageSize'];
    if (asked == null || asked.trim().isEmpty) return _defaultPageSize;
    final v = int.tryParse(asked.trim());
    if (v == null) return _defaultPageSize;
    if (v == 0) return 0;
    if (v < 0) return _defaultPageSize;
    return v > _maxPageSize ? _maxPageSize : v;
  }
}

/// A request we are refusing, with the reason to send back.
class _BadRequest implements Exception {
  final String message;

  _BadRequest(this.message);
}
