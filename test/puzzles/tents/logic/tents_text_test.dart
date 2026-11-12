import 'package:klura/core/grid.dart';
import 'package:klura/puzzles/tents/logic/tents_marks.dart';
import 'package:klura/puzzles/tents/logic/tents_puzzle.dart';
import 'package:klura/puzzles/tents/logic/tents_text.dart';
import 'package:test/test.dart';

void main() {
  const board = '''
  101
1 T^.
1 --T
''';

  test('reads trees, numbers and marks', () {
    final (puzzle, marks) = parseTents(board);

    expect(
      puzzle,
      TentsPuzzle(
        width: 3,
        height: 2,
        trees: const [Position(0, 0), Position(2, 1)],
        rowTents: const [1, 1],
        columnTents: const [1, 0, 1],
      ),
    );
    expect(
      marks,
      TentsMarks({
        const Position(1, 0): TentsMark.tent,
        const Position(0, 1): TentsMark.grass,
        const Position(1, 1): TentsMark.grass,
      }),
    );
  });

  test('writes what it reads', () {
    final (puzzle, marks) = parseTents(board);

    expect(formatTents(puzzle, marks), board);
  });

  test('draws a puzzle without marks', () {
    final (puzzle, _) = parseTents(board);

    expect(formatTents(puzzle), '''
  101
1 T..
1 ..T
''');
  });

  test('ignores blank lines around the board', () {
    expect(parseTents('\n\n$board\n\n'), parseTents(board));
  });

  group('rejects', () {
    final cases = {
      'a missing number line': '1 T.\n',
      'a number line without its spaces': '10\n1 T.\n',
      'a row without its number': '  10\nT.\n',
      'a row of the wrong length': '  10\n1 T..\n',
      'an unknown cell': '  10\n1 Tx\n',
      'a number that is not a digit': '  1a\n1 T.\n',
    };

    for (final MapEntry(key: description, value: text) in cases.entries) {
      test(description, () {
        expect(() => parseTents(text), throwsFormatException);
      });
    }

    test('a board that breaks a rule of the puzzle', () {
      expect(() => parseTents('  11\n1 T.\n'), throwsArgumentError);
    });

    test('a mark on a tree when writing', () {
      final (puzzle, _) = parseTents(board);
      final marks = TentsMarks({const Position(0, 0): TentsMark.tent});

      expect(() => formatTents(puzzle, marks), throwsArgumentError);
    });
  });
}
