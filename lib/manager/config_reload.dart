import 'dart:io';

import 'package:path/path.dart' as p;

import '../bot/common.dart';
import 'scraper_service.dart';

/// A file's modification time and size. Matching stamps are treated as
/// an unchanged file.
class FileStamp {
  final DateTime changed;
  final int size;

  const FileStamp(this.changed, this.size);

  /// The stamp of the file at [path], or null when there is no such file.
  static FileStamp? of(String path) {
    final stat = FileStat.statSync(path);
    if (stat.type == FileSystemEntityType.notFound) return null;
    return FileStamp(stat.modified, stat.size);
  }

  @override
  bool operator ==(Object other) =>
      other is FileStamp && other.changed == changed && other.size == size;

  @override
  int get hashCode => Object.hash(changed, size);
}

/// Reloads a changed config file before a job and rebuilds the services.
///
/// Building the services costs as much as starting the server (every cache is
/// read from disk again), so it only happens when the file's change time or
/// size changed. The data folder and the log level are taken from the settings
/// the server started with, whatever the file now says: the lock, the run
/// history and the logging were all set up from those, once.
class ConfigReload {
  final String configPath;

  /// The settings the server started with.
  final BotConfig startup;

  /// Builds a new runner from new settings.
  final Future<JobRunner> Function(BotConfig config) build;

  FileStamp? _seen;

  /// [seen] is the file's stamp from just before the server read it, so a
  /// change made while the server was starting is still noticed.
  ConfigReload({
    required this.configPath,
    required this.startup,
    required this.build,
    required FileStamp? seen,
  }) : _seen = seen;

  /// For [JobManager.beforeJob]: a new runner when the file changed and could
  /// be read, otherwise null. Reports the result through [log].
  ///
  /// When the file is gone or cannot be read, the last good settings stay in
  /// use and the next job tries again.
  Future<JobRunner?> beforeJob(void Function(String line) log) async {
    final name = p.basename(configPath);
    final now = FileStamp.of(configPath);
    if (now == _seen) return null;
    if (now == null) {
      log('$name is gone, so this job uses the settings read before.');
      return null;
    }

    final read = Common.readConfig(configFilePath: configPath);
    if (read == null) {
      log('$name changed but could not be read, so this job uses the '
          'settings read before.');
      return null;
    }
    for (final ignored in [
      if (read.qbDataPath != startup.qbDataPath) 'qb_data_path',
      if (read.logLevel != startup.logLevel) 'log_level',
    ]) {
      log('$ignored changed in $name. It takes effect after a restart.');
    }
    final config = read.copyWith(
      qbDataPath: startup.qbDataPath,
      logLevel: startup.logLevel,
    );

    final JobRunner runner;
    try {
      runner = await build(config);
    } catch (e) {
      log('$name changed, but the services could not be built from it, so '
          'this job uses the settings read before: $e');
      return null;
    }
    _seen = now;
    log('$name changed since the last job. This job and the ones after it use '
        'the new settings.');
    return runner;
  }
}
