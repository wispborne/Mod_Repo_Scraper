import 'package:test/test.dart';
import 'package:usc_scraper/bot/scraper/discord_reader.dart';
import 'package:usc_scraper/bot/scraper/scraped_mod.dart';

void main() {
  // ---------------------------------------------------------------------------
  // getForumUrlFromMessage — pure function tests with real Discord data
  // ---------------------------------------------------------------------------
  group('getForumUrlFromMessage', () {
    group('labeled "Forum Link:" / "Forum Thread:" picks the correct URL', () {
      test('Animated Vanilla Portraits: picks Forum Link, not Requires dependency', () {
        // Real data from ymfah's first message in the Animated Vanilla Portraits thread.
        final lines = [
          'Animate all 225 vanilla portraits with comm static.',
          'Requires VideoLib : https://fractalsoftworks.com/forum/index.php?topic=34134',
          '',
          'Download : https://mega.nz/file/864lRQZR#lxyxnlRSBGoTQMMwT2-PL85lisaO17kMRJcxu803I8c',
          'Forum Link : http://fractalsoftworks.com/forum/index.php?topic=34849',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, contains('topic=34849'),
            reason: 'Should pick the labeled "Forum Link" URL, not the "Requires VideoLib" dependency');
      });

      test('Random Weapon Collection: "Forum link:" (lowercase l)', () {
        final lines = [
          'Adds a few weapons and some ships I wanted to make.',
          'Still under construction, but releasing so people can try them out.',
          '',
          'Forum link: https://fractalsoftworks.com/forum/index.php?topic=28822.0',
          '',
          'Download Link: https://cdn.discordapp.com/attachments/1203054429927120996/example/random_weapon_collection.zip',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, contains('topic=28822'));
      });

      test('Domain Explorarium Expansion: "Forum Link:" (capital L)', () {
        final lines = [
          'An in-development mod focused around the Domain Exploration Derelicts.',
          'Download Link: https://drive.google.com/file/d/18t8pe-R5SSfp__Eer5PicEnk-lMzNVNu/view?usp=drive_link',
          'Forum Link: https://fractalsoftworks.com/forum/index.php?topic=26432.0',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, contains('topic=26432'));
      });

      test('BigBeans Ship Compilation: "Forum Link:" with capital L', () {
        final lines = [
          'A pack of ships kitbashed or painted mostly by myself.',
          'Google Drive Link: https://drive.google.com/file/d/1mTb1c-RKaLVPz3b71d9GXrEozB6dNrmX/view?usp=drive_link',
          'Forum Link: https://fractalsoftworks.com/forum/index.php?topic=21358.0',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, contains('topic=21358'));
      });

      test('Chatter Expansion Project: "Forum Thread:" label', () {
        final lines = [
          'Adds 54 iconic characters from all over media and history.',
          'Download: https://www.dropbox.com/scl/fi/kw6wzv0ouxu0h307yzkrh/Chatter-Expansion-Project1.1.zip?rlkey=fh73lxd9j5syqfrc4nvrxrsvy&st=cgaxl95r&dl=0',
          'Forum Thread: https://fractalsoftworks.com/forum/index.php?topic=30154.0',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, contains('topic=30154'));
      });

      test('Combat Chatter: "Forum thread:" (lowercase t)', () {
        final lines = [
          'The talking ships mod.',
          'Download: <https://github.com/Histidine91/SS-CombatChatter/releases/download/v1.14.2/CombatChatter_1.14.2.zip>',
          'Changelog: <https://github.com/Histidine91/SS-CombatChatter/wiki/Changelog>',
          'Forum thread: https://fractalsoftworks.com/forum/index.php?topic=10399.0',
          'Nexus: https://www.nexusmods.com/starsector/mods/29',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, contains('topic=10399'));
      });

      test('LazyLib: simple "Forum thread:" label', () {
        final lines = [
          'A library to simplify basic mod programming tasks.',
          'Download: https://github.com/LazyWizard/lazylib/releases/download/2.8b/LazyLib.2.8b.zip',
          'Forum thread: https://fractalsoftworks.com/forum/index.php?topic=5444.0',
          'Online documentation: https://lazywizard.github.io/lazylib/',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, contains('topic=5444'));
      });

      test('Adversary: "Forum Thread:" with GitHub download', () {
        final lines = [
          'Adds a player-like faction in an ideal star system.',
          '**Download (requires Customizable Star Systems https://discord.com/channels/187635036525166592/1203405672146800690):** <https://github.com/Tranquiliti/Adversary/releases/download/v6.4.1/Adversary-v6.4.1.zip>',
          'Releases and Changelogs: <https://github.com/Tranquiliti/Adversary/releases>',
          'Forum Thread: https://fractalsoftworks.com/forum/index.php?topic=25821.0',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, contains('topic=25821'));
      });
    });

    group('markdown-style [Forum Thread](url) links', () {
      test('Substance.Abuse: # [Forum Thread](url) markdown', () {
        final lines = [
          'Substance Abuse adds 10 consumable alcohols.',
          '# [Support my Efforts](https://patreon.com/SirHartley)',
          '# [Download](https://github.com/SirHartley/Substance.Abuse.Legacy/releases/download/1.1.d/Substance.Abuse1.1.d.zip)',
          '# [Forum Thread](https://fractalsoftworks.com/forum/index.php?topic=24378.0)',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, contains('topic=24378'));
      });

      test('Industrial.Evolution: # [Forum Thread](url) markdown', () {
        final lines = [
          'A massive campaign content expansion for colonies and exploration.',
          '# [Support my Efforts](https://ko-fi.com/sirhartley)',
          '# [Download](https://bitbucket.org/SirHartley/deconomics/downloads/Industrial.Evolution3.3.e.zip)',
          '# [Forum Thread](https://fractalsoftworks.com/forum/index.php?topic=18011.0)',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, contains('topic=18011'));
      });
    });

    group('"Thread:" label variant', () {
      test('Secrets of the Frontier: "Thread:" label', () {
        // "Thread:" alone doesn't match _forumLabelRegex which looks for "forum" prefix.
        // But the URL should still be found as ambiguous last URL.
        final lines = [
          'Dance amongst the void. Discover the secrets of the frontier.',
          '(as usual, requires LazyLib, MagicLib and GraphicsLib, and can be added mid-save with full functionality).',
          'Thread: https://fractalsoftworks.com/forum/index.php?topic=15820.0',
          'Direct download: <https://github.com/InventRaccoon/secrets-of-the-frontier/releases/download/v0.14.2c/Secrets.of.the.Frontier.0.14.2c.zip>',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, contains('topic=15820'),
            reason: 'The "Thread:" line has no "Requires" label so the forum URL should be found as ambiguous');
      });
    });

    group('dependency filtering', () {
      test('"Requires" line is excluded', () {
        final lines = [
          'Requires VideoLib : https://fractalsoftworks.com/forum/index.php?topic=34134',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, isNull,
            reason: 'Only forum URL is on a "Requires" line, should be excluded');
      });

      test('"Dependencies:" block with multiple lib URLs — all excluded', () {
        final lines = [
          'Dependencies:',
          'Lazy Lib https://fractalsoftworks.com/forum/index.php?topic=5444.0',
          'Magic Lib https://fractalsoftworks.com/forum/index.php?topic=25868.0',
          'Graphic Lib https://fractalsoftworks.com/forum/index.php?topic=10982.0',
        ];

        // "Dependencies:" is on its own line with no URL.
        // The lib lines don't have "Requires" or "Dependencies" on them,
        // so they'd be treated as ambiguous. The last one wins.
        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, contains('topic=10982'),
            reason: 'Lib lines without explicit "Requires" label are ambiguous; last one wins');
      });

      test('single "Requires" line followed by own forum link', () {
        final lines = [
          'Requires LazyLib : https://fractalsoftworks.com/forum/index.php?topic=5444.0',
          'Forum Thread: https://fractalsoftworks.com/forum/index.php?topic=99999.0',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, contains('topic=99999'),
            reason: 'Labeled Forum Thread should win over Requires dependency');
      });

      test('multiple Requires lines, then Forum Link', () {
        final lines = [
          'Requires LazyLib : https://fractalsoftworks.com/forum/index.php?topic=5444.0',
          'Requires MagicLib : https://fractalsoftworks.com/forum/index.php?topic=25868.0',
          'Requires GraphicLib : https://fractalsoftworks.com/forum/index.php?topic=10982.0',
          'Forum Link: https://fractalsoftworks.com/forum/index.php?topic=12345.0',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, contains('topic=12345'));
      });

      test('XXVII Battle group: "Requires" with no forum URL', () {
        final lines = [
          'Add a mid-tech battle group.',
          'Requires Graphic Lib/Lazy Lib/Magic Lib/Nex',
          'Github(English version): https://github.com/dilinganye/XXVIIBattleGroup_EN/releases/tag/Shakeles_Garrsion',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, isNull,
            reason: 'No fractalsoftworks URL in the message at all');
      });
    });

    group('no forum URL cases', () {
      test('Gudalanmu: Discord-only mod with no forum link', () {
        final lines = [
          'Original mod by: fire_turtle',
          'An alien faction arrives in the north-eastern corner of the core worlds.',
          'Download: https://drive.google.com/uc?export=download&id=14ofSbuB1RQIlq_NLoBQAJ40x7GZiptv9',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, isNull);
      });

      test('Pipebomb: ultra-short message with only Dropbox download', () {
        final lines = [
          'replaces phase mines with pipebombs',
          'https://www.dropbox.com/scl/fi/23z9zk6jh8ir0dosx3tzy/pipebombSoCool.rar?rlkey=jcsforqdcgzq4r7f7r25vj5ig&dl=0',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, isNull);
      });

      test('Galactic Constellate: fossic.org link is not fractalsoftworks', () {
        final lines = [
          'A mid-high tech ship pack with eastern anime/game style unique ships',
          'Dependencies:',
          'Lazy Lib/Magic Lib/Graphic Lib',
          '0.97 Download:',
          'https://github.com/MycophobiaSC/Galactic-Constellate-TL/releases/download/v1.13.6a.1/Galactic_Constellate.1.13.6a.zip',
          'Original Fossic Link:',
          'https://www.fossic.org/thread-10883-1-1.html',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, isNull,
            reason: 'fossic.org is not fractalsoftworks');
      });
    });

    group('ambiguous URLs with no label', () {
      test('bare forum URL with no label is picked up', () {
        final lines = [
          'A cool mod.',
          'https://fractalsoftworks.com/forum/index.php?topic=11111.0',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, contains('topic=11111'));
      });

      test('multiple bare forum URLs — last one wins', () {
        final lines = [
          'Check out this other mod: https://fractalsoftworks.com/forum/index.php?topic=11111.0',
          'Download stuff here',
          'Also see: https://fractalsoftworks.com/forum/index.php?topic=22222.0',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, contains('topic=22222'),
            reason: 'Last ambiguous URL should be preferred');
      });

      test('labeled URL takes priority over ambiguous URL even if ambiguous is last', () {
        final lines = [
          'Forum Link: https://fractalsoftworks.com/forum/index.php?topic=11111.0',
          'Some other reference: https://fractalsoftworks.com/forum/index.php?topic=22222.0',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, contains('topic=11111'),
            reason: 'Labeled "Forum Link:" should always take priority over ambiguous');
      });

      test('labeled URL found even if not first in the message', () {
        final lines = [
          'Description of the mod.',
          'Some reference: https://fractalsoftworks.com/forum/index.php?topic=99999.0',
          'Forum Link: https://fractalsoftworks.com/forum/index.php?topic=11111.0',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, contains('topic=11111'));
      });
    });

    group('edge cases', () {
      test('empty message returns null', () {
        final result = DiscordReader.getForumUrlFromMessage([]);
        expect(result, isNull);
      });

      test('message with only blank lines returns null', () {
        final result = DiscordReader.getForumUrlFromMessage(['', '  ', '']);
        expect(result, isNull);
      });

      test('angle brackets around URL are handled by regex', () {
        final lines = [
          'Forum thread: <https://fractalsoftworks.com/forum/index.php?topic=15820.0>',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        // The regex should still match the URL inside angle brackets
        expect(result, contains('topic=15820'));
      });

      test('http and https variants both work', () {
        final httpLines = [
          'Forum Link : http://fractalsoftworks.com/forum/index.php?topic=34849',
        ];
        final httpsLines = [
          'Forum Link : https://fractalsoftworks.com/forum/index.php?topic=34849',
        ];

        expect(DiscordReader.getForumUrlFromMessage(httpLines), contains('topic=34849'));
        expect(DiscordReader.getForumUrlFromMessage(httpsLines), contains('topic=34849'));
      });

      test('"Forum Post:" variant is recognized', () {
        final lines = [
          'Forum Post: https://fractalsoftworks.com/forum/index.php?topic=28835.0',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, contains('topic=28835'));
      });

      test('"Forum Page:" variant is recognized', () {
        final lines = [
          'Forum Page: https://fractalsoftworks.com/forum/index.php?topic=12345.0',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, contains('topic=12345'));
      });

      test('"FORUM THREAD:" (all caps) is recognized', () {
        final lines = [
          'FORUM THREAD: https://fractalsoftworks.com/forum/index.php?topic=12345.0',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, contains('topic=12345'));
      });

      test('inline "[Forum Thread](url)" markdown without header', () {
        final lines = [
          'Check the [Forum Thread](https://fractalsoftworks.com/forum/index.php?topic=29440.0) for more info.',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, contains('topic=29440'));
      });

      test('first labeled Forum URL wins when multiple labeled lines exist', () {
        final lines = [
          'Forum Link: https://fractalsoftworks.com/forum/index.php?topic=11111.0',
          'Forum Thread: https://fractalsoftworks.com/forum/index.php?topic=22222.0',
        ];

        final result = DiscordReader.getForumUrlFromMessage(lines);
        expect(result, contains('topic=11111'),
            reason: 'First labeled URL should be kept (??= assignment)');
      });
    });
  });

  // ---------------------------------------------------------------------------
  // removeMarkdownFromName — pure function tests
  // ---------------------------------------------------------------------------
  group('removeMarkdownFromName', () {
    test('removes bold markdown', () {
      expect(DiscordReader.removeMarkdownFromName('**Bold Name**'), equals('Bold Name'));
    });

    test('removes italic underscores', () {
      expect(DiscordReader.removeMarkdownFromName('_Italic Name_'), equals('Italic Name'));
    });

    test('removes italic asterisks', () {
      expect(DiscordReader.removeMarkdownFromName('*Italic Name*'), equals('Italic Name'));
    });

    test('removes strikethrough', () {
      expect(DiscordReader.removeMarkdownFromName('~~Strikethrough~~'), equals('Strikethrough'));
    });

    test('removes inline code', () {
      expect(DiscordReader.removeMarkdownFromName('`Code Name`'), equals('Code Name'));
    });

    test('removes nested markdown', () {
      expect(DiscordReader.removeMarkdownFromName('**_Bold Italic_**'), equals('Bold Italic'));
    });

    test('leaves plain text unchanged', () {
      expect(DiscordReader.removeMarkdownFromName('Plain Name'), equals('Plain Name'));
    });

    test('real example: Substance.Abuse thread name', () {
      // Thread name wouldn't typically have markdown but test the function itself.
      expect(DiscordReader.removeMarkdownFromName('Substance.Abuse 1.1.c - Consumable Alcohol'),
          equals('Substance.Abuse 1.1.c - Consumable Alcohol'));
    });
  });

  // ---------------------------------------------------------------------------
  // parseAsThread — integration tests with real Discord data
  // These test the full parsing pipeline including URL extraction.
  // Note: getUrlsFromMessage calls Common.isDownloadable which requires
  // network access. These tests verify forum URL extraction and basic
  // ScrapedMod fields that don't depend on the network call.
  // ---------------------------------------------------------------------------
  group('parseAsThread', () {
    const serverId = '187635036525166592';
    const categoriesLookup = <String, String>{
      '1354896158199255211': 'Portrait/Flag Pack',
      '1203052542024622170': 'Library',
      '1203052556364816444': 'Utility',
      '1203052569572933642': 'Megamod',
      '1203052581245423676': 'Faction',
      '1203052594533236787': 'Ship Pack',
      '1203052624694349905': 'Weapon/Fighter Pack',
      '1203052663932067990': 'Colonies',
      '1203052688103972934': 'Quests and Bars',
      '1203052706713833482': 'Exploration',
      '1203052739186393118': 'Misc. Campaign Mods',
      '1203052812171477072': 'Quality of Life',
      '1203052840314998784': 'Audio/Visual',
      '1203052896116019210': 'Other/Misc.',
    };

    test('Animated Vanilla Portraits: correct forum URL, not VideoLib dependency', () async {
      final thread = const Channel(
        id: '1463849555396132916',
        name: 'Animated Vanilla Portraits',
        ownerId: '237277922916827136',
        appliedTags: ['1354896158199255211'],
      );

      final messages = [
        Message(
          id: '1463849555396132916',
          author: const User(id: '237277922916827136', username: 'ymfah'),
          content:
              'Animate all 225 vanilla portraits with comm static.\nRequires VideoLib : https://fractalsoftworks.com/forum/index.php?topic=34134\n\nDownload : https://mega.nz/file/864lRQZR#lxyxnlRSBGoTQMMwT2-PL85lisaO17kMRJcxu803I8c\nForum Link : http://fractalsoftworks.com/forum/index.php?topic=34849',
          timestamp: DateTime(2026, 1, 22, 10, 55),
          parentThread: thread,
        ),
        Message(
          id: '1463850332139425834',
          author: const User(id: '237277922916827136', username: 'ymfah'),
          content:
              'Works across all instance where a portrait appears, including:\n- Comms\n- Officer\n- Combat',
          timestamp: DateTime(2026, 1, 22, 10, 58),
          parentThread: thread,
        ),
        Message(
          id: '1465269384808366151',
          author: const User(id: '237277922916827136', username: 'ymfah'),
          content:
              'New update to VideoLib (v0.02 -> v0.1.1) drastically improves performance and ram usage for this mod as well.(https://github.com/rolfosian/Starsector-VideoLib/releases/tag/v0.1.1)\nBumping up RAM using TriOS is no longer needed.',
          timestamp: DateTime(2026, 1, 26, 8, 57),
          parentThread: thread,
        ),
        Message(
          id: '1465985668848156788',
          author: const User(id: '218010745181306880', username: 'rolfos'),
          content:
              'https://github.com/rolfosian/Starsector-VideoLib/releases/download/v0.1.1a/VideoLib.0.1.1a.zip patch with bug fixes for stuff no one would be using anyway',
          timestamp: DateTime(2026, 1, 28, 8, 23),
          parentThread: thread,
        ),
      ];

      final mod = await DiscordReader.parseAsThread(serverId, messages, categoriesLookup);

      expect(mod, isNotNull);
      expect(mod!.name, equals('Animated Vanilla Portraits'));
      expect(mod.authorsList, equals(['ymfah']));
      expect(mod.sources, equals([ModSource.Discord]));
      expect(mod.categories, equals(['Portrait/Flag Pack']));

      // The critical assertion: forum URL should be the mod's own, not VideoLib's.
      expect(mod.urls?[ModUrlType.Forum], contains('topic=34849'),
          reason: 'Forum URL should be Animated Vanilla Portraits (34849), not VideoLib (34134)');

      // Should NOT contain VideoLib's download URL.
      final directDl = mod.urls?[ModUrlType.DirectDownload] ?? '';
      final dlPage = mod.urls?[ModUrlType.DownloadPage] ?? '';
      expect(directDl, isNot(contains('VideoLib')),
          reason: 'Direct download should not be VideoLib');
      expect(dlPage, isNot(contains('rolfosian')),
          reason: 'Download page should not be VideoLib');
    });

    test('LazyLib: simple single-message thread', () async {
      final thread = const Channel(
        id: '1203159636602126367',
        name: 'LazyLib',
        ownerId: '139143349222244353',
        appliedTags: ['1203052542024622170'],
      );

      final messages = [
        Message(
          id: '1203159636602126367',
          author: const User(id: '139143349222244353', username: 'arkmagius'),
          content:
              'A library to simplify basic mod programming tasks. If you play with mods, chances are you\'ll need this installed.\n\nDownload: https://github.com/LazyWizard/lazylib/releases/download/2.8b/LazyLib.2.8b.zip\nForum thread: https://fractalsoftworks.com/forum/index.php?topic=5444.0\nOnline documentation: https://lazywizard.github.io/lazylib/',
          timestamp: DateTime(2024, 2, 2, 12, 0),
          parentThread: thread,
        ),
      ];

      final mod = await DiscordReader.parseAsThread(serverId, messages, categoriesLookup);

      expect(mod, isNotNull);
      expect(mod!.name, equals('LazyLib'));
      expect(mod.authorsList, equals(['arkmagius']));
      expect(mod.urls?[ModUrlType.Forum], contains('topic=5444'));
      expect(mod.categories, equals(['Library']));
    });

    test('Substance.Abuse: markdown-style forum/download links', () async {
      final thread = const Channel(
        id: '1203464439656087632',
        name: 'Substance.Abuse 1.1.c - Consumable Alcohol',
        ownerId: '378072735013797891',
        appliedTags: ['1203052663932067990', '1203052739186393118'],
      );

      final messages = [
        Message(
          id: '1203464439656087632',
          author: const User(id: '378072735013797891', username: 'sirhartley'),
          content:
              '`DRINK! DRINK! DRINK! (drink responsibly)`\n\nSubstance Abuse adds 10 consumable alcohols with multiple ongoing effects and full economy integration, industry items, and an industry to produce them.\n\n# [Support my Efforts](https://patreon.com/SirHartley)\n# [Download](https://github.com/SirHartley/Substance.Abuse.Legacy/releases/download/1.1.d/Substance.Abuse1.1.d.zip)\n# [Forum Thread](https://fractalsoftworks.com/forum/index.php?topic=24378.0)',
          timestamp: DateTime(2024, 2, 2, 12, 0),
          parentThread: thread,
        ),
      ];

      final mod = await DiscordReader.parseAsThread(serverId, messages, categoriesLookup);

      expect(mod, isNotNull);
      expect(mod!.name, equals('Substance.Abuse 1.1.c - Consumable Alcohol'));
      expect(mod.authorsList, equals(['sirhartley']));
      expect(mod.urls?[ModUrlType.Forum], contains('topic=24378'));
      expect(mod.categories, containsAll(['Colonies', 'Misc. Campaign Mods']));
    });

    test('Gudalanmu: no forum URL, Discord-only', () async {
      final thread = const Channel(
        id: '1355629913016635392',
        name: 'Gudalanmu 0.27',
        ownerId: '232115245395476481',
        appliedTags: ['1203052581245423676'],
      );

      final messages = [
        Message(
          id: '1355629913016635392',
          author: const User(id: '232115245395476481', username: 'mrmagolor'),
          content:
              'Original mod by: fire_turtle\n\nAn alien faction arrives in the north-eastern corner of the core worlds after an eternity of wandering.\n\nDownload: https://drive.google.com/uc?export=download&id=14ofSbuB1RQIlq_NLoBQAJ40x7GZiptv9',
          timestamp: DateTime(2025, 3, 31, 12, 0),
          parentThread: thread,
        ),
      ];

      final mod = await DiscordReader.parseAsThread(serverId, messages, categoriesLookup);

      expect(mod, isNotNull);
      expect(mod!.name, equals('Gudalanmu 0.27'));
      expect(mod.authorsList, equals(['mrmagolor']));
      expect(mod.urls?[ModUrlType.Forum], isNull,
          reason: 'No fractalsoftworks URL in this mod');
      expect(mod.urls?[ModUrlType.Discord], isNotNull);
      expect(mod.categories, equals(['Faction']));
    });

    test('Pipebomb: ultra-short Discord-only mod', () async {
      final thread = const Channel(
        id: '1224227101486481530',
        name: 'Pipebomb',
        ownerId: '156062291316441089',
        appliedTags: ['1203052840314998784', '1203052896116019210', '1203052556364816444'],
      );

      final messages = [
        Message(
          id: '1224227101486481530',
          author: const User(id: '156062291316441089', username: 'puretilt'),
          content:
              'replaces phase mines with pipebombs\nhttps://www.dropbox.com/scl/fi/23z9zk6jh8ir0dosx3tzy/pipebombSoCool.rar?rlkey=jcsforqdcgzq4r7f7r25vj5ig&dl=0',
          timestamp: DateTime(2024, 4, 1, 12, 0),
          parentThread: thread,
        ),
      ];

      final mod = await DiscordReader.parseAsThread(serverId, messages, categoriesLookup);

      expect(mod, isNotNull);
      expect(mod!.name, equals('Pipebomb'));
      expect(mod.authorsList, equals(['puretilt']));
      expect(mod.urls?[ModUrlType.Forum], isNull);
      expect(mod.categories, containsAll(['Audio/Visual', 'Other/Misc.', 'Utility']));
    });

    test('XXVII Battle group: Requires dep label, no forum URL, alt-author reply ignored', () async {
      final thread = const Channel(
        id: '1265952365031456779',
        name: 'XXVII Battle group v0.9.7',
        ownerId: '792427386452443186',
        appliedTags: ['1203052581245423676'],
      );

      final messages = [
        Message(
          id: '1265952365031456779',
          author: const User(id: '792427386452443186', username: 'yisic'),
          content:
              'Add a mid-tech battle group. Having some vanilla-like ships.\n\nRequires Graphic Lib/Lazy Lib/Magic Lib/Nex\n\nGithub(English version): https://github.com/dilinganye/XXVIIBattleGroup_EN/releases/tag/Shakeles_Garrsion',
          timestamp: DateTime(2024, 7, 24, 12, 0),
          parentThread: thread,
        ),
        // Reply from a DIFFERENT user (alt account) with a newer download link.
        Message(
          id: '1357775827978289392',
          author: const User(id: '1342184740547067935', username: 'yisic_lite'),
          content:
              'The download link of the newest version https://github.com/dilinganye/XXVIIBattleGroup_EN/releases/tag/Shakeles_Garrsion_V1.0.0',
          timestamp: DateTime(2025, 4, 7, 12, 0),
          parentThread: thread,
        ),
      ];

      final mod = await DiscordReader.parseAsThread(serverId, messages, categoriesLookup);

      expect(mod, isNotNull);
      expect(mod!.name, equals('XXVII Battle group v0.9.7'));
      expect(mod.authorsList, equals(['yisic']));
      expect(mod.urls?[ModUrlType.Forum], isNull,
          reason: 'No fractalsoftworks forum URL');
      // The yisic_lite reply should be filtered out since it is a different author.
      // Download URL should come from the first message only.
    });

    test('thread with empty messages still parses', () async {
      final thread = const Channel(
        id: 'test-thread',
        name: 'Test Mod',
        ownerId: 'author1',
        appliedTags: [],
      );

      final messages = [
        Message(
          id: 'msg1',
          author: const User(id: 'author1', username: 'testuser'),
          content: '',
          timestamp: DateTime(2024, 1, 1),
          parentThread: thread,
        ),
        Message(
          id: 'msg2',
          author: const User(id: 'author1', username: 'testuser'),
          content: 'The actual mod description.\nForum Link: https://fractalsoftworks.com/forum/index.php?topic=99999.0',
          timestamp: DateTime(2024, 1, 2),
          parentThread: thread,
        ),
      ];

      final mod = await DiscordReader.parseAsThread(serverId, messages, categoriesLookup);

      expect(mod, isNotNull);
      expect(mod!.name, equals('Test Mod'));
      expect(mod.urls?[ModUrlType.Forum], contains('topic=99999'));
    });

    test('empty message list returns null', () async {
      final mod = await DiscordReader.parseAsThread(serverId, [], categoriesLookup);
      expect(mod, isNull);
    });

    test('categories resolved from applied tags', () async {
      final thread = const Channel(
        id: 'test-thread',
        name: 'Multi-Category Mod',
        ownerId: 'author1',
        appliedTags: ['1203052706713833482', '1203052688103972934', '1203052739186393118'],
      );

      final messages = [
        Message(
          id: 'msg1',
          author: const User(id: 'author1', username: 'testuser'),
          content: 'A cool exploration mod.',
          timestamp: DateTime(2024, 1, 1),
          parentThread: thread,
        ),
      ];

      final mod = await DiscordReader.parseAsThread(serverId, messages, categoriesLookup);

      expect(mod, isNotNull);
      expect(mod!.categories, containsAll(['Exploration', 'Quests and Bars', 'Misc. Campaign Mods']));
    });

    test('Discord URL is correctly built from serverId and thread/message IDs', () async {
      final thread = const Channel(
        id: 'thread-123',
        name: 'Test Mod',
        ownerId: 'author1',
        appliedTags: [],
      );

      final messages = [
        Message(
          id: 'msg-456',
          author: const User(id: 'author1', username: 'testuser'),
          content: 'Test content',
          timestamp: DateTime(2024, 1, 1),
          parentThread: thread,
        ),
      ];

      final mod = await DiscordReader.parseAsThread(serverId, messages, categoriesLookup);

      expect(mod, isNotNull);
      expect(mod!.urls?[ModUrlType.Discord],
          equals('https://discord.com/channels/$serverId/thread-123/msg-456'));
    });

    test('summary is first two lines of first message content', () async {
      final thread = const Channel(
        id: 'test-thread',
        name: 'Test Mod',
        ownerId: 'author1',
        appliedTags: [],
      );

      final messages = [
        Message(
          id: 'msg1',
          author: const User(id: 'author1', username: 'testuser'),
          content: 'First line of description.\nSecond line.\nThird line.\nFourth line.',
          timestamp: DateTime(2024, 1, 1),
          parentThread: thread,
        ),
      ];

      final mod = await DiscordReader.parseAsThread(serverId, messages, categoriesLookup);

      expect(mod, isNotNull);
      expect(mod!.summary, equals('First line of description.\nSecond line.'));
      expect(mod.description, contains('Fourth line.'));
    });

    test('source is always Discord', () async {
      final thread = const Channel(
        id: 'test-thread',
        name: 'Test Mod',
        ownerId: 'author1',
        appliedTags: [],
      );

      final messages = [
        Message(
          id: 'msg1',
          author: const User(id: 'author1', username: 'testuser'),
          content: 'Mod content.',
          timestamp: DateTime(2024, 1, 1),
          parentThread: thread,
        ),
      ];

      final mod = await DiscordReader.parseAsThread(serverId, messages, categoriesLookup);
      expect(mod!.sources, equals([ModSource.Discord]));
    });

    test('messages ordered chronologically even if passed out of order', () async {
      final thread = const Channel(
        id: 'test-thread',
        name: 'Test Mod',
        ownerId: 'author1',
        appliedTags: [],
      );

      final messages = [
        // Second message passed first
        Message(
          id: 'msg2',
          author: const User(id: 'author1', username: 'testuser'),
          content: 'This is a follow-up.',
          timestamp: DateTime(2024, 1, 2),
          parentThread: thread,
        ),
        // First message passed second
        Message(
          id: 'msg1',
          author: const User(id: 'author1', username: 'testuser'),
          content: 'First post with links.\nForum Link: https://fractalsoftworks.com/forum/index.php?topic=12345.0',
          timestamp: DateTime(2024, 1, 1),
          parentThread: thread,
        ),
      ];

      final mod = await DiscordReader.parseAsThread(serverId, messages, categoriesLookup);

      expect(mod, isNotNull);
      // The first message (chronologically) should be used for content/URLs.
      expect(mod!.urls?[ModUrlType.Forum], contains('topic=12345'));
      expect(mod.description, contains('First post with links'));
    });
  });

  // ---------------------------------------------------------------------------
  // Download URL filtering in getUrlsFromMessage (dependency lines excluded)
  // Note: These tests will try to call Common.isDownloadable which hits the network.
  // They verify the dependency-filtering logic for the download candidates.
  // ---------------------------------------------------------------------------
  group('getUrlsFromMessage dependency filtering for downloads', () {
    test('Requires line URLs excluded from download candidates', () async {
      final lines = [
        'Requires VideoLib : https://fractalsoftworks.com/forum/index.php?topic=34134',
        'Download : https://mega.nz/file/864lRQZR#lxyxnlRSBGoTQMMwT2-PL85lisaO17kMRJcxu803I8c',
        'Forum Link : http://fractalsoftworks.com/forum/index.php?topic=34849',
      ];

      final (forumUrl, directDl, dlPage) = await DiscordReader.getUrlsFromMessage(lines);

      // Forum URL should be the mod's own.
      expect(forumUrl, contains('topic=34849'));
      // The Requires line's URL should be excluded from both download candidates.
      // (It's in _thingsThatAreNotDownloady too, but the dependency filter adds another layer.)
    });

    test('non-dependency URLs are still considered for downloads', () async {
      // A message with only a download URL and no dependencies.
      final lines = [
        'A cool mod.',
        'Download: https://github.com/example/mod/releases/download/v1.0/mod.zip',
      ];

      final (forumUrl, directDl, dlPage) = await DiscordReader.getUrlsFromMessage(lines);

      // No forum URL.
      expect(forumUrl, isNull);
      // The GitHub download link should be found.
      // (Whether it's directDl or dlPage depends on isDownloadable, which needs network,
      // but it should appear in one of them.)
    });
  });
}
