import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('the public site filter sets and saved filters', () async {
    final result = await Process.run(
      'node',
      const ['--test', 'test/site/filter_set_test.mjs'],
      runInShell: Platform.isWindows,
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });
}
