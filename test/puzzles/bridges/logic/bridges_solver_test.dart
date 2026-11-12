import 'package:klura/core/grid.dart';
import 'package:klura/core/seeded_random.dart';
import 'package:klura/puzzles/bridges/logic/bridge_arrangement.dart';
import 'package:klura/puzzles/bridges/logic/bridges_puzzle.dart';
import 'package:klura/puzzles/bridges/logic/bridges_rules.dart';
import 'package:klura/puzzles/bridges/logic/bridges_solver.dart';
import 'package:klura/puzzles/bridges/logic/bridges_text.dart';
import 'package:test/test.dart';

void main() {
  /// Solves the puzzle drawn in [board] and draws each solution found.
  Set<String> solve(String board, {int limit = 10}) {
    final (:puzzle, arrangement: _) = parseBridges(board);
    return {
      for (final solution in solveBridges(puzzle, limit: limit))
        formatBridges(puzzle, solution),
    };
  }

  test('finds the only solution of a unique puzzle', () {
    final solutions = solve('''
1.2
...
1.2
''');

    expect(solutions, {
      '''
1-2
..|
1-2
''',
    });
  });

  test('finds both solutions of a puzzle with two', () {
    final solutions = solve('''
2.4.1
.....
1.2..
''');

    expect(solutions, {
      '''
2=4-1
..|..
1-2..
''',
      '''
2-4-1
|.║..
1.2..
''',
    });
  });

  test('stops at the limit', () {
    final (:puzzle, arrangement: _) = parseBridges('2.4.1\n.....\n1.2..\n');

    expect(solveBridges(puzzle, limit: 1), hasLength(1));
  });

  test('rejects a limit below one', () {
    final (:puzzle, arrangement: _) = parseBridges('1.1');

    expect(() => solveBridges(puzzle, limit: 0), throwsRangeError);
  });

  group('finds no solution when the only fit breaks a rule', () {
    final cases = {
      'numbers that no bridges meet': '1.3',
      'a fit that leaves two groups': '''
1.1
...
1.1
''',
      'a fit that closes a loop': '''
2.2
...
2.2
''',
      'a fit with crossing bridges': '''
2.2..
.....
2...1
.....
..1..
''',
    };

    for (final MapEntry(key: description, value: board) in cases.entries) {
      test(description, () {
        expect(solve(board), isEmpty);
      });
    }
  });

  test('agrees with the rules check on small random boards', () {
    final random = SeededRandom(2026);
    final countsSeen = <int>{};

    for (var board = 0; board < 400; board++) {
      final puzzle = _randomBoard(random, fromTree: board.isEven);
      final expected = _bruteForceSolutions(puzzle);

      final actual = solveBridges(puzzle, limit: 1000);

      expect(
        actual.toSet(),
        expected.toSet(),
        reason: 'Solutions differ for\n${formatBridges(puzzle)}',
      );
      expect(actual, hasLength(expected.length));
      countsSeen.add(expected.length.clamp(0, 2));
    }

    expect(countsSeen, {0, 1, 2}, reason: 'The boards should cover every case');
  });

  group('gradeBridges', () {
    BridgesGrade grade(String board) {
      final (:puzzle, arrangement: _) = parseBridges(board);
      return gradeBridges(puzzle);
    }

    test('needs only basic moves when island numbers settle every bridge', () {
      final result = grade('''
3.2
...
1..
''');

      expect(result.reasoning, BridgesReasoning.basic);
      expect(result.openAfterBasic, 0);
    });

    test(
      'needs advanced reasoning when the rules settle what numbers cannot',
      () {
        final result = grade(_advancedPuzzle);

        expect(result.reasoning, BridgesReasoning.advanced);
        expect(result.openAfterBasic, greaterThan(0));
      },
    );

    test('needs lookahead when only trying a bridge rules it out', () {
      // Basic moves leave every connection open. Joining the two 1s would
      // leave the board in two groups, which only shows once it is tried.
      final result = grade('''
1.2
...
1.2
''');

      expect(result.reasoning, BridgesReasoning.lookahead);
      expect(result.openAfterBasic, 4);
    });

    group('needs search for a puzzle without exactly one solution', () {
      final cases = {
        'two solutions': '2.4.1\n.....\n1.2..\n',
        'no solution': '1.1\n...\n1.1\n',
      };

      for (final MapEntry(key: description, value: board) in cases.entries) {
        test(description, () {
          expect(grade(board).reasoning, BridgesReasoning.search);
        });
      }
    });

    test('agrees with the solver that settled puzzles are unique', () {
      final random = SeededRandom(11);

      for (var board = 0; board < 200; board++) {
        final puzzle = _randomBoard(random, fromTree: true);

        final result = gradeBridges(puzzle);

        if (result.reasoning != BridgesReasoning.search) {
          expect(
            solveBridges(puzzle),
            hasLength(1),
            reason:
                'Graded ${result.reasoning.name} but not unique:\n'
                '${formatBridges(puzzle)}',
          );
        }
      }
    });
  });
}

/// A unique puzzle that island numbers alone leave open. They allow the
/// four bridges around the square on the right to form a loop, and only the
/// no-loop rule rules that out.
const String _advancedPuzzle = '''
..3.2
1....
.....
2.4.2
''';

/// A board of four to nine islands on a 6 by 6 grid with at most twelve
/// connections. Its numbers come either from random bridges that may break
/// the rules, which usually leaves no solution, or, [fromTree], from a random
/// spanning tree of non-crossing bridges, which leaves one or more.
BridgesPuzzle _randomBoard(SeededRandom random, {required bool fromTree}) {
  final layout = _randomLayout(random);
  final bridges = fromTree
      ? _randomTree(layout, random)
      : _randomBridges(layout, random);
  final spans = bridges.connections.length == layout.islands.length - 1;
  if (layout.connections.length > 12 || (fromTree && !spans)) {
    return _randomBoard(random, fromTree: fromTree);
  }

  return BridgesPuzzle(
    width: layout.width,
    height: layout.height,
    islands: [
      for (final island in layout.islands)
        Island(
          island.position,
          bridges.bridgesTouching(island.position).clamp(1, 8),
        ),
    ],
  );
}

BridgeArrangement _randomBridges(BridgesPuzzle layout, SeededRandom random) {
  var bridges = const BridgeArrangement.empty();
  for (final connection in layout.connections) {
    bridges = bridges.withBridges(connection, random.nextInt(3));
  }
  return bridges;
}

/// One or two bridges on each connection of a random forest that never
/// crosses itself or closes a loop.
BridgeArrangement _randomTree(BridgesPuzzle layout, SeededRandom random) {
  final connections = layout.connections.toList();
  random.shuffle(connections);
  var bridges = const BridgeArrangement.empty();
  for (final connection in connections) {
    final candidate = bridges.withBridges(connection, 1 + random.nextInt(2));
    final check = checkBridges(layout, candidate);
    if (check.crossings.isEmpty && !check.hasLoops) {
      bridges = candidate;
    }
  }
  return bridges;
}

/// Random islands, each needing one bridge, that never sit side by side.
BridgesPuzzle _randomLayout(SeededRandom random) {
  final positions = <Position>{};
  final islandCount = 4 + random.nextInt(6);
  for (var tries = 0; positions.length < islandCount && tries < 100; tries++) {
    final position = Position(random.nextInt(6), random.nextInt(6));
    final crowded = [
      position,
      for (final direction in Direction.values) position.step(direction),
    ].any(positions.contains);
    if (!crowded) {
      positions.add(position);
    }
  }
  return BridgesPuzzle(
    width: 6,
    height: 6,
    islands: [for (final position in positions) Island(position, 1)],
  );
}

/// Every arrangement of [puzzle] that the rules check accepts, found by
/// trying all of them. Only arrangements that give an island more bridges
/// than its number are skipped, since adding bridges never fixes that.
List<BridgeArrangement> _bruteForceSolutions(BridgesPuzzle puzzle) {
  final connections = puzzle.connections;
  final solutions = <BridgeArrangement>[];

  bool overfull(BridgeArrangement arrangement, Position position) =>
      arrangement.bridgesTouching(position) >
      puzzle.islandAt(position)!.requiredBridges;

  void visit(int index, BridgeArrangement arrangement) {
    if (index == connections.length) {
      if (checkBridges(puzzle, arrangement).isSolved) {
        solutions.add(arrangement);
      }
      return;
    }
    final connection = connections[index];
    for (var bridges = 0; bridges <= 2; bridges++) {
      final next = arrangement.withBridges(connection, bridges);
      if (!overfull(next, connection.start) &&
          !overfull(next, connection.end)) {
        visit(index + 1, next);
      }
    }
  }

  visit(0, const BridgeArrangement.empty());
  return solutions;
}
