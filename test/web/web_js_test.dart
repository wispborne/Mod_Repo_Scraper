import 'dart:io';

import 'package:test/test.dart';

/// Runs the viewer's JavaScript tests through Node's built-in test runner.
/// No package install or JavaScript test framework is needed.
void main() {
  test('viewer JavaScript tests', () async {
    final result = await Process.run(
      'node',
      const ['--test', 'test/web/routes_test.mjs', 'test/web/jobs_test.mjs', 'test/web/pending_test.mjs', 'test/web/mod_helpers_test.mjs', 'test/web/change_sides_test.mjs', 'test/web/search_results_test.mjs', 'test/web/run_record_test.mjs', 'test/web/history_steps_test.mjs', 'test/web/post_guide_marks_test.mjs', 'test/web/diff_words_test.mjs', 'test/web/log_lines_test.mjs', 'test/web/icons_test.mjs'],
      runInShell: Platform.isWindows,
    );

    expect(
      result.exitCode,
      0,
      reason: '${result.stdout}\n${result.stderr}',
    );
  });
}
