import 'package:test/test.dart';

import 'package:mod_repo_scraper/bot/scraper/qb/html_processor.dart';

void main() {
  group('HtmlProcessor.stripSessionIds', () {
    test('drops PHPSESSID when it is the first query param (entity separator)',
        () {
      // The real shape seen in stored post HTML: the query separator is the
      // HTML entity &amp;, so the token value ends just before it.
      const html =
          '<a href="https://fractalsoftworks.com/forum/index.php?PHPSESSID=ba37c64828eab475215d3b8fc7ae8258&amp;topic=12041.0">link</a>';
      const expected =
          '<a href="https://fractalsoftworks.com/forum/index.php?topic=12041.0">link</a>';
      expect(HtmlProcessor.stripSessionIds(html), expected);
      expect(HtmlProcessor.stripSessionIds(html), isNot(contains('PHPSESSID')));
    });

    test('drops PHPSESSID when it is a later query param', () {
      const html =
          '<a href="https://fractalsoftworks.com/forum/index.php?topic=12041.0&amp;PHPSESSID=abc123">link</a>';
      const expected =
          '<a href="https://fractalsoftworks.com/forum/index.php?topic=12041.0">link</a>';
      expect(HtmlProcessor.stripSessionIds(html), expected);
    });

    test('drops PHPSESSID sitting between two other params', () {
      const html =
          '<a href="https://fractalsoftworks.com/forum/index.php?board=8.0&amp;PHPSESSID=abc123&amp;topic=1">link</a>';
      const expected =
          '<a href="https://fractalsoftworks.com/forum/index.php?board=8.0&amp;topic=1">link</a>';
      expect(HtmlProcessor.stripSessionIds(html), expected);
    });

    test('drops the "?" too when PHPSESSID is the only query param', () {
      const html =
          '<a href="https://fractalsoftworks.com/forum/index.php?PHPSESSID=abc123">link</a>';
      const expected =
          '<a href="https://fractalsoftworks.com/forum/index.php">link</a>';
      expect(HtmlProcessor.stripSessionIds(html), expected);
    });

    test('also handles a raw "&" separator, not only the entity form', () {
      const html =
          '<a href="https://fractalsoftworks.com/forum/index.php?PHPSESSID=abc123&topic=7">link</a>';
      const expected =
          '<a href="https://fractalsoftworks.com/forum/index.php?topic=7">link</a>';
      expect(HtmlProcessor.stripSessionIds(html), expected);
    });

    test('strips every occurrence in a post with several links', () {
      const html =
          '<a href="https://fractalsoftworks.com/forum/index.php?PHPSESSID=aaa&amp;topic=1">a</a>'
          '<a href="https://fractalsoftworks.com/forum/index.php?topic=2&amp;PHPSESSID=bbb">b</a>';
      final out = HtmlProcessor.stripSessionIds(html);
      expect(out, isNot(contains('PHPSESSID')));
      expect(out, contains('?topic=1'));
      expect(out, contains('?topic=2'));
    });

    test('leaves HTML without a session token untouched', () {
      const html =
          '<a href="https://github.com/user/repo/releases">download</a> and text';
      expect(HtmlProcessor.stripSessionIds(html), html);
    });

    test('is idempotent', () {
      const html =
          '<a href="https://fractalsoftworks.com/forum/index.php?PHPSESSID=abc123&amp;topic=1">link</a>';
      final once = HtmlProcessor.stripSessionIds(html);
      expect(HtmlProcessor.stripSessionIds(once), once);
    });

    test('does not disturb an unrelated download URL in the same post', () {
      const html =
          '<a href="https://fractalsoftworks.com/forum/index.php?PHPSESSID=abc123&amp;topic=1">forum</a>'
          '<a href="https://drive.google.com/uc?export=download&amp;id=XYZ">dl</a>';
      final out = HtmlProcessor.stripSessionIds(html);
      expect(out, isNot(contains('PHPSESSID')));
      expect(out, contains('export=download&amp;id=XYZ'));
    });
  });

  group('HtmlProcessor.processHtml', () {
    test('strips the session token as part of the normal cleanup pass', () {
      const html =
          '<a href="https://fractalsoftworks.com/forum/index.php?PHPSESSID=abc123&amp;topic=1">link</a>';
      final out = HtmlProcessor.processHtml(html);
      expect(out, isNot(contains('PHPSESSID')));
      expect(out, contains('?topic=1'));
    });
  });
}
