import 'constants.dart';

/// https://github.com/android-password-store/sublime-fuzzy
class Fuzzy {
  /// Returns true if each character in pattern is found sequentially within str
  ///
  /// @param pattern the pattern to match
  /// @param str the string to search
  /// @return A boolean representing the match status
  static bool fuzzyMatchSimple(String pattern, String str) {
    var patternIdx = 0;
    var strIdx = 0;

    final patternLength = pattern.length;
    final strLength = str.length;

    while (patternIdx != patternLength && strIdx != strLength) {
      final patternChar = pattern[patternIdx].toLowerCase();
      final strChar = str[strIdx].toLowerCase();
      if (patternChar == strChar) ++patternIdx;
      ++strIdx;
    }

    return patternLength != 0 && strLength != 0 && patternIdx == patternLength;
  }

  static (bool, int) _fuzzyMatchRecursive(
    String pattern,
    String str,
    int patternCurIndexOut,
    int strCurIndexOut,
    List<int> srcMatches,
    List<int> matches,
    int maxMatches,
    int nextMatchOut,
    int recursionCountOut,
    int recursionLimit,
  ) {
    var outScore = 0;
    var strCurIndex = strCurIndexOut;
    var patternCurIndex = patternCurIndexOut;
    var nextMatch = nextMatchOut;
    var recursionCount = recursionCountOut;

    // return if recursion limit is reached
    if (++recursionCount >= recursionLimit) {
      return (false, outScore);
    }

    // return if we reached end of strings
    if (patternCurIndex == pattern.length || strCurIndex == str.length) {
      return (false, outScore);
    }

    // recursion params
    var recursiveMatch = false;
    final bestRecursiveMatches = <int>[];
    var bestRecursiveScore = 0;

    // loop through pattern and str looking for a match
    var firstMatch = true;
    while (patternCurIndex < pattern.length && strCurIndex < str.length) {
      // match found
      if (pattern[patternCurIndex].toLowerCase() == str[strCurIndex].toLowerCase()) {
        if (nextMatch >= maxMatches) {
          return (false, outScore);
        }

        if (firstMatch && srcMatches.isNotEmpty) {
          matches.clear();
          matches.addAll(srcMatches);
          firstMatch = false;
        }

        final recursiveMatches = <int>[];
        final (matched, recursiveScore) = _fuzzyMatchRecursive(
          pattern,
          str,
          patternCurIndex,
          strCurIndex + 1,
          matches,
          recursiveMatches,
          maxMatches,
          nextMatch,
          recursionCount,
          recursionLimit,
        );

        if (matched) {
          // pick best recursive score
          if (!recursiveMatch || recursiveScore > bestRecursiveScore) {
            bestRecursiveMatches.clear();
            bestRecursiveMatches.addAll(recursiveMatches);
            bestRecursiveScore = recursiveScore;
          }
          recursiveMatch = true;
        }

        matches.add(strCurIndex);
        nextMatch++;
        ++patternCurIndex;
      }
      ++strCurIndex;
    }

    final matched = patternCurIndex == pattern.length;

    if (matched) {
      outScore = 100;

      // apply leading letter penalty
      final penalty = (Constants.leadingLetterPenalty * matches[0])
          .clamp(Constants.maxLeadingLetterPenalty, 0);
      outScore += penalty;

      // apply unmatched penalty
      final unmatched = str.length - nextMatch;
      outScore += Constants.unmatchedLetterPenalty * unmatched;

      // apply ordering bonuses
      for (var i = 0; i < nextMatch; i++) {
        final currIdx = matches[i];

        if (i > 0) {
          final prevIdx = matches[i - 1];
          if (currIdx == prevIdx + 1) {
            outScore += Constants.sequentialBonus;
          }
        }

        // check for bonuses based on neighbour character value
        if (currIdx > 0) {
          // camelcase
          final neighbour = str[currIdx - 1];
          final curr = str[currIdx];
          if (neighbour != neighbour.toUpperCase() && curr != curr.toLowerCase()) {
            outScore += Constants.camelBonus;
          }
          final isNeighbourSeparator = neighbour == '_' || neighbour == ' ';
          if (isNeighbourSeparator) {
            outScore += Constants.separatorBonus;
          }
        } else {
          // first letter
          outScore += Constants.firstLetterBonus;
        }
      }

      // return best result
      if (recursiveMatch && (!matched || bestRecursiveScore > outScore)) {
        // recursive score is better than "this"
        matches.clear();
        matches.addAll(bestRecursiveMatches);
        outScore = bestRecursiveScore;
        return (true, outScore);
      } else if (matched) {
        // "this" score is better than recursive
        return (true, outScore);
      } else {
        return (false, outScore);
      }
    }

    return (false, outScore);
  }

  /// Performs a fuzzy search to find pattern inside a string
  ///
  /// @param pattern the the pattern to match
  /// @param str the string to search
  /// @return a record containing the match status as a bool and match score as an int
  static (bool, int) fuzzyMatch(String pattern, String str) {
    const recursionCount = 0;
    const recursionLimit = 10;
    final matches = <int>[];
    const maxMatches = 256;

    return _fuzzyMatchRecursive(
      pattern,
      str,
      0,
      0,
      [],
      matches,
      maxMatches,
      0,
      recursionCount,
      recursionLimit,
    );
  }
}
