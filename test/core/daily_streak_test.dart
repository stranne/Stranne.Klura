import 'package:klura/core/daily_streak.dart';
import 'package:test/test.dart';

void main() {
  final today = DateTime(2026, 11, 12);

  /// The dates [daysAgo] days before today.
  List<DateTime> daysBefore(List<int> daysAgo) => [
    for (final days in daysAgo) DateTime(2026, 11, 12 - days),
  ];

  final cases = [
    ('no days', <int>[], 0),
    ('only today', [0], 1),
    ('today and the two days before', [0, 1, 2], 3),
    ('the run up to yesterday before today is solved', [1, 2, 3], 3),
    ('a run that ended two days ago', [2, 3, 4], 0),
    ('a gap', [0, 1, 3, 4, 5], 2),
    ('a gap before yesterday', [1, 3], 1),
    ('a day listed twice', [0, 0, 1], 2),
    ('the days in any order', [2, 0, 1], 3),
    ('a day after today', [-1, 0, 1], 2),
  ];

  for (final (description, daysAgo, expected) in cases) {
    test('counts $expected for $description', () {
      expect(countDailyStreak(daysBefore(daysAgo), today), expected);
    });
  }

  test('ignores the time of day', () {
    final days = [
      DateTime(2026, 11, 12, 0, 5),
      DateTime(2026, 11, 11, 23, 55),
    ];

    expect(countDailyStreak(days, DateTime(2026, 11, 12, 18)), 2);
  });

  test('runs across months, years and daylight saving time', () {
    final days = [
      for (var day = 0; day < 400; day++) DateTime(2027, 3, 31 - day),
    ];

    expect(countDailyStreak(days, DateTime(2027, 3, 31)), 400);
  });
}
