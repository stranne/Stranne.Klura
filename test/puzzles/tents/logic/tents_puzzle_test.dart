import 'package:klura/core/grid.dart';
import 'package:klura/puzzles/tents/logic/tents_puzzle.dart';
import 'package:test/test.dart';

void main() {
  TentsPuzzle puzzle({
    int width = 4,
    int height = 3,
    List<Position> trees = const [Position(2, 2), Position(1, 0)],
    List<int> rowTents = const [1, 0, 1],
    List<int> columnTents = const [1, 0, 0, 1],
  }) => TentsPuzzle(
    width: width,
    height: height,
    trees: trees,
    rowTents: rowTents,
    columnTents: columnTents,
  );

  test('keeps the trees in reading order', () {
    expect(puzzle().trees, const [Position(1, 0), Position(2, 2)]);
    expect(puzzle().tentCount, 2);
  });

  test('knows the trees beside a cell and where a tent may stand', () {
    final board = puzzle();

    expect(board.hasTree(const Position(1, 0)), isTrue);
    expect(board.treesBeside(const Position(2, 1)), const [Position(2, 2)]);
    expect(board.treesBeside(const Position(1, 1)), const [Position(1, 0)]);
    expect(board.treesBeside(const Position(3, 0)), isEmpty);
    expect(board.canHoldTent(const Position(0, 0)), isTrue);
    expect(board.canHoldTent(const Position(1, 0)), isFalse);
    expect(board.canHoldTent(const Position(3, 0)), isFalse);
    expect(board.canHoldTent(const Position(-1, 0)), isFalse);
  });

  test('equals a puzzle with the same trees and numbers', () {
    final reordered = puzzle(trees: const [Position(1, 0), Position(2, 2)]);

    expect(reordered, puzzle());
    expect(reordered.hashCode, puzzle().hashCode);
    expect(
      puzzle(rowTents: const [0, 1, 1]),
      isNot(puzzle()),
    );
  });

  group('rejects', () {
    final cases = {
      'an empty grid': () => puzzle(width: 0, columnTents: const []),
      'a tree outside the grid': () => puzzle(
        trees: const [Position(4, 0), Position(1, 0)],
      ),
      'two trees in one cell': () => puzzle(
        trees: const [Position(1, 0), Position(1, 0)],
      ),
      'a missing row number': () => puzzle(rowTents: const [1, 1]),
      'an extra column number': () => puzzle(
        columnTents: const [1, 0, 0, 1, 0],
      ),
      'more tents than a row can hold': () => puzzle(
        width: 3,
        trees: const [Position(1, 1), Position(1, 2), Position(2, 2)],
        rowTents: const [3, 0, 0],
        columnTents: const [1, 1, 1],
      ),
      'a negative number': () => puzzle(rowTents: const [3, -1, 0]),
      'numbers that do not give each tree a tent': () => puzzle(
        rowTents: const [1, 1, 1],
        columnTents: const [1, 1, 0, 1],
      ),
      'rows and columns that disagree': () => puzzle(
        columnTents: const [1, 0, 0, 0],
      ),
    };

    for (final MapEntry(key: description, value: create) in cases.entries) {
      test(description, () {
        expect(create, throwsArgumentError);
      });
    }
  });
}
