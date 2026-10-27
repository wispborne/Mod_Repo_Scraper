import 'package:mod_repo_scraper/bot/scraper/qb/llm/quote_cut.dart';
import 'package:test/test.dart';

void main() {
  group('cutQuote', () {
    test('cuts from the start words to the end words, as whole words', () {
      expect(
        cutQuote(
          'Thanks to everyone. All portraits were generated with AI and then '
              'edited by hand. Have fun!',
          'traits were generated',
          'edited by ha',
        ),
        'portraits were generated with AI and then edited by hand.',
        reason: 'an anchor that starts or ends inside a word is widened to '
            'the whole word, and the full stop after it comes along',
      );
    });

    test('ignores punctuation, capitals and our link notes', () {
      expect(
        cutQuote(
          'Made using [link: https://x.example/sd]Stable Diffusion, then '
              'touched up.',
          'made using stable',
          'then touched up',
        ),
        'Made using Stable Diffusion, then touched up.',
      );
    });

    test('keeps line breaks and tidies spaces inside lines', () {
      expect(
        cutQuote(
          'AI use:\n-   Portraits:  generated\n\n- Music: none\nOther text',
          'AI use Portraits',
          'Music none',
        ),
        'AI use:\n- Portraits: generated\n- Music: none',
      );
    });

    test('gives nothing when an end is missing or comes first', () {
      const text = 'The portraits are AI made. The music is my own work.';
      expect(cutQuote(text, 'portraits are AI', 'drawn by hand'), isNull);
      expect(cutQuote(text, 'music is my own', 'portraits are AI'), isNull);
    });

    test('gives nothing for an anchor too short to point at one place', () {
      expect(cutQuote('AI art. More AI art.', 'AI', 'art'), isNull);
    });

    test('keeps a long disclaimer that covers each part of the mod', () {
      // Topic 36176's statement, as the post reducer gives it. It is 1,003
      // characters once its line breaks are counted, and was dropped while
      // the limit was 1,000.
      const text = 'AI use disclaimer\n'
          ' Some or all assets and code in this mod were created using AI '
          'tools:\n'
          ' Code: Claude Opus 5.5 (Anthropic), through Claude Code. It wrote '
          'most of the Java code, the build and test tooling configuration, '
          'and the design and API documentation.\n'
          ' Code review: Claude was also used to review each milestone for '
          'bugs before release. No line of code reaches a release without a '
          'human review.\n'
          " Art: the banner at the top of this post was made with Z-Image "
          "Turbo (Alibaba's Tongyi Lab), an open image model run locally in "
          'ComfyUI, starting from vanilla Starsector portraits; its three '
          "captains are a nod to Slay the Spire's Ironclad, Silent and "
          'Defect. Nothing in the mod itself uses AI art: map and node icons '
          'are vanilla Starsector sprites.\n'
          ' How it was made: I designed the mod (the Run, the beacon types, '
          'the rules and the balance) and directed every change. Each '
          'milestone was then played and tested in game by me, against a '
          'checklist, before it was merged. The full source and the design '
          'notes are public on GitHub.\n'
          ' [close]';
      final quote = cutQuote(
        text,
        'Some or all assets and code in this mod were created using AI tools:',
        'The full source and the design notes are public on GitHub.',
      );
      expect(quote, isNotNull);
      expect(quote!.length, greaterThan(1000));
      expect(quote, startsWith('Some or all assets'));
      expect(quote, endsWith('public on GitHub.'));
      expect(quote.split('\n'), hasLength(5),
          reason: 'each part of the disclaimer keeps its own line');
    });

    test('gives nothing for a cut longer than the limit', () {
      final text = 'Start of the statement here. ${'filler words ' * 200}'
          'end of the statement here.';
      expect(
        cutQuote(text, 'Start of the statement', 'end of the statement'),
        isNull,
      );
    });
  });
}
