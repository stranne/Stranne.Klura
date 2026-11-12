import 'dart:math' as math;
import 'dart:ui';

import 'package:klura/puzzles/bridges/logic/bridge_arrangement.dart';
import 'package:klura/puzzles/bridges/logic/bridges_puzzle.dart';
import 'package:klura/puzzles/bridges/logic/geometry.dart';

/// Places a puzzle's cells on a board of square cells [cellSize] pixels wide
/// and finds what a pointer is over.
final class BridgesBoardGeometry {
  const BridgesBoardGeometry(this.puzzle, this.cellSize);

  final BridgesPuzzle puzzle;
  final double cellSize;

  Size get size => Size(puzzle.width * cellSize, puzzle.height * cellSize);

  double get islandRadius => cellSize * 0.4;

  /// The distance between the two lines of a double bridge.
  double get doubleBridgeGap => cellSize * 0.18;

  double get bridgeWidth => math.max(2, cellSize * 0.07);

  Offset centerOf(Position cell) =>
      Offset((cell.x + 0.5) * cellSize, (cell.y + 0.5) * cellSize);

  Rect rectOf(Position cell) =>
      Rect.fromLTWH(cell.x * cellSize, cell.y * cellSize, cellSize, cellSize);

  /// Where a bridge on [connection] starts and ends: just outside the
  /// islands at its ends.
  (Offset, Offset) bridgeEnds(Connection connection) =>
      _ends(connection, inset: islandRadius + cellSize * 0.04);

  /// Where the lines of a bridge on [connection] are drawn from and to:
  /// halfway into the islands at its ends.
  ///
  /// The islands are drawn above the bridges, so every line, both lines of
  /// a double bridge too, meets the round edge of its island without a gap.
  (Offset, Offset) bridgeLineEnds(Connection connection) =>
      _ends(connection, inset: islandRadius / 2);

  (Offset, Offset) _ends(Connection connection, {required double inset}) {
    final start = centerOf(connection.start);
    final end = centerOf(connection.end);
    final direction = (end - start) / (end - start).distance;
    return (start + direction * inset, end - direction * inset);
  }

  /// The island whose center is nearest to [point], if it lies within
  /// [reach] cells of it.
  Island? islandNear(Offset point, {double reach = 0.75}) {
    final column = (point.dx / cellSize).floor();
    final row = (point.dy / cellSize).floor();
    Island? nearest;
    var nearestDistance = reach * cellSize;
    for (var y = row - 1; y <= row + 1; y++) {
      for (var x = column - 1; x <= column + 1; x++) {
        final cell = Position(x, y);
        final island = puzzle.contains(cell) ? puzzle.islandAt(cell) : null;
        if (island == null) {
          continue;
        }
        final distance = (centerOf(cell) - point).distance;
        if (distance <= nearestDistance) {
          nearest = island;
          nearestDistance = distance;
        }
      }
    }
    return nearest;
  }

  /// The island a drag pressed at [point] starts from, if any.
  ///
  /// The press may be up to three quarters of a cell from the island's
  /// center, which helps where a finger hides the island, unless it is nearer
  /// to a bridge that passes beside the island. Such a press is about that
  /// bridge, so it never starts a drag that would cross it.
  Island? dragIslandNear(Offset point, BridgeArrangement arrangement) {
    final island = islandNear(point);
    if (island == null) {
      return null;
    }
    final bridge = _candidatesNear(
      point,
    ).where((candidate) => arrangement[candidate.connection] > 0).firstOrNull;
    if (bridge != null &&
        !bridge.connection.touches(island.position) &&
        bridge.distance < (centerOf(island.position) - point).distance) {
      return null;
    }
    return island;
  }

  /// The connection a tap at [point] means, or `null` if it is unclear.
  ///
  /// A tap counts within half a cell of where a bridge runs. A connection
  /// with bridges wins over an empty one, so tapping a bridge where an empty
  /// connection crosses it always changes the bridge. Between two empty
  /// connections the tap must be clearly nearer to one of them.
  Connection? connectionNear(Offset point, BridgeArrangement arrangement) {
    final candidates = _candidatesNear(point);
    for (final candidate in candidates) {
      if (arrangement[candidate.connection] > 0) {
        return candidate.connection;
      }
    }
    if (candidates.isEmpty) {
      return null;
    }
    if (candidates.length > 1 &&
        candidates[1].distance - candidates[0].distance < cellSize * 0.15) {
      return null;
    }
    return candidates.first.connection;
  }

  /// Every connection within half a cell of [point], nearest first.
  List<({Connection connection, double distance})> _candidatesNear(
    Offset point,
  ) {
    final reach = cellSize * 0.5;
    return [
      for (final connection in puzzle.connections)
        if (_distanceTo(connection, point) case final distance
            when distance <= reach)
          (connection: connection, distance: distance),
    ]..sort((a, b) => a.distance.compareTo(b.distance));
  }

  double _distanceTo(Connection connection, Offset point) {
    final (start, end) = bridgeEnds(connection);
    final along = end - start;
    final fraction =
        ((point - start).dx * along.dx + (point - start).dy * along.dy) /
        along.distanceSquared;
    final nearest = start + along * fraction.clamp(0, 1);
    return (point - nearest).distance;
  }
}
