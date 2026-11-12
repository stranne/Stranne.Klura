import 'package:klura/core/grid.dart';
import 'package:klura/puzzles/bridges/logic/bridge_arrangement.dart';
import 'package:klura/puzzles/bridges/logic/bridges_game.dart';
import 'package:klura/puzzles/bridges/logic/bridges_rules.dart';
import 'package:klura/puzzles/bridges/logic/bridges_text.dart';
import 'package:klura/puzzles/bridges/logic/geometry.dart';
import 'package:test/test.dart';

void main() {
  // Two islands at each end of a row and of a column, whose bridges would
  // cross in the middle.
  final crossing = parseBridges('''
..1..
.....
1...1
.....
..1..
''').puzzle;
  final across = Connection(const Position(0, 2), const Position(4, 2));
  final down = Connection(const Position(2, 0), const Position(2, 4));

  // Solved by a double bridge along the top and a single one down the left.
  final small = parseBridges('''
3.2
...
1..
''').puzzle;
  final top = Connection(const Position(0, 0), const Position(2, 0));
  final left = Connection(const Position(0, 0), const Position(0, 2));

  String draw(BridgesGame game) => formatBridges(game.puzzle, game.arrangement);

  test('starts with the given bridges and nothing to undo', () {
    final empty = BridgesGame(small);
    final started = BridgesGame(small, BridgeArrangement({top: 1}));

    expect(empty.arrangement, const BridgeArrangement.empty());
    expect(empty.canUndo, isFalse);
    expect(empty.canReset, isFalse);
    expect(started.arrangement[top], 1);
    expect(started.canUndo, isFalse);
    expect(started.canReset, isTrue);
  });

  test('cycles a connection through one, two and no bridges', () {
    final one = BridgesGame(small).cycleBridges(left);
    final two = one.cycleBridges(left);
    final none = two.cycleBridges(left);

    expect(one.arrangement[left], 1);
    expect(two.arrangement[left], 2);
    expect(none.arrangement[left], 0);
    expect(draw(two), '3.2\n║..\n1..\n');
  });

  test('tells how many bridges the next move leaves', () {
    final game = BridgesGame(small, BridgeArrangement({top: 2, left: 1}));

    expect(game.nextBridgeCount(left), 2);
    expect(game.nextBridgeCount(top), 0);
  });

  test('checks the bridges after every move', () {
    final single = BridgesGame(small).cycleBridges(top);
    final double = single.cycleBridges(top);

    expect(
      single.check.islandStatuses[const Position(2, 0)],
      IslandStatus.under,
    );
    expect(double.check.islandStatuses[const Position(2, 0)], IslandStatus.met);
    expect(double.isSolved, isFalse);
  });

  test('never places a bridge that would cross another', () {
    final game = BridgesGame(crossing).cycleBridges(across);

    final blocked = game.cycleBridges(down);

    expect(game.blockersOf(down), [across]);
    expect(blocked, same(game));
    expect(blocked.arrangement[down], 0);
    expect(blocked.check.crossings, isEmpty);
  });

  test('adds a second bridge where the first one already lies', () {
    final game = BridgesGame(crossing).cycleBridges(across);

    expect(game.blockersOf(across), isEmpty);
    expect(game.cycleBridges(across).arrangement[across], 2);
  });

  test('undoes moves one at a time back to the start', () {
    final first = BridgesGame(small);
    final second = first.cycleBridges(top);
    final third = second.cycleBridges(left);

    expect(third.canUndo, isTrue);
    expect(third.undo(), same(second));
    expect(third.undo().undo(), same(first));
    expect(first.undo(), same(first));
  });

  test('keeps an unlimited undo history', () {
    var game = BridgesGame(crossing);
    for (var move = 0; move < 1000; move++) {
      game = game.cycleBridges(across);
    }
    for (var move = 0; move < 1000; move++) {
      game = game.undo();
    }

    expect(game.arrangement, const BridgeArrangement.empty());
    expect(game.canUndo, isFalse);
  });

  test('resets every bridge as a move that undo takes back', () {
    final game = BridgesGame(crossing)
        .cycleBridges(across)
        .cycleBridges(across);

    final reset = game.reset();

    expect(reset.arrangement, const BridgeArrangement.empty());
    expect(reset.canReset, isFalse);
    expect(reset.undo(), same(game));
    expect(reset.reset(), same(reset));
  });

  test('takes no more moves once solved, but can be reset', () {
    final solved = BridgesGame(
      small,
    ).cycleBridges(top).cycleBridges(top).cycleBridges(left);

    expect(solved.isSolved, isTrue);
    expect(solved.cycleBridges(left), same(solved));
    expect(solved.canUndo, isFalse);
    expect(solved.undo(), same(solved));

    final reset = solved.reset();

    expect(reset.isSolved, isFalse);
    expect(reset.arrangement, const BridgeArrangement.empty());
    expect(reset.cycleBridges(left).arrangement[left], 1);
    expect(reset.undo(), same(solved));
  });

  test('rejects connections the puzzle does not offer', () {
    final game = BridgesGame(small);
    final tooShort = Connection(const Position(0, 0), const Position(0, 1));

    expect(() => game.cycleBridges(tooShort), throwsArgumentError);
    expect(() => game.blockersOf(across), throwsArgumentError);
    expect(
      () => BridgesGame(small, BridgeArrangement({across: 1})),
      throwsArgumentError,
    );
  });
}
