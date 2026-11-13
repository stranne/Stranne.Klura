import 'dart:ui';

import 'package:klura/core/grid.dart';
import 'package:klura/puzzles/logjam/logic/logjam_board.dart';

/// The water left of the grid, in cells.
const double _leftMargin = 0.2;

/// The water above and below the grid, in cells.
const double _verticalMargin = 0.25;

/// How far right of the grid the boom stands, in cells.
const double _boomDistance = 0.3;

/// The water right of the grid, in cells, past the boom to where the river
/// fades out. The marked log floats out through it.
const double _rightMargin = 0.9;

/// Places the cells, logs and boom of a board of [width] by [height] cells
/// in pixels, with cells of [cellSize], and finds the cell under a pointer.
///
/// The grid of cells is the water the logs float on. A boom closes its
/// right edge, a little apart from it, but for the gap at the exit row.
final class LogjamBoardGeometry {
  const LogjamBoardGeometry({
    required this.width,
    required this.height,
    required this.cellSize,
  });

  /// The width of a board with a grid [width] cells wide, in cells.
  static double widthInCells(int width) => _leftMargin + width + _rightMargin;

  /// The height of a board with a grid [height] cells high, in cells.
  static double heightInCells(int height) => height + 2 * _verticalMargin;

  final int width;
  final int height;
  final double cellSize;

  /// The size of the whole board, the water around the grid included.
  Size get size =>
      Size(widthInCells(width) * cellSize, heightInCells(height) * cellSize);

  /// The grid of cells.
  Rect get gridRect => Rect.fromLTWH(
    _leftMargin * cellSize,
    _verticalMargin * cellSize,
    width * cellSize,
    height * cellSize,
  );

  /// Where the boom stands, right of the grid.
  double get boomX => gridRect.right + _boomDistance * cellSize;

  /// The square of the cell at [position].
  Rect rectOf(Position position) => Rect.fromLTWH(
    gridRect.left + position.x * cellSize,
    gridRect.top + position.y * cellSize,
    cellSize,
    cellSize,
  );

  /// The cells [piece] covers when slid to [offset] along its line, which
  /// may lie between cells while it moves. Without an [offset], where it
  /// lies.
  Rect pieceRect(LogjamPiece piece, [double? offset]) {
    final along = offset ?? piece.offset.toDouble();
    final grid = gridRect;
    return piece.isHorizontal
        ? Rect.fromLTWH(
            grid.left + along * cellSize,
            grid.top + piece.y * cellSize,
            piece.length * cellSize,
            cellSize,
          )
        : Rect.fromLTWH(
            grid.left + piece.x * cellSize,
            grid.top + along * cellSize,
            cellSize,
            piece.length * cellSize,
          );
  }

  /// The middle of the gap in the boom, at the end of [exitRow].
  Offset exitPoint(int exitRow) =>
      Offset(boomX, gridRect.top + (exitRow + 0.5) * cellSize);

  /// The cell under [point], or `null` if it lies outside the grid.
  Position? cellAt(Offset point) {
    final grid = gridRect;
    if (!grid.contains(point)) {
      return null;
    }
    final position = Position(
      ((point.dx - grid.left) / cellSize).floor(),
      ((point.dy - grid.top) / cellSize).floor(),
    );
    return position.isWithin(width, height) ? position : null;
  }
}
