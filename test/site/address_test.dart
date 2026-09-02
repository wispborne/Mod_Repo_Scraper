import 'dart:io';

import 'package:test/test.dart';

/// Runs the dependency-free browser address module through Node's built-in
/// test runner. No package install or JavaScript test framework is needed.
void main() {
  test('public-site address behavior', () async {
    final result = await Process.run(
      'node',
      const ['--test', 'test/site/address_test.mjs'],
      runInShell: Platform.isWindows,
    );

    expect(
      result.exitCode,
      0,
      reason: '${result.stdout}\n${result.stderr}',
    );
  });
}
