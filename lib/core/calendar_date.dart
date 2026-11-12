/// Writes the calendar date of [date] as `yyyy-mm-dd`, such as `2026-11-12`.
///
/// The time of day is ignored, so callers pass the player's local date.
String formatCalendarDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// Reads a date written by [formatCalendarDate] as local midnight, or returns
/// `null` if [text] is not a real date in that form.
DateTime? parseCalendarDate(String text) {
  final match = _calendarDate.firstMatch(text);
  if (match == null) {
    return null;
  }
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final date = DateTime(year, month, day);
  // DateTime rolls 2026-02-30 over into March, which is not a real date.
  return date.year == year && date.month == month && date.day == day
      ? date
      : null;
}

/// The number of calendar days from [from] to [to], negative if [to] comes
/// first.
///
/// It counts dates, not hours, so a day that daylight saving time makes 23
/// or 25 hours long still counts as one.
int calendarDaysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

final RegExp _calendarDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
