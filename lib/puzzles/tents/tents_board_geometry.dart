import 'dart:ui';

import 'package:klura/core/grid.dart';

/// The width of the strips holding the row and column numbers, in cells.
const double tentsClueStrip = 0.8;

/// The margin right of and below the grid, in cells, which keeps the grid
/// from touching the edge of the screen and balances the numbers a little.
const double tentsBoardMargin = 0.4;

/// Places the cells and numbers of a board of [width] by [height] cells in
/// pixels, with cells of [cellSize], and finds the cell under a pointer.
///
/// The column numbers run along the top and the row numbers down the left,
/// each in a strip [tentsClueStrip] cells wide, and a margin of
/// [tentsBoardMargin] cells follows the grid.
final class TentsBoardGeometry {
  TentsBoardGeometry({
    required this.width,
    required this.height,
    required this.cellSize,
  }) : strip = cellSize * tentsClueStrip;

  final int width;
  final int height;
  final double cellSize;

  /// The width of the strips with the numbers, in pixels.
  final double strip;

  /// The size of the whole board, numbers and margin included.
  Size get size => Size(
    strip + (width + tentsBoardMargin) * cellSize,
    strip + (height + tentsBoardMargin) * cellSize,
  );

  /// The grid of cells, without the numbers.
  Rect get gridRect =>
      Rect.fromLTWH(strip, strip, width * cellSize, height * cellSize);

  /// The square of the cell at [position].
  Rect rectOf(Position position) => Rect.fromLTWH(
    strip + position.x * cellSize,
    strip + position.y * cellSize,
    cellSize,
    cellSize,
  );

  Offset centerOf(Position position) => rectOf(position).center;

  /// Where the number of column [x] stands, above the grid.
  Rect columnNumberRect(int x) =>
      Rect.fromLTWH(strip + x * cellSize, 0, cellSize, strip);

  /// Where the number of row [y] stands, left of the grid.
  Rect rowNumberRect(int y) =>
      Rect.fromLTWH(0, strip + y * cellSize, strip, cellSize);

  /// The cell under [point], or `null` if it lies outside the grid.
  Position? cellAt(Offset point) {
    final position = _cellNear(point);
    return position.isWithin(width, height) && gridRect.contains(point)
        ? position
        : null;
  }

  /// The cell of the grid nearest to [point], which may lie outside it.
  Position nearestCell(Offset point) {
    final position = _cellNear(point);
    return Position(
      position.x.clamp(0, width - 1),
      position.y.clamp(0, height - 1),
    );
  }

  Position _cellNear(Offset point) => Position(
    ((point.dx - strip) / cellSize).floor(),
    ((point.dy - strip) / cellSize).floor(),
  );
}
