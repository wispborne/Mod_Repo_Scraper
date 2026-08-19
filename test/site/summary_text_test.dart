import 'package:mod_repo_scraper/site/summary_text.dart';
import 'package:test/test.dart';

/// The card summary is copied from whichever source the merge liked best, and
/// plenty of those are not descriptions at all — a download link, the mod's own
/// name in bold, or a line of requirements. Those are dropped so the AI
/// sentence can take their place, labelled as AI.
void main() {
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
