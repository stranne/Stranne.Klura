import 'dart:convert';

import 'package:klura/puzzles/logjam/logic/logjam_board.dart';
import 'package:klura/puzzles/logjam/logic/logjam_generator.dart';
import 'package:klura/puzzles/logjam/logic/logjam_save.dart';
import 'package:klura/puzzles/logjam/logic/logjam_text.dart';
import 'package:test/test.dart';

void main() {
  final date = DateTime(2026, 11, 12);

  // Solved in two moves: B down 1, then the marked log right 1.
  final puzzle = parseLogjam('''
A...
A**B>
...B
CC..
''');

  final smallSave = LogjamSave(
    level: LogjamLevel.normal,
    date: date,
    seedKey: 'logjam-normal:v1:2026-11-12',
    puzzle: puzzle,
    fewestMoves: 2,
    moves: const [LogjamMove(piece: 3, to: 1), LogjamMove(piece: 2, to: 2)],
    bestMoves: 3,
    playedTime: const Duration(minutes: 4, seconds: 12, milliseconds: 345),
    wasSolved: true,
  );

  /// The JSON of [smallSave] after [edit], as stored text.
  String edited(void Function(Map<String, Object?> json) edit) {
    final json =
        jsonDecode(encodeLogjamSave(smallSave)) as Map<String, Object?>;
    edit(json);
    return jsonEncode(json);
  }

  Map<String, Object?> puzzleOf(Map<String, Object?> json) =>
      json['puzzle']! as Map<String, Object?>;

  group('LogjamSave', () {
    test('keeps only the calendar date', () {
      final save = LogjamSave(
        level: LogjamLevel.hard,
        date: DateTime(2026, 11, 12, 18, 30),
        seedKey: 'test',
        puzzle: puzzle,
        fewestMoves: 2,
      );

      expect(save.date, date);
      expect(save.moves, isEmpty);
      expect(save.bestMoves, isNull);
      expect(save.playedTime, Duration.zero);
      expect(save.wasSolved, isFalse);
    });

    test('rejects a move through another log', () {
      expect(
        () => LogjamSave(
          level: LogjamLevel.normal,
          date: date,
          seedKey: 'test',
          puzzle: puzzle,
          fewestMoves: 2,
          moves: const [LogjamMove(piece: 0, to: 2)],
        ),
        throwsArgumentError,
      );
    });

    test('rejects a best below the fewest moves', () {
      expect(
        () => LogjamSave(
          level: LogjamLevel.normal,
          date: date,
          seedKey: 'test',
          puzzle: puzzle,
          fewestMoves: 2,
          bestMoves: 1,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a negative time or count', () {
      expect(
        () => LogjamSave(
          level: LogjamLevel.normal,
          date: date,
          seedKey: 'test',
          puzzle: puzzle,
          fewestMoves: 2,
          playedTime: const Duration(seconds: -1),
        ),
        throwsArgumentError,
      );
      expect(
        () => LogjamSave(
          level: LogjamLevel.normal,
          date: date,
          seedKey: 'test',
          puzzle: puzzle,
          fewestMoves: -1,
        ),
        throwsArgumentError,
      );
    });

    test('equals a save with the same moves', () {
      final copy = decodeLogjamSave(encodeLogjamSave(smallSave));

      expect(copy, smallSave);
      expect(copy.hashCode, smallSave.hashCode);
    });
  });

  group('encodeLogjamSave', () {
    test('writes the logs, the moves and the best solve', () {
      final json =
          jsonDecode(encodeLogjamSave(smallSave)) as Map<String, Object?>;

      expect(json, {
        'format': logjamSaveFormat,
        'level': 'normal',
        'date': '2026-11-12',
        'seedKey': 'logjam-normal:v1:2026-11-12',
        'puzzle': {
          'width': 4,
          'height': 4,
          'logs': [
            [1, 1, 2, 'row'],
            [0, 0, 2, 'column'],
            [3, 1, 2, 'column'],
            [0, 3, 2, 'row'],
          ],
        },
        'fewestMoves': 2,
        'moves': [
          [3, 1],
          [2, 2],
        ],
        'bestMoves': 3,
        'playedMs': 252345,
        'solved': true,
      });
    });
  });

  group('decodeLogjamSave', () {
    test('reads what encodeLogjamSave writes', () {
      expect(decodeLogjamSave(encodeLogjamSave(smallSave)), smallSave);
    });

    test('reads a game without a solve', () {
      final save = decodeLogjamSave(
        edited((json) {
          json['bestMoves'] = null;
          json['solved'] = false;
        }),
      );

      expect(save?.bestMoves, isNull);
      expect(save?.wasSolved, isFalse);
    });

    test('rejects text that is not a save', () {
      expect(decodeLogjamSave('not json'), isNull);
      expect(decodeLogjamSave('[]'), isNull);
      expect(decodeLogjamSave('{}'), isNull);
    });

    test('rejects another format version', () {
      expect(
        decodeLogjamSave(edited((json) => json['format'] = 2)),
        isNull,
      );
    });

    test('rejects an unknown level, date or missing field', () {
      expect(
        decodeLogjamSave(edited((json) => json['level'] = 'easy')),
        isNull,
      );
      expect(
        decodeLogjamSave(edited((json) => json['date'] = '2026-13-01')),
        isNull,
      );
      expect(decodeLogjamSave(edited((json) => json.remove('moves'))), isNull);
      expect(
        decodeLogjamSave(edited((json) => json.remove('bestMoves'))),
        isNull,
      );
    });

    test('rejects a malformed log or move', () {
      expect(
        decodeLogjamSave(
          edited(
            (json) => puzzleOf(json)['logs'] = [
              [1, 1, 2, 'diagonal'],
            ],
          ),
        ),
        isNull,
      );
      expect(
        decodeLogjamSave(
          edited(
            (json) => json['moves'] = [
              [3, '1'],
            ],
          ),
        ),
        isNull,
      );
    });

    test('rejects logs that break the rules of the board', () {
      expect(
        decodeLogjamSave(
          edited(
            (json) => puzzleOf(json)['logs'] = [
              [1, 1, 2, 'row'],
              [2, 0, 2, 'column'],
            ],
          ),
        ),
        isNull,
      );
      expect(
        decodeLogjamSave(
          edited(
            (json) => puzzleOf(json)['logs'] = [
              [0, 0, 2, 'column'],
            ],
          ),
        ),
        isNull,
      );
    });

    test('rejects a move that is not legal where it is played', () {
      expect(
        decodeLogjamSave(
          edited(
            (json) => json['moves'] = [
              [0, 2],
            ],
          ),
        ),
        isNull,
      );
    });

    test('rejects a negative time or a best below the fewest moves', () {
      expect(
        decodeLogjamSave(edited((json) => json['playedMs'] = -1)),
        isNull,
      );
      expect(
        decodeLogjamSave(edited((json) => json['bestMoves'] = 1)),
        isNull,
      );
    });
  });
}
