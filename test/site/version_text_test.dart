import 'package:mod_repo_scraper/site/version_text.dart';
import 'package:test/test.dart';

void main() {
  group('cleaning', () {
    test('the same version spelled differently cleans to one thing', () {
      expect(VersionText.clean('0.95'), '0.95');
      expect(VersionText.clean('v.0.95'), '0.95');
      expect(VersionText.clean('V 0.95'), '0.95');
      expect(VersionText.clean('Version 0.95'), '0.95');
      expect(VersionText.clean('update 0.95'), '0.95');
      expect(VersionText.clean('rev.0.95'), '0.95');
    });

    test('spaces, dashes and underscores are read as dots', () {
      expect(VersionText.clean('1-0-rc1'), '1.0.rc1');
      expect(VersionText.clean('0.99a BETA'), '0.99a.beta');
      expect(VersionText.clean('2_1_4'), '2.1.4');
    });

    test('a version that does not start with a number is unreadable', () {
      expect(VersionText.clean('the latest one'), isNull);
      expect(VersionText.clean('alpha'), isNull);
      expect(VersionText.clean(''), isNull);
      expect(VersionText.clean(null), isNull);
    });

    test('text holding more than one version is unreadable', () {
      expect(VersionText.clean('v.60, .54a'), isNull);
      expect(VersionText.clean('0.95 and 1.0'), isNull);
      expect(VersionText.clean('1.2 / 1.3'), isNull);
    });
  });

  group('comparing', () {
    test('a letter on the end is newer: 3.5.2 against 3.5.2g', () {
      expect(VersionText.compare('3.5.2g', '3.5.2'), greaterThan(0));
      expect(VersionText.compare('3.5.2', '3.5.2g'), lessThan(0));
      expect(VersionText.compare('3.5.2g', '3.5.2h'), lessThan(0));
    });

    test('a run-up is older: 1.0-rc1 against 1.0', () {
      final rc = VersionText.clean('1.0-rc1')!;
      final out = VersionText.clean('1.0')!;
      expect(VersionText.compare(rc, out), lessThan(0));
      expect(VersionText.compare(out, rc), greaterThan(0));
      expect(VersionText.compare(VersionText.clean('1.0-rc2')!, rc),
          greaterThan(0));
    });

    test('leaving beta: "0.99a BETA" against "0.99a"', () {
      final beta = VersionText.clean('0.99a BETA')!;
      final out = VersionText.clean('0.99a')!;
      expect(VersionText.compare(beta, out), lessThan(0));
      expect(VersionText.isNewer(out, beta), isTrue);
    });

    test('numbers are read as numbers, not as text', () {
      expect(VersionText.compare('1.10', '1.9'), greaterThan(0));
      expect(VersionText.compare('0.12.2', '0.12.1'), greaterThan(0));
    });

    test('a missing part counts as zero', () {
      expect(VersionText.compare('1.0', '1'), 0);
      expect(VersionText.compare('1.0.1', '1'), greaterThan(0));
    });

    test('the run-up words run dev, pre, alpha, beta, rc', () {
      final order = ['1.0.dev', '1.0.pre', '1.0.alpha', '1.0.beta', '1.0.rc'];
      for (var i = 1; i < order.length; i++) {
        expect(VersionText.compare(order[i], order[i - 1]), greaterThan(0),
            reason: '${order[i]} should be later than ${order[i - 1]}');
      }
    });
  });

  group('the game version is not the mod version', () {
    test('a reading matching the thread game version is thrown out', () {
      expect(
        VersionText.isGameVersion('0.98a',
            threadGameVersion: '0.98a', threadTitle: '[0.98a] Some Mod'),
        isTrue,
      );
    });

    test('a reading matching the bracket at the front is thrown out', () {
      expect(
        VersionText.isGameVersion('0.98a', threadTitle: '[0.98a] Some Mod'),
        isTrue,
      );
    });

    test('a real mod version is kept', () {
      expect(
        VersionText.isGameVersion('0.12.2',
            threadGameVersion: '0.98a', threadTitle: '[0.98a] Nexerelin v0.12.2'),
        isFalse,
      );
    });
  });

  group('reading a version out of the title', () {
    test('the bracketed game version at the front is ignored', () {
      expect(VersionText.versionFromTitle('[0.98a] Nexerelin v0.12.2'), '0.12.2');
      expect(VersionText.versionFromTitle('[0.98a] Some Mod 1.4.3'), '1.4.3');
    });

    test('a version in brackets further along still counts', () {
      expect(
          VersionText.versionFromTitle('BattleFarer Forever [v 0.3]'), '0.3');
    });

    test('a title with no version says so', () {
      expect(VersionText.versionFromTitle('Planet Search'), isNull);
      expect(VersionText.versionFromTitle('[0.98a] Planet Search'), isNull);
      expect(VersionText.versionFromTitle(null), isNull);
    });

    test('a lone number in a name is not taken for a version', () {
      expect(VersionText.versionFromTitle('[0.98a] Ship Pack 2'), isNull);
    });

    test('where a title names several, the last one is used', () {
      expect(
        VersionText.versionFromTitle('[0.98a] Some Mod v1.2 (was v1.1)'),
        '1.1',
      );
    });
  });
}
