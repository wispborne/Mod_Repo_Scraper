import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/viewer/site_version.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  /// A folder standing in for the one a release is unpacked into.
  Directory emptyFolder() {
    final folder = Directory.systemTemp.createTempSync('site_version_test');
    addTearDown(() => folder.deleteSync(recursive: true));
    return folder;
  }

  void writeVersionFile(Directory folder, String contents) {
    final file = File(p.join(folder.path, 'site', 'version.json'));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }

  group('SiteVersion', () {
    test('reads what the build left in site/version.json', () {
      final folder = emptyFolder();
      writeVersionFile(folder,
          jsonEncode({'build': 48, 'commit': '28cbe0f', 'date': '2026-08-24'}));

      expect(
        SiteVersion(folder.path).read(),
        equals({'build': 48, 'commit': '28cbe0f', 'date': '2026-08-24'}),
      );
    });

    test('a folder with no file and no git checkout has nothing to say', () {
      expect(SiteVersion(emptyFolder().path).read(), isNull);
    });

    test('a half-written file is no answer at all', () {
      final folder = emptyFolder();
      writeVersionFile(folder, '{"build": 48, "comm');

      expect(SiteVersion(folder.path).read(), isNull);
    });

    test('a file of the wrong shape is no answer at all', () {
      final folder = emptyFolder();
      writeVersionFile(folder, jsonEncode({'version': '4.0.0'}));

      expect(SiteVersion(folder.path).read(), isNull);
    });

    test('this checkout falls back to asking git', () {
      final version = SiteVersion(Directory.current.path).read();
      // Skipped where the tests run from a copy that is not a checkout.
      if (version == null) return;

      expect(version['build'], isA<int>());
      expect(version['build'], greaterThan(0));
      expect(version['commit'], isA<String>());
      expect(version['commit'], isNotEmpty);
    });
  });
}
