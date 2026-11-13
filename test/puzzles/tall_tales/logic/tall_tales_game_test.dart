import 'package:klura/puzzles/tall_tales/logic/tall_tales_game.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_marks.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_text.dart';
import 'package:test/test.dart';

void main() {
  // Solved by Alva telling the truth, and Bo and Cajsa tall tales.
  final (puzzle, _) = parseTallTales('''
Alva: Bo and I are not alike.
Bo: Cajsa tells the truth.
Cajsa: Alva tells tall tales.
''');

  test('starts blank with nothing to undo or clear', () {
    final game = TallTalesGame(puzzle);

    expect(game.isBlank, isTrue);
    expect(game.isSolved, isFalse);
    expect(game.canUndo, isFalse);
    expect(game.canReset, isFalse);
    expect(game.marks, TallTalesMarks.empty(3));
  });

  test('moves a fisher through the truth, tall tales and unmarked', () {
    final first = TallTalesGame(puzzle).cycleMark(1);
    final second = first.cycleMark(1);
    final third = second.cycleMark(1);

    expect(first.marks[1], TallTalesMark.truth);
    expect(second.marks[1], TallTalesMark.tallTales);
    expect(third.marks[1], isNull);
    expect(third.isBlank, isTrue);
    expect(third.canUndo, isTrue);
  });

  test('tells the next mark of each fisher', () {
    final game = TallTalesGame(
      puzzle,
      TallTalesMarks(const [
        TallTalesMark.truth,
        TallTalesMark.tallTales,
        null,
      ]),
    );

    expect(game.nextMark(0), TallTalesMark.tallTales);
    expect(game.nextMark(1), isNull);
    expect(game.nextMark(2), TallTalesMark.truth);
  });

  test('checks the marks after every move', () {
    final game = TallTalesGame(puzzle).cycleMark(0).cycleMark(1);

    expect(game.check.broken, [0]);
  });

  test('undoes moves one at a time back to the start', () {
    final start = TallTalesGame(puzzle);
    final game = start.cycleMark(0).cycleMark(2);

    final once = game.undo();
    final twice = once.undo();

    expect(once.marks, TallTalesMarks(const [TallTalesMark.truth, null, null]));
    expect(twice, same(start));
    expect(twice.undo(), same(start));
  });

  test('is solved once every statement fits, and then takes no moves', () {
    final solved = TallTalesGame(puzzle)
        .cycleMark(0)
        .cycleMark(1)
        .cycleMark(1)
        .cycleMark(2)
        .cycleMark(2);

    expect(solved.isSolved, isTrue);
    expect(solved.canUndo, isFalse);
    expect(solved.cycleMark(1), same(solved));
    expect(solved.undo(), same(solved));
  });

  test('starts over as a move that undo takes back', () {
    final game = TallTalesGame(puzzle).cycleMark(0).cycleMark(1);

    final reset = game.reset();

    expect(reset.isBlank, isTrue);
    expect(reset.canReset, isFalse);
    expect(reset.reset(), same(reset));
    expect(reset.undo(), same(game));
  });

  test('starts over after a solve', () {
    final solved = TallTalesGame(
      puzzle,
      TallTalesMarks(const [
        TallTalesMark.truth,
        TallTalesMark.tallTales,
        TallTalesMark.tallTales,
      ]),
    );

    expect(solved.isSolved, isTrue);
    expect(solved.reset().isBlank, isTrue);
  });

  test('rejects a fisher who is not on the jetty', () {
    final game = TallTalesGame(puzzle);

    expect(() => game.cycleMark(3), throwsRangeError);
    expect(() => game.cycleMark(-1), throwsRangeError);
  });

  test('rejects marks for another number of fishers', () {
    expect(
      () => TallTalesGame(puzzle, TallTalesMarks.empty(4)),
      throwsArgumentError,
    );
  });
}
