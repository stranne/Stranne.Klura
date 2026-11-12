import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:klura/core/grid.dart';
import 'package:klura/puzzles/tents/tents_board_geometry.dart';

void main() {
  final geometry = TentsBoardGeometry(width: 4, height: 3, cellSize: 50);

  test('leaves room for the numbers above and left of the grid', () {
    expect(geometry.strip, 40);
    expect(geometry.size, const Size(40 + 4 * 50 + 20, 40 + 3 * 50 + 20));
    expect(geometry.gridRect, const Rect.fromLTWH(40, 40, 200, 150));
    expect(
      geometry.rectOf(const Position(1, 2)),
      const Rect.fromLTWH(90, 140, 50, 50),
    );
    expect(geometry.columnNumberRect(3), const Rect.fromLTWH(190, 0, 50, 40));
    expect(geometry.rowNumberRect(0), const Rect.fromLTWH(0, 40, 40, 50));
  });

  test('finds the cell under a point, or none outside the grid', () {
    expect(geometry.cellAt(const Offset(41, 41)), const Position(0, 0));
    expect(geometry.cellAt(const Offset(239, 189)), const Position(3, 2));
    expect(geometry.cellAt(const Offset(20, 60)), isNull);
    expect(geometry.cellAt(const Offset(60, 20)), isNull);
    expect(geometry.cellAt(const Offset(245, 60)), isNull);
  });

  test('finds the nearest cell to a point beyond the grid', () {
    expect(geometry.nearestCell(const Offset(-30, 60)), const Position(0, 0));
    expect(geometry.nearestCell(const Offset(400, 120)), const Position(3, 1));
    expect(geometry.nearestCell(const Offset(100, 900)), const Position(1, 2));
  });
}
