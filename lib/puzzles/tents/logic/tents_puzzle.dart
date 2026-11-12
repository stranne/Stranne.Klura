import 'package:klura/core/grid.dart';
import 'package:meta/meta.dart';

/// A Tents puzzle: a grid with trees and the number of tents in each row and
/// column.
///
/// The player's tents and grass are a separate value, `TentsMarks`, and
/// `checkTents` judges them against the rules. The puzzle holds no solution.
@immutable
final class TentsPuzzle {
  /// Creates a puzzle of [width] by [height] cells holding [trees], with
  /// [rowTents] tents in each row from the top and [columnTents] in each
  /// column from the left.
  ///
  /// Throws an [ArgumentError] if the grid is empty, a tree lies outside it
  /// or shares a cell, there is not one count for each row and column, a
  /// count is more than its row or column can hold, or the counts do not add
  /// up to one tent for each tree.
  factory TentsPuzzle({
    required int width,
    required int height,
    required Iterable<Position> trees,
    required List<int> rowTents,
    required List<int> columnTents,
  }) {
    if (width < 1) {
      throw RangeError.range(width, 1, null, 'width');
    }
    if (height < 1) {
      throw RangeError.range(height, 1, null, 'height');
    }

    final sorted = trees.toList()..sort();
    for (final (index, tree) in sorted.indexed) {
      if (!tree.isWithin(width, height)) {
        throw ArgumentError.value(tree, 'trees', 'Lies outside the grid');
      }
      if (index > 0 && sorted[index - 1] == tree) {
        throw ArgumentError.value(tree, 'trees', 'Shares a cell');
      }
    }
    _checkCounts(rowTents, height, width, sorted.length, 'rowTents');
    _checkCounts(columnTents, width, height, sorted.length, 'columnTents');

    return TentsPuzzle._(
      width: width,
      height: height,
      trees: List.unmodifiable(sorted),
      rowTents: List.unmodifiable(rowTents),
      columnTents: List.unmodifiable(columnTents),
    );
  }

  TentsPuzzle._({
    required this.width,
    required this.height,
    required this.trees,
    required this.rowTents,
    required this.columnTents,
  }) : _treeSet = trees.toSet();

  final int width;
  final int height;

  /// The trees in reading order: by row, then by column.
  final List<Position> trees;

  /// The number of tents in each row, from the top.
  final List<int> rowTents;

  /// The number of tents in each column, from the left.
  final List<int> columnTents;

  final Set<Position> _treeSet;

  /// The number of tents a solution has: one for each tree.
  int get tentCount => trees.length;

  /// Whether [position] lies on the board.
  bool contains(Position position) => position.isWithin(width, height);

  /// Whether a tree stands at [position].
  bool hasTree(Position position) => _treeSet.contains(position);

  /// The trees directly above, below, left or right of [position].
  Iterable<Position> treesBeside(Position position) => [
    for (final direction in Direction.values)
      if (position.step(direction) case final cell when hasTree(cell)) cell,
  ];

  /// Whether a tent may stand at [position]: on a free cell directly beside
  /// a tree. A tent anywhere else can never belong to a tree.
  bool canHoldTent(Position position) =>
      contains(position) &&
      !hasTree(position) &&
      treesBeside(position).isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is TentsPuzzle &&
      other.width == width &&
      other.height == height &&
      _listEquals(other.trees, trees) &&
      _listEquals(other.rowTents, rowTents) &&
      _listEquals(other.columnTents, columnTents);

  @override
  int get hashCode => Object.hash(
    width,
    height,
    Object.hashAll(trees),
    Object.hashAll(rowTents),
    Object.hashAll(columnTents),
  );

  @override
  String toString() =>
      'TentsPuzzle(${width}x$height, $trees, rows $rowTents, '
      'columns $columnTents)';
}

/// Checks that [counts] has one count for each of [lines] lines of [length]
/// cells, that each fits its line and that they add up to [tentCount].
void _checkCounts(
  List<int> counts,
  int lines,
  int length,
  int tentCount,
  String name,
) {
  if (counts.length != lines) {
    throw ArgumentError.value(counts, name, 'Must have $lines counts');
  }
  // Tents never touch, so at most every other cell of a line holds one.
  final most = (length + 1) ~/ 2;
  var total = 0;
  for (final count in counts) {
    if (count < 0 || count > most) {
      throw ArgumentError.value(counts, name, 'Must be 0 to $most each');
    }
    total += count;
  }
  if (total != tentCount) {
    throw ArgumentError.value(
      counts,
      name,
      'Must add up to $tentCount, one tent for each tree',
    );
  }
}

bool _listEquals<T>(List<T> first, List<T> second) {
  if (first.length != second.length) {
    return false;
  }
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) {
      return false;
    }
  }
  return true;
}
