import 'package:klura/puzzles/bridges/logic/bridge_arrangement.dart';
import 'package:klura/puzzles/bridges/logic/bridges_rules.dart';
import 'package:klura/puzzles/bridges/logic/bridges_text.dart';
import 'package:klura/puzzles/bridges/logic/geometry.dart';
import 'package:test/test.dart';

void main() {
  BridgesCheck check(String board) {
    final (:puzzle, :arrangement) = parseBridges(board);
    return checkBridges(puzzle, arrangement);
  }

  test('accepts a board that meets every rule', () {
    final result = check('''
3=2
|..
1..
''');

    expect(result.isSolved, isTrue);
    expect(result.islandStatuses.values, everyElement(IslandStatus.met));
    expect(result.crossings, isEmpty);
    expect(result.isConnected, isTrue);
    expect(result.hasLoops, isFalse);
  });

  test(
    'reports islands with too few, the right number and too many bridges',
    () {
      final result = check('''
2=2.1
|....
1....
''');

      expect(result.islandStatuses, {
        const Position(0, 0): IslandStatus.over,
        const Position(2, 0): IslandStatus.met,
        const Position(4, 0): IslandStatus.under,
        const Position(0, 2): IslandStatus.met,
      });
      expect(result.isSolved, isFalse);
    },
  );

  test('reports an empty board as unmet', () {
    final (:puzzle, arrangement: _) = parseBridges('1.1');

    final result = checkBridges(puzzle, const BridgeArrangement.empty());

    expect(result.islandStatuses.values, everyElement(IslandStatus.under));
    expect(result.isConnected, isFalse);
    expect(result.isSolved, isFalse);
  });

  test('reports crossing bridges', () {
    final result = check('''
2-2..
|.|..
2-┼-1
..|..
..1..
''');

    expect(result.crossings, [
      (
        Connection(const Position(2, 0), const Position(2, 4)),
        Connection(const Position(0, 2), const Position(4, 2)),
      ),
    ]);
    expect(result.islandStatuses.values, everyElement(IslandStatus.met));
    expect(result.isConnected, isTrue);
    expect(result.hasLoops, isFalse);
    expect(result.isSolved, isFalse);
  });

  test('reports islands that are not all connected', () {
    final result = check('''
1-1
...
1-1
''');

    expect(result.islandStatuses.values, everyElement(IslandStatus.met));
    expect(result.isConnected, isFalse);
    expect(result.isSolved, isFalse);
  });

  test('reports the connections that form a loop', () {
    final result = check('''
2-3-1
|.|..
2-2..
''');

    expect(result.loopConnections, [
      Connection(const Position(0, 0), const Position(2, 0)),
      Connection(const Position(0, 0), const Position(0, 2)),
      Connection(const Position(2, 0), const Position(2, 2)),
      Connection(const Position(0, 2), const Position(2, 2)),
    ]);
    expect(result.hasLoops, isTrue);
    expect(result.islandStatuses.values, everyElement(IslandStatus.met));
    expect(result.isConnected, isTrue);
    expect(result.isSolved, isFalse);
  });

  test('does not count a double bridge as a loop', () {
    final result = check('''
2=5=2
..|..
..1..
''');

    expect(result.hasLoops, isFalse);
    expect(result.isSolved, isTrue);
  });

  test('rejects bridges the puzzle does not offer', () {
    final (:puzzle, arrangement: _) = parseBridges('1.2.1');
    final overIsland = BridgeArrangement({
      Connection(const Position(0, 0), const Position(4, 0)): 1,
    });

    expect(() => checkBridges(puzzle, overIsland), throwsArgumentError);
  });
}
