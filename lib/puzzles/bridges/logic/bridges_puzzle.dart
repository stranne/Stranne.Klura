import 'package:klura/puzzles/bridges/logic/geometry.dart';
import 'package:meta/meta.dart';

/// An island on a Bridges board.
@immutable
final class Island {
  const Island(this.position, this.requiredBridges);

  final Position position;

  /// The number shown on the island: how many bridges must touch it.
  final int requiredBridges;

  @override
  bool operator ==(Object other) =>
      other is Island &&
      other.position == position &&
      other.requiredBridges == requiredBridges;

  @override
  int get hashCode => Object.hash(position, requiredBridges);

  @override
  String toString() => 'Island($position, $requiredBridges)';
}

/// A Bridges puzzle: a grid with numbered islands and no bridges.
///
/// The player's bridges are a separate value, a `BridgeArrangement`, and
/// `checkBridges` judges them against the rules. The puzzle holds no solution.
///
/// Islands never sit side by side in a row or column, so every bridge spans
/// at least one empty cell and stays visible.
@immutable
final class BridgesPuzzle {
  /// Creates a puzzle of [width] by [height] cells holding [islands].
  ///
  /// Throws an [ArgumentError] if the grid is empty, an island lies outside
  /// it, two islands share a cell or sit side by side, or an island needs
  /// fewer than one or more than [maxRequiredBridges] bridges.
  factory BridgesPuzzle({
    required int width,
    required int height,
    required Iterable<Island> islands,
  }) {
    if (width < 1) {
      throw RangeError.range(width, 1, null, 'width');
    }
    if (height < 1) {
      throw RangeError.range(height, 1, null, 'height');
    }

    final sorted = islands.toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    final islandsAt = <Position, Island>{};
    for (final island in sorted) {
      final position = island.position;
      if (!position.isWithin(width, height)) {
        throw ArgumentError.value(island, 'islands', 'Lies outside the grid');
      }
      if (island.requiredBridges < 1 ||
          island.requiredBridges > maxRequiredBridges) {
        throw ArgumentError.value(
          island,
          'islands',
          'Must need 1 to $maxRequiredBridges bridges',
        );
      }
      if (islandsAt.containsKey(position)) {
        throw ArgumentError.value(island, 'islands', 'Shares a cell');
      }
      islandsAt[position] = island;
    }

    final connections = <Connection>[];
    for (final island in sorted) {
      for (final direction in const [Direction.right, Direction.down]) {
        final position = island.position;
        if (islandsAt.containsKey(position.step(direction))) {
          throw ArgumentError.value(
            island,
            'islands',
            'Sits beside another island',
          );
        }
        final other = _neighbor(islandsAt, width, height, position, direction);
        if (other != null) {
          connections.add(Connection(position, other.position));
        }
      }
    }

    return BridgesPuzzle._(
      width: width,
      height: height,
      islands: List.unmodifiable(sorted),
      connections: List.unmodifiable(connections),
      islandsAt: Map.unmodifiable(islandsAt),
    );
  }

  BridgesPuzzle._({
    required this.width,
    required this.height,
    required this.islands,
    required this.connections,
    required this._islandsAt,
  }) : _connectionSet = connections.toSet();

  /// The most bridges an island can need: two in each direction.
  static const int maxRequiredBridges = 8;

  final int width;
  final int height;

  /// The islands in reading order: by row, then by column.
  final List<Island> islands;

  /// Every place a bridge can go, in order: each pair of islands that face
  /// each other along a row or column with no island between them.
  final List<Connection> connections;

  final Map<Position, Island> _islandsAt;
  final Set<Connection> _connectionSet;

  /// Whether [position] lies on the board.
  bool contains(Position position) => position.isWithin(width, height);

  /// The island at [position], or `null` if the cell is empty.
  Island? islandAt(Position position) => _islandsAt[position];

  /// The nearest island from [from] in [direction], not counting an island at
  /// [from] itself, or `null` if there is none before the edge.
  Island? neighbor(Position from, Direction direction) =>
      _neighbor(_islandsAt, width, height, from, direction);

  /// Whether [connection] is one of [connections].
  bool hasConnection(Connection connection) =>
      _connectionSet.contains(connection);

  /// Whether an island lies strictly between the ends of [connection].
  bool passesOverIsland(Connection connection) =>
      connection.cellsBetween.any(_islandsAt.containsKey);

  @override
  bool operator ==(Object other) =>
      other is BridgesPuzzle &&
      other.width == width &&
      other.height == height &&
      _listEquals(other.islands, islands);

  @override
  int get hashCode => Object.hash(width, height, Object.hashAll(islands));

  @override
  String toString() => 'BridgesPuzzle(${width}x$height, $islands)';
}

Island? _neighbor(
  Map<Position, Island> islandsAt,
  int width,
  int height,
  Position from,
  Direction direction,
) {
  for (
    var position = from.step(direction);
    position.isWithin(width, height);
    position = position.step(direction)
  ) {
    if (islandsAt[position] case final island?) {
      return island;
    }
  }
  return null;
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
