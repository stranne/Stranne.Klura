import 'package:klura/core/grid.dart';
import 'package:klura/puzzles/tents/logic/pairing.dart';
import 'package:klura/puzzles/tents/logic/tents_marks.dart';
import 'package:klura/puzzles/tents/logic/tents_puzzle.dart';

/// How the tents in a row or column compare with its number.
enum LineStatus { under, met, over }

/// The result of judging the player's marks against the rules.
final class TentsCheck {
  const TentsCheck._({
    required this.rowStatuses,
    required this.columnStatuses,
    required this.touching,
    required this.tentsWithoutTree,
    required this.everyTentHasTree,
    required this.everyTreeHasTent,
  });

  /// The status of each row, from the top.
  final List<LineStatus> rowStatuses;

  /// The status of each column, from the left.
  final List<LineStatus> columnStatuses;

  /// Each pair of tents that touch, diagonals included, with the earlier
  /// tent in reading order first.
  final List<(Position, Position)> touching;

  /// The tents with no tree directly beside them, in reading order.
  final List<Position> tentsWithoutTree;

  /// Whether each tent can have a tree of its own beside it, with no two
  /// tents sharing one.
  final bool everyTentHasTree;

  /// Whether each tree can have a tent of its own beside it, with no two
  /// trees sharing one.
  final bool everyTreeHasTent;

  /// The tents that touch another tent, in reading order.
  Set<Position> get touchingTents => {
    for (final (first, second) in touching) ...[first, second],
  };

  /// Whether every row and column has as many tents as its number.
  bool get linesMet => [
    ...rowStatuses,
    ...columnStatuses,
  ].every((status) => status == LineStatus.met);

  /// Whether the marks meet every rule, which makes their tents a solution.
  ///
  /// Grass plays no part: it is only the player's note.
  bool get isSolved =>
      linesMet && touching.isEmpty && everyTentHasTree && everyTreeHasTent;
}

/// Judges [marks] against the rules of [puzzle].
///
/// The rules are the only judge: any tents that meet them solve the puzzle,
/// whatever solution the generator had in mind. Which tree a tent belongs to
/// is never fixed; the tents only have to allow some pairing.
///
/// Throws an [ArgumentError] if a mark lies outside the board or on a tree.
TentsCheck checkTents(TentsPuzzle puzzle, TentsMarks marks) {
  for (final position in marks.marks.keys) {
    if (!puzzle.contains(position) || puzzle.hasTree(position)) {
      throw ArgumentError.value(
        position,
        'marks',
        'Must be a free cell of the puzzle',
      );
    }
  }

  final tents = marks.tents.toList();
  final rowCounts = List.filled(puzzle.height, 0);
  final columnCounts = List.filled(puzzle.width, 0);
  for (final tent in tents) {
    rowCounts[tent.y]++;
    columnCounts[tent.x]++;
  }

  final touching = [
    for (var first = 0; first < tents.length; first++)
      for (var second = first + 1; second < tents.length; second++)
        if (tents[first].touches(tents[second])) (tents[first], tents[second]),
  ];

  final treeIndexes = {
    for (final (index, tree) in puzzle.trees.indexed) tree: index,
  };
  final treesOfTent = [
    for (final tent in tents)
      [for (final tree in puzzle.treesBeside(tent)) treeIndexes[tree]!],
  ];
  final pairs = countPairs(treesOfTent, puzzle.trees.length);

  return TentsCheck._(
    rowStatuses: List.unmodifiable(_statuses(rowCounts, puzzle.rowTents)),
    columnStatuses: List.unmodifiable(
      _statuses(columnCounts, puzzle.columnTents),
    ),
    touching: List.unmodifiable(touching),
    tentsWithoutTree: List.unmodifiable([
      for (final (index, tent) in tents.indexed)
        if (treesOfTent[index].isEmpty) tent,
    ]),
    everyTentHasTree: pairs == tents.length,
    everyTreeHasTent: pairs == puzzle.trees.length,
  );
}

List<LineStatus> _statuses(List<int> counts, List<int> required) => [
  for (final (index, count) in counts.indexed)
    if (count < required[index])
      LineStatus.under
    else if (count == required[index])
      LineStatus.met
    else
      LineStatus.over,
];
