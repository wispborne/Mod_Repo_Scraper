import 'package:mod_repo_scraper/site/discord_markdown.dart';
import 'package:test/test.dart';

void main() {
  group('discordMarkdownAsHtml', () {
    test('nothing in, nothing out', () {
      expect(discordMarkdownAsHtml(null), isNull);
      expect(discordMarkdownAsHtml('   '), isNull);
    });

    test('lines become paragraphs, a blank line between them', () {
      expect(discordMarkdownAsHtml('one\ntwo\n\nthree'),
          '<p>one<br>two</p><p>three</p>');
    });

    test('bold, italics, underline and strikethrough', () {
      final html = discordMarkdownAsHtml(
          '**bold** *italic* _also_ __under__ ~~gone~~ ***both***')!;
      expect(html, contains('<strong>bold</strong>'));
      expect(html, contains('<em>italic</em>'));
      expect(html, contains('<em>also</em>'));
      expect(html, contains('<u>under</u>'));
      expect(html, contains('<s>gone</s>'));
      expect(html, contains('<strong><em>both</em></strong>'));
    });

    test('underscores inside an address are not read as italics', () {
      final html = discordMarkdownAsHtml(
          'https://www.mediafire.com/file/x/Mayasuran_Navy_11.0.0_RC4.zip/file')!;
      expect(html, isNot(contains('<em>')));
      expect(html, contains('href="https://www.mediafire.com/file/x/Mayasuran_Navy_11.0.0_RC4.zip/file"'));
    });

    test('a link with words of its own keeps them', () {
      final html = discordMarkdownAsHtml('[Download **here**](https://example.com/a)')!;
      expect(html, contains('href="https://example.com/a"'));
      expect(html, contains('Download <strong>here</strong></a>'));
    });

    test('headings sit below the page\'s own', () {
      expect(discordMarkdownAsHtml('# Big\n## Middle\n### Small'),
          '<h3>Big</h3><h4>Middle</h4><h5>Small</h5>');
    });

    test('lists, numbered lists and a list inside an item', () {
      expect(discordMarkdownAsHtml('- one\n- two\n  - inner\n- three'),
          '<ul><li>one</li><li>two<ul><li>inner</li></ul></li><li>three</li></ul>');
      expect(discordMarkdownAsHtml('1. first\n2. second'),
          '<ol><li>first</li><li>second</li></ol>');
    });

    test('quotes', () {
      expect(discordMarkdownAsHtml('> quoted\n> still\nafter'),
          '<blockquote><p>quoted<br>still</p></blockquote><p>after</p>');
      expect(discordMarkdownAsHtml('before\n>>> all\nof this'),
          '<p>before</p><blockquote><p>all<br>of this</p></blockquote>');
    });

    test('code is kept as written, marks and all', () {
      expect(discordMarkdownAsHtml('```java\nint **x** = 1;\n```'),
          '<pre><code>int **x** = 1;</code></pre>');
      expect(discordMarkdownAsHtml('```Lore```\nText'),
          '<pre><code>Lore</code></pre><p>Text</p>');
      expect(discordMarkdownAsHtml('use `a_b_c` here'),
          '<p>use <code>a_b_c</code> here</p>');
    });

    // Industrial Evolution's post shuts one block and opens the next on one
    // line. Reading "```diff" as words left every fence after it out of step,
    // so the rest of the post came out as code.
    test('a block that opens on the line another one shuts', () {
      expect(
          discordMarkdownAsHtml(
              '```diff\nChangelog:\n``````diff\n- NOT save compatible\n```\n'
              '# [Download](https://x.com/a.zip)\n_the end_'),
          '<pre><code>Changelog:</code></pre>'
          '<pre><code>- NOT save compatible</code></pre>'
          '<h3><a href="https://x.com/a.zip" rel="nofollow noopener" target="_blank">Download</a></h3>'
          '<p><em>the end</em></p>');
    });

    test('mentions go, emoji keep their names, spoilers are plain words', () {
      expect(discordMarkdownAsHtml('Thanks <@1234> in <#99> <:smile:42> ||secret||'),
          '<p>Thanks  in  :smile: secret</p>');
    });

    test('a timestamp becomes its day', () {
      expect(discordMarkdownAsHtml('Out <t:1700000000:R>'), '<p>Out 2023-11-14</p>');
    });

    test('nothing that can run gets through', () {
      final html = discordMarkdownAsHtml(
          '<script>alert(1)</script> [x](javascript:alert(1)) <img src=x onerror=alert(1)>')!;
      expect(html, isNot(contains('<script')));
      expect(html, isNot(contains('<img')));
      expect(html, isNot(contains('href="javascript')));
    });
  });

  test('sameWords ignores spacing only', () {
    expect(sameWords('a  b\nc', 'a b c'), isTrue);
    expect(sameWords('a b', 'a c'), isFalse);
    expect(sameWords(null, 'a'), isFalse);
  });
}
