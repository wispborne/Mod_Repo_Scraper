import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('the browse page AI use filter', () async {
    final result = await Process.run(
      'node',
      const ['--test', 'test/site/ai_filter_test.mjs'],
      runInShell: Platform.isWindows,
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });
}
