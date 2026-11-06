import 'dart:io';

import 'package:test/test.dart';

/// Runs the new viewer's routing tests through Node's built-in test runner.
/// No package install or JavaScript test framework is needed.
void main() {
  test('new viewer routing helpers', () async {
    final result = await Process.run(
      'node',
      const ['--test', 'test/web2/routes_test.mjs'],
      runInShell: Platform.isWindows,
    );

    expect(
      result.exitCode,
      0,
      reason: '${result.stdout}\n${result.stderr}',
    );
  });
}
