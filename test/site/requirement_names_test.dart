import 'dart:io';

import 'package:mod_repo_scraper/bot/scraper/qb/llm/llm_client.dart';
import 'package:mod_repo_scraper/site/requirement_asker.dart';
import 'package:mod_repo_scraper/site/requirement_names.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Answers each call with the next of [answers], and keeps what it was asked.
class _ScriptedClient implements LlmClient {
  final List<String> answers;
  final List<LlmRequest> asked = [];

  _ScriptedClient(this.answers);

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    asked.add(request);
    return LlmResponse(content: answers[asked.length - 1]);
  }
}

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('requirement_names'));
  tearDown(() => dir.deleteSync(recursive: true));

  const lazyLib = RequiredModNames(id: 'lazylib', shownName: 'LazyLib');
  const graphicsLib = RequiredModNames(id: 'graphicslib', shownName: 'GraphicsLib');
  const nexerelin = RequiredModNames(
      id: 'nexerelin', shownName: 'Nexerelin', nicknames: ['Nex']);

  group('requirementKey', () {
    test('spaces, capitals and versions do not count', () {
      expect(requirementKey('Lazy Lib'), requirementKey('LazyLib'));
      expect(requirementKey('lazylib v3.0'), requirementKey('LazyLib'));
      expect(requirementKey('Magic-Lib'), requirementKey('MagicLib'));
    });

    test('a different word is a different key', () {
      expect(requirementKey('Graphic Lib'), isNot(requirementKey('GraphicsLib')));
    });
  });

  group('RequirementResolver', () {
    test('a nickname matches when one mod uses it', () {
      final resolver = RequirementResolver([lazyLib, nexerelin]);
      expect(resolver.resolve('Nex')?.id, 'nexerelin');
      expect(resolver.resolve('nex')?.name, 'Nexerelin');
    });

    test('a nickname two mods use matches neither', () {
      final resolver = RequirementResolver([
        nexerelin,
        const RequiredModNames(id: 'other', shownName: 'Other', nicknames: ['Nex']),
      ]);
      expect(resolver.resolve('Nex'), isNull);
      expect(resolver.unmatched.values.single.written, 'Nex');
    });

    test('a real name beats a nickname', () {
      final resolver = RequirementResolver([
        const RequiredModNames(id: 'ships', shownName: 'Big Pack', nicknames: ['LazyLib']),
        lazyLib,
      ]);
      expect(resolver.resolve('LazyLib')?.id, 'lazylib');
    });

    test('a hand entry beats the rules, and a hand "none" links nothing', () {
      final store = RequirementNameStore(dir.path);
      File(store.file.path).writeAsStringSync('''
{"names": {
  "a": {"written": "Graphic Lib", "id": "graphicslib"},
  "b": {"written": "Lazy Lib", "id": null}
}}''');
      store.load();
      final resolver =
          RequirementResolver([lazyLib, graphicsLib], store: store);
      expect(resolver.resolve('graphic lib')?.id, 'graphicslib');
      expect(resolver.resolve('LazyLib'), isNull);
      expect(resolver.unmatched, isEmpty,
          reason: 'a name a person decided is never asked about');
    });

    test('an LLM answer for a mod that is gone decides nothing', () {
      final store = RequirementNameStore(dir.path)
        ..putLlmAnswer('Graphic Lib', 'graphicslib', offered: 'x');
      final resolver = RequirementResolver([lazyLib], store: store);
      expect(resolver.resolve('Graphic Lib'), isNull);
      expect(resolver.unmatched, hasLength(1));
    });
  });

  group('RequirementNameStore', () {
    test('answers are saved and read back', () async {
      final store = RequirementNameStore(dir.path)
        ..putLlmAnswer('Graphic Lib', 'graphicslib', offered: 'x')
        ..putLlmAnswer('Kadur', null, offered: 'abc');
      await store.save();

      final again = RequirementNameStore(dir.path)..load();
      expect(again.answerFor('graphiclib')?.id, 'graphicslib');
      expect(again.answerFor('Kadur')?.offered, 'abc');
      expect(again.answerFor('Kadur')?.by, RequirementAnswerBy.llm);
    });

    test('a file that cannot be read is never saved over', () async {
      final store = RequirementNameStore(dir.path);
      store.file.writeAsStringSync('{ not json');
      store
        ..load()
        ..putLlmAnswer('Graphic Lib', 'graphicslib', offered: 'x');
      await store.save();
      expect(store.file.readAsStringSync(), '{ not json');
    });

    test('an LLM answer never replaces a hand entry', () {
      final store = RequirementNameStore(dir.path);
      store.file.writeAsStringSync(
          '{"names": {"x": {"written": "Nex", "id": "nexerelin"}}}');
      store
        ..load()
        ..putLlmAnswer('Nex', null, offered: 'x');
      expect(store.answerFor('Nex')?.id, 'nexerelin');
    });
  });

  group('RequirementAsker', () {
    Map<String, ({String written, int count})> unmatched(List<String> names) =>
        {for (final n in names) requirementKey(n): (written: n, count: 1)};

    test('asks once, saves the answers, and skips short names', () async {
      final client = _ScriptedClient([
        '{"answers": [{"name": "Graphic Lib", "id": "graphicslib"}, '
            '{"name": "Kadur Remnant", "id": null}]}',
      ]);
      final store = RequirementNameStore(dir.path);
      final asker = RequirementAsker(client: client, takeCall: () async => true);

      final matched = await asker.ask(
        unmatched: unmatched(['Graphic Lib', 'Kadur Remnant', 'Nex']),
        candidates: [lazyLib, graphicsLib],
        store: store,
      );

      expect(matched, 1);
      expect(client.asked, hasLength(1));
      expect(client.asked.single.userPrompt, isNot(contains('- Nex')));
      expect(store.answerFor('Graphic Lib')?.id, 'graphicslib');
      expect(store.answerFor('Kadur Remnant')?.id, isNull);
      expect(store.answerFor('Nex'), isNull);
      expect(File(p.join(dir.path, RequirementNameStore.fileName)).existsSync(),
          isTrue);
    });

    test('a "none" is asked again only once the list of mods changes',
        () async {
      final store = RequirementNameStore(dir.path);
      final first = RequirementAsker(
          client: _ScriptedClient(['{"answers": [{"name": "Kadur Remnant", "id": null}]}']),
          takeCall: () async => true);
      await first.ask(
          unmatched: unmatched(['Kadur Remnant']), candidates: [lazyLib], store: store);

      final same = _ScriptedClient([]);
      await RequirementAsker(client: same, takeCall: () async => true).ask(
          unmatched: unmatched(['Kadur Remnant']), candidates: [lazyLib], store: store);
      expect(same.asked, isEmpty);

      final grown = _ScriptedClient(['{"answers": []}']);
      await RequirementAsker(client: grown, takeCall: () async => true).ask(
          unmatched: unmatched(['Kadur Remnant']),
          candidates: [lazyLib, graphicsLib],
          store: store);
      expect(grown.asked, hasLength(1));
    });

    test('no budget means no call', () async {
      final client = _ScriptedClient([]);
      await RequirementAsker(client: client, takeCall: () async => false).ask(
          unmatched: unmatched(['Graphic Lib']),
          candidates: [graphicsLib],
          store: RequirementNameStore(dir.path));
      expect(client.asked, isEmpty);
    });

    test('an id that is not on the list is saved as none', () async {
      final store = RequirementNameStore(dir.path);
      await RequirementAsker(
        client: _ScriptedClient(['{"answers": [{"name": "graphic lib", "id": "made-up"}]}']),
        takeCall: () async => true,
      ).ask(
          unmatched: unmatched(['Graphic Lib']), candidates: [graphicsLib], store: store);
      expect(store.answerFor('Graphic Lib')?.id, isNull);
    });
  });
}
