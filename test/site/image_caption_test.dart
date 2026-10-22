import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('gallery captions follow the reader AI settings', () async {
    final result = await Process.run(
      'node',
      const ['--test', 'test/site/image_caption_test.mjs'],
      runInShell: Platform.isWindows,
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });
}
