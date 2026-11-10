import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/bot/scraper/qb/download_resolver.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/anchor_key.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/extraction_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/plain_spaces.dart';
import 'package:mod_repo_scraper/site/release_state_store.dart';
import 'package:test/test.dart';

void main() {
  group('withoutNonBreakingSpaces', () {
    test('makes every form a space, and trims', () {
      expect(withoutNonBreakingSpaces('&nbsp; Download'), 'Download');
      expect(withoutNonBreakingSpaces('a&#160;b&#xA0;c d&NBSP;e'),
          'a b c d e');
    });

    test('folds runs of spaces on one line', () {
      expect(withoutNonBreakingSpaces('==&nbsp; DOWNLOAD HERE&nbsp; =='),
          '== DOWNLOAD HERE ==');
    });

    test('keeps the indents of text with several lines', () {
      expect(withoutNonBreakingSpaces('New wings\n&nbsp; &nbsp; - Toxot'),
          'New wings\n    - Toxot');
    });

    test('leaves text with no non-breaking space exactly as it was', () {
      const text = '  two  spaces  ';
      expect(withoutNonBreakingSpaces(text), text);
    });

    test('reaches every string inside a JSON value, and no key', () {
      expect(
        withoutNonBreakingSpacesInside({
          'a&nbsp;b': ['x&nbsp;y'],
          'n': 1,
          'm': {'q': 'p&nbsp;q'},
        }),
        {
          'a&nbsp;b': ['x y'],
          'n': 1,
          'm': {'q': 'p q'},
        },
      );
    });
  });

  group('anchors', () {
    test('a non-breaking space in the post is not letters to match', () {
      expect(
        anchorsFoundIn('everything except&nbsp; the code and ship stats',
            'everything except the', 'code and ship stats'),
        isTrue,
      );
    });

    test('the key with places agrees with the plain key', () {
      const text = 'one&nbsp;two&#160;three';
      final (:key, :at) = anchorKeyWithPlaces(text);
      expect(key, anchorKey(text));
      expect(key, 'onetwothree');
      expect(text[at[key.indexOf('three')]], 't');
      expect(at[key.indexOf('three')], text.indexOf('three'));
    });
  });

  group('saved text is cleaned when it is read back', () {
    test('a download candidate\'s link text', () {
      final candidate = DownloadCandidate.fromJson({
        'sourceUrl': 'https://x.example/a.zip',
        'resolvedUrl': 'https://x.example/a.zip',
        'confidence': 'high',
        'linkText': '==&nbsp; DOWNLOAD&nbsp; ==',
      });
      expect(candidate.linkText, '== DOWNLOAD ==');
    });

    test('a release\'s changelog notes', () {
      final release = ThreadRelease.fromMap({
        'topicId': 1,
        'modName': 'm',
        'seenOn': '2026-11-09',
        'newVersion': '1.0',
        'changelogNotes': 'Save compatible\n&nbsp;&nbsp;&nbsp;-Fixed a crash',
      });
      expect(release.changelogNotes, 'Save compatible\n   -Fixed a crash');
    });

    test('a saved LLM answer', () async {
      final dir = Directory.systemTemp.createTempSync('plain_spaces');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/llm-extraction-cache.json').writeAsStringSync(
        jsonEncode({
          '7': {
            'fingerprint': 'abc',
            'schemaVersion': LlmExtractionStore.schemaVersion,
            'promptVersion': 1,
            'mods': [
              {
                'name': 'm',
                'role': 'main',
                'downloads': [
                  {
                    'url': 'https://x.example/a.zip',
                    'label': '&nbsp; Download',
                    'kind': 'direct',
                    'confidence': 'low',
                    'requiresManualStep': false,
                  },
                ],
                'extras': {
                  'aiUse': {
                    'quote': 'Made by an algorithm&nbsp;',
                    'usesAi': true,
                  },
                },
              },
            ],
          },
        }),
      );

      final store = LlmExtractionStore(dir.path);
      await store.load();

      final mod = store.get(7)!.mods.single;
      expect(mod.downloads.single.label, 'Download');
      expect(mod.extras!.aiUse!.quote, 'Made by an algorithm');
    });
  });
}
