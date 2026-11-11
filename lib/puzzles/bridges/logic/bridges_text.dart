import 'package:klura/puzzles/bridges/logic/bridge_arrangement.dart';
import 'package:klura/puzzles/bridges/logic/bridges_puzzle.dart';
import 'package:klura/puzzles/bridges/logic/geometry.dart';

// A small text notation for Bridges boards, used for test fixtures and
// readable failure messages. Each character is one cell:
//
//   1-8  an island needing that many bridges
//   .    an empty cell
//   - =  one or two horizontal bridges
//   | ║  one or two vertical bridges
//   ┼ ╪ ╫ ╬  crossing bridges: single, horizontal double, vertical double,
//            both double
//
// For example, an island needing three bridges with a double bridge to the
// right and a single bridge down:
//
//   3=2
//   |..
//   1..

/// The glyph for each cell, keyed by its horizontal and vertical bridges.
const Map<(int, int), String> _glyphs = {
  (0, 0): '.',
  (1, 0): '-',
  (2, 0): '=',
  (0, 1): '|',
  (0, 2): '║',
  (1, 1): '┼',
  (2, 1): '╪',
  (1, 2): '╫',
  (2, 2): '╬',
};

final Map<String, (int, int)> _cellsByGlyph = {
  for (final MapEntry(:key, :value) in _glyphs.entries) value: key,
};

/// Draws [puzzle] with the bridges of [arrangement] as text, one line per row
/// with a line break after each.
///
/// Throws an [ArgumentError] if [arrangement] has bridges on a connection the
/// puzzle does not offer.
String formatBridges(
  BridgesPuzzle puzzle, [
  BridgeArrangement arrangement = const BridgeArrangement.empty(),
]) {
  final width = puzzle.width;
  final horizontal = List.filled(width * puzzle.height, 0);
  final vertical = List.filled(width * puzzle.height, 0);
  for (final MapEntry(key: connection, value: count)
      in arrangement.bridges.entries) {
    if (!puzzle.hasConnection(connection)) {
      throw ArgumentError.value(
        connection,
        'arrangement',
        'Is not a connection of the puzzle',
      );
    }
    final counts = connection.isHorizontal ? horizontal : vertical;
    for (final cell in connection.cellsBetween) {
      counts[cell.y * width + cell.x] = count;
    }
  }

  final text = StringBuffer();
  for (var y = 0; y < puzzle.height; y++) {
    for (var x = 0; x < width; x++) {
      final island = puzzle.islandAt(Position(x, y));
      final index = y * width + x;
      text.write(
        island?.requiredBridges ??
            _glyphs[(horizontal[index], vertical[index])],
      );
    }
    text.writeln();
  }
  return text.toString();
}

/// Reads a board written in the notation of [formatBridges].
///
/// Leading indentation, trailing spaces and blank lines are ignored, so
/// fixtures can be indented multi-line strings. Throws a [FormatException]
/// for unknown characters, uneven rows and bridges that do not run between
/// two islands, and an [ArgumentError] if the islands break a rule of
/// [BridgesPuzzle].
({BridgesPuzzle puzzle, BridgeArrangement arrangement}) parseBridges(
  String text,
) {
  final rows = [
    for (final line in text.split('\n'))
      if (line.trim() case final row when row.isNotEmpty) row,
  ];
  if (rows.isEmpty) {
    throw FormatException('Expected at least one row', text);
  }

  final width = rows.first.length;
  final height = rows.length;
  final islands = <Island>[];
  final horizontal = List.filled(width * height, 0);
  final vertical = List.filled(width * height, 0);
  for (var y = 0; y < height; y++) {
    final row = rows[y];
    if (row.length != width) {
      throw FormatException(
        'Row ${y + 1} has ${row.length} cells, expected $width',
        row,
      );
    }
    for (var x = 0; x < width; x++) {
      final glyph = row[x];
      final requiredBridges = int.tryParse(glyph);
      if (requiredBridges != null) {
        islands.add(Island(Position(x, y), requiredBridges));
      } else if (_cellsByGlyph[glyph] case (final across, final down)) {
        horizontal[y * width + x] = across;
        vertical[y * width + x] = down;
      } else {
        throw FormatException('Unknown character "$glyph"', row, x);
      }
    }
  }

  final puzzle = BridgesPuzzle(width: width, height: height, islands: islands);
  final bridges = {
    ..._readBridges(puzzle, horizontal, Direction.right),
    ..._readBridges(puzzle, vertical, Direction.down),
  };
  return (puzzle: puzzle, arrangement: BridgeArrangement(bridges));
}

/// Collects the bridges drawn in [counts] that run in [direction], checking
/// that each joins two islands and has one count along its length.
Map<Connection, int> _readBridges(
  BridgesPuzzle puzzle,
  List<int> counts,
  Direction direction,
) {
  final width = puzzle.width;
  int countAt(Position cell) =>
      puzzle.contains(cell) ? counts[cell.y * width + cell.x] : 0;

  final bridges = <Connection, int>{};
  for (var index = 0; index < counts.length; index++) {
    final first = Position(index % width, index ~/ width);
    final count = countAt(first);
    final before = first.step(direction.opposite);
    if (count == 0 || countAt(before) != 0) {
      continue;
    }

    var after = first;
    while (countAt(after) != 0) {
      if (countAt(after) != count) {
        throw FormatException('Bridge counts change at $after');
      }
      after = after.step(direction);
    }
    if (puzzle.islandAt(before) == null || puzzle.islandAt(after) == null) {
      throw FormatException('Bridge at $first does not join two islands');
    }
    bridges[Connection(before, after)] = count;
  }
  return bridges;
}
