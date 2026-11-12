import 'package:klura/core/calendar_date.dart';
import 'package:test/test.dart';

void main() {
  group('formatCalendarDate', () {
    final cases = [
      (DateTime(2026, 11, 12), '2026-11-12'),
      (DateTime(2027, 1, 5), '2027-01-05'),
      (DateTime(2026, 11, 12, 23, 59, 59), '2026-11-12'),
      (DateTime(987, 6, 5), '0987-06-05'),
    ];

    for (final (date, expected) in cases) {
      test('writes $date as $expected', () {
        expect(formatCalendarDate(date), expected);
      });
    }
  });

  group('parseCalendarDate', () {
    test('reads a date as local midnight', () {
      expect(parseCalendarDate('2026-11-12'), DateTime(2026, 11, 12));
      expect(parseCalendarDate('2028-02-29'), DateTime(2028, 2, 29));
    });

    final invalid = [
      '',
      '2026-11-1',
      '2026-1-12',
      '26-11-12',
      '2026/11/12',
      '2026-11-12T00:00',
      ' 2026-11-12',
      '2026-13-01',
      '2026-00-10',
      '2026-02-29',
      '2026-04-31',
      '2026-11-00',
    ];

    for (final text in invalid) {
      test('rejects "$text"', () {
        expect(parseCalendarDate(text), isNull);
      });
    }

    test('reads back what formatCalendarDate writes', () {
      for (var day = 0; day < 800; day++) {
        final date = DateTime(2026, 1, 1 + day);

        expect(parseCalendarDate(formatCalendarDate(date)), date);
      }
    });
  });

  group('calendarDaysBetween', () {
    final cases = [
      (DateTime(2026, 11, 12), DateTime(2026, 11, 12), 0),
      (DateTime(2026, 11, 12, 23, 59), DateTime(2026, 11, 13, 0, 1), 1),
      (DateTime(2026, 11, 13), DateTime(2026, 11, 12), -1),
      (DateTime(2026, 12, 31), DateTime(2027), 1),
      (DateTime(2028, 2, 28), DateTime(2028, 3), 2),
      // Across the start and end of daylight saving time in Europe.
      (DateTime(2027, 3, 27), DateTime(2027, 3, 29), 2),
      (DateTime(2026, 10, 24), DateTime(2026, 10, 26), 2),
      (DateTime(2026), DateTime(2027), 365),
    ];

    for (final (from, to, expected) in cases) {
      test('counts $expected from $from to $to', () {
        expect(calendarDaysBetween(from, to), expected);
      });
    }
  });
}
