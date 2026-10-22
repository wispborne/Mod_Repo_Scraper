import 'package:mod_repo_scraper/bot/scraper/qb/models/post_extraction.dart';
import 'package:mod_repo_scraper/catalog/fact_choice.dart';
import 'package:mod_repo_scraper/catalog/source_post.dart';
import 'package:test/test.dart';

LlmMod _mod({List<String> downloads = const [], LlmExtras? extras}) => LlmMod(
      name: 'Mod',
      downloads: [for (final url in downloads) LlmDownload(url: url)],
      extras: extras,
    );

void main() {
  test("a Discord-only mod takes every fact from that thread's answer", () {
    final facts = chooseFacts([
      FactSource(
        _mod(
          downloads: ['https://e/d.zip'],
          extras: LlmExtras(needs: ['LazyLib'], license: 'MIT', canAdd: SaveAnswer.yes, saveCompatibility: 'Safe to add.'),
        ),
        SourceKind.discord,
      ),
    ])!;
    expect(facts.downloads.single.url, 'https://e/d.zip');
    expect(facts.extras!.needs, ['LazyLib']);
    expect(facts.extras!.license, 'MIT');
    expect(facts.extras!.canAdd, SaveAnswer.yes);
  });

  test('a field the forum answer leaves empty is filled from Discord', () {
    final facts = chooseFacts([
      FactSource(_mod(extras: LlmExtras(license: 'MIT')), SourceKind.discord),
      FactSource(_mod(extras: LlmExtras(needs: ['MagicLib'])), SourceKind.forum),
    ])!;
    expect(facts.extras!.license, 'MIT');
    expect(facts.extras!.needs, ['MagicLib']);
  });

  test("the forum's downloads win as a whole over Discord's", () {
    final facts = chooseFacts([
      FactSource(_mod(downloads: ['https://e/discord.zip']), SourceKind.discord),
      FactSource(_mod(downloads: ['https://e/a.zip', 'https://e/b.zip']), SourceKind.forum),
    ])!;
    expect(facts.downloads.map((d) => d.url), ['https://e/a.zip', 'https://e/b.zip']);
  });

  test('Discord announcing a newer version wins the version', () {
    final facts = chooseFacts([
      FactSource(_mod(extras: LlmExtras(version: '1.2')), SourceKind.forum),
      FactSource(_mod(extras: LlmExtras(version: '1.3')), SourceKind.discord),
    ])!;
    expect(facts.extras!.version, '1.3');
  });

  test('between two forum posts the newer is read first', () {
    final facts = chooseFacts([
      FactSource(_mod(extras: LlmExtras(license: 'Old')), SourceKind.forum, postedAt: DateTime(2020)),
      FactSource(_mod(extras: LlmExtras(license: 'New')), SourceKind.forum, postedAt: DateTime(2026)),
    ])!;
    expect(facts.extras!.license, 'New');
  });

  test("an answer and its words travel together", () {
    final facts = chooseFacts([
      FactSource(_mod(extras: LlmExtras(saveCompatibility: 'Safe to add.', canAdd: SaveAnswer.yes)), SourceKind.forum),
      FactSource(_mod(extras: LlmExtras(saveCompatibility: 'Needs a new game.', canAdd: SaveAnswer.no)), SourceKind.discord),
    ])!;
    expect(facts.extras!.saveCompatibility, 'Safe to add.');
    expect(facts.extras!.canAdd, SaveAnswer.yes);
  });

  test("the forum's AI-use answer wins whole over Discord's", () {
    final forum = LlmAiUse(quote: 'No AI Generation.', usesAi: false);
    final discord = LlmAiUse(
      quote: 'Portraits made with Midjourney.',
      usesAi: true,
      uses: [LlmAiUseEntry(area: AiUseArea.portraits)],
      tools: ['Midjourney'],
    );
    final facts = chooseFacts([
      FactSource(_mod(extras: LlmExtras(aiUse: discord)), SourceKind.discord),
      FactSource(_mod(extras: LlmExtras(aiUse: forum)), SourceKind.forum),
    ])!;
    expect(facts.extras!.aiUse, forum);
  });

  test("Discord's AI-use answer is used when the forum has none", () {
    final discord = LlmAiUse(
      quote: 'Music made with Suno.',
      usesAi: true,
      uses: [LlmAiUseEntry(area: AiUseArea.music)],
    );
    final facts = chooseFacts([
      FactSource(_mod(extras: LlmExtras(aiUse: discord)), SourceKind.discord),
      FactSource(_mod(extras: LlmExtras(license: 'MIT')), SourceKind.forum),
    ])!;
    expect(facts.extras!.aiUse, discord);
  });

  test("a forum post that says nothing about AI leaves it to Discord's", () {
    final discord = LlmAiUse(
      quote: 'Portraits made with Midjourney.',
      usesAi: true,
      uses: [LlmAiUseEntry(area: AiUseArea.portraits)],
    );
    final facts = chooseFacts([
      FactSource(_mod(extras: LlmExtras(aiUse: discord)), SourceKind.discord),
      FactSource(_mod(extras: LlmExtras(aiUse: LlmAiUse.notStated())), SourceKind.forum),
    ])!;
    expect(facts.extras!.aiUse, discord);
  });

  test('a mod whose every post says nothing about AI is not stated, not unread', () {
    final facts = chooseFacts([
      FactSource(_mod(extras: LlmExtras(license: 'MIT')), SourceKind.discord),
      FactSource(_mod(extras: LlmExtras(aiUse: LlmAiUse.notStated())), SourceKind.forum),
    ])!;
    expect(facts.extras!.aiUse, LlmAiUse.notStated());
  });

  test('no answers, no facts', () {
    expect(chooseFacts(const []), isNull);
  });
}
