import 'package:klura/puzzles/logjam/logic/logjam_board.dart';
import 'package:klura/puzzles/logjam/logic/logjam_game.dart';
import 'package:klura/puzzles/logjam/logic/logjam_text.dart';
import 'package:test/test.dart';

void main() {
  // Solved in two moves: B down 1, then the marked log right 1.
  final puzzle = parseLogjam('''
A...
A**B>
...B
CC..
''');
  const marked = 0;
  const a = 1;
  const b = 2;
  const c = 3;

  LogjamMove move(int piece, int to) => LogjamMove(piece: piece, to: to);

  test('starts blank, with nothing to undo or clear', () {
    final game = LogjamGame(puzzle);

    expect(game.board, puzzle);
    expect(game.moves, isEmpty);
    expect(game.isBlank, isTrue);
    expect(game.isSolved, isFalse);
    expect(game.canUndo, isFalse);
    expect(game.canReset, isFalse);
  });

  test('a slide moves the log and counts one move however far it goes', () {
    final game = LogjamGame(puzzle).slide(move(c, 2));

    expect(game.board.pieces[c], const LogjamPiece.horizontal(2, 3, 2));
    expect(game.moves, [move(c, 2)]);
    expect(game.isBlank, isFalse);
    expect(game.canUndo, isTrue);
    expect(game.canReset, isTrue);
  });

  test('slides of the same log in a row count as one move', () {
    final start = LogjamGame(puzzle);
    final game = start.slide(move(c, 1)).slide(move(c, 2));

    expect(game.moves, [move(c, 2)]);
    expect(game.undo(), same(start));
  });

  test('a log slid back to where its move began takes the move back', () {
    final start = LogjamGame(puzzle);
    final first = start.slide(move(a, 1));
    final second = first.slide(move(c, 2));

    expect(second.slide(move(c, 0)), same(first));
    expect(first.slide(move(a, 0)), same(start));
  });

  test('a slide of another log in between keeps the moves apart', () {
    final game = LogjamGame(
      puzzle,
    ).slide(move(c, 1)).slide(move(a, 1)).slide(move(c, 2));

    expect(game.moves, [move(c, 1), move(a, 1), move(c, 2)]);
    expect(game.undo().moves, [move(c, 1), move(a, 1)]);
  });

  test('a slide to where the log lies changes nothing', () {
    final game = LogjamGame(puzzle);

    expect(game.slide(move(c, 0)), same(game));
  });

  test('rejects a slide through another log or off the board', () {
    final game = LogjamGame(puzzle);

    expect(() => game.slide(move(marked, 2)), throwsArgumentError);
    expect(() => game.slide(move(c, 3)), throwsArgumentError);
    expect(() => game.slide(move(9, 1)), throwsArgumentError);
  });

  test('a solved game takes no moves and cannot be undone', () {
    final game = LogjamGame(puzzle).slide(move(b, 2)).slide(move(marked, 2));

    expect(game.isSolved, isTrue);
    expect(game.moves, hasLength(2));
    expect(game.canUndo, isFalse);
    expect(game.undo(), same(game));
    expect(game.slide(move(c, 2)), same(game));
  });

  test('starting over puts every log back, and undo brings the moves back', () {
    final solved = LogjamGame(
      puzzle,
    ).slide(move(b, 2)).slide(move(marked, 2));

    final reset = solved.reset();

    expect(reset.board, puzzle);
    expect(reset.moves, isEmpty);
    expect(reset.canReset, isFalse);
    expect(reset.reset(), same(reset));
    expect(reset.undo(), same(solved));
  });

  test('starting over counts the moves afresh', () {
    final game = LogjamGame(puzzle)
        .slide(move(c, 1))
        .reset()
        .slide(
          move(c, 2),
        );

    expect(game.moves, [move(c, 2)]);
  });

  group('playing saved moves', () {
    test('rebuilds the board and lets undo reach each move', () {
      final game = LogjamGame(puzzle, [move(c, 1), move(a, 1), move(b, 2)]);

      expect(game.moves, [move(c, 1), move(a, 1), move(b, 2)]);
      expect(game.board.pieces[b], const LogjamPiece.vertical(3, 2, 2));
      expect(game.undo().undo().undo().board, puzzle);
      expect(game.undo().undo().undo().canUndo, isFalse);
    });

    test('joins slides of the same log in a row', () {
      expect(LogjamGame(puzzle, [move(c, 1), move(c, 2)]).moves, [
        move(c, 2),
      ]);
    });

    test('rejects a move that is not legal where it is played', () {
      expect(() => LogjamGame(puzzle, [move(marked, 2)]), throwsArgumentError);
    });

    test('rejects a move after the solve', () {
      expect(
        () => LogjamGame(puzzle, [move(b, 2), move(marked, 2), move(c, 1)]),
        throwsArgumentError,
      );
    });
  });
}
