import 'package:mod_repo_scraper/bot/scraper/scraped_mod.dart';
import 'package:mod_repo_scraper/site/discord_download.dart';
import 'package:test/test.dart';

void main() {
  group('the download a Discord announcement carried', () {
    test('is nothing when the announcement had no download link', () {
      expect(
        discordDownloadFor(const {
          ModUrlType.Discord: 'https://discord.com/channels/1/2/3',
        }),
        isNull,
      );
    });

    test('is the direct link when there is one', () {
      final download = discordDownloadFor(const {
        ModUrlType.Discord: 'https://discord.com/channels/1/2/3',
        ModUrlType.DirectDownload:
            'https://github.com/a/b/releases/download/1.0.1/alkemia-1.0.1.zip',
      })!;

      expect(download.url,
          'https://github.com/a/b/releases/download/1.0.1/alkemia-1.0.1.zip');
      expect(download.needsAnotherStep, isFalse);
      expect(download.directUrl, download.url);
      expect(download.fileName, 'alkemia-1.0.1.zip');
      expect(download.host, 'GitHub');
    });

    test('falls back to the download page when there is no direct link', () {
      final download = discordDownloadFor(const {
        ModUrlType.DownloadPage: 'https://www.fossic.org/thread-12826-1-1.html',
      })!;

      expect(download.url, 'https://www.fossic.org/thread-12826-1-1.html');
      expect(download.needsAnotherStep, isTrue);
      expect(download.directUrl, isNull);
    });
  });

  group('what needs another step', () {
    // The Astartes Minipack, which is what started this. The scraper filed
    // this under DirectDownload because its probe thought it was downloadable,
    // but it opens Drive's preview page. A button saying "Download" would be a
    // lie, and setting directUrl would put it behind the browse page's "goes
    // straight to a file" switch.
    test('a Google Drive view page does, though it is filed as direct', () {
      final download = discordDownloadFor(const {
        ModUrlType.DirectDownload:
            'https://drive.google.com/file/d/1ANiXX8vidc9fZZAhuo2cMJk2tk-ZtnTd/view?usp=sharing',
      })!;

      expect(download.needsAnotherStep, isTrue);
      expect(download.directUrl, isNull);
      expect(download.fileName, isNull);
      expect(download.host, 'Google Drive');
    });

    test("Google Drive's own export address does not", () {
      final download = discordDownloadFor(const {
        ModUrlType.DirectDownload:
            'https://drive.google.com/uc?export=download&id=1jie8F3V4oia',
      })!;

      expect(download.needsAnotherStep, isFalse);
      expect(download.directUrl, download.url);
    });

    test('a mega.nz file does', () {
      final download = discordDownloadFor(const {
        ModUrlType.DirectDownload: 'https://mega.nz/file/Me5wnK7I#eZMBzreBJZ',
      })!;

      expect(download.needsAnotherStep, isTrue);
      expect(download.directUrl, isNull);
    });

    test('a Dropbox share asking for the file does not', () {
      final download = discordDownloadFor(const {
        ModUrlType.DirectDownload:
            'https://www.dropbox.com/s/lxq/Domain%20Drones%2B%20Vanilla.rar?dl=1',
      })!;

      expect(download.needsAnotherStep, isFalse);
      expect(download.fileName, 'Domain Drones+ Vanilla.rar');
      expect(download.host, 'Dropbox');
    });

    test('a GitHub releases page does, but a release asset does not', () {
      final page = discordDownloadFor(const {
        ModUrlType.DirectDownload: 'https://github.com/Anex/AnexWeapons/releases/latest/',
      })!;
      expect(page.needsAnotherStep, isTrue);

      final asset = discordDownloadFor(const {
        ModUrlType.DirectDownload:
            'https://github.com/s/b/releases/latest/download/bustednomore.zip',
      })!;
      expect(asset.needsAnotherStep, isFalse);
      expect(asset.fileName, 'bustednomore.zip');
    });
  });

  group('what is not a download at all', () {
    // getUrlsFromMessage in discord_reader.dart ends with `?? forumUrl`, so a
    // mod whose announcement had no download link stores its forum thread as
    // the download page. 138 mods do. A "Download page" button that opens the
    // forum thread is worse than the "On the forum" button it would replace.
    test('the forum thread stored as a download page', () {
      expect(
        discordDownloadFor(const {
          ModUrlType.Forum:
              'https://fractalsoftworks.com/forum/index.php?topic=25807',
          ModUrlType.DownloadPage:
              'https://fractalsoftworks.com/forum/index.php?topic=25807',
        }),
        isNull,
      );
    });

    test("a forum thread that is not even the mod's own", () {
      expect(
        discordDownloadFor(const {
          ModUrlType.DownloadPage:
              'https://fractalsoftworks.com/forum/index.php?topic=30687.0',
        }),
        isNull,
      );
    });

    test('a Discord message link', () {
      expect(
        discordDownloadFor(const {
          ModUrlType.DownloadPage:
              'https://discord.com/channels/187635036525166592/1208975007993176094',
        }),
        isNull,
      );
    });

    test('a link to a subreddit', () {
      expect(
        discordDownloadFor(const {
          ModUrlType.DownloadPage: 'https://www.reddit.com/r/vexillology/',
        }),
        isNull,
      );
    });

    test("the mod's own Nexus page", () {
      expect(
        discordDownloadFor(const {
          ModUrlType.NexusMods: 'https://www.nexusmods.com/starsector/mods/12',
          ModUrlType.DownloadPage:
              'https://www.nexusmods.com/starsector/mods/12',
        }),
        isNull,
      );
    });

    test('anything that is not a web address', () {
      for (final bad in const [
        'not a url',
        'ftp://example.com/mod.zip',
        'javascript:alert(1)',
        '',
        '   ',
      ]) {
        expect(
          discordDownloadFor({ModUrlType.DirectDownload: bad}),
          isNull,
          reason: 'should have refused "$bad"',
        );
      }
    });

    test('but a junk direct link still lets the download page through', () {
      final download = discordDownloadFor(const {
        ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=1.0',
        ModUrlType.DirectDownload:
            'https://fractalsoftworks.com/forum/index.php?topic=1.0',
        ModUrlType.DownloadPage: 'https://www.mediafire.com/file/abc/mod.zip',
      })!;

      expect(download.url, 'https://www.mediafire.com/file/abc/mod.zip');
      expect(download.host, 'MediaFire');
    });
  });
}
