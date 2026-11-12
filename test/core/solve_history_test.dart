import 'dart:convert';

import 'package:klura/core/solve_history.dart';
import 'package:test/test.dart';

enum _Level { normal, hard }

void main() {
  final date = DateTime(2026, 11, 12);
  final earlier = DateTime(2026, 11, 10);

  test('keeps the first solve of each puzzle', () {
    final history = const SolveHistory<_Level>.empty()
        .withSolve(_Level.normal, date, const Duration(seconds: 90))
        .withSolve(_Level.hard, earlier, const Duration(minutes: 9));

    final again = history.withSolve(
      _Level.normal,
      DateTime(2026, 11, 12, 20),
      const Duration(seconds: 30),
    );

    expect(again, same(history));
    expect(history.solveTime(_Level.normal, date), const Duration(seconds: 90));
    expect(history.solveTime(_Level.hard, earlier), const Duration(minutes: 9));
    expect(history.solveTime(_Level.hard, date), isNull);
  });

  test('is written as explicit JSON and read back', () {
    final history = const SolveHistory<_Level>.empty()
        .withSolve(_Level.normal, date, const Duration(seconds: 90))
        .withSolve(_Level.normal, earlier, const Duration(seconds: 70))
        .withSolve(_Level.hard, date, const Duration(minutes: 9));

    final text = encodeSolveHistory(history, _Level.values);
    final read = decodeSolveHistory(text, _Level.values)!;

    expect(jsonDecode(text), {
      'format': 1,
      'solved': {
        'normal': {'2026-11-10': 70000, '2026-11-12': 90000},
        'hard': {'2026-11-12': 540000},
      },
    });
    expect(read.solveTime(_Level.normal, earlier), const Duration(seconds: 70));
    expect(read.solveTime(_Level.hard, date), const Duration(minutes: 9));
    expect(encodeSolveHistory(read, _Level.values), text);
  });

  test('is read as missing when damaged or of another format', () {
    final unreadable = [
      '',
      '{"format": 1',
      '[]',
      '{"format": 2, "solved": {}}',
      '{"solved": {}}',
      '{"format": 1, "solved": []}',
    ];

    for (final text in unreadable) {
      expect(decodeSolveHistory(text, _Level.values), isNull, reason: text);
    }
  });

  test('skips damaged entries and keeps the rest', () {
    final history = decodeSolveHistory('''
{
  "format": 1,
  "solved": {
    "normal": {
      "2026-11-12": 90000,
      "2026-02-30": 1000,
      "yesterday": 1000,
      "2026-11-11": -5,
      "2026-11-10": "fast"
    },
    "hard": [1, 2],
    "easy": {"2026-11-09": 1000}
  }
}
''', _Level.values)!;

    expect(
      encodeSolveHistory(history, _Level.values),
      '{"format":1,"solved":{"normal":{"2026-11-12":90000}}}',
    );
  });
}
