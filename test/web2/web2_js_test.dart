import 'dart:io';

import 'package:test/test.dart';

/// Runs the new viewer's JavaScript tests through Node's built-in test runner.
/// No package install or JavaScript test framework is needed.
void main() {
  test('new viewer JavaScript tests', () async {
    final result = await Process.run(
      'node',
      const ['--test', 'test/web2/routes_test.mjs', 'test/web2/jobs_test.mjs', 'test/web2/pending_test.mjs', 'test/web2/mod_helpers_test.mjs', 'test/web2/change_sides_test.mjs', 'test/web2/search_results_test.mjs'],
      runInShell: Platform.isWindows,
    );

    expect(
      result.exitCode,
      0,
      reason: '${result.stdout}\n${result.stderr}',
    );
  });
}
