/// https://github.com/android-password-store/sublime-fuzzy
class Constants {
  static const int sequentialBonus = 15;
  static const int separatorBonus = 30;
  static const int camelBonus = 30;
  static const int firstLetterBonus = 15;

  static const int leadingLetterPenalty = -5;
  static const int maxLeadingLetterPenalty = -15;
  static const int unmatchedLetterPenalty = -1;
}
