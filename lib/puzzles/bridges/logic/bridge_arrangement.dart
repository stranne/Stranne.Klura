import 'dart:collection';

import 'package:klura/puzzles/bridges/logic/geometry.dart';
import 'package:meta/meta.dart';

/// The bridges on a board: one or two on each connection that has any.
///
/// An arrangement is a value. Changing it returns a new arrangement, and two
/// arrangements are equal when they hold the same bridges. It does not know
/// its puzzle; `checkBridges` judges it against one.
@immutable
final class BridgeArrangement {
  /// Creates an arrangement with the given number of [bridges] on each
  /// connection.
  ///
  /// Throws an [ArgumentError] if a count is not 1 or 2. Leave a connection
  /// out to give it no bridges.
  factory BridgeArrangement(Map<Connection, int> bridges) {
    for (final MapEntry(key: connection, value: count) in bridges.entries) {
      if (count < 1 || count > maxBridges) {
        throw ArgumentError.value(
          count,
          'bridges[$connection]',
          'Must be 1 or $maxBridges',
        );
      }
    }
    return BridgeArrangement._sorted(bridges);
  }

  /// Creates an arrangement without bridges.
  const BridgeArrangement.empty() : _bridges = const {};

  BridgeArrangement._sorted(Map<Connection, int> bridges)
    : _bridges = UnmodifiableMapView({
        for (final connection in bridges.keys.toList()..sort())
          connection: bridges[connection]!,
      });

  /// The most bridges between one pair of islands.
  static const int maxBridges = 2;

  final Map<Connection, int> _bridges;

  /// The number of bridges on each connection that has any, ordered by
  /// connection.
  Map<Connection, int> get bridges => _bridges;

  /// The connections that have bridges, in order.
  Iterable<Connection> get connections => _bridges.keys;

  bool get isEmpty => _bridges.isEmpty;

  /// The number of bridges on [connection]: 0, 1 or 2.
  int operator [](Connection connection) => _bridges[connection] ?? 0;

  /// Returns a copy with [count] bridges on [connection], where 0 removes
  /// them.
  BridgeArrangement withBridges(Connection connection, int count) {
    RangeError.checkValueInInterval(count, 0, maxBridges, 'count');
    final bridges = Map.of(_bridges);
    if (count == 0) {
      bridges.remove(connection);
    } else {
      bridges[connection] = count;
    }
    return BridgeArrangement._sorted(bridges);
  }

  /// The total number of bridges with an end at [position].
  int bridgesTouching(Position position) {
    var total = 0;
    for (final MapEntry(key: connection, value: count) in _bridges.entries) {
      if (connection.touches(position)) {
        total += count;
      }
    }
    return total;
  }

  /// The connections with bridges that [connection] would cross, in order.
  List<Connection> bridgesCrossing(Connection connection) => [
    for (final other in _bridges.keys)
      if (other.crosses(connection)) other,
  ];

  @override
  bool operator ==(Object other) {
    if (other is! BridgeArrangement ||
        other._bridges.length != _bridges.length) {
      return false;
    }
    for (final MapEntry(key: connection, value: count) in _bridges.entries) {
      if (other._bridges[connection] != count) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([
    for (final MapEntry(key: connection, value: count) in _bridges.entries) ...[
      connection,
      count,
    ],
  ]);

  @override
  String toString() => 'BridgeArrangement($_bridges)';
}
