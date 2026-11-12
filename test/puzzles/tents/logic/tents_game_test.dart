import 'package:klura/core/grid.dart';
import 'package:klura/puzzles/tents/logic/tents_game.dart';
import 'package:klura/puzzles/tents/logic/tents_marks.dart';
import 'package:klura/puzzles/tents/logic/tents_text.dart';
import 'package:test/test.dart';

TentsGame gameOf(String board) {
  final (puzzle, marks) = parseTents(board);
  return TentsGame(puzzle, marks);
}

String boardOf(TentsGame game) => formatTents(game.puzzle, game.marks);

void main() {
  // Two trees in one column, each with a tent to its right.
  const start = '''
  0002
1 ..T.
0 ....
1 ..T.
''';

  test('starts blank with nothing to undo or clear', () {
    final game = gameOf(start);

    expect(game.isBlank, isTrue);
    expect(game.canUndo, isFalse);
    expect(game.canReset, isFalse);
    expect(game.isSolved, isFalse);
  });

  test('cycles a cell through grass, a tent and empty', () {
    const cell = Position(3, 0);
    final game = gameOf(start);

    final grass = game.cycleMark(cell);
    final tent = grass.cycleMark(cell);
    final empty = tent.cycleMark(cell);

    expect(game.nextMark(cell), TentsMark.grass);
    expect(grass.marks[cell], TentsMark.grass);
    expect(grass.nextMark(cell), TentsMark.tent);
    expect(tent.marks[cell], TentsMark.tent);
    expect(tent.nextMark(cell), isNull);
    expect(empty.marks[cell], isNull);
    expect(empty.canUndo, isTrue);
  });

  test('rejects a cycle on a tree or off the board', () {
    final game = gameOf(start);

    expect(() => game.cycleMark(const Position(2, 0)), throwsArgumentError);
    expect(() => game.cycleMark(const Position(4, 0)), throwsArgumentError);
  });

  test('fills the empty cells of a line with grass as one move', () {
    final game = gameOf('''
  0002
1 ..T^
0 ....
1 ..T.
''');
    final row = [for (var x = 0; x < 4; x++) Position(x, 0)];

    final filled = game.fillGrass(row);

    expect(game.fillableCells(row), const [Position(0, 0), Position(1, 0)]);
    expect(boardOf(filled), '''
  0002
1 --T^
0 ....
1 ..T.
''');
    expect(filled.undo(), same(game));
    expect(filled.fillGrass(row), same(filled));
  });

  test('clears the grass of a line as one move', () {
    final game = gameOf('''
  0002
1 --T^
0 -...
1 ..T.
''');
    final row = [for (var x = 0; x < 4; x++) Position(x, 0)];

    final cleared = game.clearGrass(row);

    expect(game.grassCells(row), const [Position(0, 0), Position(1, 0)]);
    expect(boardOf(cleared), '''
  0002
1 ..T^
0 -...
1 ..T.
''');
    expect(cleared.clearGrass(row), same(cleared));
  });

  test('rejects grass off the board', () {
    final game = gameOf(start);

    expect(
      () => game.fillGrass(const [Position(0, 0), Position(0, 3)]),
      throwsArgumentError,
    );
  });

  test('undoes moves one at a time back to the start', () {
    final game = gameOf(start);

    final moved = game
        .cycleMark(const Position(3, 0))
        .cycleMark(const Position(3, 0))
        .fillGrass(const [Position(0, 1), Position(1, 1)]);

    expect(moved.undo().undo().undo(), same(game));
    expect(game.undo(), same(game));
  });

  test('takes no more moves once solved', () {
    final game = gameOf('''
  0002
1 ..T^
0 ....
1 ..T^
''');

    expect(game.isSolved, isTrue);
    expect(game.cycleMark(const Position(0, 0)), same(game));
    expect(game.fillGrass(const [Position(0, 1)]), same(game));
    expect(game.canUndo, isFalse);
  });

  test('starts over as a move that undo takes back', () {
    final solved = gameOf(start)
        .cycleMark(const Position(3, 0))
        .cycleMark(const Position(3, 0))
        .cycleMark(const Position(3, 2))
        .cycleMark(const Position(3, 2));

    final reset = solved.reset();

    expect(solved.isSolved, isTrue);
    expect(reset.isBlank, isTrue);
    expect(reset.canUndo, isTrue);
    expect(reset.undo(), same(solved));
    expect(reset.reset(), same(reset));
  });
}
