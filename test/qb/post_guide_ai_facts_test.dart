import 'package:mod_repo_scraper/bot/scraper/qb/llm/extraction_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/post_guide_check.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/post_guide_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/post_extraction.dart';
import 'package:test/test.dart';

/// The AI disclaimer item, answered from what the post's own LLM read saved
/// about AI use. The rules for posting a new mod ask for the model and the
/// kinds of assets made with it.
void main() {
  LlmStoreEntry answer(List<LlmAiUse?> aiUses) => LlmStoreEntry(
        fingerprint: 'f',
        schemaVersion: 1,
        promptVersion: 1,
        mods: [
          for (final aiUse in aiUses)
            LlmMod(name: 'A Mod', extras: aiUse == null ? null : LlmExtras(aiUse: aiUse)),
        ],
      );

  LlmAiUse used({List<String>? tools, List<AiUseArea> areas = const []}) => LlmAiUse(
        usesAi: true,
        tools: tools,
        uses: [for (final area in areas) LlmAiUseEntry(area: area)],
      );

  test('a model and a kind of asset pass ("Code by Claude")', () {
    expect(aiDisclaimerFromFacts(answer([used(tools: ['Claude'], areas: [AiUseArea.code])])), GuideAnswer.yes);
  });

  test('AI use with no model named fails ("AI was used extensively")', () {
    expect(aiDisclaimerFromFacts(answer([used(areas: [AiUseArea.portraits])])), GuideAnswer.no);
  });

  test('a statement that no AI was used passes', () {
    expect(aiDisclaimerFromFacts(answer([LlmAiUse(usesAi: false)])), GuideAnswer.yes);
  });

  test('nothing stated, no saved answer, or a model with no kind of asset is left to the check\'s own answer', () {
    expect(aiDisclaimerFromFacts(answer([LlmAiUse.notStated()])), isNull);
    expect(aiDisclaimerFromFacts(null), isNull);
    expect(aiDisclaimerFromFacts(answer([null])), isNull);
    expect(aiDisclaimerFromFacts(answer([used(tools: ['Fable'], areas: [AiUseArea.other])])), isNull);
  });

  test('a thread of several mods uses AI when any of its mods does', () {
    expect(aiDisclaimerFromFacts(answer([LlmAiUse(usesAi: false), used(areas: [AiUseArea.illustrations])])),
        GuideAnswer.no);
  });

  test("the facts' answer wins over the check's own, a no included", () {
    PostGuideEntry entry({required GuideAnswer? facts, required GuideAnswer llm}) => PostGuideEntry(
          fingerprint: 'f',
          checkedAt: DateTime.utc(2026, 11, 6),
          llm: {'aiDisclaimer': llm},
          rules: {if (facts != null) 'aiDisclaimer': facts},
        );
    GuideItemResult ai(PostGuideEntry e) => postGuideResults(e).firstWhere((r) => r.item.id == 'aiDisclaimer');

    expect(ai(entry(facts: GuideAnswer.yes, llm: GuideAnswer.no)).answer, GuideAnswer.yes);
    expect(ai(entry(facts: GuideAnswer.no, llm: GuideAnswer.yes)).answer, GuideAnswer.no);
    expect(ai(entry(facts: null, llm: GuideAnswer.no)).answer, GuideAnswer.no);
    expect(ai(entry(facts: null, llm: GuideAnswer.no)).by, GuideAnsweredBy.llm);
  });
}
