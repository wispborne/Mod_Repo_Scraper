/// Forum posts are full of non-breaking spaces, and our cleaned-up post text
/// keeps them as the literal text `&nbsp;`. That text has to stay in what the
/// model is sent, because changing the prompt would make every post be read
/// again. Everything else treats it as an ordinary space.
library;

/// A non-breaking space in any form a post or the model might use: `&nbsp;`,
/// its numeric forms (`&#160;`, `&#xa0;`) or the U+00A0 character.
final RegExp nonBreakingSpace =
    RegExp('&nbsp;|&#0*160;|&#x0*a0;| ', caseSensitive: false);

/// [text] with each non-breaking space made an ordinary space, for comparing
/// it with something else.
String plainSpaces(String text) => text.replaceAll(nonBreakingSpace, ' ');

/// [text] ready to keep or show, with its non-breaking spaces gone. The ends
/// are trimmed. Runs of spaces are made one, except on text of several lines,
/// where they may be an author's indents. Text with no non-breaking space comes
/// back exactly as it was.
String withoutNonBreakingSpaces(String text) {
  final plain = plainSpaces(text);
  if (plain == text) return text;
  final trimmed = plain.trim();
  return trimmed.contains('\n')
      ? trimmed
      : trimmed.replaceAll(_runOfSpaces, ' ');
}

/// [json] with [withoutNonBreakingSpaces] applied to every string value inside
/// it. Map keys are left alone.
Object? withoutNonBreakingSpacesInside(Object? json) => switch (json) {
      final String text => withoutNonBreakingSpaces(text),
      final List<dynamic> list => [
          for (final item in list) withoutNonBreakingSpacesInside(item),
        ],
      final Map<String, dynamic> map => <String, dynamic>{
          for (final entry in map.entries)
            entry.key: withoutNonBreakingSpacesInside(entry.value),
        },
      _ => json,
    };

final RegExp _runOfSpaces = RegExp(r'[ \t]{2,}');
