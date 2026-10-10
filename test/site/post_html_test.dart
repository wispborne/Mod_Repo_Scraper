import 'package:mod_repo_scraper/site/post_html.dart';
import 'package:test/test.dart';

/// The mod page shows the author's own forum post. It arrives as whatever HTML
/// the forum produced, so only a small, safe set of tags is published: enough
/// to keep paragraphs, lists, emphasis, links and pictures, and nothing that
/// can run or style the page.
void main() {
  test('keeps paragraphs, lists and emphasis', () {
    expect(
      cleanPostHtml('<p>Hello <b>world</b></p><ul><li>one</li><li>two</li></ul>'),
      '<p>Hello <b>world</b></p><ul><li>one</li><li>two</li></ul>',
    );
  });

  test('drops scripts, styles and frames', () {
    final cleaned = cleanPostHtml(
      '<p>Before</p><script>alert(1)</script><style>p{color:red}</style>'
      '<iframe src="https://example.com"></iframe>'
      '<p>After</p>',
    );
    expect(cleaned, '<p>Before</p><p>After</p>');
  });

  const pictureTail = 'loading="lazy" decoding="async" referrerpolicy="no-referrer">';

  test('keeps a picture where the post put it', () {
    expect(
      cleanPostHtml('<p>Before</p><img src="https://i.imgur.com/a.png" '
          'alt="" class="bbc_img"><p>After</p>'),
      '<p>Before</p><img src="https://i.imgur.com/a.png" alt="" $pictureTail'
      '<p>After</p>',
    );
  });

  test('a picture keeps only its address, alt text and size', () {
    expect(
      cleanPostHtml('<img src="https://x/y.png" alt="A ship" width="640" '
          'height="360" style="border:9px" class="c" onerror="go()">'),
      isNull, // a picture alone is no description: nothing to read
    );
    expect(
      cleanPostHtml('<p>Hi<img src="https://x/y.png" alt="A &quot;ship&quot;" '
          'width="640" height="12px" style="border:9px" class="c" '
          'onerror="go()"></p>'),
      '<p>Hi<img src="https://x/y.png" alt="A &quot;ship&quot;" width="640" '
      '$pictureTail</p>',
    );
  });

  test('a picture with an address that is not a web address is dropped', () {
    expect(cleanPostHtml('<p>Hi<img src="javascript:alert(1)"></p>'), '<p>Hi</p>');
    expect(cleanPostHtml('<p>Hi<img src="data:image/png;base64,AAAA"></p>'),
        '<p>Hi</p>');
    expect(cleanPostHtml('<p>Hi<img></p>'), '<p>Hi</p>');
  });

  test('badges and donation buttons are kept too', () {
    expect(
      cleanPostHtml('<p>Hi</p><img src="https://storage.ko-fi.com/cdn/kofi.png">'),
      '<p>Hi</p><img src="https://storage.ko-fi.com/cdn/kofi.png" alt="" '
      '$pictureTail',
    );
  });

  test('a download link whose only content is a badge is kept', () {
    // Topic 35651's shape: every download is a shields.io badge in a link.
    expect(
      cleanPostHtml('<p>Get it</p><a href="https://github.com/x/y/releases">'
          '<img src="https://img.shields.io/badge/KWIN-RELEASE-blue"></a>'),
      '<p>Get it</p><a href="https://github.com/x/y/releases" '
      'rel="nofollow noopener" target="_blank">'
      '<img src="https://img.shields.io/badge/KWIN-RELEASE-blue" alt="" '
      '$pictureTail</a>',
    );
  });

  test('line breaks around a picture are left alone', () {
    expect(
      cleanPostHtml('A<br><br><img src="https://x/y.png"><br><br>B'),
      'A<br><br><img src="https://x/y.png" alt="" $pictureTail<br><br>B',
    );
  });

  test('picture tags do not count toward the length cap', () {
    final pictures = List.generate(
        200, (i) => '<img src="https://i.imgur.com/picture$i.png">').join();
    final cleaned = cleanPostHtml('<p>Short words.</p>$pictures<p>The end.</p>')!;
    expect(cleaned, contains('picture199.png'));
    expect(cleaned, contains('The end.'));
    expect(cleaned, isNot(endsWith('<p>…</p>')));
  });

  test('the plain words of a post leave its pictures out', () {
    expect(postHtmlAsText('<p>Hello<img src="https://x/y.png"> world</p>'),
        'Hello world');
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
          '<img src="javascript:x"></a>'),
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
