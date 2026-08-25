import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/site/models/mod_release.dart';
import 'package:mod_repo_scraper/site/models/public_mod.dart';
import 'package:mod_repo_scraper/site/models/public_mod_detail.dart';
import 'package:test/test.dart';

/// The hand-written example files under `site/sample-data/` are what the
/// website is built against before the real files exist. If one of them drifts
/// from the models, the site is being built against a shape the scraper will
/// never produce — so every sample has to survive a round trip through its own
/// model with nothing added, dropped or changed.
void main() {
  Map<String, dynamic> readJson(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path is missing');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  test('mods.json parses back into PublicModList without loss', () {
    final raw = readJson('site/sample-data/mods.json');
    final parsed = PublicModListMapper.fromMap(raw);

    expect(parsed.mods, hasLength(4));
    expect(parsed.toMap(), equals(raw));
  });

  test('updates.json parses back into ModReleaseFeed without loss', () {
    final raw = readJson('site/sample-data/updates.json');
    final parsed = ModReleaseFeedMapper.fromMap(raw);

    expect(parsed.releases, hasLength(2));
    expect(parsed.toMap(), equals(raw));
  });

  test('every per-mod file parses back into PublicModDetail without loss', () {
    final files = Directory('site/sample-data/mods')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();
    expect(files, hasLength(4));

    for (final file in files) {
      final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final parsed = PublicModDetailMapper.fromMap(raw);
      expect(parsed.toMap(), equals(raw), reason: '${file.path} lost data');
    }
  });

  test('the samples cover a mod published from somebody else\'s thread', () {
    final threadOnly = PublicModDetailMapper.fromMap(
        readJson('site/sample-data/mods/lost-sector.json'));

    // The site has to be seen with one of these while it is being worked on,
    // or the "part of <thread>" line is written blind.
    expect(threadOnly.partOfThreadTitle, "Hartley's Miscellaneous Mods");
    expect(threadOnly.listing.partOfThreadTitle, threadOnly.partOfThreadTitle);
    expect(threadOnly.listing.sources, ['forum']);
    expect(threadOnly.downloads, isNotEmpty);
    // Its thread is about four mods, so the post is nobody's description.
    expect(threadOnly.descriptionIsGenerated, isTrue);
    expect(threadOnly.descriptionHtml, isNull);

    // Every other sample is a merged mod, and a merged mod never carries it.
    for (final id in const ['nexerelin', 'quality-captains', 'industrial-evolution']) {
      final merged =
          PublicModDetailMapper.fromMap(readJson('site/sample-data/mods/$id.json'));
      expect(merged.partOfThreadTitle, isNull, reason: '$id is a merged mod');
      expect(merged.listing.partOfThreadTitle, isNull, reason: '$id is a merged mod');
    }
  });

  test('the samples cover a full mod, a Discord-only mod and one with add-ons',
      () {
    final full =
        PublicModDetailMapper.fromMap(readJson('site/sample-data/mods/nexerelin.json'));
    expect(full.forumUrl, isNotNull);
    expect(full.changelog, isNotEmpty);
    expect(full.downloads, isNotEmpty);

    final discordOnly = PublicModDetailMapper.fromMap(
        readJson('site/sample-data/mods/quality-captains.json'));
    expect(discordOnly.forumUrl, isNull);
    expect(discordOnly.discordUrl, isNotNull);
    expect(discordOnly.changelog, isEmpty);
    expect(discordOnly.listing.saveCompatible, isNull);

    final withAddons = PublicModDetailMapper.fromMap(
        readJson('site/sample-data/mods/industrial-evolution.json'));
    expect(withAddons.addons, hasLength(1));
    expect(withAddons.addons.single.requires, 'Industrial.Evolution');
  });

  test('the samples cover a tidied name and a formatted description', () {
    final full = PublicModDetailMapper.fromMap(
        readJson('site/sample-data/mods/nexerelin.json'));
    expect(full.listing.name, contains('['),
        reason: 'one sample has to carry a raw thread title, or the site is '
            'never seen with one');
    expect(full.listing.displayName, 'Nexerelin');
    expect(full.descriptionHtml, contains('<p>'));
  });

  test('every mod in the list has a per-mod file, and the two agree', () {
    final list = PublicModListMapper.fromMap(readJson('site/sample-data/mods.json'));

    for (final mod in list.mods) {
      final detail = PublicModDetailMapper.fromMap(
          readJson('site/sample-data/mods/${mod.id}.json'));
      expect(detail.listing.toMap(), equals(mod.toMap()),
          reason: '${mod.id} is written two different ways');
    }
  });
}
