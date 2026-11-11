import 'dart:typed_data';

import 'package:klura/puzzles/bridges/logic/bridge_arrangement.dart';
import 'package:klura/puzzles/bridges/logic/bridges_puzzle.dart';
import 'package:klura/puzzles/bridges/logic/union_find.dart';

/// Finds up to [limit] distinct arrangements that solve [puzzle].
///
/// The search enforces every rule: island numbers, at most two bridges per
/// connection, no crossings, every island connected and no loops. It knows
/// nothing of how the puzzle was made. A [limit] of 2, the default, is enough
/// to tell whether a puzzle has exactly one solution.
///
/// The search is deterministic: the same puzzle always gives the same
/// solutions in the same order.
List<BridgeArrangement> solveBridges(BridgesPuzzle puzzle, {int limit = 2}) {
  if (limit < 1) {
    throw RangeError.range(limit, 1, null, 'limit');
  }
  return _Search(puzzle, limit).run();
}

/// A depth-first search over the number of bridges on each connection.
///
/// Each connection has a range of possible counts, stored in a `low` and a
/// `high` list indexed like [BridgesPuzzle.connections]. Propagation narrows
/// the ranges with every rule until nothing changes, and the search then
/// branches on the most constrained open connection. Islands are indexed like
/// [BridgesPuzzle.islands].
final class _Search {
  factory _Search(BridgesPuzzle puzzle, int limit) {
    final islandIndexes = {
      for (final (index, island) in puzzle.islands.indexed)
        island.position: index,
    };
    final connections = puzzle.connections;
    final starts = Int32List(connections.length);
    final ends = Int32List(connections.length);
    final incident = [for (final _ in puzzle.islands) <int>[]];
    for (final (index, connection) in connections.indexed) {
      starts[index] = islandIndexes[connection.start]!;
      ends[index] = islandIndexes[connection.end]!;
      incident[starts[index]].add(index);
      incident[ends[index]].add(index);
    }

    return _Search._(
      puzzle: puzzle,
      limit: limit,
      requiredBridges: Int32List.fromList([
        for (final island in puzzle.islands) island.requiredBridges,
      ]),
      starts: starts,
      ends: ends,
      incident: incident,
      crossing: [
        for (final connection in connections)
          [
            for (final (index, other) in connections.indexed)
              if (connection.crosses(other)) index,
          ],
      ],
    );
  }

  _Search._({
    required this._puzzle,
    required this._limit,
    required this._requiredBridges,
    required this._starts,
    required this._ends,
    required this._incident,
    required this._crossing,
  });

  final BridgesPuzzle _puzzle;
  final int _limit;

  /// The number on each island.
  final Int32List _requiredBridges;

  /// The island at the start and at the end of each connection.
  final Int32List _starts;
  final Int32List _ends;

  /// The connections touching each island.
  final List<List<int>> _incident;

  /// The connections that cross each connection.
  final List<List<int>> _crossing;

  final List<BridgeArrangement> _solutions = [];

  int get _islandCount => _requiredBridges.length;

  int get _connectionCount => _starts.length;

  List<BridgeArrangement> run() {
    final low = Uint8List(_connectionCount);
    final high = Uint8List(_connectionCount)
      ..fillRange(0, _connectionCount, BridgeArrangement.maxBridges);
    _search(low, high);
    return List.unmodifiable(_solutions);
  }

  void _search(Uint8List low, Uint8List high) {
    if (!_propagate(low, high)) {
      return;
    }

    final connection = _chooseOpenConnection(low, high);
    if (connection < 0) {
      _solutions.add(_arrangementOf(low));
      return;
    }

    for (
      var bridges = low[connection];
      bridges <= high[connection];
      bridges++
    ) {
      final nextLow = Uint8List.fromList(low)..[connection] = bridges;
      final nextHigh = Uint8List.fromList(high)..[connection] = bridges;
      _search(nextLow, nextHigh);
      if (_solutions.length >= _limit) {
        return;
      }
    }
  }

  /// Narrows the ranges in place until no rule narrows them further.
  ///
  /// Returns `false` if a rule cannot be met. When every range is a single
  /// value and this returns `true`, the values form a solution.
  bool _propagate(Uint8List low, Uint8List high) {
    var changed = true;
    while (changed) {
      changed = false;

      // Each island's number bounds the bridges on each of its connections
      // by what its other connections can and must carry.
      for (var island = 0; island < _islandCount; island++) {
        final incident = _incident[island];
        var lowSum = 0;
        var highSum = 0;
        for (final connection in incident) {
          lowSum += low[connection];
          highSum += high[connection];
        }
        final requiredBridges = _requiredBridges[island];
        if (lowSum > requiredBridges || highSum < requiredBridges) {
          return false;
        }
        for (final connection in incident) {
          final atLeast = requiredBridges - (highSum - high[connection]);
          final atMost = requiredBridges - (lowSum - low[connection]);
          if (atLeast > low[connection]) {
            low[connection] = atLeast;
            changed = true;
          }
          if (atMost < high[connection]) {
            high[connection] = atMost;
            changed = true;
          }
        }
      }

      // A connection that must have bridges rules out all that cross it.
      for (var connection = 0; connection < _connectionCount; connection++) {
        if (low[connection] == 0) {
          continue;
        }
        for (final other in _crossing[connection]) {
          if (low[other] > 0) {
            return false;
          }
          if (high[other] > 0) {
            high[other] = 0;
            changed = true;
          }
        }
      }

      // Connections that must have bridges may not form a loop, so no
      // connection may join two islands they already link.
      final linked = UnionFind(_islandCount);
      for (var connection = 0; connection < _connectionCount; connection++) {
        if (low[connection] > 0 &&
            !linked.union(_starts[connection], _ends[connection])) {
          return false;
        }
      }
      for (var connection = 0; connection < _connectionCount; connection++) {
        if (low[connection] == 0 &&
            high[connection] > 0 &&
            linked.connects(_starts[connection], _ends[connection])) {
          high[connection] = 0;
          changed = true;
        }
      }

      // Connections that may still have bridges must link every island. A
      // solution is a tree with one connection fewer than there are islands,
      // so if only that many remain, each of them needs a bridge.
      final reachable = UnionFind(_islandCount);
      var possibleCount = 0;
      for (var connection = 0; connection < _connectionCount; connection++) {
        if (high[connection] > 0) {
          reachable.union(_starts[connection], _ends[connection]);
          possibleCount++;
        }
      }
      if (reachable.groupCount > 1) {
        return false;
      }
      if (possibleCount == _islandCount - 1) {
        for (var connection = 0; connection < _connectionCount; connection++) {
          if (high[connection] > 0 && low[connection] == 0) {
            low[connection] = 1;
            changed = true;
          }
        }
      }
    }
    return true;
  }

  /// Returns the open connection to branch on, or -1 if all are decided.
  ///
  /// Prefers connections with two possible counts over three, then those at
  /// an island with few open connections, where a wrong guess fails fast.
  int _chooseOpenConnection(Uint8List low, Uint8List high) {
    final openAtIsland = Int32List(_islandCount);
    for (var connection = 0; connection < _connectionCount; connection++) {
      if (low[connection] < high[connection]) {
        openAtIsland[_starts[connection]]++;
        openAtIsland[_ends[connection]]++;
      }
    }

    var best = -1;
    var bestScore = 0;
    for (var connection = 0; connection < _connectionCount; connection++) {
      final span = high[connection] - low[connection];
      if (span == 0) {
        continue;
      }
      final startOpen = openAtIsland[_starts[connection]];
      final endOpen = openAtIsland[_ends[connection]];
      final score = span * 32 + (startOpen < endOpen ? startOpen : endOpen);
      if (best < 0 || score < bestScore) {
        best = connection;
        bestScore = score;
      }
    }
    return best;
  }

  BridgeArrangement _arrangementOf(Uint8List bridges) => BridgeArrangement({
    for (final (index, connection) in _puzzle.connections.indexed)
      if (bridges[index] > 0) connection: bridges[index],
  });
}
