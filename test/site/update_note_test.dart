import 'package:mod_repo_scraper/bot/scraper/qb/models/post_extraction.dart';
import 'package:mod_repo_scraper/site/update_note.dart';
import 'package:test/test.dart';

void main() {
  final oldPatch = LlmUpdateNote(
      version: 'v1.0.1', quote: 'It is save-compatible.', answer: SaveAnswer.yes);
  final standing = LlmUpdateNote(
      quote: 'All updates are save-compatible.', answer: SaveAnswer.yes);

  test('a note written for a version speaks for that version', () {
    expect(
        updateNoteFor([standing, oldPatch], version: '1.0.1', isCurrent: false),
        same(oldPatch));
  });

  test('a note about an old release never speaks for the current one', () {
    // The case that started this: a note about patch v1.0.1, read as if it
    // were about v3.0.2.
    expect(updateNoteFor([oldPatch], version: '3.0.2', isCurrent: true),
        isNull);
  });

  test('a note tied to no release speaks only for the current version', () {
    expect(updateNoteFor([standing], version: '3.0.2', isCurrent: true),
        same(standing));
    expect(updateNoteFor([standing], version: '2.0.0', isCurrent: false),
        isNull);
  });

  test('a note for the version wins over a note tied to no release', () {
    expect(
        updateNoteFor([standing, oldPatch], version: 'v1.0.1', isCurrent: true),
        same(oldPatch));
  });

  test('with no current version known, only a note tied to no release fits',
      () {
    expect(
        updateNoteFor([oldPatch, standing], version: null, isCurrent: true),
        same(standing));
    expect(updateNoteFor(null, version: '1.0', isCurrent: true), isNull);
  });

  test('versions are compared the way authors write them', () {
    expect(sameVersion('v1.0.1', 'Version 1.0.1'), isTrue);
    expect(sameVersion('1.0.1', '1.0.2'), isFalse);
    expect(sameVersion(null, null), isFalse);
  });
}
