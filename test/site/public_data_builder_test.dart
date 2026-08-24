import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/bot/scraper/qb/models/assumed_download.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/forum_data_bundle.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_summary.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/post_extraction.dart';
import 'package:mod_repo_scraper/bot/scraper/scraped_mod.dart';
import 'package:mod_repo_scraper/site/mod_id_store.dart';
import 'package:mod_repo_scraper/site/models/public_mod.dart';
import 'package:mod_repo_scraper/site/public_data_builder.dart';
import 'package:mod_repo_scraper/site/release_state_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late ModIdStore idStore;
  late PublicDataBuilder builder;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('public_site');
    idStore = ModIdStore(p.join(dir.path, 'data'))..load();
    builder = PublicDataBuilder(
      outputPath: p.join(dir.path, 'outputs'),
      idStore: idStore,
    );
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  /// A merged mod with a forum thread, as the ModRepo pipeline produces one.
  ScrapedMod forumMod({
    String name = 'Nexerelin',
    int topicId = 9175,
    String? summary = 'Adds diplomacy and invasions.',
    String? description,
    Map<String, Image> images = const {},
  }) =>
      ScrapedMod(
        name: name,
        description: description,
        summary: summary,
        images: images,
        gameVersionReq: '0.98a',
        authorsList: const ['Histidine'],
        categories: const ['Total Conversions'],
        sources: const [ModSource.Index],
        urls: {
          ModUrlType.Forum:
              'https://fractalsoftworks.com/forum/index.php?topic=$topicId.0',
        },
      );

  /// One thread in the bundle, with whatever the LLM found on it.
  QbModSummary thread({
    int topicId = 9175,
    String title = '[0.98a] Nexerelin v0.12.2',
    List<LlmMod> llmMods = const [],
    bool isWip = false,
    String? createdDate,
  }) =>
      QbModSummary(
        topicId: topicId,
        title: title,
        gameVersion: '0.98a',
        author: 'Histidine',
        createdDate: createdDate,
        topicUrl:
            'https://fractalsoftworks.com/forum/index.php?topic=$topicId.0',
        isWip: isWip,
        llm: llmMods.isEmpty ? null : LlmThreadData(mods: llmMods),
      );

  ForumDataBundle bundleOf({
    List<QbModSummary> index = const [],
    Map<String, QbModDetail> details = const {},
    Map<String, List<AssumedDownloadCandidate>> downloads = const {},
  }) =>
      ForumDataBundle(
        updatedAt: DateTime.utc(2026, 8, 18),
        index: index,
        details: details,
        assumedDownloads: downloads,
      );

  QbModDetail postOf(String contentHtml,
          {int topicId = 9175,
          List<ImageRef> images = const [],
          String? avatarPath}) =>
      QbModDetail(
        topicId: topicId,
        title: '[0.98a] Nexerelin v0.12.2',
        author: 'Histidine',
        authorAvatarPath: avatarPath,
        contentHtml: contentHtml,
        images: images,
      );

  test('the name a reader sees has the thread-title noise taken off it', () {
    final data = builder.build(
      mods: [forumMod(name: '[0.98a] Nexerelin v0.12.2')],
      bundle: bundleOf(),
    );

    final mod = data.list.mods.single;
    expect(mod.displayName, 'Nexerelin');
    expect(mod.name, '[0.98a] Nexerelin v0.12.2',
        reason: 'the title as written is still published, so a search for an '
            'old spelling finds the mod');
  });

  test('a name that needs no tidying is not published twice', () {
    final data =
        builder.build(mods: [forumMod(name: 'Nexerelin')], bundle: bundleOf());
    expect(data.list.mods.single.displayName, isNull);
  });

  test('the list is in order of the name a reader sees, not the raw title', () {
    final data = builder.build(
      mods: [
        forumMod(name: 'Zebra Mod', topicId: 1),
        forumMod(name: '- Starter Pack v1.1.3', topicId: 2),
        forumMod(name: '[0.98a] Aardvark', topicId: 3),
      ],
      bundle: bundleOf(),
    );

    expect(data.list.mods.map((m) => m.displayName ?? m.name),
        ['Aardvark', 'Starter Pack', 'Zebra Mod']);
  });

  test('the release feed uses the tidied name too', () {
    final data = builder.build(
      mods: [forumMod(name: '[0.98a] Nexerelin v0.12.2')],
      bundle: bundleOf(),
      threadReleases: [
        const ThreadRelease(
          topicId: 9175,
          modName: '[0.98a] Nexerelin v0.12.2',
          seenOn: '2026-08-14',
          newVersion: '0.12.2',
        ),
      ],
    );

    expect(data.feed.releases.single.modName, 'Nexerelin');
  });

  test('the description is the forum post, kept formatted and made safe', () {
    final data = builder.build(
      mods: [
        forumMod(
          name: 'Nexerelin',
          description: 'Discord: 4X in Starsector. Download: https://x/y',
        ),
      ],
      bundle: bundleOf(
        index: [thread()],
        details: {
          '9175': postOf('<p>A campaign <b>overhaul</b>.</p>'
              '<script>alert(1)</script>'),
        },
      ),
    );

    final detail = data.details['nexerelin']!;
    expect(detail.descriptionHtml, '<p>A campaign <b>overhaul</b>.</p>');
    expect(detail.description, 'A campaign overhaul.');
    expect(detail.descriptionIsGenerated, isFalse);
  });

  test('a mod with no forum post falls back to the text the merge had', () {
    final discordOnly = ScrapedMod(
      name: 'Quality Captains',
      description: 'Officers gain skills you choose.',
      authorsList: const ['Sundog'],
      sources: const [ModSource.Discord],
      urls: const {ModUrlType.Discord: 'https://discord.com/channels/1/2'},
    );

    final detail = builder
        .build(mods: [discordOnly], bundle: bundleOf())
        .details['quality-captains']!;
    expect(detail.description, 'Officers gain skills you choose.');
    expect(detail.descriptionHtml, '<p>Officers gain skills you choose.</p>');
    expect(detail.descriptionIsGenerated, isFalse);
  });

  test('the gallery leaves out buttons, badges and tiny pictures', () {
    const post = '<p>Look</p>'
        '<img src="https://i.imgur.com/shot.png" width="900">'
        '<img src="https://ko-fi.com/img/donate.png">'
        '<img src="https://i.imgur.com/tiny.png" width="88">';

    final data = builder.build(
      mods: [forumMod(name: 'Nexerelin')],
      bundle: bundleOf(index: [thread()], details: {
        '9175': postOf(post, images: [
          ImageRef(originalUrl: 'https://i.imgur.com/shot.png'),
          ImageRef(originalUrl: 'https://ko-fi.com/img/donate.png'),
          ImageRef(originalUrl: 'https://i.imgur.com/tiny.png'),
        ]),
      }),
    );

    final detail = data.details['nexerelin']!;
    expect(detail.gallery.map((i) => i.url), ['https://i.imgur.com/shot.png']);
  });

  test('the card picture is picked the way TriOS picks it', () {
    // The merged picture first, then the one the LLM found in the post, then
    // the author's forum avatar — the same order TriOS's catalog falls through,
    // so a mod looks the same in both.
    final withMerged = builder.build(
      mods: [
        forumMod(images: const {
          '1': Image(id: '1', url: 'https://i.imgur.com/merged.png'),
        }),
      ],
      bundle: bundleOf(index: [
        thread(llmMods: [LlmMod(name: 'Nexerelin', image: 'ext:https://x/l.png')]),
      ], details: {
        '9175': postOf('<p>Look</p>', avatarPath: 'avatars/histidine.png'),
      }),
    );
    expect(withMerged.list.mods.single.imageUrl,
        'https://i.imgur.com/merged.png');

    final withLlm = builder.build(
      mods: [forumMod()],
      bundle: bundleOf(index: [
        thread(llmMods: [LlmMod(name: 'Nexerelin', image: 'ext:https://x/l.png')]),
      ], details: {
        '9175': postOf('<p>Look</p>', avatarPath: 'avatars/histidine.png'),
      }),
    );
    expect(withLlm.list.mods.single.imageUrl, 'https://x/l.png');

    final withAvatar = builder.build(
      mods: [forumMod()],
      bundle: bundleOf(index: [thread()], details: {
        '9175': postOf('<p>Look</p>', avatarPath: 'avatars/histidine.png'),
      }),
    );
    expect(withAvatar.list.mods.single.imageUrl,
        'https://fractalsoftworks.com/forum/avatars/histidine.png',
        reason: 'an avatar path is written relative to the forum');
  });

  test('a picture in the post is not the card picture', () {
    // TriOS does not go looking through the post for one, so neither does this.
    final data = builder.build(
      mods: [forumMod()],
      bundle: bundleOf(index: [thread()], details: {
        '9175': postOf('<img src="https://i.imgur.com/shot.png" width="900">',
            images: [ImageRef(originalUrl: 'https://i.imgur.com/shot.png')]),
      }),
    );
    expect(data.list.mods.single.imageUrl, isNull);
  });

  test('a summary that is only a download link gives way to the AI sentence',
      () {
    final data = builder.build(
      mods: [forumMod(name: 'Nexerelin', summary: 'Download: https://x/y.zip')],
      bundle: bundleOf(index: [
        thread(llmMods: [
          LlmMod(
            name: 'Nexerelin',
            extras: LlmExtras(
              summary: LlmModSummary(sentence: 'Adds diplomacy and invasions.'),
            ),
          ),
        ]),
      ]),
    );

    final mod = data.list.mods.single;
    expect(mod.summary, 'Adds diplomacy and invasions.');
    expect(mod.summaryIsGenerated, isTrue);
  });

  test('the mods a mod needs are published, pointed at their own pages', () {
    final data = builder.build(
      mods: [
        forumMod(name: 'Nexerelin', topicId: 9175),
        forumMod(name: 'LazyLib', topicId: 5444),
      ],
      bundle: bundleOf(index: [
        thread(llmMods: [
          LlmMod(
            name: 'Nexerelin',
            extras: LlmExtras(needs: const ['LazyLib', 'Kadur Remnant']),
          ),
        ]),
      ]),
    );

    final nexerelin =
        data.list.mods.firstWhere((m) => m.id == 'nexerelin');
    expect(nexerelin.needs.map((n) => n.name), ['LazyLib', 'Kadur Remnant']);
    expect(nexerelin.needs.first.id, 'lazylib',
        reason: 'a mod we have a page for becomes a link');
    expect(nexerelin.needs.last.id, isNull,
        reason: 'a mod we do not publish is still worth naming');
  });

  test('a mod that names itself as a requirement is left alone', () {
    final data = builder.build(
      mods: [forumMod(name: 'Nexerelin')],
      bundle: bundleOf(index: [
        thread(llmMods: [
          LlmMod(
            name: 'Nexerelin',
            extras: LlmExtras(needs: const ['Nexerelin', 'LazyLib']),
          ),
        ]),
      ]),
    );

    expect(data.list.mods.single.needs.map((n) => n.name), ['LazyLib']);
  });

  test('a mod named twice is only needed once', () {
    final data = builder.build(
      mods: [forumMod(name: 'Nexerelin', topicId: 9175),
        forumMod(name: 'LazyLib', topicId: 5444)],
      bundle: bundleOf(index: [
        thread(llmMods: [
          LlmMod(
            name: 'Nexerelin',
            extras: LlmExtras(needs: const ['LazyLib', 'lazylib v3.0']),
          ),
        ]),
      ]),
    );

    expect(
        data.list.mods.firstWhere((m) => m.id == 'nexerelin').needs, hasLength(1));
  });

  test('the site has its own categories, and keeps the raw names on the page',
      () {
    final data = builder.build(
      mods: [
        ScrapedMod(
          name: 'Nexerelin',
          authorsList: const ['Histidine'],
          categories: const ['Ship Pack', 'Weapon/Fighter Pack', 'Discord Only'],
          sources: const [ModSource.Index, ModSource.Discord],
          urls: const {
            ModUrlType.Forum:
                'https://fractalsoftworks.com/forum/index.php?topic=9175.0',
          },
        ),
      ],
      bundle: bundleOf(),
    );

    final mod = data.list.mods.single;
    expect(mod.categories, ['Ships and weapons'],
        reason: '"Discord Only" says where a mod was found, not what it is');
    expect(mod.sources, ['forum', 'discord']);

    expect(data.details['nexerelin']!.rawCategories,
        ['Ship Pack', 'Weapon/Fighter Pack'],
        reason: 'the page says which shelves it is filed under, and "Discord '
            'Only" is not one — it is published as a source instead');
  });

  test('the card carries one download, picked the same way TriOS picks it', () {
    final data = builder.build(
      mods: [forumMod()],
      bundle: bundleOf(index: [
        thread(llmMods: [
          LlmMod(
            name: 'Nexerelin',
            downloads: [
              LlmDownload(
                url: 'https://www.mediafire.com/file/abc/Nexerelin.zip',
                kind: LlmDownloadKind.mirror,
                requiresManualStep: true,
              ),
              LlmDownload(
                url: 'https://github.com/x/y/releases/download/v1/z.zip',
                resolvedDirectUrl: 'https://cdn.example.com/z.zip',
                kind: LlmDownloadKind.direct,
              ),
              LlmDownload(
                url: 'https://trilink.wispborne.com/open.html?mod=%7B%7D',
                kind: LlmDownloadKind.trios,
                requiresManualStep: true,
              ),
            ],
          ),
        ]),
      ]),
    );

    final mod = data.list.mods.single;
    expect(mod.bestDownload?.kind, 'trios',
        reason: 'a TriOS link installs what the mod needs as well, so it leads');
    expect(mod.bestDownload?.needsAnotherStep, isFalse,
        reason: 'opening a TriOS link is the step, so it never counts as one');
    expect(mod.downloadCount, 3);

    expect(
      data.details['nexerelin']!.downloads.map((d) => d.kind),
      ['trios', 'direct', 'mirror'],
      reason: 'the page for the mod lists them best first as well',
    );
  });

  test('the card download is the resolved address, not the link as written',
      () {
    final data = builder.build(
      mods: [forumMod()],
      bundle: bundleOf(index: [
        thread(llmMods: [
          LlmMod(
            name: 'Nexerelin',
            downloads: [
              LlmDownload(
                url: 'https://github.com/x/y/releases/tag/v1',
                resolvedDirectUrl: 'https://cdn.example.com/z.zip',
                kind: LlmDownloadKind.direct,
              ),
            ],
          ),
        ]),
      ]),
    );

    expect(data.list.mods.single.bestDownload?.url,
        'https://cdn.example.com/z.zip');
  });

  test('a download that opens the host page says so', () {
    final data = builder.build(
      mods: [forumMod()],
      bundle: bundleOf(index: [
        thread(llmMods: [
          LlmMod(
            name: 'Nexerelin',
            downloads: [
              LlmDownload(
                url: 'https://www.mediafire.com/file/abc/Nexerelin.zip',
                kind: LlmDownloadKind.direct,
                requiresManualStep: true,
              ),
            ],
          ),
        ]),
      ]),
    );

    final mod = data.list.mods.single;
    expect(mod.bestDownload?.needsAnotherStep, isTrue);
    expect(mod.hasDirectDownload, isFalse);
  });

  test('a mod with nothing to download carries no download at all', () {
    final data = builder.build(mods: [forumMod()], bundle: bundleOf());

    final mod = data.list.mods.single;
    expect(mod.bestDownload, isNull,
        reason: 'the site offers the forum thread instead');
    expect(mod.downloadCount, 0);
    expect(mod.forumUrl,
        'https://fractalsoftworks.com/forum/index.php?topic=9175.0',
        reason: 'a card with no download offers the thread, so the address has '
            'to be in the file the cards are drawn from');
  });

  test('a Discord-only mod carries its Discord post for the same reason', () {
    final data = builder.build(
      mods: [
        ScrapedMod(
          name: 'Quality Captains',
          authorsList: const ['Sundog'],
          sources: const [ModSource.Discord],
          urls: const {
            ModUrlType.Discord: 'https://discord.com/channels/1/2',
          },
        ),
      ],
      bundle: bundleOf(),
    );

    final mod = data.list.mods.single;
    expect(mod.forumUrl, isNull);
    expect(mod.discordUrl, 'https://discord.com/channels/1/2');
  });

  test('a category nobody has seen before is left off rather than guessed', () {
    final data = builder.build(
      mods: [
        ScrapedMod(
          name: 'Some Mod',
          authorsList: const ['Someone'],
          categories: const ['Something New'],
          sources: const [ModSource.Discord],
          urls: const {ModUrlType.Discord: 'https://discord.com/channels/1/2'},
        ),
      ],
      bundle: bundleOf(),
    );

    expect(data.list.mods.single.categories, isEmpty);
    expect(data.details['some-mod']!.rawCategories, ['Something New']);
  });

  test('a mod is joined to its thread on the forum topic id', () {
    final data = builder.build(
      mods: [forumMod()],
      bundle: bundleOf(index: [
        thread(llmMods: [
          LlmMod(
            name: 'Nexerelin',
            downloads: [
              LlmDownload(
                url: 'https://github.com/x/y/releases/download/v1/z.zip',
                resolvedDirectUrl:
                    'https://github.com/x/y/releases/download/v1/z.zip',
                fileName: 'z.zip',
                sourceHost: 'GitHub',
              ),
            ],
            extras: LlmExtras(
              version: '0.12.2',
              license: 'CC BY-NC-SA 4.0',
              sourceCode: 'https://github.com/Histidine91/Nexerelin',
              saveCompatibility: 'Requires a new game.',
              changelog: LlmChangelog(entries: {'0.12.2': 'Fixed a crash.'}),
            ),
          ),
        ]),
      ]),
    );

    final mod = data.list.mods.single;
    expect(mod.id, 'nexerelin');
    expect(mod.modVersion, '0.12.2');
    expect(mod.gameVersion, '0.98a');
    expect(mod.hasDirectDownload, isTrue);
    expect(mod.sourceIsPublic, isTrue);
    expect(mod.saveCompatible, isFalse);

    final detail = data.details['nexerelin']!;
    expect(detail.license, 'CC BY-NC-SA 4.0');
    expect(detail.changelog, {'0.12.2': 'Fixed a crash.'});
    expect(detail.saveCompatibilityText, 'Requires a new game.');
    expect(detail.downloads.single.fileName, 'z.zip');
  });

  test('a mod with no forum thread leaves the bundle-only fields out', () {
    final discordOnly = ScrapedMod(
      name: 'Quality Captains',
      authorsList: const ['Sundog'],
      sources: const [ModSource.Discord],
      urls: const {
        ModUrlType.Discord: 'https://discord.com/channels/1/2',
      },
    );

    final data = builder.build(mods: [discordOnly], bundle: bundleOf());

    final mod = data.list.mods.single;
    expect(mod.id, 'quality-captains');
    expect(mod.modVersion, isNull);
    expect(mod.saveCompatible, isNull);

    final detail = data.details['quality-captains']!;
    expect(detail.forumUrl, isNull);
    expect(detail.discordUrl, 'https://discord.com/channels/1/2');
    expect(detail.changelog, isEmpty);
    expect(detail.releases, isEmpty);
  });

  test('a multi-mod thread uses the main mod and lists the add-ons', () {
    final data = builder.build(
      mods: [forumMod(name: 'Industrial.Evolution', topicId: 15380)],
      bundle: bundleOf(index: [
        thread(topicId: 15380, title: '[0.98a] Industrial.Evolution 3.5.2', llmMods: [
          LlmMod(
            name: 'Industrial.Evolution',
            extras: LlmExtras(version: '3.5.2'),
          ),
          LlmMod(
            name: 'IndEvo Vanilla Structures',
            role: LlmModRole.addon,
            requires: 'Industrial.Evolution',
            downloads: [LlmDownload(url: 'https://example.com/addon.zip')],
          ),
          LlmMod(
            name: 'Some Unrelated Mod',
            role: LlmModRole.separate,
          ),
        ]),
      ]),
    );

    final detail = data.details['industrial-evolution']!;
    expect(detail.listing.modVersion, '3.5.2');
    expect(detail.addons, hasLength(1));
    expect(detail.addons.single.name, 'IndEvo Vanilla Structures');
    expect(detail.addons.single.requires, 'Industrial.Evolution');
  });

  test('an LLM summary is marked as written, a copied one is not', () {
    final generated = builder.build(
      mods: [forumMod(summary: null)],
      bundle: bundleOf(index: [
        thread(llmMods: [
          LlmMod(
            name: 'Nexerelin',
            extras: LlmExtras(
              summary: LlmModSummary(
                  sentence: 'A campaign overhaul.',
                  paragraph: 'It adds diplomacy and invasions.'),
            ),
          ),
        ]),
      ]),
    );
    expect(generated.list.mods.single.summary, 'A campaign overhaul.');
    expect(generated.list.mods.single.summaryIsGenerated, isTrue);
    expect(generated.details['nexerelin']!.descriptionIsGenerated, isTrue);

    final copied = PublicDataBuilder(
      outputPath: p.join(dir.path, 'outputs2'),
      idStore: ModIdStore(p.join(dir.path, 'data2'))..load(),
    ).build(
      mods: [forumMod(summary: 'The author\'s own words.')],
      bundle: bundleOf(index: [thread()]),
    );
    expect(copied.list.mods.single.summary, "The author's own words.");
    expect(copied.list.mods.single.summaryIsGenerated, isFalse);
  });

  test('the rules-based downloads are used when the LLM found none', () {
    final data = builder.build(
      mods: [forumMod()],
      bundle: bundleOf(
        index: [thread()],
        downloads: {
          '9175': [
            AssumedDownloadCandidate(
              originalUrl: 'https://example.com/page',
              resolvedDirectUrl: 'https://example.com/mod.zip',
              sourceHost: 'example.com',
              fileName: 'mod.zip',
              confidence: 'high',
              linkText: 'Download',
            ),
          ],
        },
      ),
    );

    final detail = data.details['nexerelin']!;
    expect(detail.downloads.single.url, 'https://example.com/page');
    expect(detail.downloads.single.directUrl, 'https://example.com/mod.zip');
    expect(detail.listing.hasDirectDownload, isTrue);
  });

  test('a release gives the mod a last release date and its own history', () {
    final release = ThreadRelease(
      topicId: 9175,
      modName: 'Nexerelin',
      seenOn: '2026-08-14',
      oldVersion: '0.12.1e',
      newVersion: '0.12.2',
      gameVersion: '0.98a',
    );

    final data = builder.build(
      mods: [forumMod()],
      bundle: bundleOf(index: [thread()]),
      threadReleases: [release],
    );

    expect(data.list.mods.single.lastReleaseDate, DateTime.utc(2026, 8, 14));
    expect(data.details['nexerelin']!.releases, hasLength(1));
    expect(data.details['nexerelin']!.releases.single.modId, 'nexerelin');
    expect(data.feed.releases, hasLength(1));
  });

  test('the feed reads newest first and drops releases with no mod behind them',
      () {
    final data = builder.build(
      mods: [forumMod(), forumMod(name: 'Second Mod', topicId: 100)],
      bundle: bundleOf(),
      threadReleases: [
        ThreadRelease(
            topicId: 9175,
            modName: 'Nexerelin',
            seenOn: '2026-08-10',
            newVersion: '0.12.1'),
        ThreadRelease(
            topicId: 100,
            modName: 'Second Mod',
            seenOn: '2026-08-14',
            newVersion: '2.0'),
        ThreadRelease(
            topicId: 999,
            modName: 'A thread nobody merged',
            seenOn: '2026-08-16',
            newVersion: '9.9'),
      ],
    );

    expect(data.feed.releases.map((r) => r.modId),
        ['second-mod', 'nexerelin']);
  });

  test('a picture stored as ext:<url> is published as a plain URL', () {
    final data = builder.build(
      mods: [forumMod()],
      bundle: bundleOf(index: [
        thread(llmMods: [
          LlmMod(name: 'Nexerelin', image: 'ext:https://example.com/shot.png'),
        ]),
      ]),
    );
    expect(data.list.mods.single.imageUrl, 'https://example.com/shot.png');
  });

  test('a saved local image path is never published', () {
    final data = builder.build(
      mods: [forumMod()],
      bundle: bundleOf(index: [
        thread(llmMods: [
          LlmMod(name: 'Nexerelin', image: 'images/9175/thumb.png'),
        ]),
      ]),
    );
    expect(data.list.mods.single.imageUrl, isNull);
  });

  test('the author\'s own words decide save compatibility', () {
    expect(PublicDataBuilder.readSaveCompatibility('Save compatible'), isTrue);
    expect(PublicDataBuilder.readSaveCompatibility('Not save compatible'),
        isFalse);
    expect(PublicDataBuilder.readSaveCompatibility('Requires a new game'),
        isFalse);
    expect(
        PublicDataBuilder.readSaveCompatibility('Can be added to an existing '
            'save'),
        isTrue);
    expect(PublicDataBuilder.readSaveCompatibility('Have fun!'), isNull);
    expect(PublicDataBuilder.readSaveCompatibility(null), isNull);
  });

  test('writing puts the files where the site asks for them', () async {
    final data = builder.build(
      mods: [forumMod(), forumMod(name: 'Second Mod', topicId: 100)],
      bundle: bundleOf(),
    );
    await builder.write(data);

    expect(File(p.join(builder.siteDir, 'mods.json')).existsSync(), isTrue);
    expect(File(p.join(builder.siteDir, 'updates.json')).existsSync(), isTrue);
    expect(File(p.join(builder.modsDir, 'nexerelin.json')).existsSync(), isTrue);
    expect(File(p.join(builder.modsDir, 'second-mod.json')).existsSync(), isTrue);
  });

  test('the release feed is written out beside the rest', () async {
    final data = builder.build(
      mods: [forumMod()],
      bundle: bundleOf(),
      threadReleases: [
        const ThreadRelease(
          topicId: 9175,
          modName: 'Nexerelin',
          seenOn: '2026-08-14',
          newVersion: '0.12.2',
        ),
      ],
    );
    await builder.write(data);

    final feed = File(p.join(builder.siteDir, 'updates.xml'));
    expect(feed.existsSync(), isTrue,
        reason: 'a reader who subscribed has nothing to read without it');
    expect(feed.readAsStringSync(), contains('<title>Nexerelin 0.12.2</title>'));
  });

  test('each mod gets a little page of its own, for links and search engines',
      () async {
    await builder.write(builder.build(
      mods: [forumMod(name: 'Nexerelin')],
      bundle: bundleOf(),
    ));

    final page = File(p.join(builder.modsDir, 'nexerelin', 'index.html'));
    expect(page.existsSync(), isTrue);

    final html = page.readAsStringSync();
    expect(html, contains('<title>Nexerelin — Starmodder</title>'));
    expect(html, contains('../../#/mods/nexerelin'));
  });

  test('a mod that is gone loses its little page as well', () async {
    await builder.write(builder.build(
      mods: [forumMod(), forumMod(name: 'Second Mod', topicId: 100)],
      bundle: bundleOf(),
    ));
    expect(Directory(p.join(builder.modsDir, 'second-mod')).existsSync(), isTrue);

    await builder.write(builder.build(mods: [forumMod()], bundle: bundleOf()));
    expect(
        Directory(p.join(builder.modsDir, 'second-mod')).existsSync(), isFalse);
    expect(Directory(p.join(builder.modsDir, 'nexerelin')).existsSync(), isTrue);
  });

  test('a mod that is gone loses its page on the next write', () async {
    await builder.write(builder.build(
      mods: [forumMod(), forumMod(name: 'Second Mod', topicId: 100)],
      bundle: bundleOf(),
    ));
    expect(File(p.join(builder.modsDir, 'second-mod.json')).existsSync(), isTrue);

    await builder.write(builder.build(mods: [forumMod()], bundle: bundleOf()));
    expect(File(p.join(builder.modsDir, 'nexerelin.json')).existsSync(), isTrue);
    expect(
        File(p.join(builder.modsDir, 'second-mod.json')).existsSync(), isFalse);
  });

  test("other names are kept per person, not pooled across a mod's authors",
      () {
    // Kaleidoscope credits two people: SirHartley made the mod, pixel_rice_bowl
    // made the textures. When other names were one list for the whole mod, the
    // author page read it as one person and said SirHartley was also known as
    // pixel_rice_bowl.
    final mod = ScrapedMod(
      name: 'Nexerelin',
      gameVersionReq: '0.98a',
      authorsList: const ['Histidine', 'Zaphide'],
      sources: const [ModSource.Index],
      urls: {
        ModUrlType.Forum:
            'https://fractalsoftworks.com/forum/index.php?topic=9175.0',
      },
    );

    final record = builder.build(mods: [mod], bundle: bundleOf()).list.mods
        .single;

    expect(record.otherAuthorNames.keys, ['Histidine']);
    expect(record.otherAuthorNames['Histidine'], contains('histidine_my'));
    expect(record.otherAuthorNames.containsKey('Zaphide'), isFalse);
    expect(
      record.otherAuthorNames.values.expand((names) => names),
      isNot(contains('Zaphide')),
    );
  });

  test('mods.json stays under 2 MB for a mod set the size of the real one', () {
    // The real set is around 900 mods. A thousand, each with a long name, a
    // full-length summary, several authors and categories, and a TriOS link for
    // its download, is the worst case the browse page has to fetch whole — a
    // TriOS link carries the mod's details packed into the address, and the
    // longest real one runs to about 850 characters.
    final mods = [
      for (var i = 0; i < 1000; i++)
        ScrapedMod(
          name: 'A Rather Long Starsector Mod Name Number $i',
          summary: 'A one-line summary of what this mod does, written out at '
              'about the length the longest real ones run to, so the count is '
              'not flattered by short text. Mod number $i.',
          gameVersionReq: '0.98a',
          authorsList: const ['Some Author', 'Another Author'],
          categories: const ['Faction Mods', 'Ship Packs'],
          urls: {
            ModUrlType.Forum:
                'https://fractalsoftworks.com/forum/index.php?topic=$i.0',
          },
          images: {
            'a': Image(
              id: 'a',
              url: 'https://fractalsoftworks.com/forum/index.php?action='
                  'dlattach;topic=$i.0;attach=12345;image',
            ),
          },
        ),
    ];

    final trilink = 'https://trilink.wispborne.com/open.html?mod='
        '${'%7B%22url%22%3A%22https%3A%2F%2Fraw.githubusercontent.com%2F' * 4}';
    final data = builder.build(
      mods: mods,
      bundle: bundleOf(index: [
        for (var i = 0; i < 1000; i++)
          thread(topicId: i, llmMods: [
            LlmMod(
              name: 'A Rather Long Starsector Mod Name Number $i',
              downloads: [
                LlmDownload(
                  url: '$trilink$i',
                  kind: LlmDownloadKind.trios,
                  requiresManualStep: true,
                ),
              ],
            ),
          ]),
      ]),
    );
    final bytes = utf8
        .encode(const JsonEncoder.withIndent('  ').convert(data.list.toMap()))
        .length;

    expect(data.list.mods, hasLength(1000));
    expect(bytes, lessThan(2 * 1024 * 1024),
        reason: 'mods.json came to ${(bytes / 1024).round()} KB');
    expect(data.list.mods.first.bestDownload, isNotNull,
        reason: 'the worst case has to include what a card downloads');
  });

  test('nothing internal reaches the published files', () async {
    final data = builder.build(
      mods: [forumMod()],
      bundle: bundleOf(
        index: [
          thread(llmMods: [
            LlmMod(
              name: 'Nexerelin',
              downloads: [
                LlmDownload(
                  url: 'https://example.com/mod.zip',
                  resolvedDirectUrl: 'https://example.com/mod.zip',
                  confidence: 'high',
                ),
              ],
              extras: LlmExtras(version: '0.12.2'),
            ),
          ]),
        ],
        details: {
          '9175': QbModDetail(
            topicId: 9175,
            contentHtml: '<p>the whole post</p>',
            images: [
              ImageRef(
                originalUrl: 'https://example.com/shot.png',
                localPath: r'F:\qb_data\images\9175\shot.png',
              ),
            ],
          ),
        },
      ),
    );
    await builder.write(data);

    final published = [
      File(builder.modsFilePath).readAsStringSync(),
      File(builder.updatesFilePath).readAsStringSync(),
      File(p.join(builder.modsDir, 'nexerelin.json')).readAsStringSync(),
    ].join('\n');

    // Config keys, tokens and anything only the scraper cares about.
    for (final banned in [
      'qb_data',
      'config.properties',
      'apiToken',
      'authToken',
      'discord_auth',
      'confidence',
      'runId',
      'localPath',
      'isPlaceholderDetail',
      'contentHtml',
      'scrapedAt',
    ]) {
      expect(published.contains(banned), isFalse,
          reason: '"$banned" reached the published files');
    }

    // No Windows or POSIX local path, either.
    expect(RegExp(r'[A-Za-z]:\\\\').hasMatch(published), isFalse);
    expect(published.contains(dir.path.replaceAll(r'\', r'\\')), isFalse);
  });

  test('every record in the list has a file, and the two agree', () async {
    final data = builder.build(
      mods: [forumMod(), forumMod(name: 'Second Mod', topicId: 100)],
      bundle: bundleOf(),
    );
    await builder.write(data);

    final list = PublicModListMapper.fromJson(
        File(builder.modsFilePath).readAsStringSync());
    for (final mod in list.mods) {
      final file = File(p.join(builder.modsDir, '${mod.id}.json'));
      expect(file.existsSync(), isTrue, reason: '${mod.id} has no page');
    }
  });

  group('the day a mod was added', () {
    test('is the day the forum thread was posted', () {
      final data = builder.build(
        mods: [forumMod()],
        bundle: bundleOf(
          index: [thread(createdDate: 'May 04, 2014, 01:33:25 AM')],
        ),
      );

      expect(data.list.mods.single.addedOn, '2014-05-04');
    });

    test('is the Discord message day for a mod that is only on Discord', () {
      final discordOnly = ScrapedMod(
        name: 'Quality Captains',
        authorsList: const ['Sundog'],
        sources: const [ModSource.Discord],
        urls: const {ModUrlType.Discord: 'https://discord.com/channels/1/2'},
        dateTimeCreated: DateTime.utc(2026, 6, 22, 13, 32),
      );

      final data = builder.build(mods: [discordOnly], bundle: bundleOf());

      expect(data.list.mods.single.addedOn, '2026-06-22');
    });

    test('is the earliest date, not the latest', () {
      final onBoth = ScrapedMod(
        name: 'Nexerelin',
        authorsList: const ['Histidine'],
        sources: const [ModSource.Index, ModSource.Discord],
        urls: const {
          ModUrlType.Forum:
              'https://fractalsoftworks.com/forum/index.php?topic=9175.0',
        },
        // Announced on Discord this year; the thread has been up since 2014.
        dateTimeCreated: DateTime.utc(2026, 6, 22),
      );

      final data = builder.build(
        mods: [onBoth],
        bundle: bundleOf(
          index: [thread(createdDate: 'May 04, 2014, 01:33:25 AM')],
        ),
      );

      expect(data.list.mods.single.addedOn, '2014-05-04');
    });

    test('is nothing at all when every mod was given its id in one go', () {
      // The id file is written in one batch, so "first seen today" here means
      // "was already here". A day nobody can stand behind is worse than none.
      final data = builder.build(
        mods: [forumMod()],
        bundle: bundleOf(index: [thread()]),
      );

      expect(data.list.mods.single.addedOn, isNull);
    });

    test('falls back to the day we first saw a mod that came later', () {
      // A first run gives every mod an id on the same day.
      builder.build(mods: [forumMod()], bundle: bundleOf(index: [thread()]));
      idStore.save();

      // A mod that turns up a day later, with no date of its own anywhere.
      final laterStore = ModIdStore(
        p.join(dir.path, 'data'),
        now: () => DateTime.utc(2030, 1, 2),
      )..load();
      final laterBuilder = PublicDataBuilder(
        outputPath: p.join(dir.path, 'outputs'),
        idStore: laterStore,
      );

      final data = laterBuilder.build(
        mods: [forumMod(), forumMod(name: 'Second Wave Options', topicId: 20)],
        bundle: bundleOf(index: [thread()]),
      );

      final newcomer =
          data.list.mods.firstWhere((m) => m.name == 'Second Wave Options');
      expect(newcomer.addedOn, '2030-01-02');
    });
  });
}
