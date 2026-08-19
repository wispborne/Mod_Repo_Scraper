import 'package:mod_repo_scraper/site/display_name.dart';
import 'package:test/test.dart';

/// Thread titles carry the game version, the mod version, dates, "WIP" tags and
/// leading dashes. The name a reader sees should carry none of them — and
/// because Browse sorts by name, a leading dash or bracket would otherwise put
/// the worst-named mods on page one.
void main() {
  test('takes the bracketed game version off the front', () {
    expect(displayName('[0.98a] Nexerelin v0.12.2'), 'Nexerelin');
    expect(displayName('[0.98] Show Encounter Stats v1.1.2'),
        'Show Encounter Stats');
  });

  test('takes a leading dash off', () {
    expect(displayName('- Starter Pack v1.1.3'), 'Starter Pack');
    expect(displayName('-- Stat-Derived Ship Costs v1.1.4'),
        'Stat-Derived Ship Costs');
    expect(displayName('– Some Mod'), 'Some Mod');
  });

  test('takes a leading dash off whichever side of the brackets it is', () {
    expect(displayName('- [0.98a] Some Mod'), 'Some Mod');
    expect(displayName('[0.98a] - Some Mod'), 'Some Mod');
  });

  test('takes a version on the end off, with or without a "v"', () {
    expect(displayName('Diable Avionics 1.3.7'), 'Diable Avionics');
    expect(displayName('Some Mod ver 2.0'), 'Some Mod');
  });

  test('leaves a number that is part of the name alone', () {
    expect(displayName('Ship Pack 2'), 'Ship Pack 2');
  });

  test('takes an "updated" tail off', () {
    expect(displayName('Some Mod (Updated 2026-01-05)'), 'Some Mod');
    expect(displayName('Some Mod - Updated: 5 January 2026'), 'Some Mod');
    expect(displayName('Some Mod, updated!'), 'Some Mod');
  });

  test('keeps the WIP tag out of the name — it is shown as a badge', () {
    expect(displayName('[WIP] Europa Federation'), 'Europa Federation');
    expect(displayName('Europa Federation [WIP]'), 'Europa Federation');
    expect(displayName('Europa Federation (WIP)'), 'Europa Federation');
  });

  test('keeps the author\'s own capitals', () {
    expect(displayName('[0.98a] LazyLib v2.8'), 'LazyLib');
  });

  test('leaves an ordinary name alone', () {
    expect(displayName('Industrial Evolution'), 'Industrial Evolution');
  });

  test('falls back to the name as written when nothing would be left', () {
    expect(displayName('[0.98a]'), '[0.98a]');
    expect(displayName('   '), '   ');
  });

  test('does not leave a bracket hanging open when a version comes off', () {
    expect(displayName('Mimikko Assistant v (0.96/0.97)'), 'Mimikko Assistant');
    expect(displayName('Some Mod (for 0.98a'), 'Some Mod');
  });

  test('tidies the spacing and any punctuation left dangling', () {
    expect(displayName('Some   Mod  -  v1.2'), 'Some Mod');
    expect(displayName('Some Mod :'), 'Some Mod');
  });
}
