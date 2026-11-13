import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:klura/core/grid.dart';
import 'package:klura/puzzles/logjam/logic/logjam_board.dart';
import 'package:klura/puzzles/logjam/logjam_board_geometry.dart';

void main() {
  const geometry = LogjamBoardGeometry(width: 6, height: 6, cellSize: 50);

  test('leaves water around the grid, more on the right for the boom', () {
    expect(geometry.size, const Size(355, 325));
    expect(geometry.gridRect, const Rect.fromLTWH(10, 12.5, 300, 300));
    expect(geometry.boomX, 325);
    expect(geometry.exitPoint(2), const Offset(325, 137.5));
    expect(LogjamBoardGeometry.widthInCells(6), closeTo(7.1, 1e-9));
    expect(LogjamBoardGeometry.heightInCells(6), closeTo(6.5, 1e-9));
  });

  test('places a log where it lies or between cells as it slides', () {
    const across = LogjamPiece.horizontal(1, 2, 3);
    const down = LogjamPiece.vertical(4, 0, 2);

    expect(geometry.pieceRect(across), const Rect.fromLTWH(60, 112.5, 150, 50));
    expect(
      geometry.pieceRect(across, 1.5),
      const Rect.fromLTWH(85, 112.5, 150, 50),
    );
    expect(geometry.pieceRect(down), const Rect.fromLTWH(210, 12.5, 50, 100));
    expect(
      geometry.pieceRect(down, 3),
      const Rect.fromLTWH(210, 162.5, 50, 100),
    );
  });

  test('finds the cell under a point on the grid only', () {
    expect(geometry.cellAt(const Offset(11, 13)), const Position(0, 0));
    expect(geometry.cellAt(const Offset(309, 312)), const Position(5, 5));
    expect(geometry.cellAt(const Offset(5, 100)), isNull);
    expect(geometry.cellAt(const Offset(320, 100)), isNull);
  });
}
