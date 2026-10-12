import 'dart:io';

import 'package:test/test.dart';

/// Runs the public site's version comparison tests through Node's built-in
/// test runner, the same way `search_test.dart` runs the search tests.
void main() {
  test('public-site version comparison', () async {
    final result = await Process.run(
      'node',
      const ['--test', 'test/site/version_test.mjs'],
      runInShell: Platform.isWindows,
    );

    expect(
      result.exitCode,
      0,
      reason: '${result.stdout}\n${result.stderr}',
    );
  });
}
