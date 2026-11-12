import 'package:flutter/foundation.dart';

/// Reads a clock that only moves forward, such as a running [Stopwatch].
typedef MonotonicClock = Duration Function();

/// Counts the time spent playing: it runs only between [start] and [pause].
///
/// The time comes from a monotonic clock, so a change to the device's date
/// or time never moves it. Listeners hear when it starts and pauses, not on
/// every tick; a clock on screen polls [elapsed] while [isRunning].
final class PlayTimer extends ChangeNotifier {
  /// Creates a paused timer that has counted [elapsed] so far.
  PlayTimer({Duration elapsed = Duration.zero, MonotonicClock? clock})
    : _counted = elapsed,
      _clock = clock ?? _stopwatchClock;

  final MonotonicClock _clock;

  /// The time counted up to the last pause.
  Duration _counted;

  /// The clock reading at the last start, while running.
  Duration? _startedAt;

  /// The time counted so far, including the current run.
  Duration get elapsed => switch (_startedAt) {
    final startedAt? => _counted + (_clock() - startedAt),
    null => _counted,
  };

  bool get isRunning => _startedAt != null;

  /// Starts counting, unless the timer is already running.
  void start() {
    if (isRunning) {
      return;
    }
    _startedAt = _clock();
    notifyListeners();
  }

  /// Stops counting and keeps the time so far, unless already paused.
  void pause() {
    if (!isRunning) {
      return;
    }
    _counted = elapsed;
    _startedAt = null;
    notifyListeners();
  }
}

final Stopwatch _stopwatch = Stopwatch()..start();

Duration _stopwatchClock() => _stopwatch.elapsed;
