/// Reading the `YYYY-MM-DD` days the site writes.
///
/// Both the builder and the release feed want this, and neither should have to
/// import the other to get it.

/// A `YYYY-MM-DD` day read as that day in UTC, or null when it is not one.
///
/// Parsing it the ordinary way would read it as local midnight, which lands on
/// the day before or after once it is written back out.
DateTime? readDay(String day) {
  final parts = day.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final date = int.tryParse(parts[2]);
  if (year == null || month == null || date == null) return null;
  return DateTime.utc(year, month, date);
}

/// A moment written back as a `YYYY-MM-DD` day.
String writeDay(DateTime when) {
  final month = when.month.toString().padLeft(2, '0');
  final day = when.day.toString().padLeft(2, '0');
  return '${when.year}-$month-$day';
}
