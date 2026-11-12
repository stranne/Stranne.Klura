import 'dart:convert';

import 'package:klura/puzzles/bridges/logic/bridge_arrangement.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
import 'package:klura/puzzles/bridges/logic/bridges_save.dart';
import 'package:klura/puzzles/bridges/logic/bridges_text.dart';
import 'package:klura/puzzles/bridges/logic/geometry.dart';
import 'package:test/test.dart';

void main() {
  final date = DateTime(2026, 11, 12);

  // Solved by a double bridge along the top and a single one down the left;
  // here only the top has its bridges.
  final small = parseBridges('''
3=2
...
1..
''');
  final top = Connection(const Position(0, 0), const Position(2, 0));
  final left = Connection(const Position(0, 0), const Position(0, 2));

  final smallSave = BridgesSave(
    level: BridgesLevel.normal,
    date: date,
    seedKey: 'bridges-normal:v2:2026-11-12',
    puzzle: small.puzzle,
    arrangement: small.arrangement,
    playedTime: const Duration(minutes: 4, seconds: 12, milliseconds: 345),
  );

  /// The JSON of [smallSave] after [edit], as stored text.
  String edited(void Function(Map<String, Object?> json) edit) {
    final json =
        jsonDecode(encodeBridgesSave(smallSave)) as Map<String, Object?>;
    edit(json);
    return jsonEncode(json);
  }

  Map<String, Object?> puzzleOf(Map<String, Object?> json) =>
      json['puzzle']! as Map<String, Object?>;

  group('BridgesSave', () {
    test('keeps only the calendar date', () {
      final save = BridgesSave(
        level: BridgesLevel.hard,
        date: DateTime(2026, 11, 12, 18, 30),
        seedKey: 'test',
        puzzle: small.puzzle,
        arrangement: const BridgeArrangement.empty(),
      );

      expect(save.date, date);
      expect(save.playedTime, Duration.zero);
      expect(save.wasSolved, isFalse);
    });

    test('rejects bridges the puzzle does not offer', () {
      expect(
        () => BridgesSave(
          level: BridgesLevel.normal,
          date: date,
          seedKey: 'test',
          puzzle: small.puzzle,
          arrangement: BridgeArrangement({
            Connection(const Position(2, 0), const Position(0, 2)): 1,
          }),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a negative time', () {
      expect(
        () => BridgesSave(
          level: BridgesLevel.normal,
          date: date,
          seedKey: 'test',
          puzzle: small.puzzle,
          arrangement: small.arrangement,
          playedTime: const Duration(seconds: -1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('encodeBridgesSave', () {
    test('writes explicit JSON in format 1', () {
      expect(jsonDecode(encodeBridgesSave(smallSave)), {
        'format': 1,
        'level': 'normal',
        'date': '2026-11-12',
        'seedKey': 'bridges-normal:v2:2026-11-12',
        'puzzle': {
          'width': 3,
          'height': 3,
          'islands': [
            [0, 0, 3],
            [2, 0, 2],
            [0, 2, 1],
          ],
        },
        'bridges': [
          [0, 0, 2, 0, 2],
        ],
        'playedMs': 252345,
        'solved': false,
      });
    });
  });

  group('decodeBridgesSave', () {
    test('reads back a saved game', () {
      expect(decodeBridgesSave(encodeBridgesSave(smallSave)), smallSave);
    });

    test('reads back a solved game', () {
      final solved = BridgesSave(
        level: BridgesLevel.normal,
        date: date,
        seedKey: 'test',
        puzzle: small.puzzle,
        arrangement: BridgeArrangement({top: 2, left: 1}),
        playedTime: const Duration(seconds: 95),
        wasSolved: true,
      );

      expect(decodeBridgesSave(encodeBridgesSave(solved)), solved);
    });

    for (final level in BridgesLevel.values) {
      test('reads back the daily ${level.name} puzzle and its solution', () {
        final generated = generateDailyBridges(level, date);
        final save = BridgesSave(
          level: level,
          date: date,
          seedKey: generated.seedKey,
          puzzle: generated.puzzle,
          arrangement: generated.solution,
          playedTime: const Duration(hours: 1, milliseconds: 1),
          wasSolved: true,
        );

        final text = encodeBridgesSave(save);

        expect(decodeBridgesSave(text), save);
        // Small enough to keep a week of games in a corner of the storage.
        expect(text.length, lessThan(1200));
      });
    }

    final versions = <String, Object?>{
      'format 0': 0,
      'format 2': 2,
      'a format in text': '1',
      'a fractional format': 1.5,
      'no format': null,
    };

    for (final MapEntry(key: description, value: format) in versions.entries) {
      test('reads $description as missing', () {
        final text = edited((json) {
          if (format == null) {
            json.remove('format');
          } else {
            json['format'] = format;
          }
        });

        expect(decodeBridgesSave(text), isNull);
      });
    }

    final damaged = <String, String>{
      'empty text': '',
      'text that is not JSON': 'not a save',
      'cut-off JSON': encodeBridgesSave(smallSave).substring(0, 40),
      'a JSON list': '[1, 2, 3]',
      'JSON null': 'null',
      'an unknown level': edited((json) => json['level'] = 'easy'),
      'a date in another form': edited((json) => json['date'] = '12/11/2026'),
      'a date that does not exist': edited(
        (json) => json['date'] = '2026-02-30',
      ),
      'a seed key that is not text': edited((json) => json['seedKey'] = 7),
      'no puzzle': edited((json) => json.remove('puzzle')),
      'no bridges': edited((json) => json.remove('bridges')),
      'no time': edited((json) => json.remove('playedMs')),
      'no solved flag': edited((json) => json.remove('solved')),
      'a solved flag that is not a boolean': edited(
        (json) => json['solved'] = 'yes',
      ),
      'a negative time': edited((json) => json['playedMs'] = -1),
      'a fractional time': edited((json) => json['playedMs'] = 1.5),
      'an empty grid': edited((json) => puzzleOf(json)['width'] = 0),
      'an enormous grid': edited((json) => puzzleOf(json)['height'] = 100000),
      'islands that are not a list': edited(
        (json) => puzzleOf(json)['islands'] = {'0': 3},
      ),
      'an island with two numbers': edited(
        (json) => puzzleOf(json)['islands'] = [
          [0, 0],
        ],
      ),
      'an island with text': edited(
        (json) => puzzleOf(json)['islands'] = [
          ['0', 0, 1],
        ],
      ),
      'an island outside the grid': edited(
        (json) => puzzleOf(json)['islands'] = [
          [3, 0, 1],
        ],
      ),
      'islands side by side': edited(
        (json) => puzzleOf(json)['islands'] = [
          [0, 0, 1],
          [1, 0, 1],
        ],
      ),
      'an island that needs nine bridges': edited(
        (json) => puzzleOf(json)['islands'] = [
          [0, 0, 9],
        ],
      ),
      'a bridge the puzzle does not offer': edited(
        (json) => json['bridges'] = [
          [2, 0, 0, 2, 1],
        ],
      ),
      'a diagonal bridge': edited(
        (json) => json['bridges'] = [
          [0, 0, 2, 2, 1],
        ],
      ),
      'three bridges on one connection': edited(
        (json) => json['bridges'] = [
          [0, 0, 2, 0, 3],
        ],
      ),
      'a connection with no bridges listed': edited(
        (json) => json['bridges'] = [
          [0, 0, 2, 0, 0],
        ],
      ),
      'a connection listed twice': edited(
        (json) => json['bridges'] = [
          [0, 0, 2, 0, 1],
          [2, 0, 0, 0, 1],
        ],
      ),
      'a bridge with four numbers': edited(
        (json) => json['bridges'] = [
          [0, 0, 2, 0],
        ],
      ),
    };

    for (final MapEntry(key: description, value: text) in damaged.entries) {
      test('reads a save with $description as missing', () {
        expect(decodeBridgesSave(text), isNull);
      });
    }

    test('ignores fields it does not know', () {
      final text = edited((json) => json['note'] = 'from a later version');

      expect(decodeBridgesSave(text), smallSave);
    });
  });

  group('BridgesHistory', () {
    final earlier = DateTime(2026, 11, 10);

    test('keeps the first solve of each puzzle', () {
      final history = const BridgesHistory.empty()
          .withSolve(BridgesLevel.normal, date, const Duration(seconds: 90))
          .withSolve(BridgesLevel.hard, earlier, const Duration(minutes: 9));

      final again = history.withSolve(
        BridgesLevel.normal,
        DateTime(2026, 11, 12, 20),
        const Duration(seconds: 30),
      );

      expect(again, same(history));
      expect(
        history.solveTime(BridgesLevel.normal, date),
        const Duration(seconds: 90),
      );
      expect(history.solveTime(BridgesLevel.hard, date), isNull);
      expect(history.solvedDays, {date, earlier});
    });

    test('is written as explicit JSON and read back', () {
      final history = const BridgesHistory.empty()
          .withSolve(BridgesLevel.normal, date, const Duration(seconds: 90))
          .withSolve(BridgesLevel.normal, earlier, const Duration(seconds: 70))
          .withSolve(BridgesLevel.hard, date, const Duration(minutes: 9));

      final text = encodeBridgesHistory(history);
      final read = decodeBridgesHistory(text)!;

      expect(jsonDecode(text), {
        'format': 1,
        'solved': {
          'normal': {'2026-11-10': 70000, '2026-11-12': 90000},
          'hard': {'2026-11-12': 540000},
        },
      });
      expect(read.solvedDays, {date, earlier});
      expect(
        read.solveTime(BridgesLevel.hard, date),
        const Duration(minutes: 9),
      );
      expect(encodeBridgesHistory(read), text);
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
        expect(decodeBridgesHistory(text), isNull, reason: text);
      }
    });

    test('skips damaged entries and keeps the rest', () {
      final history = decodeBridgesHistory('''
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
''')!;

      expect(history.solvedDays, {date});
      expect(
        history.solveTime(BridgesLevel.normal, date),
        const Duration(seconds: 90),
      );
    });
  });
}
