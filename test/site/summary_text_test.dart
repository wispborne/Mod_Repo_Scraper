import 'package:mod_repo_scraper/site/post_html.dart';
import 'package:mod_repo_scraper/site/summary_text.dart';
import 'package:test/test.dart';

/// The card summary is copied from whichever source the merge liked best, and
/// plenty of those are not descriptions at all — a download link, the mod's own
/// name in bold, or a line of requirements. Those are dropped so the AI
/// sentence can take their place, labelled as AI.
void main() {
  group('the opening sentences of an author excerpt', () {
    test('removes bullet markers and stops at a blank line', () {
      expect(
          summaryOfExcerpt('- Lets you upgrade your ships. Only yours.\n'
              '- More features.\n\nInstall it like any mod.'),
          'Lets you upgrade your ships. Only yours. More features.');
    });

    test('a sentence the author broke over two lines is kept whole', () {
      // Topic 25040, whose card stopped at "…feel more part of".
      expect(
          summaryOfExcerpt('Offers changes to the player faction to make it '
              'feel more part of\nthe world + other optional add-ons.\n'
              'This mod is broken into six distinct submods that can be '
              'enabled or disabled independently.'),
          'Offers changes to the player faction to make it feel more part of '
          'the world + other optional add-ons. This mod is broken into six '
          'distinct submods that can be enabled or disabled independently.');
    });

    test('a version number does not end the sentence', () {
      expect(summaryOfExcerpt('Adds ships for 0.98a. Includes weapons.'),
          'Adds ships for 0.98a. Includes weapons.');
      expect(summaryOfExcerpt('Adds ships for 0.98a and weapons.'),
          'Adds ships for 0.98a and weapons.');
    });

    test('uses the first line when there is no sentence ending', () {
      expect(summaryOfExcerpt('Adds new ships\nAnd new weapons'),
          'Adds new ships');
    });

    test('keeps non-English sentence endings', () {
      expect(summaryOfExcerpt('添加新的舰船。还有武器。\n\n更多'), '添加新的舰船。还有武器。');
    });

    test('stops adding sentences once the summary is long', () {
      // 129 characters each: two fit in 300, a third would not.
      final sentence = '${'Word ' * 25}end.';
      final summary = summaryOfExcerpt('$sentence $sentence $sentence')!;
      expect(summary, '$sentence $sentence');
    });

    test('always keeps the first sentence, however long', () {
      final sentence = '${'Word ' * 80}end.';
      expect(summaryOfExcerpt('$sentence Short one.'), sentence);
    });

    test('a link inside the sentence does not cut it short', () {
      // Topic 36126, whose card read "A fork of Starficz's".
      final excerpt = plainWordsOf("A fork of Starficz's "
          '<a href="https://x.com/">Refit Filters</a>. '
          'It keeps everything the original does.');
      expect(summaryOfExcerpt(excerpt),
          "A fork of Starficz's Refit Filters. "
          'It keeps everything the original does.');
    });

    test('an empty excerpt has no summary', () {
      expect(summaryOfExcerpt(null), isNull);
      expect(summaryOfExcerpt('  '), isNull);
    });
  });

  test('keeps a real description', () {
    expect(usableSummary('Adds diplomacy, invasions and a 4X layer.'),
        'Adds diplomacy, invasions and a 4X layer.');
  });

  test('drops a summary that is only a link', () {
    expect(usableSummary('https://github.com/x/y'), isNull);
    expect(usableSummary('Download link: https://github.com/x/y'), isNull);
    expect(usableSummary('Download: <https://github.com/x/y>'), isNull);
    expect(usableSummary('Current version: https://gitlab.com/x/y.zip'), isNull);
  });

  test('drops a heading and a labelled link at the top of a Discord post', () {
    // Hullmods - Renewed, as its Discord post opens.
    expect(
        usableSummary('## Hullmods - Renewed\n'
            'Forum post: https://fractalsoftworks.com/forum/index.php?topic=35619.0'),
        isNull);
    expect(usableSummary('# Big Mod\nAdds a new faction to the sector.'),
        'Adds a new faction to the sector.');
    expect(usableSummary('- Create custom hullmods.\n- Delve too deep.'),
        'Create custom hullmods. Delve too deep.');
  });

  test('a bold label before a link is still only a label', () {
    expect(usableSummary('**Download (latest release):** https://github.com/x/y'),
        isNull);
  });

  test('a Discord post gives its first paragraph with words in it', () {
    // Hullmods - Renewed's post, as it opens.
    const post = '## Hullmods - Renewed\n'
        'Forum post: https://fractalsoftworks.com/forum/index.php?topic=35619.0\n'
        '**Download (latest release):** https://github.com/x/y/releases/latest\n'
        '\n'
        'Ever scrolled past 200+ hullmods hunting for the one you actually wanted?\n'
        'Ever been annoyed by carrier mods cluttering the list?';
    expect(summaryOfDiscordPost(post),
        'Ever scrolled past 200+ hullmods hunting for the one you actually wanted? '
        'Ever been annoyed by carrier mods cluttering the list?');
  });

  test('a Discord post with nothing usable near the top gives nothing', () {
    expect(summaryOfDiscordPost(null), isNull);
    expect(
        summaryOfDiscordPost('# A\n\nhttps://x.com/a\n\n# B\n\nLink: https://x.com/b\n\n'
            'Adds a new faction to the sector.'),
        isNull);
  });

  test('keeps a line that has words of its own beside a link', () {
    expect(usableSummary('Adds new ships, see https://x.com/y for pictures.'),
        'Adds new ships, see https://x.com/y for pictures.');
  });

  test('drops a summary that is only the mod\'s name in bold', () {
    expect(usableSummary('**StopBloatingMe**'), isNull);
    expect(usableSummary('__LazyLib__'), isNull);
    expect(usableSummary('`Nexerelin`'), isNull);
  });

  test('drops a summary that is only a list of requirements', () {
    expect(usableSummary('REQUIRES LAZYLIB, LUNALIB, MAGICLIB'), isNull);
    expect(usableSummary('Requires: LazyLib'), isNull);
  });

  test('keeps a summary that names its requirements and then says what it is',
      () {
    expect(usableSummary('Requires LazyLib. Adds a new faction to the sector.'),
        'Requires LazyLib. Adds a new faction to the sector.');
  });

  test('takes the emphasis marks off a summary it keeps', () {
    expect(usableSummary('**Nexerelin** adds diplomacy and invasions.'),
        'Nexerelin adds diplomacy and invasions.');
  });

  test('tidies the spacing', () {
    expect(usableSummary('  Adds   ships.\n\nAnd weapons.  '),
        'Adds ships. And weapons.');
  });

  test('nothing in, nothing out', () {
    expect(usableSummary(null), isNull);
    expect(usableSummary('   '), isNull);
    expect(usableSummary('****'), isNull);
  });
}
