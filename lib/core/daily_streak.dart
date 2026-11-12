import 'package:klura/core/calendar_date.dart';

/// Counts the calendar days in a row among [days] that end on [today], or on
/// the day before while today is not among them.
///
/// A streak therefore survives until the end of a day without a solve: it
/// still counts yesterday's run in the morning, before today's puzzle is
/// done. Days after [today], from a clock that was set ahead, never count.
/// The time of day in every date is ignored.
int countDailyStreak(Iterable<DateTime> days, DateTime today) {
  final daysBack = {
    for (final day in days) calendarDaysBetween(day, today),
  };
  var daysAgo = daysBack.contains(0) ? 0 : 1;
  var streak = 0;
  while (daysBack.contains(daysAgo)) {
    streak++;
    daysAgo++;
  }
  return streak;
}
