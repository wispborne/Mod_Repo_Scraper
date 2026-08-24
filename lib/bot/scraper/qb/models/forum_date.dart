/// Reading the forum's own way of writing a date.
///
/// SMF writes "May 04, 2014, 01:33:25 AM" on a post and in the topic lists, and
/// that string is what the scrape keeps. Anything that wants to sort by it, or
/// to say which day it was, has to read it back — so it is read back in one
/// place.
library;

const Map<String, int> _months = {
  'January': 1,
  'February': 2,
  'March': 3,
  'April': 4,
  'May': 5,
  'June': 6,
  'July': 7,
  'August': 8,
  'September': 9,
  'October': 10,
  'November': 11,
  'December': 12,
};

final RegExp _forumDate = RegExp(
  r'^(\w+)\s+(\d{1,2}),\s+(\d{4}),\s+(\d{1,2}):(\d{2}):(\d{2})\s*([AP]M)?',
);

/// Reads the forum's "May 04, 2014, 01:33:25 AM" form. Returns null when the
/// string is missing or is written some other way — the forum also says things
/// like "Today at 03:12:22 PM", which names no day at all.
DateTime? parseForumDate(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  final m = _forumDate.firstMatch(text.trim());
  if (m == null) return null;
  final month = _months[m.group(1)];
  if (month == null) return null;

  var hour = int.parse(m.group(4)!);
  final halfOfDay = m.group(7);
  if (halfOfDay == 'PM' && hour != 12) hour += 12;
  if (halfOfDay == 'AM' && hour == 12) hour = 0;

  return DateTime(int.parse(m.group(3)!), month, int.parse(m.group(2)!), hour,
      int.parse(m.group(5)!), int.parse(m.group(6)!));
}
