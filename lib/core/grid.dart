import 'package:meta/meta.dart';

/// A cell on a puzzle grid: column [x] from the left, row [y] from the top.
@immutable
final class Position implements Comparable<Position> {
  const Position(this.x, this.y);

  final int x;
  final int y;

  /// Whether this cell lies on a grid of [width] by [height] cells.
  bool isWithin(int width, int height) =>
      x >= 0 && x < width && y >= 0 && y < height;

  /// The cell one step in [direction], which may lie off the grid.
  Position step(Direction direction) =>
      Position(x + direction.dx, y + direction.dy);

  /// Whether [other] is one of the eight cells around this one, diagonals
  /// included.
  bool touches(Position other) =>
      other != this && (other.x - x).abs() <= 1 && (other.y - y).abs() <= 1;

  /// Orders positions in reading order: by row, then by column.
  @override
  int compareTo(Position other) => y != other.y ? y - other.y : x - other.x;

  @override
  bool operator ==(Object other) =>
      other is Position && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x, $y)';
}

/// One of the four directions along a row or column.
enum Direction {
  up(0, -1),
  right(1, 0),
  down(0, 1),
  left(-1, 0);

  const Direction(this.dx, this.dy);

  /// The change in column for one step.
  final int dx;

  /// The change in row for one step.
  final int dy;

  bool get isHorizontal => dy == 0;

  Direction get opposite => switch (this) {
    up => down,
    right => left,
    down => up,
    left => right,
  };
}
