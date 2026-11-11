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
  return _Constraints(puzzle).solve(limit);
}

/// How much reasoning a puzzle needs, from an empty board, to solve without
/// trial and error.
///
/// Each level includes the ones before it.
enum BridgesReasoning {
  /// Island numbers and crossings settle every bridge, one island at a time.
  basic,

  /// Also needs the loop and connectivity rules: no bridge may close a loop,
  /// and the bridges that remain possible must still link every island.
  advanced,

  /// Also needs lookahead: trying one bridge, following its consequences and
  /// finding that it breaks a rule.
  lookahead,

  /// Needs deeper trial and error, or the puzzle has no single solution.
  search,
}

/// How hard a puzzle is for a person, as measured by [gradeBridges].
final class BridgesGrade {
  const BridgesGrade._({
    required this.reasoning,
    required this.openAfterBasic,
  });

  /// The least reasoning that solves the puzzle.
  final BridgesReasoning reasoning;

  /// How many connections basic moves leave open on an empty board: the
  /// choices a player has to think about rather than see at once.
  final int openAfterBasic;
}

/// Grades [puzzle] by the reasoning it needs and the choices it leaves open.
///
/// Any grade below [BridgesReasoning.search] also proves that the puzzle has
/// exactly one solution, because every deduction holds for every solution.
BridgesGrade gradeBridges(BridgesPuzzle puzzle) => _Constraints(puzzle).grade();

/// The rules of one puzzle, as constraints on the number of bridges on each
/// connection.
///
/// Each connection has a range of possible counts, stored in a `low` and a
/// `high` list indexed like [BridgesPuzzle.connections]. Propagation narrows
/// the ranges with the rules until nothing changes. The solver then branches
/// on the most constrained open connection. Islands are indexed like
/// [BridgesPuzzle.islands].
final class _Constraints {
  factory _Constraints(BridgesPuzzle puzzle) {
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

    return _Constraints._(
      puzzle: puzzle,
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

  _Constraints._({
    required this._puzzle,
    required this._requiredBridges,
    required this._starts,
    required this._ends,
    required this._incident,
    required this._crossing,
  });

  final BridgesPuzzle _puzzle;

  /// The number on each island.
  final Int32List _requiredBridges;

  /// The island at the start and at the end of each connection.
  final Int32List _starts;
  final Int32List _ends;

  /// The connections touching each island.
  final List<List<int>> _incident;

  /// The connections that cross each connection.
  final List<List<int>> _crossing;

  int get _islandCount => _requiredBridges.length;

  int get _connectionCount => _starts.length;

  List<BridgeArrangement> solve(int limit) {
    final solutions = <BridgeArrangement>[];
    _search(_emptyLow(), _emptyHigh(), solutions, limit);
    return List.unmodifiable(solutions);
  }

  BridgesGrade grade() {
    final low = _emptyLow();
    final high = _emptyHigh();
    final basicHolds = _propagate(low, high, basicOnly: true);
    final openAfterBasic = _openCount(low, high);

    final BridgesReasoning reasoning;
    if (!basicHolds || !_propagate(low, high)) {
      reasoning = BridgesReasoning.search;
    } else if (openAfterBasic == 0) {
      reasoning = BridgesReasoning.basic;
    } else if (_openCount(low, high) == 0) {
      reasoning = BridgesReasoning.advanced;
    } else if (_lookAhead(low, high) && _openCount(low, high) == 0) {
      reasoning = BridgesReasoning.lookahead;
    } else {
      reasoning = BridgesReasoning.search;
    }
    return BridgesGrade._(reasoning: reasoning, openAfterBasic: openAfterBasic);
  }

  Uint8List _emptyLow() => Uint8List(_connectionCount);

  Uint8List _emptyHigh() =>
      Uint8List(_connectionCount)
        ..fillRange(0, _connectionCount, BridgeArrangement.maxBridges);

  int _openCount(Uint8List low, Uint8List high) {
    var open = 0;
    for (var connection = 0; connection < _connectionCount; connection++) {
      if (low[connection] < high[connection]) {
        open++;
      }
    }
    return open;
  }

  void _search(
    Uint8List low,
    Uint8List high,
    List<BridgeArrangement> solutions,
    int limit,
  ) {
    if (!_propagate(low, high)) {
      return;
    }

    final connection = _chooseOpenConnection(low, high);
    if (connection < 0) {
      solutions.add(_arrangementOf(low));
      return;
    }

    for (
      var bridges = low[connection];
      bridges <= high[connection];
      bridges++
    ) {
      final nextLow = Uint8List.fromList(low)..[connection] = bridges;
      final nextHigh = Uint8List.fromList(high)..[connection] = bridges;
      _search(nextLow, nextHigh, solutions, limit);
      if (solutions.length >= limit) {
        return;
      }
    }
  }

  /// Narrows the ranges with one step of lookahead: a count that makes
  /// propagation fail at once is ruled out. Repeats until nothing changes.
  ///
  /// Only the lowest or highest count of a range can be ruled out, so the
  /// possible counts stay a range.
  bool _lookAhead(Uint8List low, Uint8List high) {
    if (!_propagate(low, high)) {
      return false;
    }
    var changed = true;
    while (changed) {
      changed = false;
      for (var connection = 0; connection < _connectionCount; connection++) {
        if (low[connection] == high[connection]) {
          continue;
        }
        if (!_allows(low, high, connection, low[connection])) {
          low[connection]++;
        } else if (!_allows(low, high, connection, high[connection])) {
          high[connection]--;
        } else {
          continue;
        }
        if (!_propagate(low, high)) {
          return false;
        }
        changed = true;
      }
    }
    return true;
  }

  /// Whether giving [connection] exactly [bridges] survives propagation.
  bool _allows(Uint8List low, Uint8List high, int connection, int bridges) {
    final tryLow = Uint8List.fromList(low)..[connection] = bridges;
    final tryHigh = Uint8List.fromList(high)..[connection] = bridges;
    return _propagate(tryLow, tryHigh);
  }

  /// Narrows the ranges in place until no rule narrows them further.
  ///
  /// With [basicOnly], only island numbers and crossings narrow them: the
  /// moves a player sees by looking at one island at a time.
  ///
  /// Returns `false` if a rule cannot be met. When every range is a single
  /// value and this returns `true` with every rule, the values form a
  /// solution.
  bool _propagate(Uint8List low, Uint8List high, {bool basicOnly = false}) {
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

      if (basicOnly) {
        continue;
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
