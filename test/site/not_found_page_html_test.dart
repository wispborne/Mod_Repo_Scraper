import 'dart:io';

import 'package:mod_repo_scraper/site/mod_id_store.dart';
import 'package:mod_repo_scraper/site/not_found_page_html.dart';
import 'package:mod_repo_scraper/site/public_data_builder.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// `404.html` is the site's own document with its head swapped, so a missing
/// address still has the site's header, footer, theme and scripts.
void main() {
  const shell = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <!--page-head-->
  <base href="./">
  <title>Starmodder 4: Starsector mods</title>
  <!--/page-head-->
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <main id="app"><!--page-body--><div class="loading">Loading…</div><!--/page-body--></main>
</body>
</html>
''';

  test('the head says not found, is not indexed, and loads from the root at any depth', () {
    final page = buildNotFoundPageHtml(shell)!;
    expect(page, contains('<base href="/">'));
    expect(page, contains('<title>Not found | Starmodder</title>'));
    expect(page, contains('<meta name="robots" content="noindex">'));
    expect(page, contains(notFoundMark));
    expect(page, isNot(contains('Starmodder 4: Starsector mods')));
    expect(page, contains('<link rel="stylesheet" href="style.css">'));
  });

  test('a shell without its marks gives no page, and the plain one carries the message', () {
    expect(buildNotFoundPageHtml('<html></html>'), isNull);
    expect(plainNotFoundPage(), contains(notFoundMessage));
    expect(plainNotFoundPage(), contains('<a href="/">'));
  });

  test('the message is word for word what was asked for', () {
    expect(
      notFoundMessage,
      'This mod may have been removed at the request of its owner...or it may never have existed in the first '
      'place. Or something else.',
    );
  });

  group('written by the site build', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('not_found_page'));
    tearDown(() => dir.deleteSync(recursive: true));

    PublicDataBuilder builderWith(String sitePath) => PublicDataBuilder(
          outputPath: p.join(dir.path, 'outputs'),
          idStore: ModIdStore(p.join(dir.path, 'data'))..load(),
          sitePath: sitePath,
        );

    test('from the site document', () async {
      final site = Directory(p.join(dir.path, 'site'))..createSync();
      File(p.join(site.path, 'index.html')).writeAsStringSync(shell);
      final builder = builderWith(site.path);
      await builder.write(builder.build(mods: const []));
      final page = File(p.join(builder.siteDir, notFoundFileName)).readAsStringSync();
      expect(page, contains(notFoundMark));
    });

    test('as a plain page when there is no site document', () async {
      final builder = builderWith(p.join(dir.path, 'nowhere'));
      await builder.write(builder.build(mods: const []));
      final page = File(p.join(builder.siteDir, notFoundFileName)).readAsStringSync();
      expect(page, contains(notFoundMessage));
    });
  });
}
