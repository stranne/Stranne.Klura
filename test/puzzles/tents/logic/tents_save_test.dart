import 'dart:convert';

import 'package:klura/core/grid.dart';
import 'package:klura/puzzles/tents/logic/tents_generator.dart';
import 'package:klura/puzzles/tents/logic/tents_marks.dart';
import 'package:klura/puzzles/tents/logic/tents_save.dart';
import 'package:klura/puzzles/tents/logic/tents_text.dart';
import 'package:test/test.dart';

void main() {
  final date = DateTime(2026, 11, 12);

  // Solved by a tent to the right of each tree; here the top one has its
  // tent and the left column is grass.
  final (puzzle, marks) = parseTents('''
  0002
1 -.T^
0 -...
1 -.T.
''');

  final smallSave = TentsSave(
    level: TentsLevel.normal,
    date: date,
    seedKey: 'tents-normal:v1:2026-11-12',
    puzzle: puzzle,
    marks: marks,
    playedTime: const Duration(minutes: 4, seconds: 12, milliseconds: 345),
  );

  /// The JSON of [smallSave] after [edit], as stored text.
  String edited(void Function(Map<String, Object?> json) edit) {
    final json = jsonDecode(encodeTentsSave(smallSave)) as Map<String, Object?>;
    edit(json);
    return jsonEncode(json);
  }

  Map<String, Object?> puzzleOf(Map<String, Object?> json) =>
      json['puzzle']! as Map<String, Object?>;

  group('TentsSave', () {
    test('keeps only the calendar date', () {
      final save = TentsSave(
        level: TentsLevel.hard,
        date: DateTime(2026, 11, 12, 18, 30),
        seedKey: 'test',
        puzzle: puzzle,
        marks: const TentsMarks.empty(),
      );

      expect(save.date, date);
      expect(save.playedTime, Duration.zero);
      expect(save.wasSolved, isFalse);
    });

    test('rejects a mark on a tree', () {
      expect(
        () => TentsSave(
          level: TentsLevel.normal,
          date: date,
          seedKey: 'test',
          puzzle: puzzle,
          marks: TentsMarks({const Position(2, 0): TentsMark.tent}),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a negative time', () {
      expect(
        () => TentsSave(
          level: TentsLevel.normal,
          date: date,
          seedKey: 'test',
          puzzle: puzzle,
          marks: marks,
          playedTime: const Duration(seconds: -1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('save format', () {
    test('writes explicit JSON', () {
      expect(jsonDecode(encodeTentsSave(smallSave)), {
        'format': 1,
        'level': 'normal',
        'date': '2026-11-12',
        'seedKey': 'tents-normal:v1:2026-11-12',
        'puzzle': {
          'width': 4,
          'height': 3,
          'trees': [
            [2, 0],
            [2, 2],
          ],
          'rows': [1, 0, 1],
          'columns': [0, 0, 0, 2],
        },
        'tents': [
          [3, 0],
        ],
        'grass': [
          [0, 0],
          [0, 1],
          [0, 2],
        ],
        'playedMs': 252345,
        'solved': false,
      });
    });

    test('reads back what it writes', () {
      final solved = TentsSave(
        level: TentsLevel.hard,
        date: date,
        seedKey: 'test',
        puzzle: puzzle,
        marks: const TentsMarks.empty(),
        playedTime: const Duration(seconds: 3),
        wasSolved: true,
      );

      for (final save in [smallSave, solved]) {
        expect(decodeTentsSave(encodeTentsSave(save)), save);
      }
    });

    test('reads a generated daily puzzle back unchanged', () {
      final generated = generateDailyTents(TentsLevel.hard, date);
      final save = TentsSave(
        level: TentsLevel.hard,
        date: date,
        seedKey: generated.seedKey,
        puzzle: generated.puzzle,
        marks: generated.solution,
      );

      expect(decodeTentsSave(encodeTentsSave(save)), save);
    });

    test('ignores fields it does not know', () {
      final text = edited((json) => json['note'] = 'from a later version');

      expect(decodeTentsSave(text), smallSave);
    });

    group('reads as missing', () {
      final cases = <String, String Function()>{
        'text that is not JSON': () => '{"format": 1',
        'another format version': () => edited((json) => json['format'] = 2),
        'an unknown level': () => edited((json) => json['level'] = 'easy'),
        'a date that does not exist': () =>
            edited((json) => json['date'] = '2026-02-30'),
        'a missing field': () => edited((json) => json.remove('grass')),
        'a negative time': () => edited((json) => json['playedMs'] = -1),
        'an enormous grid': () =>
            edited((json) => puzzleOf(json)['width'] = 41),
        'a malformed cell': () => edited(
          (json) => json['tents'] = [
            [3, 0, 1],
          ],
        ),
        'a cell named twice': () => edited(
          (json) => json['tents'] = [
            [3, 0],
            [3, 0],
          ],
        ),
        'a cell with a tent and grass': () => edited(
          (json) => json['grass'] = [
            [3, 0],
          ],
        ),
        'a number that is not a whole number': () =>
            edited((json) => puzzleOf(json)['rows'] = [1, 0, '1']),
        'numbers that do not add up': () =>
            edited((json) => puzzleOf(json)['rows'] = [1, 1, 1]),
        'a tent on a tree': () => edited(
          (json) => json['tents'] = [
            [2, 0],
          ],
        ),
        'a tree off the board': () => edited(
          (json) => puzzleOf(json)['trees'] = [
            [2, 0],
            [4, 2],
          ],
        ),
      };

      for (final MapEntry(key: description, value: text) in cases.entries) {
        test(description, () {
          expect(decodeTentsSave(text()), isNull);
        });
      }
    });
  });
}
