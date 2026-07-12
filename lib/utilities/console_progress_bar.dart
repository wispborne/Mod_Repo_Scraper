import 'dart:io';
import 'dart:math' as math;

import 'package:mod_repo_scraper/timber/timber.dart';

/// A progress bar drawn to the console only.
///
/// Bars write straight to stdout and never go through the logger, so nothing
/// here lands in the log file. Several bars can be shown at once: they stack in
/// a sticky block pinned to the bottom of the console, and log lines print
/// above the block, which then redraws underneath. This lets the concurrent
/// Forum / Discord / Nexus scrapers each show their own bar at the same time.
///
/// Everything is a no-op when stdout is not a real terminal (output piped to a
/// file, or CI), so redirected output stays free of control codes.
class ConsoleProgressBar {
  final String label;
  final int barWidth;
  int _total;
  int _current = 0;
  String? _item;

  ConsoleProgressBar._(this.label, this._total, this.barWidth);

  /// Start a new bar and add it to the sticky console block. Returns a handle
  /// you drive with [update] / [tick] / [finish]. [total] may be 0 or unknown;
  /// pass the real total later via [update].
  factory ConsoleProgressBar.start(String label, int total,
      {int barWidth = 22}) {
    final bar = ConsoleProgressBar._(label, total, barWidth);
    _ProgressDisplay.instance.add(bar);
    return bar;
  }

  /// Set absolute progress. Optionally correct the [total] or set the [item]
  /// text shown after the bar.
  void update(int current, {int? total, String? item}) {
    _current = current;
    if (total != null) _total = total;
    if (item != null) _item = item;
    _ProgressDisplay.instance.redraw();
  }

  /// Advance progress by one step.
  void tick({String? item}) => update(_current + 1, item: item);

  /// Remove the bar from the console block.
  void finish() => _ProgressDisplay.instance.remove(this);

  /// Renders this bar as a single line (no newline, no leading control codes).
  String renderLine() {
    final total = _total;
    final current = total > 0 ? math.min(_current, total) : _current;
    final fraction = total > 0 ? current / total : 0.0;
    final filled = (fraction * barWidth).round().clamp(0, barWidth);
    final filledStr = '#' * filled;
    final emptyStr = '-' * (barWidth - filled);
    final counts = total > 0 ? '$current/$total' : '$current';
    final pct = total > 0 ? '  ${(fraction * 100).round()}%' : '';

    var line = '$label [$filledStr$emptyStr] $counts$pct';
    final item = _item;
    if (item != null && item.isNotEmpty) {
      line += '  $item';
    }

    // Keep it to a single terminal line so the block's line math stays correct.
    final cols = stdout.hasTerminal ? stdout.terminalColumns : 80;
    if (line.length > cols - 1) {
      line = '${line.substring(0, cols - 2)}…';
    }
    return line;
  }
}

/// Manages the sticky block of bars at the bottom of the console.
///
/// It hooks into the logger's console output so each log line first erases the
/// block, prints above where the block was, and then the block redraws below.
class _ProgressDisplay {
  static final _ProgressDisplay instance = _ProgressDisplay._();
  _ProgressDisplay._();

  final List<ConsoleProgressBar> _bars = [];
  int _renderedLines = 0;
  bool _hooksInstalled = false;

  bool get _enabled => stdout.hasTerminal;

  void add(ConsoleProgressBar bar) {
    if (!_enabled) return;
    _installHooks();
    _bars.add(bar);
    redraw();
  }

  void remove(ConsoleProgressBar bar) {
    if (!_enabled) return;
    if (!_bars.remove(bar)) return;
    redraw();
    if (_bars.isEmpty) _uninstallHooks();
  }

  /// Redraw the whole block in place (a bar advanced without a log line).
  void redraw() {
    if (!_enabled) return;
    final out = StringBuffer();
    if (_renderedLines > 0) out.write('\x1b[${_renderedLines}A'); // to block top
    out.write('\r\x1b[0J'); // clear from cursor to end of screen
    _writeBars(out);
    stdout.write(out.toString());
  }

  void _installHooks() {
    if (_hooksInstalled) return;
    DebugTree.beforeConsoleWrite = _eraseForLog;
    DebugTree.afterConsoleWrite = _redrawAfterLog;
    _hooksInstalled = true;
  }

  void _uninstallHooks() {
    DebugTree.beforeConsoleWrite = null;
    DebugTree.afterConsoleWrite = null;
    _hooksInstalled = false;
  }

  // Move to the top of the block and clear it so a log line can print there.
  void _eraseForLog() {
    if (!_enabled) return;
    final out = StringBuffer();
    if (_renderedLines > 0) out.write('\x1b[${_renderedLines}A');
    out.write('\r\x1b[0J');
    _renderedLines = 0;
    stdout.write(out.toString());
  }

  // Draw the block just below the cursor (right after a log line printed).
  void _redrawAfterLog() {
    if (!_enabled || _bars.isEmpty) return;
    final out = StringBuffer();
    _writeBars(out);
    stdout.write(out.toString());
  }

  // Writes each bar line followed by a newline, leaving the cursor on the line
  // below the block. Records how many lines the block now occupies.
  void _writeBars(StringBuffer out) {
    for (final bar in _bars) {
      out.write(bar.renderLine());
      out.write('\x1b[0K\n'); // clear rest of line, then newline
    }
    _renderedLines = _bars.length;
  }
}
