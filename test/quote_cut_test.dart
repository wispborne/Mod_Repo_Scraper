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
