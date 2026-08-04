/*
 * This file is distributed under the GPLv3. An informal description follows:
 * - Anyone can copy, modify and distribute this software as long as the other points are followed.
 * - You must include the license and copyright notice with each and every distribution.
 * - You may use this software for commercial purposes.
 * - If you modify it, you must indicate changes made to the code.
 * - Any modifications of this code base MUST be distributed with the same license, GPLv3.
 * - This software is provided without warranty.
 * - The software author or license can not be held liable for any damages inflicted by the software.
 * The full license is available from <https://www.gnu.org/licenses/gpl-3.0.txt>.
 */

import 'package:mod_repo_scraper/timber/ktx/timber_kt.dart' as timber;
import '../../utilities/parallel_map.dart';
import 'fuzzy/fuzzy.dart';

final _versionNoiseRe = RegExp(r'^(?:\[[^\]]*\]\s*)?(.*?)(?:\s*[(\[]?[vV]?\.?\d+\.\d+.*)?$');
final _trailingSeparatorsRe = RegExp(r'[-–|:,\s]+$');

String stripVersionNoise(String name) {
  final m = _versionNoiseRe.firstMatch(name);
  if (m == null) return name;
  var stripped = m.group(1)!;
  stripped = stripped.replaceAll(_trailingSeparatorsRe, '');
  return stripped.isEmpty ? name : stripped;
}

class ModRepoUtils {
  static const List<List<String>> authorAliases = [
    ["Soren", "Søren", "Harmful Mechanic"],
    ["RustyCabbage", "rubi", "ceruleanpancake"],
    ["Wisp", "Wispborne", "Tartiflette and Wispborne"],
    ["DesperatePeter", "Jannes"],
    ["shoi", "gettag"],
    ["Dark.Revenant", "DR"],
    ["LazyWizard", "Lazy", "arkmagius"],
    ["Techpriest", "Timid"],
    ["Nick XR", "Nick", "nick7884"],
    ["PMMeCuteBugPhotos", "MrFluffster"],
    ["Dazs", "Spiritfox", "spiritfox_"],
    ["Histidine, Zaphide", "Histidine", "histidine_my"],
    ["Snrasha", "Snrasha, the tinkerer"],
    ["Hotpics", "jackwolfskin"],
    ["cptdash", "SpeedRacer"],
    ["Elseud", "Elseudo"],
    ["TobiaF", "Toby"],
    ["Mephyr", "Liral"],
    ["Tranquility", "tranquil_light"],
    ["FasterThanSleepyfish", "Sleepyfish"],
    ["Nerzhull_AI", "nerzhulai"],
    ["theDragn", "iryx.gay"],
    ["Audax", "Audaxl"],
    ["Pogre", "noof"],
    ["lord_dalton", "Epta Consortium"],
    ["hakureireimu", "LngA7Gw"],
    ["Nes", "nescom"],
    ["float", "this_is_a_username"],
    ["AERO", "aero.assault"],
    ["Fellout", "felloutwastaken"],
    ["Mr. THG", "thog"],
    ["Derelict_Surveyor", "jdt15"],
    ["astarat.", "Astarat", "Astarat and PureTilt"],
    ["Yogurt Fox", "YogurtFox", "Mycophobia"],
  ];

  /// Splits an author credit like "Ed, Nick XR & Foo and Bar" into the
  /// individual names. The credit itself is not included in the result.
  static List<String> splitAuthorNames(String authors) {
    return authors
        .split(RegExp(r',|&|/|\band\b', caseSensitive: false))
        .map((name) => name.trim())
        .where((name) => name.length >= 2)
        .toList();
  }

  /// Tidies a mod's author list so that each person is named once, in one
  /// spelling.
  ///
  /// Merging pulls the same person in from every source at once — a forum
  /// name, a Discord name, and a credit that names the whole team — and all
  /// of them would otherwise be published side by side. Nexerelin came out as
  /// "Histidine", "Histidine, Zaphide" and "histidine_my", which is two people
  /// written three ways.
  ///
  /// So: credits that name several people are split into the individual
  /// names, then names that mean the same person are folded together — the
  /// same name in different capitals or punctuation ("Kaysaar" / "kaysaar"),
  /// a name with a tag on the end ("Sundog" / "sundog3161"), and names listed
  /// together in [authorAliases] ("Nes" / "nescom"). The best-looking spelling
  /// of each person is the one kept.
  static List<String> tidyAuthorNames(List<String> authors) {
    final names = <String>[];
    for (final credit in authors) {
      for (final name in _peopleNamedIn(credit)) {
        if (!names.contains(name)) names.add(name);
      }
    }
    // Nothing usable to work with — leave the list as it was found.
    if (names.isEmpty) return authors;

    // Which names turned out to be the same person.
    final groupOf = List<int>.generate(names.length, (i) => i);

    int rootOf(int i) {
      var root = i;
      while (groupOf[root] != root) {
        root = groupOf[root];
      }
      return root;
    }

    final plainNames = names.map(_plainName).toList();
    final plainNamesWithoutTag = names.map(_plainNameWithoutTag).toList();
    final aliasRows = names.map(_aliasRowFor).toList();

    for (var i = 0; i < names.length; i++) {
      for (var j = i + 1; j < names.length; j++) {
        final sameSpelling = plainNames[i] != null && plainNames[i] == plainNames[j];
        final sameOnceTagsAreDropped = plainNamesWithoutTag[i] != null &&
            plainNamesWithoutTag[i] == plainNamesWithoutTag[j];
        final sameAliasRow =
            aliasRows[i].isNotEmpty && aliasRows[j].isNotEmpty && aliasRows[i].first == aliasRows[j].first;

        if (sameSpelling || sameOnceTagsAreDropped || sameAliasRow) {
          final rootA = rootOf(i);
          final rootB = rootOf(j);
          if (rootA != rootB) groupOf[rootA] = rootB;
        }
      }
    }

    // Keep the best-looking spelling from each group.
    final bestOfGroup = <int, int>{};
    for (var i = 0; i < names.length; i++) {
      final root = rootOf(i);
      final best = bestOfGroup[root];
      if (best == null || _isBetterSpelling(names[i], names[best])) {
        bestOfGroup[root] = i;
      }
    }

    return bestOfGroup.values.map((i) => names[i]).toList()..sort(_byNameIgnoringCase);
  }

  static final _leadingByRe = RegExp(r'^by\s+', caseSensitive: false);
  static final _endsInDigitsRe = RegExp(r'\d+$');
  static final _capitalRe = RegExp(r'[A-Z]');
  static final _notALetterOrDigitRe = RegExp(r'[^A-Za-z0-9]');

  /// Words that never start a name of their own, so a piece beginning with one
  /// belongs to the name before it: "Snrasha, the tinkerer" is one person.
  static const _notANameStart = {'the', 'a', 'an', 'of'};

  /// The individual people named by one author credit.
  static List<String> _peopleNamedIn(String credit) {
    final trimmed = credit.trim().replaceFirst(_leadingByRe, '').trim();
    if (trimmed.isEmpty) return const [];

    final parts = splitAuthorNames(trimmed);
    if (parts.length < 2) return [trimmed];

    for (final part in parts) {
      final firstWord = part.split(RegExp(r'\s+')).first.toLowerCase();
      if (_notANameStart.contains(firstWord)) return [trimmed];
    }
    return parts.map((part) => part.replaceFirst(_leadingByRe, '').trim()).where((part) => part.isNotEmpty).toList();
  }

  /// A name reduced to what it has in common with other spellings of itself:
  /// lowercase, letters and digits only. "Dark.Revenant" and "dark.revenant"
  /// both come out as "darkrevenant". Null when nothing is left.
  static String? _plainName(String name) {
    final plain = name.toLowerCase().replaceAll(_notALetterOrDigitRe, '');
    return plain.isEmpty ? null : plain;
  }

  /// The same, with the digits some people carry on the end of a Discord name
  /// dropped, so "sundog3161" lines up with "Sundog". Only used when at least
  /// three characters are left, so a name that is mostly digits ("A-111164")
  /// is never worn down to nothing.
  static String? _plainNameWithoutTag(String name) {
    final plain = _plainName(name);
    if (plain == null) return null;
    final withoutTag = plain.replaceFirst(_endsInDigitsRe, '');
    return withoutTag.length >= 3 ? withoutTag : plain;
  }

  /// Whether [candidate] is a nicer way of writing the person's name than
  /// [current]. In order: one with capitals in it beats one without
  /// ("Kaysaar" over "kaysaar"), one without digits on the end beats one with
  /// ("Sundog" over "sundog3161"), fewer odd characters beats more
  /// ("vicegrip" over ".vicegrip"), then the order the name is listed in
  /// [authorAliases], then the shorter name, then alphabetical so the answer
  /// never depends on which name happened to arrive first.
  static bool _isBetterSpelling(String candidate, String current) {
    final candidateRank = _spellingRank(candidate);
    final currentRank = _spellingRank(current);
    for (var i = 0; i < candidateRank.length; i++) {
      if (candidateRank[i] != currentRank[i]) return candidateRank[i] < currentRank[i];
    }
    return _byNameIgnoringCase(candidate, current) < 0;
  }

  /// How good a spelling looks, lower being better, compared piece by piece.
  static List<int> _spellingRank(String name) => [
        name.contains(_capitalRe) ? 0 : 1,
        _endsInDigitsRe.hasMatch(name) ? 1 : 0,
        _notALetterOrDigitRe.allMatches(name).length,
        _aliasRank(name),
        name.length,
      ];

  /// The row of [authorAliases] a name belongs to, if any.
  ///
  /// A name with digits on the end is tried again without them, so
  /// "hakureireimu6512" finds the row that lists "hakureireimu".
  static List<String> _aliasRowFor(String name) {
    final row = getOtherMatchingAliases(name);
    if (row.isNotEmpty) return row;

    final withoutTag = name.replaceFirst(_endsInDigitsRe, '');
    if (withoutTag.length < 3 || withoutTag == name) return const [];
    return getOtherMatchingAliases(withoutTag);
  }

  /// Where a name sits in its row of [authorAliases] — the first name in a row
  /// is the one that row prefers. A name in no row sorts last.
  static int _aliasRank(String name) {
    final row = _aliasRowFor(name);
    if (row.isEmpty) return 999;
    final index = row.indexOf(name.toLowerCase());
    return index < 0 ? 999 : index;
  }

  static int _byNameIgnoringCase(String a, String b) {
    final ignoringCase = a.toLowerCase().compareTo(b.toLowerCase());
    return ignoringCase != 0 ? ignoringCase : a.compareTo(b);
  }

  static List<String> getOtherMatchingAliases(
    String author, {
    bool fuzzyMatchAliases = false,
    int matchScoreNeeded = 150,
  }) {
    final aliasesFormatted =
        authorAliases.map((aliases) => aliases.map((alias) => alias.toLowerCase()).toList()).toList();
    final authorFormatted = author.toLowerCase();

    // fuzzyMatchAliases is slower, more flexible, but risks false positives.
    // Last check, using score limit of 150, it only confused "nick", "nick7884", and "nicke535".
    // Without fuzzy merge: Total time to merge 726 mods: 2565ms
    // With fuzzy merge: Total time to merge 726 mods: 4938ms
    if (fuzzyMatchAliases) {
      for (final aliases in aliasesFormatted) {
        for (final alias in aliases) {
          final match1 = Fuzzy.fuzzyMatch(authorFormatted.toLowerCase(), alias.toLowerCase());
          if (match1.$1) {
            if (match1.$2 > matchScoreNeeded) {
              timber.v(message: () => "Matched alias '$author' with '$alias' with score ${match1.$2}.");
              return aliases;
            } else {
              timber.v(message: () => "Did not match alias '$author' with '$alias' with score ${match1.$2}.");
            }
          }

          final match2 = Fuzzy.fuzzyMatch(alias.toLowerCase(), authorFormatted.toLowerCase());
          if (match2.$1) {
            if (match2.$2 > matchScoreNeeded) {
              timber.v(message: () => "Matched alias '$author' with '$alias' with score ${match2.$2}.");
              return aliases;
            } else {
              timber.v(message: () => "Did not match alias '$author' with '$alias' with score ${match2.$2}.");
            }
          }
        }
      }
      return [];
    } else {
      for (final aliasesRow in aliasesFormatted) {
        for (final alias in aliasesRow) {
          if (alias == authorFormatted) {
            timber.v(message: () => "Matched author '$author' with alias list '${aliasesRow.join(', ')}'.");
            return aliasesRow;
          }
        }
      }
      return [];
    }
  }

  static Future<MatchResult> compareToFindBestMatch({
    required List<String> leftList,
    required List<String> rightList,
    bool stopAtFirstMatch = true,
    int scoreThreshold = 100,
  }) async {
    timber.v(message: () => "Comparing left: ${leftList.join(', ')} to right: ${rightList.join(', ')}.");

    final pairs = <(String, String)>[];
    for (final i in leftList) {
      for (final j in rightList) {
        pairs.add((i, j));
      }
    }

    final results = await pairs.parallelMap((pair) async {
      // Subsequence matching is one-way: "hqz" is found inside "hqz nightkev",
      // but not the other way round. Check both directions and keep the better,
      // so the answer doesn't depend on which side a name arrived on.
      final forward = Fuzzy.fuzzyMatch(pair.$1, pair.$2);
      final backward = Fuzzy.fuzzyMatch(pair.$2, pair.$1);
      // A direction that actually matched beats one that didn't; between two
      // matches, the higher score wins.
      final (bool, int) fuzzyMatch;
      if (forward.$1 != backward.$1) {
        fuzzyMatch = forward.$1 ? forward : backward;
      } else {
        fuzzyMatch = forward.$2 >= backward.$2 ? forward : backward;
      }
      final obj = MatchResult(
        leftMatch: pair.$1,
        rightMatch: pair.$2,
        isMatch: fuzzyMatch.$1,
        score: fuzzyMatch.$2,
      );

      timber.v(message: () => "Compared: $obj.");

      if (stopAtFirstMatch && fuzzyMatch.$2 > scoreThreshold) {
        return obj;
      }
      return obj;
    });

    if (results.isEmpty) {
      return const MatchResult(leftMatch: "", rightMatch: "", isMatch: false, score: 0);
    }

    final highestMatch = results.reduce((curr, next) => curr.score > next.score ? curr : next);

    if (highestMatch.score > scoreThreshold) {
      return highestMatch;
    }

    return const MatchResult(leftMatch: "", rightMatch: "", isMatch: false, score: 0);
  }
}

class MatchResult {
  final String leftMatch;
  final String rightMatch;
  final bool isMatch;
  final int score;

  const MatchResult({
    required this.leftMatch,
    required this.rightMatch,
    required this.isMatch,
    required this.score,
  });

  @override
  String toString() => "MatchResult(leftMatch: $leftMatch, rightMatch: $rightMatch, isMatch: $isMatch, score: $score)";
}
