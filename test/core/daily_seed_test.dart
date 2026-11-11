import 'package:klura/core/daily_seed.dart';
import 'package:test/test.dart';

void main() {
  group('dailySeedKey', () {
    final cases = [
      (DateTime(2026, 11, 11), 'bridges:v1:2026-11-11'),
      (DateTime(2027, 1, 5), 'bridges:v1:2027-01-05'),
      (DateTime(2026, 11, 11, 23, 59, 59), 'bridges:v1:2026-11-11'),
    ];

    for (final (date, expected) in cases) {
      test('builds $expected from $date', () {
        final key = dailySeedKey(
          puzzleId: 'bridges',
          generatorVersion: 1,
          date: date,
        );

        expect(key, expected);
      });
    }

    test('includes the puzzle and generator version', () {
      final key = dailySeedKey(
        puzzleId: 'suguru',
        generatorVersion: 3,
        date: DateTime(2026, 11, 11),
      );

      expect(key, 'suguru:v3:2026-11-11');
    });
  });
}
