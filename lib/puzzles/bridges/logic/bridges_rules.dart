import 'package:klura/puzzles/bridges/logic/bridge_arrangement.dart';
import 'package:klura/puzzles/bridges/logic/bridges_puzzle.dart';
import 'package:klura/puzzles/bridges/logic/geometry.dart';
import 'package:klura/puzzles/bridges/logic/union_find.dart';

/// How the bridges touching an island compare with its number.
enum IslandStatus { under, met, over }

/// The result of judging a bridge arrangement against the rules.
final class BridgesCheck {
  const BridgesCheck._({
    required this.islandStatuses,
    required this.crossings,
    required this.isConnected,
    required this.loopConnections,
  });

  /// The status of each island by position, in reading order.
  final Map<Position, IslandStatus> islandStatuses;

  /// Each pair of bridges that cross, with the earlier connection first.
  final List<(Connection, Connection)> crossings;

  /// Whether the bridges link every island into one group.
  final bool isConnected;

  /// The connections with bridges that lie on a loop, in order.
  ///
  /// A loop needs three or more islands. A double bridge between two islands
  /// is a single connection, not a loop.
  final List<Connection> loopConnections;

  bool get hasLoops => loopConnections.isNotEmpty;

  /// Whether the arrangement meets every rule, which makes it a solution.
  bool get isSolved =>
      isConnected &&
      crossings.isEmpty &&
      loopConnections.isEmpty &&
      islandStatuses.values.every((status) => status == IslandStatus.met);
}

/// Judges [arrangement] against the rules of [puzzle].
///
/// The rules are the only judge: any arrangement that meets them solves the
/// puzzle, whatever solution the generator had in mind.
///
/// Throws an [ArgumentError] if [arrangement] has bridges on a connection the
/// puzzle does not offer, such as one that passes over an island.
BridgesCheck checkBridges(
  BridgesPuzzle puzzle,
  BridgeArrangement arrangement,
) {
  final connections = arrangement.connections.toList();
  for (final connection in connections) {
    if (!puzzle.hasConnection(connection)) {
      throw ArgumentError.value(
        connection,
        'arrangement',
        'Is not a connection of the puzzle',
      );
    }
  }

  final islandStatuses = {
    for (final island in puzzle.islands)
      island.position: _statusOf(
        arrangement.bridgesTouching(island.position),
        island.requiredBridges,
      ),
  };

  final crossings = [
    for (var first = 0; first < connections.length; first++)
      for (var second = first + 1; second < connections.length; second++)
        if (connections[first].crosses(connections[second]))
          (connections[first], connections[second]),
  ];

  final indexes = {
    for (final (index, island) in puzzle.islands.indexed)
      island.position: index,
  };
  final groups = UnionFind(indexes.length);
  for (final connection in connections) {
    groups.union(indexes[connection.start]!, indexes[connection.end]!);
  }

  return BridgesCheck._(
    islandStatuses: Map.unmodifiable(islandStatuses),
    crossings: List.unmodifiable(crossings),
    isConnected: groups.groupCount <= 1,
    loopConnections: List.unmodifiable(_loopConnections(connections, indexes)),
  );
}

IslandStatus _statusOf(int bridges, int requiredBridges) {
  if (bridges < requiredBridges) {
    return IslandStatus.under;
  }
  return bridges == requiredBridges ? IslandStatus.met : IslandStatus.over;
}

/// Returns the connections whose islands stay linked without them, which are
/// exactly the connections on a loop.
List<Connection> _loopConnections(
  List<Connection> connections,
  Map<Position, int> indexes,
) => [
  for (final connection in connections)
    if (_linksWithout(connection, connections, indexes)) connection,
];

bool _linksWithout(
  Connection removed,
  List<Connection> connections,
  Map<Position, int> indexes,
) {
  final groups = UnionFind(indexes.length);
  for (final connection in connections) {
    if (connection != removed) {
      groups.union(indexes[connection.start]!, indexes[connection.end]!);
    }
  }
  return groups.connects(indexes[removed.start]!, indexes[removed.end]!);
}
