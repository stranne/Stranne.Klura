import 'package:klura/core/seeded_random.dart';
import 'package:klura/puzzles/logjam/logic/logjam_generator.dart';
import 'package:klura/puzzles/logjam/logic/logjam_text.dart';

/// Measures how long the daily Logjam puzzles of each level take to generate,
/// how many attempts they need and how many moves they take, for two years
/// from the first day Klura offers them.
///
/// Run on the VM:
///
/// ```sh
/// dart run tool/benchmark_logjam.dart [days]
/// ```
///
/// Run compiled to JavaScript under Node.js, as in a browser:
///
/// ```sh
/// dart compile js -O2 -o build/benchmark_logjam.js tool/benchmark_logjam.dart
/// node build/benchmark_logjam.js
/// ```
///
/// The first puzzle of each level is reported separately: a page load
/// generates a puzzle before the JavaScript engine has warmed up. The digest
/// covers the text of every puzzle, so equal digests on the VM, in
/// JavaScript and in WebAssembly mean equal puzzles.
///
/// With `survey [boards]` instead, the script shows how many moves random
/// boards need: for each of that many keys it keeps the first random board
/// with a solvable start, whatever its moves, and counts how far its
/// farthest position is from the exit.
void main(List<String> arguments) {
  if (arguments.isNotEmpty && arguments.first == 'survey') {
    _survey(arguments.length > 1 ? int.parse(arguments[1]) : 2000);
    return;
  }
  final days = arguments.isEmpty ? 731 : int.parse(arguments.first);
  for (final level in LogjamLevel.values) {
    _report(level, days);
  }
}

void _report(LogjamLevel level, int days) {
  final firstDate = DateTime.utc(2026, 11, 12);
  final samples = <_Sample>[];
  var digest = 0;
  for (var day = 0; day < days; day++) {
    final date = DateTime.utc(
      firstDate.year,
      firstDate.month,
      firstDate.day + day,
    );
    final stopwatch = Stopwatch()..start();
    final generated = generateDailyLogjam(level, date);
    stopwatch.stop();
    samples.add((
      key: generated.seedKey,
      microseconds: stopwatch.elapsedMicroseconds,
      attempts: generated.attempts,
      moves: generated.fewestMoves,
      positions: generated.positions,
    ));
    digest = SeededRandom.hashKey('$digest ${formatLogjam(generated.puzzle)}');
  }

  final warm = samples.skip(1).toList();
  final byTime = [...warm]
    ..sort((a, b) => a.microseconds.compareTo(b.microseconds));
  final byAttempts = [...samples]
    ..sort((a, b) => a.attempts.compareTo(b.attempts));
  final byPositions = [...samples]
    ..sort((a, b) => a.positions.compareTo(b.positions));
  final totalAttempts = samples.fold(0, (sum, sample) => sum + sample.attempts);

  _write('${level.name} puzzles: $days from ${samples.first.key}');
  _write('  ${level.config}');
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
  _write('Positions reachable from each puzzle:');
  _write('  median  ${byPositions[byPositions.length ~/ 2].positions}');
  _write('  worst   ${byPositions.last.positions}');
  _write('Fewest moves: ${_histogram(samples.map((sample) => sample.moves))}');
  _write('Digest: ${digest.toRadixString(16).padLeft(8, '0')}');
  _write('');
}

void _survey(int boards) {
  const config = LogjamConfig(minMoves: 1, maxMoves: 999);
  final moves = <int>[];
  var attempts = 0;
  final stopwatch = Stopwatch()..start();
  for (var index = 0; index < boards; index++) {
    final generated = generateLogjam('logjam-survey:$index', config);
    moves.add(generated.fewestMoves);
    attempts += generated.attempts;
  }
  stopwatch.stop();

  _write('Survey of $boards random boards with a solvable start');
  _write('  $config');
  _write(
    'Random boards per solvable one: '
    '${(attempts / boards).toStringAsFixed(2)}',
  );
  _write(
    'Time per random board: '
    '${_ms(stopwatch.elapsedMicroseconds ~/ attempts)}',
  );
  _write('Most moves in the cluster: ${_histogram(moves)}');
  _write('Share needing at least:');
  for (final least in [6, 8, 10, 12, 14, 16, 18, 20, 25, 30]) {
    final count = moves.where((value) => value >= least).length;
    _write(
      '  ${'$least'.padLeft(2)} moves  '
      '${(100 * count / boards).toStringAsFixed(2).padLeft(6)} %',
    );
  }
}

typedef _Sample = ({
  String key,
  int microseconds,
  int attempts,
  int moves,
  int positions,
});

int _mean(List<_Sample> samples) =>
    samples.fold(0, (sum, sample) => sum + sample.microseconds) ~/
    samples.length;

String _ms(int microseconds) =>
    '${(microseconds / 1000).toStringAsFixed(2)} ms';

/// Writes how often each value occurs, as `value×count`, in order.
String _histogram(Iterable<int> values) {
  final counts = <int, int>{};
  for (final value in values) {
    counts[value] = (counts[value] ?? 0) + 1;
  }
  final keys = counts.keys.toList()..sort();
  return [for (final key in keys) '$key×${counts[key]}'].join(' ');
}

void _write(String line) {
  // The script also runs compiled to JavaScript, which has no dart:io.
  // ignore: avoid_print
  print(line);
}
