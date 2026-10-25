import 'package:mod_repo_scraper/bot/scraper/qb/llm/changelog_slice.dart';
import 'package:test/test.dart';

String? notes(List<String> posts, String version, String start, String end) =>
    cutChangelogEntry(posts, version, start, end).notes;

ChangelogCutFailure? failure(
        List<String> posts, String version, String start, String end) =>
    cutChangelogEntry(posts, version, start, end).failure;

void main() {
  const post = '''
Changelog
1.2.0
- Added the Hammerhead variant
- Fixed a crash when loading saves

1.1.0
- Rebalanced the missiles
- Fixed a crash when loading saves
''';

  test('cuts the notes from the first words to the end of the last line', () {
    expect(
      notes([post], '1.2.0', 'Added the Hammerhead', 'loading saves'),
      '- Added the Hammerhead variant\n- Fixed a crash when loading saves',
    );
  });

  test('keeps line breaks and leaves the heading out', () {
    final cut = notes([post], '1.1.0', 'Rebalanced the missiles', 'crash when loading')!;
    expect(cut, '- Rebalanced the missiles\n- Fixed a crash when loading saves');
    expect(cut, isNot(contains('1.1.0')));
  });

  test('a heading on the same line as the first words stays out', () {
    const text = 'v2.0 - Fixed the shield bug\nAdded two new ships\n\nv1.9 - Old';
    expect(
      notes([text], '2.0', 'Fixed the shield bug', 'two new ships'),
      'Fixed the shield bug\nAdded two new ships',
    );
  });

  test('"1.2.1" does not match inside "1.2.1a" or "11.2.1"', () {
    const text = '11.2.1\n- Not this one at all\n\n1.2.1a\n- Nor this one either\n';
    expect(failure([text], '1.2.1', 'Not this one', 'one at all'),
        ChangelogCutFailure.versionNotFound);
  });

  test('a "v" before the version is fine, either way round', () {
    const text = 'Version 3.1\n- Fixed the hull sprites\n\nV.3.0\n- Something else\n';
    expect(notes([text], '3.1', 'Fixed the hull', 'hull sprites'),
        '- Fixed the hull sprites');
    expect(notes([text], 'v3.0', 'Something else', 'Something else'),
        '- Something else');
  });

  test('a version first named inside other notes is cut from its own heading',
      () {
    // Topic 9583: "1.2.1" is mentioned in the 1.2.1a notes before its heading.
    const text = '''
1.2.1a
- Fixes a save made on 1.2.1 failing to load

1.2.1
Campaign stuff:
- Campaign rig fleets now spawn less often.
''';
    expect(
      notes([text], '1.2.1', 'Campaign stuff', 'now spawn less often'),
      'Campaign stuff:\n- Campaign rig fleets now spawn less often.',
    );
  });

  test('the same first words under several versions are cut under the right one',
      () {
    expect(
      notes([post], '1.1.0', 'Fixed a crash when loading', 'loading saves'),
      '- Fixed a crash when loading saves',
    );
    expect(
      notes([post], '1.2.0', 'Fixed a crash when loading', 'loading saves'),
      '- Fixed a crash when loading saves',
    );
    // The 1.1.0 cut comes from below its heading, not from the 1.2.0 notes.
    final at110 = post.indexOf('1.1.0');
    final cut = notes([post], '1.1.0', 'Rebalanced the missiles', 'loading saves')!;
    expect(post.indexOf(cut), greaterThan(at110));
  });

  test('our link notes are taken out', () {
    const text = '1.0\n- Added a download mirror [link: https://x.test/a.zip] here\n- Fixed typos everywhere\n';
    expect(
      notes([text], '1.0', 'Added a download', 'typos everywhere'),
      '- Added a download mirror here\n- Fixed typos everywhere',
    );
  });

  test('punctuation and spacing in the pointer do not matter', () {
    const text = "0.5\n- Don't crash when the fleet's empty & docked\n";
    expect(notes([text], '0.5', 'Dont crash, when  the', 'fleets empty docked.'),
        "- Don't crash when the fleet's empty & docked");
  });

  test('a pointer too short to point at one place is turned away', () {
    expect(failure([post], '1.2.0', 'Added', 'loading saves'),
        ChangelogCutFailure.pointerTooShort);
  });

  test('pointers split across two posts are not cut', () {
    expect(
      failure(['1.0\n- Added the new ships'], '1.0', 'Added the new ships',
          'Fixed the old shields'),
      ChangelogCutFailure.lastWordsNotFound,
    );
    expect(
      notes(['1.0\n- Added the new ships', '- Fixed the old shields'], '1.0',
          'Added the new ships', 'Fixed the old shields'),
      isNull,
    );
  });

  test('each kind of failure is reported', () {
    expect(failure([post], '9.9.9', 'Added the Hammerhead', 'loading saves'),
        ChangelogCutFailure.versionNotFound);
    expect(failure([post], '1.2.0', 'Nothing like this here', 'loading saves'),
        ChangelogCutFailure.firstWordsNotFound);
    expect(failure([post], '1.2.0', 'Added the Hammerhead', 'not in this post'),
        ChangelogCutFailure.lastWordsNotFound);
  });

  test('the notes can sit in a later post', () {
    expect(
      notes(['The mod.', '2.1\n- Added the new ships\n- Fixed shields'], '2.1',
          'Added the new', 'Fixed shields'),
      '- Added the new ships\n- Fixed shields',
    );
  });

  test("the forum's spoiler end mark is left out", () {
    const text = '1.0\n- Added the new ships\n- Fixed the old shields [close]\n';
    expect(notes([text], '1.0', 'Added the new ships', 'Fixed the old shields'),
        '- Added the new ships\n- Fixed the old shields');
  });

  test('&nbsp; left in the post does not block the match', () {
    // Topic 24545: the notes arrive as "&nbsp;&nbsp;&nbsp;Campaign:".
    const text = '**** Version 0.2.2 ****\n'
        '&nbsp;&nbsp;&nbsp;Campaign:\n&nbsp;&nbsp;&nbsp;&nbsp;Added a threat.\n';
    expect(notes([text], '0.2.2', 'Campaign: Added a threat', 'Added a threat.'),
        'Campaign:\n    Added a threat.');
  });

  test('notes written before their version are found', () {
    // Topic 30736: the version is on the download link after the notes.
    const text = 'Yet another update to hopefully make it work this time.\n\n'
        "Omega's External Settings 1.1.2 download\n";
    expect(notes([text], '1.1.2', 'Yet another update to', 'work this time.'),
        'Yet another update to hopefully make it work this time.');
  });

  test('notes in another message than the version are found', () {
    // A Discord thread: the version is in the thread's first line, the notes
    // in a later message.
    expect(
      notes(['Suitable Star Systems 2.4.0a', '- Update cryovolcanic world to gas giant'],
          '2.4.0a', 'Update cryovolcanic world', 'to gas giant'),
      '- Update cryovolcanic world to gas giant',
    );
  });

  test('a version only in the title is enough', () {
    const text = 'Added the Putrifier as a head boss, good luck.\n';
    expect(failure([text], '2.05', 'Added the Putrifier', 'head boss, good luck'),
        ChangelogCutFailure.versionNotFound);
    expect(
      cutChangelogEntry([text], '2.05', 'Added the Putrifier', 'head boss, good luck',
              title: 'Star Wars Mod 2.05 (under new management)')
          .notes,
      'Added the Putrifier as a head boss, good luck.',
    );
  });

  test('a dash, underscore or space between version parts all match', () {
    // Topic 18227: the post writes "0.3.8 RC1", the model "0.3.8-RC1".
    const text = '2020-9-10 0.3.8 RC1\n- Fire Hammer added for Arbiters\n';
    expect(notes([text], '0.3.8-RC1', 'Fire Hammer added for', 'added for Arbiters'),
        '- Fire Hammer added for Arbiters');
    // Dots still have to match.
    expect(failure([text], '0.38-RC1', 'Fire Hammer added for', 'added for Arbiters'),
        ChangelogCutFailure.versionNotFound);
  });

  test('runs of blank lines are made one', () {
    const text = '1.0\nFirst change of many\n\n\n\nLast change of many\n';
    expect(notes([text], '1.0', 'First change of', 'Last change of many'),
        'First change of many\n\nLast change of many');
  });
}
