import 'package:flutter_test/flutter_test.dart';
import 'package:klura/puzzles/bridges/bridges_board_geometry.dart';
import 'package:klura/puzzles/bridges/logic/bridges_text.dart';
import 'package:klura/puzzles/bridges/logic/geometry.dart';

void main() {
  final (:puzzle, arrangement: _) = parseBridges('''
2.2
...
1..
''');
  final across = Connection(const Position(0, 0), const Position(2, 0));
  final down = Connection(const Position(0, 0), const Position(0, 2));

  for (final cellSize in [20.0, 36.0, 60.0]) {
    test('the lines of a bridge reach under its islands at $cellSize px', () {
      final geometry = BridgesBoardGeometry(puzzle, cellSize);
      // The far side of either line of a double bridge.
      final side = geometry.doubleBridgeGap / 2 + geometry.bridgeWidth / 2;

      for (final connection in [across, down]) {
        final (start, end) = geometry.bridgeLineEnds(connection);
        final along = (end - start) / (end - start).distance;
        final sideways = Offset(-along.dy, along.dx) * side;
        for (final (island, point) in [
          (connection.start, start),
          (connection.end, end),
        ]) {
          for (final corner in [point + sideways, point - sideways]) {
            expect(
              (corner - geometry.centerOf(island)).distance,
              lessThan(geometry.islandRadius),
            );
          }
        }
      }
    });
  }
}
