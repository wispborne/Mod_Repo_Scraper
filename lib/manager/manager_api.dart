import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../bot/scraper/author_aliases.dart';
import 'corrections_service.dart';
import 'job.dart';
import 'job_manager.dart';
import 'modrepo_service.dart';
import 'self_update.dart';
import 'settings_catalog.dart';
import 'settings_file.dart';

/// The HTTP face of the manager core: start a job, watch it, stop it, and read
/// what past runs did.
///
/// Requests and answers use the core's own shapes, so there is no second set of
/// models to keep in step. Every answer here is built by hand from a short list
/// of fields. No secret from `config.properties` is ever sent: the settings
/// route says only whether each token is set, and hides the user name,
/// password and query of an address. Other settings appear only in that
/// route's answer, and the data folder in the status too (the CLI needs it to
/// check both sides mean the same folder).
///
/// Every `POST` must come from the viewer's own page or the CLI: see
/// [sameOriginRefusal].
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

  /// Updates the server to the newest release. Null where nobody set it up,
  /// which answers as "this server cannot update itself".
  final SelfUpdate? selfUpdate;

  /// The config file edited by the Settings page. When null, requests return
  /// "this server has no settings to change".
  final SettingsFile? settings;

  /// Host names, besides the loopback ones, at which changes are accepted
  /// (`viewer_allowed_hosts`). Lower case.
  final Set<String> allowedHosts;

  ManagerApi({
    required this.manager,
    required String dataPath,
    this.selfUpdate,
    this.settings,
    Set<String> allowedHosts = const {},
  })  : dataPath = p.normalize(p.absolute(dataPath)),
        allowedHosts = {for (final h in allowedHosts) h.toLowerCase()};

  Handler get router {
    final r = Router();

    r.get('/status', _status);
    r.post('/jobs', _submitJob);
    r.post('/jobs/cancel', _cancelJob);
    r.get('/runs', _runs);
    r.get('/runs/<id>', _run);
    r.get('/runs/<id>/log', _runLog);
    r.get('/update', _updateStatus);
    r.post('/update', _startUpdate);
    r.get('/settings', _settings);
    r.post('/settings', _saveSettings);

    final routes = r.call;
    return (Request req) {
      if (req.method == 'POST') {
        final refused = sameOriginRefusal(req, allowedHosts: allowedHosts);
        if (refused != null) {
          return _error(refused, status: HttpStatus.forbidden);
        }
      }
      return routes(req);
    };
  }

  /// Host names that can only reach this machine.
  static const Set<String> _loopbackHosts = {'127.0.0.1', 'localhost', '::1'};

  /// The reason a POST request is rejected, or null if it is allowed.
  ///
  /// A page on another website open in the same browser can make the browser
  /// post to this server. Three rules stop it:
  /// - the request must be addressed to a loopback name, or to one of
  ///   [allowedHosts] (a name a reverse proxy passes on). This also stops a
  ///   website that points its own name at 127.0.0.1;
  /// - an `Origin` header, which every browser sends with a post, must name
  ///   this same host and port. For one of [allowedHosts] only the host is
  ///   compared, because the proxy changes the scheme and port: the browser
  ///   says `https://name`, and this server sees `http://name`;
  /// - the body must be JSON, which another website cannot send without this
  ///   server's permission. The CLI sends no `Origin`, so this is the rule that
  ///   holds for it.
  static String? sameOriginRefusal(Request req,
      {Set<String> allowedHosts = const {}}) {
    final target = req.requestedUri;
    final host = target.host.toLowerCase();
    final proxied = !_loopbackHosts.contains(host);
    if (proxied && !allowedHosts.contains(host)) {
      return 'Changes are only accepted at 127.0.0.1 or localhost. This '
          'request was sent to "${target.host}", so it was refused. To accept '
          'changes there, add ${target.host} to viewer_allowed_hosts in the '
          'config file and restart the server.';
    }

    final origin = req.headers['origin'];
    if (origin != null && !_sameOrigin(origin, target, hostOnly: proxied)) {
      return 'This request came from another website ($origin), so it was '
          "refused. Changes can only be made from the viewer's own page.";
    }

    if (req.mimeType != 'application/json') {
      return 'Changes must be sent as JSON (content-type: application/json). '
          'Nothing was done.';
    }
    return null;
  }

  static bool _sameOrigin(String origin, Uri target, {bool hostOnly = false}) {
    final parsed = Uri.tryParse(origin);
    if (parsed == null || parsed.host.isEmpty) return false;
    if (parsed.host.toLowerCase() != target.host.toLowerCase()) return false;
    return hostOnly ||
        (parsed.scheme == target.scheme && parsed.port == target.port);
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
    // The update stops the server, and with it any job started now.
    if (selfUpdate?.isRunning ?? false) {
      return _error(
          'The server is updating and will restart in a moment. Start the job '
          'once it is back.',
          status: HttpStatus.conflict);
    }
    final body = await req.readAsString();
    final JobRequest request;
    try {
      request = _parseJobRequest(body);
    } on _BadRequest catch (e) {
      return _error(e.message, status: HttpStatus.badRequest);
    }

    // One request at a time from here to the queue, so a save is checked
    // against every save sent before it, even one still on its way in.
    final previous = _submitting;
    final turn = Completer<void>();
    _submitting = turn.future;
    try {
      await previous;
      if (request.kind == JobKind.saveCorrections) {
        // Check before the browser removes these changes from its pending list.
        // Apply earlier saves first. The job checks again when it runs.
        final refusal = _correctionsService?.refusalOf(request.corrections, ahead: _correctionsAhead());
        if (refusal != null) return _error(refusal, status: HttpStatus.badRequest);
      }

      // Answers as soon as the job is on the queue. A scrape can take an
      // hour; nobody should hold a connection open for it.
      final record = await manager.enqueue(request);
      return _json(record.toMap());
    } finally {
      turn.complete();
    }
  }

  /// Ends when the request before has reached the queue. See [_submitJob].
  Future<void> _submitting = Future<void>.value();

  /// The corrections of each `saveCorrections` job running now or waiting to
  /// run, in the order they will run.
  List<List<Correction>> _correctionsAhead() => [
        for (final run in [if (manager.currentRun case final current?) current, ...manager.queuedRuns])
          if (run.request.kind == JobKind.saveCorrections) run.request.corrections,
      ];

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

    if (request.kind == JobKind.extractLlm &&
        request.topicIds.isEmpty &&
        request.discordThreadIds.isEmpty) {
      throw _BadRequest('An "extractLlm" job needs at least one topic id in '
          '"topicIds" or one Discord thread id in "discordThreadIds".');
    }
    if (request.kind != JobKind.extractLlm &&
        perTopicKinds.contains(request.kind) &&
        request.topicIds.isEmpty) {
      throw _BadRequest('A "${request.kind.name}" job needs at least one topic '
          'id in "topicIds".');
    }
    if (request.kind == JobKind.takeDown &&
        (request.takedownModId?.trim() ?? '').isEmpty &&
        !request.takedownAuthors.any((name) => name.trim().isNotEmpty)) {
      throw _BadRequest('A takedown needs a mod id in "takedownModId" or at '
          'least one name in "takedownAuthors".');
    }
    if (request.kind == JobKind.setRequirementNames &&
        !request.requirementChanges.any((c) => c.written.trim().isNotEmpty)) {
      throw _BadRequest('A setRequirementNames job needs at least one change in '
          '"requirementChanges".');
    }
    if (request.kind == JobKind.setAuthorAliases) {
      // Checked here too, so a list that cannot be saved never waits in the
      // queue only to be refused.
      try {
        checkAliasRows(request.authorAliasPeople, request.authorAliasNotSame);
      } on StateError catch (e) {
        throw _BadRequest(e.message);
      }
    }
    if (request.kind == JobKind.saveCorrections) {
      if (request.corrections.isEmpty) {
        throw _BadRequest('A saveCorrections job needs at least one correction in '
            '"corrections".');
      }
    }
    if (request.kind == JobKind.restoreTakedown &&
        (request.takedownEntry?.trim() ?? '').isEmpty) {
      throw _BadRequest('A restore needs the entry to remove in '
          '"takedownEntry".');
    }
    return request;
  }

  /// The service that saves corrections, found through the manager's runner
  /// so the check reads the same folders the job will. Null when the runner
  /// has none.
  CorrectionsService? get _correctionsService {
    final runner = manager.service;
    if (runner is CorrectionsService) return runner;
    if (runner is JobRouter) {
      final corrections = runner.corrections;
      if (corrections is CorrectionsService) return corrections;
    }
    return null;
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
    final pageSize = _pageSize(req);
    // A page past the end shows the last page. It is clamped before it is
    // multiplied, so a huge page number cannot overflow. The answer says
    // which page it gave.
    final lastPage = pageSize == 0 || all.isEmpty ? 0 : (all.length - 1) ~/ pageSize;
    final asked = _page(req);
    final page = asked > lastPage ? lastPage : asked;
    final List<RunRecord> slice;
    if (pageSize == 0) {
      slice = all;
    } else {
      final start = page * pageSize;
      slice = all.sublist(start, (start + pageSize).clamp(0, all.length));
    }
    return _json({
      'items': [for (final r in slice) r.toMap()],
      'total': all.length,
      'page': page,
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

  // --- Updating the server ---

  Future<Response> _updateStatus(Request req) async {
    final update = selfUpdate;
    if (update == null) {
      return _json({
        'supported': false,
        'reason': 'This server was started without a way to update itself.',
      });
    }
    return _json(await update.status());
  }

  Future<Response> _startUpdate(Request req) async {
    final update = selfUpdate;
    if (update == null) {
      return _error('This server was started without a way to update itself.',
          status: HttpStatus.conflict);
    }
    final refused = await update.start();
    if (refused != null) return _error(refused, status: HttpStatus.conflict);
    return _json({'started': true}, status: HttpStatus.accepted);
  }

  // --- Settings ---

  static const String _noSettings =
      'This server was started without a config file, so there are no '
      'settings to change here.';

  Response _settings(Request req) {
    final file = settings;
    if (file == null) return _error(_noSettings, status: HttpStatus.conflict);
    return _json(file.describe());
  }

  Future<Response> _saveSettings(Request req) async {
    final file = settings;
    if (file == null) return _error(_noSettings, status: HttpStatus.conflict);

    final Object? decoded;
    try {
      decoded = jsonDecode(await req.readAsString());
    } catch (_) {
      return _error('The settings could not be read: the body is not JSON.',
          status: HttpStatus.badRequest);
    }
    if (decoded is! Map<String, dynamic>) {
      return _error(
          'Send the settings as a JSON object with "set", "reset" and '
          '"clearSecrets".',
          status: HttpStatus.badRequest);
    }
    final Map<String, dynamic> body = decoded;

    final set = <String, String>{};
    final rawSet = body['set'];
    if (rawSet != null) {
      if (rawSet is! Map) {
        return _error('"set" must be an object of setting names and values.',
            status: HttpStatus.badRequest);
      }
      for (final entry in rawSet.entries) {
        final value = entry.value;
        if (value is! String && value is! num && value is! bool) {
          return _error(
              'The value for ${entry.key} must be text, a number, or true or '
              'false.',
              status: HttpStatus.badRequest);
        }
        set['${entry.key}'] = '$value';
      }
    }

    List<String>? names(String field) {
      final raw = body[field];
      if (raw == null) return const [];
      if (raw is! List || raw.any((e) => e is! String)) return null;
      return raw.cast<String>();
    }

    final reset = names('reset');
    final clearSecrets = names('clearSecrets');
    if (reset == null || clearSecrets == null) {
      return _error('"reset" and "clearSecrets" must be lists of setting names.',
          status: HttpStatus.badRequest);
    }

    final List<String> saved;
    try {
      saved = await file.save(
          set: set, reset: reset, clearSecrets: clearSecrets);
    } on SettingsRefused catch (e) {
      return _error(e.message, status: HttpStatus.badRequest);
    }
    return _json({
      'saved': saved,
      'jobRunning': manager.currentRun != null,
      'restartNeeded': [
        for (final key in saved)
          if (SettingsCatalog.byKey(key)?.restart ?? false) key,
      ],
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
