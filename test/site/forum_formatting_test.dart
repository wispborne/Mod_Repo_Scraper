import 'package:mod_repo_scraper/site/forum_formatting.dart';
import 'package:mod_repo_scraper/site/post_html.dart';
import 'package:test/test.dart';

/// The forum writes its formatting as `div`s and `span`s with classes and
/// styles of its own. The description keeps that formatting, but always in the
/// site's own tags and classes — every case below is markup copied from real
/// saved posts.
void main() {
  const pictureTail =
      'loading="lazy" decoding="async" referrerpolicy="no-referrer">';

  group('spoilers', () {
    test('a spoiler is a shut fold labelled with its title, without "[close]"',
        () {
      expect(
        cleanPostHtml('<div class="sp-wrap sp-wrap-default">'
            '<div class="sp-head">Changelog</div>'
            '<div class="sp-body folded">v1.2 fixes things<br>'
            '<div class="sp-foot">[close]</div></div></div>'),
        '<details class="spoiler"><summary>Changelog</summary>'
        'v1.2 fixes things</details>',
      );
    });

    test('a spoiler with no title is called "Spoiler"', () {
      expect(
        cleanPostHtml('<div class="sp-wrap"><div class="sp-head">&nbsp;</div>'
            '<div class="sp-body">Hidden</div></div>'),
        '<details class="spoiler"><summary>Spoiler</summary>Hidden</details>',
      );
    });

    test('a spoiler inside a spoiler folds inside it', () {
      final cleaned = cleanPostHtml('<div class="sp-wrap">'
          '<div class="sp-head">Outer</div><div class="sp-body">A'
          '<div class="sp-wrap"><div class="sp-head">Inner</div>'
          '<div class="sp-body">B</div></div></div></div>')!;
      expect(
          cleaned,
          '<details class="spoiler"><summary>Outer</summary>A'
          '<details class="spoiler"><summary>Inner</summary>B</details>'
          '</details>');
    });
  });

  group('quotes and code', () {
    test('a plain quote loses its "Quote" header', () {
      expect(
        cleanPostHtml('<div class="quoteheader"><div class="topslice_quote">'
            'Quote</div></div><blockquote class="bbc_standard_quote">'
            'In a far, far away solar system</blockquote>'
            '<div class="quotefooter"><div class="botslice_quote"></div></div>'),
        '<blockquote>In a far, far away solar system</blockquote>',
      );
    });

    test('a quote that names someone keeps the name as a cite', () {
      expect(
        cleanPostHtml('<div class="quoteheader"><div class="topslice_quote">'
            '<a href="https://fractalsoftworks.com/forum/index.php?topic=1.msg2#msg2">'
            'Quote from: Vayra on September 01, 2021</a></div></div>'
            '<blockquote class="bbc_standard_quote">Words</blockquote>'),
        '<blockquote><cite>Quote from: Vayra on September 01, 2021</cite>'
        'Words</blockquote>',
      );
    });

    test('a code block loses its "Code" header', () {
      expect(
        cleanPostHtml('<div class="codeheader">Code</div>'
            '<div class="block_code" style="font-size: small"><pre><code>'
            'v1.2.1<br>* Fixes</code></pre></div>'),
        '<pre><code>v1.2.1<br>* Fixes</code></pre>',
      );
    });

    test('typewriter text is code', () {
      expect(cleanPostHtml('<p>Run <tt class="bbc_tt">PrintChatterChars</tt></p>'),
          '<p>Run <code>PrintChatterChars</code></p>');
    });

    // The forum moved to SMF 2.1 in October 2026, which writes these its own way.
    test('an SMF 2.1 quote keeps the name from its cite, without the link', () {
      expect(
        cleanPostHtml('<blockquote class="bbc_standard_quote"><cite>'
            '<a href="https://fractalsoftworks.com/forum/index.php?topic=10982.msg187260#msg187260">'
            'Quote from: samsaq on April 21, 2016, 07:56:58 PM</a></cite><br />'
            'I have an issue.</blockquote>'),
        '<blockquote><cite>Quote from: samsaq on April 21, 2016, 07:56:58 PM</cite>'
        'I have an issue.</blockquote>',
      );
      expect(
        cleanPostHtml('<blockquote class="bbc_standard_quote"><cite>Quote</cite>'
            '<br />Words</blockquote>'),
        '<blockquote>Words</blockquote>',
      );
    });

    test('an SMF 2.1 code block loses its header and keeps its lines', () {
      expect(
        cleanPostHtml('<div class="codeheader"><span class="code floatleft">Code</span>'
            ' (java) <a class="codeoperation smf_select_text">Select</a></div>'
            '<code class="bbc_code">public static boolean hasGraphicsLib;<br />'
            '@Override</code>'),
        '<pre><code>public static boolean hasGraphicsLib;<br>@Override</code></pre>',
      );
    });

    test('SMF 2.1 typewriter text is code', () {
      expect(
        cleanPostHtml('<p>The <span class="monospace">magicSettings </span>functions</p>'),
        '<p>The <code>magicSettings </code>functions</p>',
      );
    });
  });

  group('tables', () {
    test('a table keeps its cells, in a box that scrolls sideways', () {
      expect(
        cleanPostHtml('<table class="bbc_table"><tbody><tr>'
            '<td><div align="center"><strong>Extreme Modifications</strong></div></td>'
            '<td><div align="center"><strong>PD Assault</strong></div></td>'
            '</tr></tbody></table>'),
        '<div class="table-scroll"><table><tbody><tr>'
        '<td><div class="align-center"><strong>Extreme Modifications</strong></div></td>'
        '<td><div class="align-center"><strong>PD Assault</strong></div></td>'
        '</tr></tbody></table></div>',
      );
    });

    test('an empty cell is kept, so the columns stay lined up', () {
      expect(
        cleanPostHtml('<table><tr><td></td><td>B</td></tr></table>'),
        '<div class="table-scroll"><table><tbody><tr><td></td><td>B</td>'
        '</tr></tbody></table></div>',
      );
    });

    test('the plain words of a table keep its cells apart', () {
      expect(postHtmlAsText('<table><tr><td>One</td><td>Two</td></tr></table>'),
          'One Two');
    });
  });

  group('alignment, size, underline and lists', () {
    test('centred and right-aligned blocks keep their alignment', () {
      expect(cleanPostHtml('<div align="center">Middle</div>'),
          '<div class="align-center">Middle</div>');
      expect(cleanPostHtml('<div style="text-align: right;">Right</div>'),
          '<div class="align-right">Right</div>');
      expect(cleanPostHtml('<div style="text-align: left;">Left</div>'), 'Left');
    });

    test('SMF 2.1 aligns with a class', () {
      expect(cleanPostHtml('<div class="centertext">Middle</div>'),
          '<div class="align-center">Middle</div>');
      expect(cleanPostHtml('<div class="righttext">Right</div>'),
          '<div class="align-right">Right</div>');
      expect(cleanPostHtml('<div class="lefttext">Left</div>'), 'Left');
    });

    test('an empty centred block goes', () {
      expect(cleanPostHtml('<p>Hi</p><div align="center"></div>'), '<p>Hi</p>');
    });

    test('sizes become one of four steps', () {
      String sized(String size) => cleanPostHtml(
          '<span style="font-size: $size;" class="bbc_size">Words</span>')!;
      expect(sized('8pt'), '<span class="size-small">Words</span>');
      expect(sized('12pt'), 'Words');
      expect(sized('14pt'), '<span class="size-big">Words</span>');
      expect(sized('18pt'), '<span class="size-bigger">Words</span>');
      expect(sized('36pt'), '<span class="size-biggest">Words</span>');
      expect(sized('1.35em'), '<span class="size-big">Words</span>');
      expect(sized('16px'), 'Words');
      expect(sized('huge'), 'Words');
    });

    test('an underline is underlined', () {
      expect(cleanPostHtml('<span class="bbc_u">Standard Loadout</span>'),
          '<u>Standard Loadout</u>');
    });

    test('a list the forum numbers is a numbered list', () {
      expect(
        cleanPostHtml('<ul class="bbc_list" style="list-style-type: decimal">'
            '<li>One</li></ul>'),
        '<ol><li>One</li></ol>',
      );
      expect(cleanPostHtml('<ul class="bbc_list"><li>One</li></ul>'),
          '<ul><li>One</li></ul>');
    });

    test('fonts, shadows and marquees go, keeping their words', () {
      expect(
        cleanPostHtml('<span style="font-family: Comic Sans" class="bbc_font">A</span>'
            '<span style="text-shadow: red 1px 1px 1px">B</span>'
            '<marquee>C</marquee>'),
        'ABC',
      );
    });
  });

  group('colours', () {
    test('a colour is written as six hex digits', () {
      String coloured(String colour) => cleanPostHtml(
          '<span style="color: $colour;" class="bbc_color">Words</span>')!;
      expect(coloured('red'),
          '<span class="author-colour" style="--c:#ff0000">Words</span>');
      expect(coloured('#bbb'),
          '<span class="author-colour" style="--c:#bbbbbb">Words</span>');
      expect(coloured('rgb(255, 255, 255)'),
          '<span class="author-colour" style="--c:#ffffff">Words</span>');
      expect(coloured('transparent'), 'Words');
    });

    test('a colour that is not a plain colour writes nothing', () {
      for (final hostile in [
        'red url(x)',
        'expression(alert(1))',
        '#ff000g',
        'rgb(300, 0, 0)',
        'var(--primary)',
      ]) {
        expect(
            cleanPostHtml(
                '<span style="color: $hostile" class="bbc_color">Words</span>'),
            'Words',
            reason: hostile);
      }
    });

    test('another declaration beside the colour never comes through', () {
      expect(
        cleanPostHtml(
            '<span style="color: red; background: url(x)">Words</span>'),
        '<span class="author-colour" style="--c:#ff0000">Words</span>',
      );
    });

    test('a size and a colour on one tag are both kept', () {
      expect(
        cleanPostHtml('<span style="font-size: 18pt; color: blue">Big</span>'),
        '<span class="size-bigger"><span class="author-colour" '
        'style="--c:#0000ff">Big</span></span>',
      );
    });
  });

  group('videos', () {
    test('a YouTube video is a link to it, holding its thumbnail', () {
      expect(
        cleanPostHtml('<p>Trailer</p><iframe title="YouTube video player" '
            'width="640" height="385" '
            'src="//www.youtube.com/embed/9fRQzyMvl7k?rel=0" frameborder="0" '
            'allowfullscreen=""></iframe>'),
        '<p>Trailer</p><a class="video-link" '
        'href="https://www.youtube.com/watch?v=9fRQzyMvl7k" '
        'rel="nofollow noopener" target="_blank">'
        '<img src="https://i.ytimg.com/vi/9fRQzyMvl7k/hqdefault.jpg" '
        'alt="Video on YouTube" $pictureTail</a>',
      );
    });

    test('a Vimeo video is a plain link', () {
      expect(
        cleanPostHtml('<p>Trailer</p><iframe '
            'src="https://player.vimeo.com/video/123456789"></iframe>'),
        '<p>Trailer</p><p><a href="https://vimeo.com/123456789" '
        'rel="nofollow noopener" target="_blank">Video on Vimeo</a></p>',
      );
    });

    test('a broken video address or another host writes nothing', () {
      for (final src in [
        '//www.youtube.com/embed/short',
        '//www.youtube.com/embed/9fRQzyMvl7k/../other',
        'https://evil.example/embed/9fRQzyMvl7k',
        'javascript:alert(1)',
      ]) {
        expect(cleanPostHtml('<p>Hi</p><iframe src="$src"></iframe>'), '<p>Hi</p>',
            reason: src);
      }
    });
  });

  test('only the site\'s own classes and one kind of style ever come out', () {
    const everything = '<div class="sp-wrap"><div class="sp-head">S</div>'
        '<div class="sp-body"><span style="font-size: 18pt; color: red" '
        'class="bbc_size" id="x" onclick="go()">A</span>'
        '<div align="center" class="evil">B</div>'
        '<table class="bbc_table" style="width:900px"><tr><td class="c">C</td>'
        '</tr></table><span class="bbc_u">D</span>'
        '<iframe src="//www.youtube.com/embed/9fRQzyMvl7k"></iframe>'
        '</div></div>';
    final cleaned = cleanPostHtml(everything)!;

    const allowed = {
      'spoiler', 'table-scroll', 'align-center', 'align-right', 'size-small',
      'size-big', 'size-bigger', 'size-biggest', 'author-colour', 'video-link',
    };
    final classes = RegExp(r'class="([^"]*)"')
        .allMatches(cleaned)
        .expand((m) => m[1]!.split(' '))
        .toSet();
    expect(allowed.containsAll(classes), isTrue, reason: '$classes');
    for (final style in RegExp(r'style="([^"]*)"').allMatches(cleaned)) {
      expect(style[1], matches(RegExp(r'^--c:#[0-9a-f]{6}$')));
    }
    expect(cleaned, isNot(contains('id=')));
    expect(cleaned, isNot(contains('onclick')));
  });

  group('the readers on their own', () {
    test('sizes', () {
      expect(sizeStepOf('small'), SizeStep.small);
      expect(sizeStepOf('9.5pt'), SizeStep.small);
      expect(sizeStepOf('10pt'), isNull);
      expect(sizeStepOf('2em'), SizeStep.biggest);
      expect(sizeStepOf('24px'), SizeStep.bigger);
      expect(sizeStepOf(''), isNull);
      expect(sizeStepOf('calc(1px + 9pt)'), isNull);
    });

    test('colours', () {
      expect(hexColourOf('Navy'), '#000080');
      expect(hexColourOf(' #6AA84F '), '#6aa84f');
      expect(hexColourOf('rgb(0,0,0)'), '#000000');
      expect(hexColourOf('rgba(0,0,0,0.5)'), isNull);
    });
  });
}
