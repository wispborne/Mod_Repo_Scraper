import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/site/site_changelog.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory folder;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('site_changelog_test');
  });
  tearDown(() => folder.deleteSync(recursive: true));

  void git(List<String> args) {
    final result = Process.runSync('git', args,
        workingDirectory: folder.path, runInShell: true);
    if (result.exitCode != 0) fail('git ${args.join(' ')}: ${result.stderr}');
  }

  void commit(String file, String message) {
    final target = File(p.join(folder.path, file));
    target.parent.createSync(recursive: true);
    target.writeAsStringSync('${DateTime.now().microsecondsSinceEpoch}');
    git(['add', '.']);
    // From a file, because a shell drops the line breaks in an argument.
    final messageFile = File(p.join(folder.parent.path,
        '${p.basename(folder.path)}-message.txt'))
      ..writeAsStringSync(message);
    git(['commit', '-q', '-F', messageFile.path]);
    messageFile.deleteSync();
  }

  test('lists only commits that changed the website, with their build numbers',
      () {
    git(['init', '-q']);
    git(['config', 'user.email', 'test@example.com']);
    git(['config', 'user.name', 'Test']);
    commit('site/app.js', 'First site change');
    commit('lib/bot/x.dart', 'Scraper only');
    commit('lib/site/y.dart',
        'Second site change\n\nWhat changed.\n\nCo-Authored-By: Someone <a@b.c>');

    final entries = SiteChangelog(folder.path).fromGit()!;

    expect(entries.map((e) => e['title']),
        ['Second site change', 'First site change']);
    expect(entries.map((e) => e['build']), [3, 1]);
    expect(entries.first['body'], 'What changed.');
    expect(entries.last.containsKey('body'), isFalse);
  });

  test('a released copy reads the file the build wrote, not git', () {
    final file = File(p.join(folder.path, 'site', 'changelog.json'));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode([
      {'build': 5, 'commit': 'abc1234', 'date': '2026-10-24', 'title': 'T'}
    ]));

    expect(SiteChangelog(folder.path).read(), [
      {'build': 5, 'commit': 'abc1234', 'date': '2026-10-24', 'title': 'T'}
    ]);
  });
}
