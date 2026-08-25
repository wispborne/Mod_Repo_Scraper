import 'package:mod_repo_scraper/site/gallery_filter.dart';
import 'package:test/test.dart';

/// Every picture in a forum post used to be published as a screenshot, so
/// Nexerelin's "Screenshots" were a blurred icon, a title banner and a yellow
/// "Buy me a coffee" button. These rules keep the badges, buttons and tiny
/// pictures out.
void main() {
  test('drops donation buttons and badges by where they are hosted', () {
    expect(looksLikeAScreenshot('https://ko-fi.com/img/githubbutton_sm.svg'),
        isFalse);
    expect(looksLikeAScreenshot('https://img.buymeacoffee.com/button.png'),
        isFalse);
    expect(looksLikeAScreenshot('https://c5.patreon.com/become_a_patron.png'),
        isFalse);
    expect(looksLikeAScreenshot('https://img.shields.io/badge/build-ok.svg'),
        isFalse);
    expect(looksLikeAScreenshot('https://www.paypalobjects.com/donate.gif'),
        isFalse);
  });

  test('drops the forum\'s own smileys and interface pictures', () {
    expect(
        looksLikeAScreenshot(
            'https://fractalsoftworks.com/forum/Smileys/default/smiley.gif'),
        isFalse);
    expect(
        looksLikeAScreenshot(
            'https://fractalsoftworks.com/forum/Themes/default/images/ip.gif'),
        isFalse);
  });

  test('drops a picture whose own address says it is a button or a badge', () {
    expect(looksLikeAScreenshot('https://example.com/donate-button.png'),
        isFalse);
    expect(looksLikeAScreenshot('https://example.com/patreon_badge.png'),
        isFalse);
    expect(looksLikeAScreenshot('https://example.com/avatar/1234.png'), isFalse);
    expect(looksLikeAScreenshot('https://cdn.discordapp.com/a/nex_icon.png'),
        isFalse);
    expect(looksLikeAScreenshot('https://example.com/mod-logo.png'), isFalse);
  });

  test('keeps an ordinary screenshot', () {
    expect(
        looksLikeAScreenshot(
            'https://fractalsoftworks.com/forum/index.php?action=dlattach;topic=9175.0;attach=61234;image'),
        isTrue);
    expect(looksLikeAScreenshot('https://i.imgur.com/abcdef.png'), isTrue);
  });

  test('reads the sizes the post gives its pictures', () {
    final sizes = pictureSizesInPost(
      '<img src="https://x/a.png" width="120" height="40">'
      '<img src="https://x/b.png" width="900">'
      '<img src="https://x/c.png" style="width: 64px; height: 64px">'
      '<img src="https://x/d.png">',
    );
    expect(sizes['https://x/a.png'], 120);
    expect(sizes['https://x/b.png'], 900);
    expect(sizes['https://x/c.png'], 64);
    expect(sizes.containsKey('https://x/d.png'), isFalse);
  });

  test('drops a small picture where the post said how big it is', () {
    final sizes = {'https://x/a.png': 120, 'https://x/b.png': 900};
    expect(looksLikeAScreenshot('https://x/a.png', sizes: sizes), isFalse);
    expect(looksLikeAScreenshot('https://x/b.png', sizes: sizes), isTrue);
    // Nothing said, so nothing is assumed.
    expect(looksLikeAScreenshot('https://x/c.png', sizes: sizes), isTrue);
  });

  // The LLM extraction step uses [isBadgeOrDonationImage] to decide which of a
  // post's pictures the model may pick a mod's picture from. It must agree
  // with the gallery about donation buttons — a Patreon banner offered to the
  // model is how LunaLib's card showed a Patreon image — while still letting
  // through a mod's own logo, which is a fine card picture but not a
  // screenshot.
  test('the shared badge check agrees with the gallery on donation buttons',
      () {
    expect(isBadgeOrDonationImage('https://ko-fi.com/img/githubbutton_sm.svg'),
        isTrue);
    expect(isBadgeOrDonationImage('https://c5.patreon.com/become_a_patron.png'),
        isTrue);
    expect(isBadgeOrDonationImage('https://example.com/donate-button.png'),
        isTrue);
    expect(isBadgeOrDonationImage('https://example.com/avatar/1234.png'),
        isTrue);
    expect(isBadgeOrDonationImage('https://example.com/loading.gif'), isTrue);
  });

  test('a mod\'s own logo is not a badge, but is not a screenshot either', () {
    const logo = 'https://example.com/mod-logo.png';
    expect(isBadgeOrDonationImage(logo), isFalse);
    expect(looksLikeAScreenshot(logo), isFalse);
    const icon = 'https://raw.githubusercontent.com/someone/theirmod/main/graphics/mod_icon.png';
    expect(isBadgeOrDonationImage(icon), isFalse);
    expect(looksLikeAScreenshot(icon), isFalse);
  });

  test('a picture in a mod repository\'s graphics folder is not furniture', () {
    // A Starsector mod's own repository keeps its pictures in graphics/ too —
    // only the forum's graphics/ is the forum's furniture.
    expect(
        looksLikeAScreenshot(
            'https://raw.githubusercontent.com/someone/theirmod/main/graphics/screenshot1.png'),
        isTrue);
    expect(
        looksLikeAScreenshot(
            'https://fractalsoftworks.com/forum/graphics/star.gif'),
        isFalse);
  });

  test('an ordinary screenshot passes both checks', () {
    const shot = 'https://i.imgur.com/abcdef.png';
    expect(isBadgeOrDonationImage(shot), isFalse);
    expect(looksLikeAScreenshot(shot), isTrue);
  });
}
