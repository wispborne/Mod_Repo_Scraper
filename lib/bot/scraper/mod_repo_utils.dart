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
    ["theDrag", "iryx."],
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
  ];

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
      final fuzzyMatch = Fuzzy.fuzzyMatch(pair.$1, pair.$2);
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
