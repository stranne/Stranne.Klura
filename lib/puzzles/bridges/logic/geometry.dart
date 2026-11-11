import 'package:meta/meta.dart';

/// A cell on a Bridges board: column [x] from the left, row [y] from the top.
@immutable
final class Position implements Comparable<Position> {
  const Position(this.x, this.y);

  final int x;
  final int y;

  /// Whether this cell lies on a grid of [width] by [height] cells.
  bool isWithin(int width, int height) =>
      x >= 0 && x < width && y >= 0 && y < height;

  /// The cell one step in [direction], which may lie off the board.
  Position step(Direction direction) =>
      Position(x + direction.dx, y + direction.dy);

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

/// One of the four directions a bridge can run from an island.
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

/// A straight line between two cells in the same row or column, such as the
/// place for a bridge between two islands.
///
/// The ends are stored in reading order, so [start] is the left end of a
/// horizontal connection and the top end of a vertical one. A connection
/// equals the one created from its other end.
@immutable
final class Connection implements Comparable<Connection> {
  /// Creates the connection between [first] and [second].
  ///
  /// Throws an [ArgumentError] unless the cells are distinct and share a row
  /// or column.
  factory Connection(Position first, Position second) {
    if (first == second) {
      throw ArgumentError.value(second, 'second', 'Must differ from $first');
    }
    if (first.x != second.x && first.y != second.y) {
      throw ArgumentError.value(
        second,
        'second',
        'Must share a row or column with $first',
      );
    }
    return first.compareTo(second) < 0
        ? Connection._(first, second)
        : Connection._(second, first);
  }

  const Connection._(this.start, this.end);

  final Position start;
  final Position end;

  bool get isHorizontal => start.y == end.y;

  /// The cells strictly between the ends, where a bridge is drawn.
  Iterable<Position> get cellsBetween sync* {
    final direction = isHorizontal ? Direction.right : Direction.down;
    for (var cell = start.step(direction); cell != end;) {
      yield cell;
      cell = cell.step(direction);
    }
  }

  /// Whether [position] is one of the ends.
  bool touches(Position position) => position == start || position == end;

  /// Whether this connection and [other] cross between their ends.
  ///
  /// Only perpendicular connections can cross. Connections that meet at an
  /// end do not cross, so bridges sharing an island never do.
  bool crosses(Connection other) {
    if (isHorizontal == other.isHorizontal) {
      return false;
    }

    final horizontal = isHorizontal ? this : other;
    final vertical = isHorizontal ? other : this;
    final column = vertical.start.x;
    final row = horizontal.start.y;
    return column > horizontal.start.x &&
        column < horizontal.end.x &&
        row > vertical.start.y &&
        row < vertical.end.y;
  }

  /// Orders connections by [start], then by [end].
  @override
  int compareTo(Connection other) {
    final byStart = start.compareTo(other.start);
    return byStart != 0 ? byStart : end.compareTo(other.end);
  }

  @override
  bool operator ==(Object other) =>
      other is Connection && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '$start-$end';
}
