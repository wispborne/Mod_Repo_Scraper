/*
 * This file is distributed under the GPLv3. An informal description follows:
 * - Anyone can copy, modify and distribute this software as long as the other points are followed.
 * - You must include the license and copyright notice with each and every distribution.
 * - You may this software for commercial purposes.
 * - If you modify it, you must indicate changes made to the code.
 * - Any modifications of this code base MUST be distributed with the same license, GPLv3.
 * - This software is provided without warranty.
 * - The software author or license can not be held liable for any damages inflicted by the software.
 * The full license is available from <https://www.gnu.org/licenses/gpl-3.0.txt>.
 */

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'log_level.dart';

/// Logging for lazy people.
///
/// Wisp: Based upon Timber (https://github.com/JakeWharton/timber) and modified to work without Android.
abstract class Timber {
  static final _trees = <Tree>[];

  static List<Tree> get _treeArray => List.unmodifiable(_trees);

  static String findClassName() {
    final stackTrace = StackTrace.current.toString();
    final lines = stackTrace.split('\n');

    final fqcnIgnore = [
      'Timber',
      'Forest',
      'Tree',
      'DebugTree',
    ];

    final relevantLines = lines
        .where((line) => !fqcnIgnore.any((ignore) => line.contains(ignore)))
        .take(2)
        .map((line) {
      // Extract class and method from stack trace line
      final match = RegExp(r'#\d+\s+(.+?)\s+\(').firstMatch(line);
      return match?.group(1)?.split('.').last ?? '';
    }).where((s) => s.isNotEmpty);

    return relevantLines.join('->');
  }

  // Static forest methods
  static void v(String? message, [List<Object?>? args]) {
    for (var tree in _treeArray) {
      tree.v(message, args);
    }
  }

  static void vWithError(Object? t, String? message, [List<Object?>? args]) {
    for (var tree in _treeArray) {
      tree.vWithError(t, message, args);
    }
  }

  static void vError(Object? t) {
    for (var tree in _treeArray) {
      tree.vError(t);
    }
  }

  static void d(String? message, [List<Object?>? args]) {
    for (var tree in _treeArray) {
      tree.d(message, args);
    }
  }

  static void dWithError(Object? t, String? message, [List<Object?>? args]) {
    for (var tree in _treeArray) {
      tree.dWithError(t, message, args);
    }
  }

  static void dError(Object? t) {
    for (var tree in _treeArray) {
      tree.dError(t);
    }
  }

  static void i(String? message, [List<Object?>? args]) {
    for (var tree in _treeArray) {
      tree.i(message, args);
    }
  }

  static void iWithError(Object? t, String? message, [List<Object?>? args]) {
    for (var tree in _treeArray) {
      tree.iWithError(t, message, args);
    }
  }

  static void iError(Object? t) {
    for (var tree in _treeArray) {
      tree.iError(t);
    }
  }

  static void w(String? message, [List<Object?>? args]) {
    for (var tree in _treeArray) {
      tree.w(message, args);
    }
  }

  static void wWithError(Object? t, String? message, [List<Object?>? args]) {
    for (var tree in _treeArray) {
      tree.wWithError(t, message, args);
    }
  }

  static void wError(Object? t) {
    for (var tree in _treeArray) {
      tree.wError(t);
    }
  }

  static void e(String? message, [List<Object?>? args]) {
    for (var tree in _treeArray) {
      tree.e(message, args);
    }
  }

  static void eWithError(Object? t, String? message, [List<Object?>? args]) {
    for (var tree in _treeArray) {
      tree.eWithError(t, message, args);
    }
  }

  static void eError(Object? t) {
    for (var tree in _treeArray) {
      tree.eError(t);
    }
  }

  static void wtf(String? message, [List<Object?>? args]) {
    for (var tree in _treeArray) {
      tree.wtf(message, args);
    }
  }

  static void wtfWithError(Object? t, String? message, [List<Object?>? args]) {
    for (var tree in _treeArray) {
      tree.wtfWithError(t, message, args);
    }
  }

  static void wtfError(Object? t) {
    for (var tree in _treeArray) {
      tree.wtfError(t);
    }
  }

  static void log(LogLevel priority, String? message, [List<Object?>? args]) {
    for (var tree in _treeArray) {
      tree.log(priority, message, args);
    }
  }

  static void logWithError(LogLevel priority, Object? t, String? message,
      [List<Object?>? args]) {
    for (var tree in _treeArray) {
      tree.logWithError(priority, t, message, args);
    }
  }

  static void logError(LogLevel priority, Object? t) {
    for (var tree in _treeArray) {
      tree.logError(priority, t);
    }
  }

  static Tree asTree() {
    throw UnimplementedError('asTree not needed in Dart implementation');
  }

  /// Set a one-time tag for use on the next logging call.
  static void tag(String tag) {
    for (var tree in _treeArray) {
      tree._explicitTag = tag;
    }
  }

  /// Add a new logging tree.
  static void plant(Tree tree) {
    if (identical(tree, Timber)) {
      throw ArgumentError('Cannot plant Timber into itself.');
    }
    _trees.add(tree);
  }

  /// Remove a planted tree.
  static void uproot(Tree tree) {
    if (!_trees.remove(tree)) {
      throw ArgumentError('Cannot uproot tree which is not planted: $tree');
    }
  }

  /// Remove all planted trees.
  static void uprootAll() {
    _trees.clear();
  }

  /// Return a copy of all planted [Tree]s.
  static List<Tree> forest() {
    return List.unmodifiable(_trees);
  }

  static int get treeCount => _trees.length;
}

/// A facade for handling logging calls. Install instances via [plant].
abstract class Tree {
  String? _explicitTag;

  String? get tag {
    final tag = _explicitTag;
    if (tag != null) {
      _explicitTag = null;
    }
    return tag;
  }

  /// Log a verbose message with optional format args.
  void v(String? message, [List<Object?>? args]) {
    prepareLog(LogLevel.verbose, null, message, args);
  }

  /// Log a verbose exception and a message with optional format args.
  void vWithError(Object? t, String? message, [List<Object?>? args]) {
    prepareLog(LogLevel.verbose, t, message, args);
  }

  /// Log a verbose exception.
  void vError(Object? t) {
    prepareLog(LogLevel.verbose, t, null, null);
  }

  /// Log a debug message with optional format args.
  void d(String? message, [List<Object?>? args]) {
    prepareLog(LogLevel.debug, null, message, args);
  }

  /// Log a debug exception and a message with optional format args.
  void dWithError(Object? t, String? message, [List<Object?>? args]) {
    prepareLog(LogLevel.debug, t, message, args);
  }

  /// Log a debug exception.
  void dError(Object? t) {
    prepareLog(LogLevel.debug, t, null, null);
  }

  /// Log an info message with optional format args.
  void i(String? message, [List<Object?>? args]) {
    prepareLog(LogLevel.info, null, message, args);
  }

  /// Log an info exception and a message with optional format args.
  void iWithError(Object? t, String? message, [List<Object?>? args]) {
    prepareLog(LogLevel.info, t, message, args);
  }

  /// Log an info exception.
  void iError(Object? t) {
    prepareLog(LogLevel.info, t, null, null);
  }

  /// Log a warning message with optional format args.
  void w(String? message, [List<Object?>? args]) {
    prepareLog(LogLevel.warn, null, message, args);
  }

  /// Log a warning exception and a message with optional format args.
  void wWithError(Object? t, String? message, [List<Object?>? args]) {
    prepareLog(LogLevel.warn, t, message, args);
  }

  /// Log a warning exception.
  void wError(Object? t) {
    prepareLog(LogLevel.warn, t, null, null);
  }

  /// Log an error message with optional format args.
  void e(String? message, [List<Object?>? args]) {
    prepareLog(LogLevel.error, null, message, args);
  }

  /// Log an error exception and a message with optional format args.
  void eWithError(Object? t, String? message, [List<Object?>? args]) {
    prepareLog(LogLevel.error, t, message, args);
  }

  /// Log an error exception.
  void eError(Object? t) {
    prepareLog(LogLevel.error, t, null, null);
  }

  /// Log an assert message with optional format args.
  void wtf(String? message, [List<Object?>? args]) {
    prepareLog(LogLevel.wtf, null, message, args);
  }

  /// Log an assert exception and a message with optional format args.
  void wtfWithError(Object? t, String? message, [List<Object?>? args]) {
    prepareLog(LogLevel.wtf, t, message, args);
  }

  /// Log an assert exception.
  void wtfError(Object? t) {
    prepareLog(LogLevel.wtf, t, null, null);
  }

  /// Log at [priority] a message with optional format args.
  void log(LogLevel priority, String? message, [List<Object?>? args]) {
    prepareLog(priority, null, message, args);
  }

  /// Log at [priority] an exception and a message with optional format args.
  void logWithError(LogLevel priority, Object? t, String? message,
      [List<Object?>? args]) {
    prepareLog(priority, t, message, args);
  }

  /// Log at [priority] an exception.
  void logError(LogLevel priority, Object? t) {
    prepareLog(priority, t, null, null);
  }

  /// Return whether a message at [priority] should be logged.
  bool isLoggable(String? tag, LogLevel priority) => true;

  void prepareLog(
      LogLevel priority, Object? t, String? message, List<Object?>? args) {
    if (!shouldLog(priority)) return;

    // Consume tag even when message is not loggable so that next message is correctly tagged.
    final tag = this.tag;
    if (!isLoggable(tag, priority)) {
      return;
    }

    var msg = message;
    if (msg == null || msg.isEmpty) {
      if (t == null) {
        return; // Swallow message if it's null and there's no throwable.
      }
      msg = getStackTraceString(t);
    } else {
      if (args != null && args.isNotEmpty) {
        msg = formatMessage(msg, args);
      }
      if (t != null) {
        final throwableMessage = getThrowableMessage(t);
        if (throwableMessage != null) {
          msg += '\n$throwableMessage';
        }
        msg += '\n${getStackTraceString(t)}';
      }
    }

    logImpl(priority, tag, msg, t);
  }

  /// Formats a log message with optional arguments.
  String formatMessage(String message, List<Object?> args) {
    // Simple string interpolation
    var result = message;
    for (var arg in args) {
      result = result.replaceFirst('%s', arg.toString());
    }
    return result;
  }

  String getStackTraceString(Object t) {
    if (t is Error) {
      return t.stackTrace?.toString() ?? t.toString();
    } else if (t is Exception) {
      return t.toString();
    }
    return t.toString();
  }

  String? getThrowableMessage(Object t) {
    if (t is Error) {
      return t.toString();
    } else if (t is Exception) {
      return t.toString();
    }
    return null;
  }

  /// Write a log message to its destination. Called for all level-specific methods by default.
  ///
  /// @param priority Log level. See [LogLevel] for constants.
  /// @param tag Explicit or inferred tag. May be null.
  /// @param message Formatted log message.
  /// @param t Accompanying exceptions. May be null.
  void logImpl(LogLevel priority, String? tag, String message, Object? t);

  bool shouldLog(LogLevel priority);
}

/// A [Tree] for debug builds. Automatically infers the tag from the calling class.
class DebugTree extends Tree {
  final LogLevel minLogLevelToShow;
  final List<void Function(LogLevel level, String formattedMessage)> appenders;
  static const int maxLogLength = 4000;

  final StreamController<void> _logController = StreamController<void>();
  final Zone _logZone = Zone.current;

  DebugTree({
    required this.minLogLevelToShow,
    this.appenders = const [],
  });

  @override
  String? get tag => super.tag ?? Timber.findClassName();

  @override
  bool shouldLog(LogLevel priority) => priority >= minLogLevelToShow;

  @override
  void logImpl(LogLevel priority, String? tag, String message, Object? t) {
    if (!shouldLog(priority)) return;

    if (message.length < maxLogLength) {
      logToConsole(priority, tag, message, _getCurrentThreadName());
      return;
    }

    // Split by line, then ensure each line can fit into Log's maximum length.
    var i = 0;
    final length = message.length;
    while (i < length) {
      var newline = message.indexOf('\n', i);
      newline = newline != -1 ? newline : length;
      do {
        final end = (newline < i + maxLogLength) ? newline : i + maxLogLength;
        final part = message.substring(i, end);
        logToConsole(priority, tag, part, _getCurrentThreadName());
        i = end;
      } while (i < newline);
      i++;
    }
  }

  String formatLogString(
      LogLevel priority, String thread, String? tag, String message) {
    final logLevelSection =
        priority.name.isNotEmpty ? '${priority.name[0].toUpperCase()}/' : '';
    final tagSection = (tag != null && tag.isNotEmpty) ? '$tag/' : '';
    final now = DateTime.now().toUtc();
    final timestamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    return '$timestamp [$thread] $logLevelSection$tagSection $message';
  }

  void logToConsole(
      LogLevel priority, String? tag, String message, String thread) {
    try {
      _logZone.run(() {
        final formattedMsg = formatLogString(priority, thread, tag, message);
        if (priority < LogLevel.warn) {
          stdout.writeln(formattedMsg);
        } else {
          stderr.writeln(formattedMsg);
        }

        for (var appender in appenders) {
          appender(priority, formattedMsg);
        }
      });
    } catch (e) {
      stderr.writeln(e.toString());
    }
  }

  String _getCurrentThreadName() {
    return Isolate.current.debugName ?? 'main';
  }
}
