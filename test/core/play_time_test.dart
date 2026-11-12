import 'package:klura/core/play_time.dart';
import 'package:test/test.dart';

void main() {
  final cases = [
    (Duration.zero, '0:00', '0 seconds'),
    (const Duration(milliseconds: 999), '0:00', '0 seconds'),
    (const Duration(seconds: 1), '0:01', '1 second'),
    (const Duration(seconds: 7), '0:07', '7 seconds'),
    (const Duration(minutes: 1), '1:00', '1 minute'),
    (const Duration(minutes: 4, seconds: 12), '4:12', '4 minutes 12 seconds'),
    (
      const Duration(minutes: 59, seconds: 59),
      '59:59',
      '59 minutes 59 seconds',
    ),
    (const Duration(hours: 1), '1:00:00', '1 hour'),
    (const Duration(hours: 1, seconds: 3), '1:00:03', '1 hour 3 seconds'),
    (
      const Duration(hours: 2, minutes: 5, seconds: 30),
      '2:05:30',
      '2 hours 5 minutes 30 seconds',
    ),
  ];

  for (final (time, clock, words) in cases) {
    test('writes $time as $clock and "$words"', () {
      expect(formatPlayTime(time), clock);
      expect(describePlayTime(time), words);
    });
  }
}
