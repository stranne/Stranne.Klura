import 'package:klura/core/grid.dart';
import 'package:klura/puzzles/tents/logic/tents_marks.dart';
import 'package:klura/puzzles/tents/logic/tents_rules.dart';
import 'package:klura/puzzles/tents/logic/tents_text.dart';
import 'package:test/test.dart';

TentsCheck check(String board) {
  final (puzzle, marks) = parseTents(board);
  return checkTents(puzzle, marks);
}

void main() {
  test('accepts tents that meet every rule', () {
    final result = check('''
  20101
1 ^T...
0 ....T
1 ....^
1 ^.T..
1 T.^..
''');

    expect(result.isSolved, isTrue);
    expect(result.linesMet, isTrue);
    expect(result.everyTentHasTree, isTrue);
    expect(result.everyTreeHasTent, isTrue);
  });

  test('ignores grass', () {
    final result = check('''
  20101
1 ^T---
0 ----T
1 ----^
1 ^-T--
1 T-^--
''');

    expect(result.isSolved, isTrue);
  });

  test('compares each row and column with its number', () {
    final result = check('''
  20101
1 ^T^..
0 ....T
1 .....
1 ..T..
1 T.^..
''');

    expect(result.rowStatuses, const [
      LineStatus.over,
      LineStatus.met,
      LineStatus.under,
      LineStatus.under,
      LineStatus.met,
    ]);
    expect(result.columnStatuses, const [
      LineStatus.under,
      LineStatus.met,
      LineStatus.over,
      LineStatus.met,
      LineStatus.under,
    ]);
    expect(result.linesMet, isFalse);
    expect(result.isSolved, isFalse);
  });

  test('finds tents that touch, diagonals included', () {
    final result = check('''
  1010
1 ^T^.
1 .^T.
''');

    expect(result.touching, const [
      (Position(0, 0), Position(1, 1)),
      (Position(2, 0), Position(1, 1)),
    ]);
    expect(result.touchingTents, {
      const Position(0, 0),
      const Position(1, 1),
      const Position(2, 0),
    });
    expect(result.isSolved, isFalse);
  });

  test('finds tents with no tree beside them', () {
    final result = check('''
  100
1 ^..
0 .T.
''');

    expect(result.tentsWithoutTree, const [Position(0, 0)]);
    expect(result.everyTentHasTree, isFalse);
    expect(result.isSolved, isFalse);
  });

  test('needs a tree of its own for each tent and a tent for each tree', () {
    // The numbers are met, but both tents stand beside the same tree.
    final result = check('''
  01010
2 .^T^.
0 .....
0 T....
''');

    expect(result.linesMet, isTrue);
    expect(result.touching, isEmpty);
    expect(result.tentsWithoutTree, isEmpty);
    expect(result.tentsSharingTree, const [Position(1, 0), Position(3, 0)]);
    expect(result.sharedTrees, const [Position(2, 0)]);
    expect(result.everyTentHasTree, isFalse);
    expect(result.everyTreeHasTent, isFalse);
    expect(result.isSolved, isFalse);
  });

  test('names every tent of a group that outnumbers its trees', () {
    // The three tents in the top row have only two trees between them.
    // The tent below has a tree of its own and is not named.
    final result = check('''
  101010
2 ^T^T^.
0 ......
1 ^T....
''');

    expect(result.tentsSharingTree, const [
      Position(0, 0),
      Position(2, 0),
      Position(4, 0),
    ]);
    expect(result.sharedTrees, const [Position(1, 0), Position(3, 0)]);
    expect(result.everyTentHasTree, isFalse);
  });

  test('does not count a tent with no tree beside it as sharing', () {
    final result = check('''
  01000
1 .^T^.
0 .....
0 ^....
''');

    expect(result.tentsWithoutTree, const [Position(0, 2)]);
    expect(result.tentsSharingTree, const [Position(1, 0), Position(3, 0)]);
    expect(result.sharedTrees, const [Position(2, 0)]);
  });

  test('lets a tent belong to whichever tree it can', () {
    // The left tent stands beside both trees. It first takes the tree to
    // its right, which the other tent needs, so it moves to the left one.
    final result = check('''
  0101
0 ....
2 T^T^
0 ....
''');

    expect(result.tentsSharingTree, isEmpty);
    expect(result.everyTentHasTree, isTrue);
    expect(result.everyTreeHasTent, isTrue);
    expect(result.isSolved, isTrue);
  });

  test('knows that an empty board is still short of tents', () {
    final result = check('''
  10
1 .T
''');

    expect(result.everyTentHasTree, isTrue);
    expect(result.everyTreeHasTent, isFalse);
    expect(result.isSolved, isFalse);
  });

  test('rejects a mark on a tree', () {
    final (puzzle, _) = parseTents('''
  10
1 .T
''');
    final marks = TentsMarks({const Position(1, 0): TentsMark.tent});

    expect(() => checkTents(puzzle, marks), throwsArgumentError);
  });
}
