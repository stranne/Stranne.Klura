import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';

/// Measures how long the daily Bridges puzzles take to generate and how many
/// attempts they need, for two years from the first day Klura offers.
///
/// Run on the VM:
///
/// ```sh
/// dart run tool/benchmark_bridges.dart [days]
/// ```
///
/// Run compiled to JavaScript under Node.js, as in a browser:
///
/// ```sh
/// dart compile js -O2 -o build/benchmark_bridges.js tool/benchmark_bridges.dart
/// node build/benchmark_bridges.js
/// ```
///
/// The first puzzle is reported separately: a page load generates one puzzle
/// before the JavaScript engine has warmed up.
void main(List<String> arguments) {
  final days = arguments.isEmpty ? 731 : int.parse(arguments.first);
  final firstDate = DateTime.utc(2026, 11, 11);

  final samples = <_Sample>[];
  for (var day = 0; day < days; day++) {
    final date = DateTime.utc(
      firstDate.year,
      firstDate.month,
      firstDate.day + day,
    );
    final stopwatch = Stopwatch()..start();
    final generated = generateDailyBridges(date);
    stopwatch.stop();
    samples.add(
      (
        key: generated.seedKey,
        microseconds: stopwatch.elapsedMicroseconds,
        attempts: generated.attempts,
      ),
    );
  }

  final warm = samples.skip(1).toList();
  final byTime = [...warm]
    ..sort((a, b) => a.microseconds.compareTo(b.microseconds));
  final byAttempts = [...samples]
    ..sort((a, b) => a.attempts.compareTo(b.attempts));
  final totalAttempts = samples.fold(0, (sum, sample) => sum + sample.attempts);

  _write('Daily Bridges puzzles: $days from ${samples.first.key}');
  _write('First puzzle (cold): ${_ms(samples.first.microseconds)}');
  _write('Later puzzles:');
  _write('  mean    ${_ms(_mean(warm))}');
  _write('  median  ${_ms(byTime[byTime.length ~/ 2].microseconds)}');
  _write('  p95     ${_ms(byTime[byTime.length * 95 ~/ 100].microseconds)}');
  _write('  worst   ${_ms(byTime.last.microseconds)} (${byTime.last.key})');
  _write('Attempts per puzzle:');
  _write('  mean    ${(totalAttempts / samples.length).toStringAsFixed(2)}');
  _write('  median  ${byAttempts[byAttempts.length ~/ 2].attempts}');
  _write('  p95     ${byAttempts[byAttempts.length * 95 ~/ 100].attempts}');
  _write('  worst   ${byAttempts.last.attempts} (${byAttempts.last.key})');
}

typedef _Sample = ({String key, int microseconds, int attempts});

int _mean(List<_Sample> samples) =>
    samples.fold(0, (sum, sample) => sum + sample.microseconds) ~/
    samples.length;

String _ms(int microseconds) =>
    '${(microseconds / 1000).toStringAsFixed(2)} ms';

void _write(String line) {
  // The script also runs compiled to JavaScript, which has no dart:io.
  // ignore: avoid_print
  print(line);
}
