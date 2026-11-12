import 'package:klura/core/grid.dart';
import 'package:klura/core/seeded_random.dart';
import 'package:klura/puzzles/tents/logic/tents_marks.dart';
import 'package:klura/puzzles/tents/logic/tents_puzzle.dart';
import 'package:klura/puzzles/tents/logic/tents_rules.dart';
import 'package:klura/puzzles/tents/logic/tents_solver.dart';
import 'package:klura/puzzles/tents/logic/tents_text.dart';
import 'package:test/test.dart';

TentsPuzzle puzzleOf(String board) => parseTents(board).$1;

TentsMarks marksOf(String board) => parseTents(board).$2;

void main() {
  test('finds the only solution of a unique puzzle', () {
    final puzzle = puzzleOf(_basicPuzzle);

    expect(solveTents(puzzle), [marksOf(_basicSolution)]);
  });

  test('finds both solutions of a puzzle with two', () {
    final puzzle = puzzleOf(_twoSolutions);

    final solutions = solveTents(puzzle);

    expect(solutions, hasLength(2));
    expect(
      solutions.map((solution) => formatTents(puzzle, solution)),
      unorderedEquals([
        '''
  0101
1 ..T^
0 ....
1 .^T.
''',
        '''
  0101
1 .^T.
0 ....
1 ..T^
''',
      ]),
    );
  });

  test('stops at the limit', () {
    expect(solveTents(puzzleOf(_twoSolutions), limit: 1), hasLength(1));
  });

  test('rejects a limit below one', () {
    expect(
      () => solveTents(puzzleOf(_basicPuzzle), limit: 0),
      throwsRangeError,
    );
  });

  test('finds no solution when the only fit has tents touching', () {
    // Each row needs its tent, and the two cells that could hold them touch.
    final puzzle = puzzleOf('''
  11
1 T.
1 .T
''');

    expect(solveTents(puzzle), isEmpty);
    expect(gradeTents(puzzle).reasoning, TentsReasoning.search);
  });

  test('agrees with the rules check on small random boards', () {
    final random = SeededRandom(2026);
    final countsSeen = <int>{};

    for (var board = 0; board < 400; board++) {
      final puzzle = _randomBoard(random, fromTents: board.isEven);
      final expected = _bruteForceSolutions(puzzle);

      final actual = solveTents(puzzle, limit: 1000);

      expect(
        actual.toSet(),
        expected.toSet(),
        reason: 'Solutions differ for\n${formatTents(puzzle)}',
      );
      expect(actual, hasLength(expected.length));
      countsSeen.add(expected.length.clamp(0, 2));
    }

    expect(countsSeen, {0, 1, 2}, reason: 'The boards should cover every case');
  });

  group('gradeTents', () {
    final cases = {
      'needs only basic reasoning when single rules settle every cell': (
        _basicPuzzle,
        TentsReasoning.basic,
      ),
      'needs advanced reasoning when rules must be combined': (
        _advancedPuzzle,
        TentsReasoning.advanced,
      ),
      'needs lookahead when only trying a cell rules it out': (
        _lookaheadPuzzle,
        TentsReasoning.lookahead,
      ),
      'needs search for a puzzle with two solutions': (
        _twoSolutions,
        TentsReasoning.search,
      ),
    };

    for (final MapEntry(key: description, value: (board, reasoning))
        in cases.entries) {
      test(description, () {
        expect(gradeTents(puzzleOf(board)).reasoning, reasoning);
      });
    }

    test('counts the cells basic reasoning leaves open', () {
      expect(gradeTents(puzzleOf(_basicPuzzle)).openAfterBasic, 0);
      expect(gradeTents(puzzleOf(_advancedPuzzle)).openAfterBasic, 11);
    });

    test('agrees with the solver that settled puzzles are unique', () {
      final random = SeededRandom(11);
      final reasoningsSeen = <TentsReasoning>{};

      for (var board = 0; board < 300; board++) {
        final puzzle = _randomBoard(random, fromTents: true);

        final result = gradeTents(puzzle);

        reasoningsSeen.add(result.reasoning);
        if (result.reasoning != TentsReasoning.search) {
          expect(
            solveTents(puzzle),
            hasLength(1),
            reason:
                'Graded ${result.reasoning.name} but not unique:\n'
                '${formatTents(puzzle)}',
          );
        }
      }

      expect(reasoningsSeen, containsAll(TentsReasoning.values));
    });
  });
}

/// A unique puzzle that single rules settle: full and empty lines, cells
/// away from the trees and beside tents, and trees with one free cell.
const String _basicPuzzle = '''
  110121
1 ......
1 ..T.TT
2 ..T...
1 ......
1 T....T
''';

const String _basicSolution = '''
  110121
1 ....^.
1 .^T.TT
2 ..T^.^
1 ^.....
1 T...^T
''';

/// A unique puzzle that needs advanced reasoning: how many tents fit in a
/// line's open stretches, or which tree a tent belongs to.
const String _advancedPuzzle = '''
  120111
1 ...T..
2 T.....
1 ..T.TT
1 ......
1 T.....
''';

/// A unique puzzle that needs a cell tried before it is settled.
const String _lookaheadPuzzle = '''
  111111
2 ..T.T.
1 ......
1 TT....
1 .T....
1 ....T.
''';

/// Two trees in one column, each with a tent to its left or right. The
/// numbers allow both mirror images.
const String _twoSolutions = '''
  0101
1 ..T.
0 ....
1 ..T.
''';

/// A random board of 5 by 4 cells with two to five trees. Its numbers come
/// either from random tents placed by the rules, which leaves one or more
/// solutions, or, unless [fromTents], from random counts that only add up,
/// which usually leaves none.
TentsPuzzle _randomBoard(SeededRandom random, {required bool fromTents}) {
  const width = 5;
  const height = 4;
  final tents = <Position>[];
  final trees = <Position>[];
  final treeCount = 2 + random.nextInt(4);
  for (var tries = 0; trees.length < treeCount && tries < 100; tries++) {
    final tent = Position(random.nextInt(width), random.nextInt(height));
    final tree = tent.step(Direction.values[random.nextInt(4)]);
    final fits =
        tree.isWithin(width, height) &&
        !trees.contains(tent) &&
        !trees.contains(tree) &&
        !tents.contains(tree) &&
        !tents.any((other) => other == tent || other.touches(tent));
    if (fits) {
      tents.add(tent);
      trees.add(tree);
    }
  }

  final rowTents = List.filled(height, 0);
  final columnTents = List.filled(width, 0);
  if (fromTents) {
    for (final tent in tents) {
      rowTents[tent.y]++;
      columnTents[tent.x]++;
    }
  } else {
    _scatter(rowTents, trees.length, (width + 1) ~/ 2, random);
    _scatter(columnTents, trees.length, (height + 1) ~/ 2, random);
  }
  return TentsPuzzle(
    width: width,
    height: height,
    trees: trees,
    rowTents: rowTents,
    columnTents: columnTents,
  );
}

/// Spreads [total] over [counts] at random, at most [most] each.
void _scatter(List<int> counts, int total, int most, SeededRandom random) {
  for (var placed = 0; placed < total;) {
    final index = random.nextInt(counts.length);
    if (counts[index] < most) {
      counts[index]++;
      placed++;
    }
  }
}

/// Every set of tents on [puzzle] that the rules check accepts, found by
/// trying every set of free cells beside a tree. Sets that put too many
/// tents in a line are skipped, since adding tents never fixes that.
List<TentsMarks> _bruteForceSolutions(TentsPuzzle puzzle) {
  final cells = [
    for (var y = 0; y < puzzle.height; y++)
      for (var x = 0; x < puzzle.width; x++)
        if (puzzle.canHoldTent(Position(x, y))) Position(x, y),
  ];
  final solutions = <TentsMarks>[];
  final rows = List.filled(puzzle.height, 0);
  final columns = List.filled(puzzle.width, 0);
  final chosen = <Position>[];

  void visit(int index) {
    if (index == cells.length) {
      final marks = TentsMarks({
        for (final tent in chosen) tent: TentsMark.tent,
      });
      if (checkTents(puzzle, marks).isSolved) {
        solutions.add(marks);
      }
      return;
    }
    visit(index + 1);
    final cell = cells[index];
    if (rows[cell.y] < puzzle.rowTents[cell.y] &&
        columns[cell.x] < puzzle.columnTents[cell.x]) {
      rows[cell.y]++;
      columns[cell.x]++;
      chosen.add(cell);
      visit(index + 1);
      chosen.removeLast();
      rows[cell.y]--;
      columns[cell.x]--;
    }
  }

  visit(0);
  return solutions;
}
