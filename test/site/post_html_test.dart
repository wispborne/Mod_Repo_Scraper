import 'package:mod_repo_scraper/site/post_html.dart';
import 'package:test/test.dart';

/// The mod page shows the author's own forum post. It arrives as whatever HTML
/// the forum produced, so only a small, safe set of tags is published: enough
/// to keep paragraphs, lists, emphasis and links, and nothing that can run,
/// style the page or load anything from another host.
void main() {
  test('keeps paragraphs, lists and emphasis', () {
    expect(
      cleanPostHtml('<p>Hello <b>world</b></p><ul><li>one</li><li>two</li></ul>'),
      '<p>Hello <b>world</b></p><ul><li>one</li><li>two</li></ul>',
    );
  });

  test('drops scripts, styles and anything that loads from elsewhere', () {
    final cleaned = cleanPostHtml(
      '<p>Before</p><script>alert(1)</script><style>p{color:red}</style>'
      '<iframe src="https://example.com"></iframe><img src="https://x/y.png">'
      '<p>After</p>',
    );
    expect(cleaned, '<p>Before</p><p>After</p>');
  });

  test('drops every attribute except a link\'s address', () {
    expect(
      cleanPostHtml('<p class="x" style="color:red" onclick="go()">Hi</p>'),
      '<p>Hi</p>',
    );
  });

  test('links leave the site safely and are not followed by search engines', () {
    expect(
      cleanPostHtml('<a href="https://example.com/x" class="y">Link</a>'),
      '<a href="https://example.com/x" rel="nofollow noopener" '
      'target="_blank">Link</a>',
    );
  });

  test('a link to anything but the web is unwrapped, keeping its words', () {
    expect(cleanPostHtml('<a href="javascript:alert(1)">Click</a>'), 'Click');
    expect(cleanPostHtml('<a href="/forum/index.php">Board</a>'), 'Board');
  });

  test('turns a bare address into a link', () {
    expect(
      cleanPostHtml('<p>Get it at https://example.com/x.zip today</p>'),
      '<p>Get it at <a href="https://example.com/x.zip" rel="nofollow noopener" '
      'target="_blank">https://example.com/x.zip</a> today</p>',
    );
  });

  test('leaves an address that is already a link alone', () {
    expect(
      cleanPostHtml('<a href="https://example.com/">https://example.com/</a>'),
      '<a href="https://example.com/" rel="nofollow noopener" '
      'target="_blank">https://example.com/</a>',
    );
  });

  test('a bare address does not swallow the punctuation after it', () {
    expect(
      cleanPostHtml('<p>See https://example.com/x.</p>'),
      '<p>See <a href="https://example.com/x" rel="nofollow noopener" '
      'target="_blank">https://example.com/x</a>.</p>',
    );
  });

  test('escapes text so nothing can break out of it', () {
    expect(cleanPostHtml('<p>a &lt; b &amp; c "d"</p>'),
        '<p>a &lt; b &amp; c "d"</p>');
  });

  test('unwraps a tag it does not know, keeping what was inside', () {
    expect(cleanPostHtml('<div><span>Words</span></div>'), 'Words');
    expect(cleanPostHtml('<font color="red"><b>Bold</b></font>'), '<b>Bold</b>');
  });

  test('turns a big heading into a small one, so it cannot outshout the page', () {
    expect(cleanPostHtml('<h1>Title</h1>'), '<h3>Title</h3>');
    expect(cleanPostHtml('<h4>Sub</h4>'), '<h4>Sub</h4>');
  });

  test('drops a link left empty because its picture went', () {
    expect(
      cleanPostHtml('<p>Get it</p><a href="https://x/y.zip">'
          '<img src="https://x/banner.png"></a>'),
      '<p>Get it</p>',
    );
  });

  test('does not leave a wall of blank lines where the pictures were', () {
    expect(cleanPostHtml('A<br><br><br><br><br>B'), 'A<br><br>B');
    expect(cleanPostHtml('<br><br>Words<br><br>'), 'Words');
  });

  test('nothing in, nothing out', () {
    expect(cleanPostHtml(''), isNull);
    expect(cleanPostHtml(null), isNull);
    expect(cleanPostHtml('<p>  </p>'), isNull);
    expect(cleanPostHtml('<script>alert(1)</script>'), isNull);
  });

  test('cuts a very long post off at a paragraph and says so', () {
    final long = List.generate(1000, (i) => '<p>Paragraph number $i.</p>').join();
    final cleaned = cleanPostHtml(long)!;
    expect(cleaned.length, lessThan(maxDescriptionLength + 200));
    expect(cleaned, contains('Paragraph number 0.'));
    expect(cleaned, isNot(contains('Paragraph number 999.')));
    expect(cleaned, endsWith('<p>…</p>'));
  });

  test('plain words become paragraphs, with the addresses in them linked', () {
    expect(plainTextAsHtml('One line.\n\nAnother.'),
        '<p>One line.</p><p>Another.</p>');
    expect(plainTextAsHtml('A\nB'), '<p>A<br>B</p>');
    expect(
      plainTextAsHtml('Get it at https://example.com/x.zip'),
      '<p>Get it at <a href="https://example.com/x.zip" rel="nofollow noopener" '
      'target="_blank">https://example.com/x.zip</a></p>',
    );
    expect(plainTextAsHtml('  '), isNull);
    expect(plainTextAsHtml(null), isNull);
  });

  test('the plain words of a post, for anything that cannot show HTML', () {
    expect(postHtmlAsText('<p>Hello <b>world</b></p><p>Again</p>'),
        'Hello world\n\nAgain');
    expect(postHtmlAsText('<script>alert(1)</script>'), isNull);
  });
}
