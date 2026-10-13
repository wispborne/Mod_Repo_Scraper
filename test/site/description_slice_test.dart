import 'package:mod_repo_scraper/site/description_slice.dart';
import 'package:mod_repo_scraper/site/post_html.dart';
import 'package:test/test.dart';

void main() {
  // Topic 11018: the heading and the introduction are two centred blocks side
  // by side. The cut used to start a block early and take in "Contents", and
  // cleaning it again dropped both blocks, so the summary read
  // "ContentsThe Ship/Weapon Pack…".
  test('a description in a centred block is cut out on its own', () {
    final post = cleanPostHtml('<hr><div align="center"><span class="bbc_u">'
        'Contents</span></div><div align="center">The Ship/Weapon Pack seeks '
        'to flesh out the content of Starsector.<br>Included are a couple '
        'dozen ships.</div><div align="center">Download</div>');
    final slice = sliceDescriptionHtml(
        post, 'The Ship/Weapon Pack seeks', 'a couple dozen ships.');
    expect(slice, isNotNull);
    expect(plainWordsOf(slice), 'The Ship/Weapon Pack seeks to flesh out the '
        'content of Starsector.\nIncluded are a couple dozen ships.');
  });

  // Topic 24579: the description sits inside a spoiler, and the summary read
  // "SpoilerWell, I am glad you asked."
  test('a description inside a spoiler leaves the fold title behind', () {
    final post = cleanPostHtml('What does this do?<br><div class="sp-wrap">'
        '<div class="sp-head">Spoiler</div><div class="sp-body folded">'
        'Well, I am glad you asked. It adds new music.<br>More words here.'
        '</div></div>');
    final slice = sliceDescriptionHtml(
        post, 'Well, I am glad you asked', 'It adds new music.');
    expect(plainWordsOf(slice), 'Well, I am glad you asked. It adds new music.');
  });

  test('cleaning a post twice keeps its blocks, text sizes and folds', () {
    final once = cleanPostHtml('<div align="center">One</div>'
        '<div style="text-align: right">Two</div>'
        '<span style="font-size: 18pt">Big</span>'
        '<div class="sp-wrap"><div class="sp-head">Story</div>'
        '<div class="sp-body">Hidden words</div></div>');
    expect(cleanPostHtml(once), once);
  });
}
