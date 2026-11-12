import 'package:flutter_test/flutter_test.dart';
import 'package:klura/play/play_timer.dart';

void main() {
  var now = Duration.zero;

  PlayTimer timerOf({Duration elapsed = Duration.zero}) {
    now = const Duration(hours: 5);
    final timer = PlayTimer(elapsed: elapsed, clock: () => now);
    addTearDown(timer.dispose);
    return timer;
  }

  test('counts only while running', () {
    final timer = timerOf();

    now += const Duration(seconds: 10);
    expect(timer.elapsed, Duration.zero);

    timer.start();
    now += const Duration(seconds: 3);
    expect(timer.isRunning, isTrue);
    expect(timer.elapsed, const Duration(seconds: 3));

    timer.pause();
    now += const Duration(minutes: 1);
    expect(timer.isRunning, isFalse);
    expect(timer.elapsed, const Duration(seconds: 3));

    timer.start();
    now += const Duration(seconds: 2);
    expect(timer.elapsed, const Duration(seconds: 5));
  });

  test('carries on from earlier time', () {
    final timer = timerOf(elapsed: const Duration(minutes: 4))..start();

    now += const Duration(seconds: 12);

    expect(timer.elapsed, const Duration(minutes: 4, seconds: 12));
  });

  test('tells listeners when it starts and pauses, once each', () {
    final timer = timerOf();
    var notifications = 0;
    timer.addListener(() => notifications++);

    timer
      ..start()
      ..start();
    now += const Duration(seconds: 1);
    timer
      ..pause()
      ..pause();

    expect(notifications, 2);
  });
}
