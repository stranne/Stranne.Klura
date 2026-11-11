import 'package:klura/core/daily_seed.dart';
import 'package:klura/core/seeded_random.dart';
import 'package:klura/puzzles/bridges/logic/bridge_arrangement.dart';
import 'package:klura/puzzles/bridges/logic/bridges_puzzle.dart';
import 'package:klura/puzzles/bridges/logic/bridges_solver.dart';
import 'package:klura/puzzles/bridges/logic/geometry.dart';
import 'package:klura/puzzles/bridges/logic/union_find.dart';
import 'package:meta/meta.dart';

/// The version of the Bridges generator in daily seed keys.
///
/// Increase it whenever a change would build a different puzzle for an
/// existing key, so saved games never refer to a puzzle that has silently
/// changed.
const int bridgesGeneratorVersion = 1;

/// The size of the puzzles to generate.
@immutable
final class BridgesConfig {
  const BridgesConfig({
    required this.width,
    required this.height,
    required this.islandCount,
  });

  /// The configuration of the puzzle of the day.
  static const BridgesConfig daily = BridgesConfig(
    width: 7,
    height: 9,
    islandCount: 16,
  );

  final int width;
  final int height;
  final int islandCount;

  @override
  String toString() => 'BridgesConfig(${width}x$height, $islandCount islands)';
}

/// A generated puzzle together with the solution it was built from.
final class GeneratedBridges {
  const GeneratedBridges._({
    required this.seedKey,
    required this.puzzle,
    required this.solution,
    required this.attempts,
  });

  /// The key the puzzle was generated from.
  final String seedKey;

  final BridgesPuzzle puzzle;

  /// The bridges the generator built the puzzle from, which are its only
  /// solution.
  ///
  /// The game judges the player with `checkBridges`, never by comparing with
  /// this arrangement.
  final BridgeArrangement solution;

  /// The number of layouts tried, including the one kept.
  final int attempts;
}

/// The seed key of the puzzle of the day for the calendar date of [date],
/// such as `bridges:v1:2026-11-11`.
String bridgesDailySeedKey(DateTime date) => dailySeedKey(
  puzzleId: 'bridges',
  generatorVersion: bridgesGeneratorVersion,
  date: date,
);

/// Generates the puzzle of the day for the calendar date of [date].
GeneratedBridges generateDailyBridges(DateTime date) =>
    generateBridges(bridgesDailySeedKey(date));

/// Generates a puzzle with exactly one solution from [seedKey].
///
/// Each attempt places the islands, links them with a random spanning tree
/// of straight, non-crossing connections, gives each connection one or two
/// bridges and numbers the islands to match. The solver then decides: the
/// puzzle is kept only if the tree is its single solution. Otherwise the
/// next attempt starts from the next seed derived from [seedKey].
///
/// The same key and [config] give the same puzzle on every platform.
/// Throws an [ArgumentError] if [config] cannot hold the islands apart, and
/// a [StateError] if no attempt succeeds.
GeneratedBridges generateBridges(
  String seedKey, {
  BridgesConfig config = BridgesConfig.daily,
}) {
  _checkConfig(config);

  for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
    final random = SeededRandom.fromKey('$seedKey#$attempt');
    final candidate = _buildCandidate(config, random);
    if (candidate == null) {
      continue;
    }

    final (puzzle, solution) = candidate;
    final solutions = solveBridges(puzzle);
    if (solutions.length != 1) {
      continue;
    }
    if (solutions.single != solution) {
      throw StateError('The solver missed the generated solution: $puzzle');
    }
    return GeneratedBridges._(
      seedKey: seedKey,
      puzzle: puzzle,
      solution: solution,
      attempts: attempt,
    );
  }

  throw StateError(
    'No unique puzzle for "$seedKey" with $config after $_maxAttempts '
    'attempts',
  );
}

/// The number of attempts before giving up. Daily puzzles need far fewer.
const int _maxAttempts = 1000;

/// The chance, in percent, that a connection gets two bridges.
const int _doubleBridgePercent = 35;

void _checkConfig(BridgesConfig config) {
  if (config.width < 1 || config.height < 1) {
    throw ArgumentError.value(config, 'config', 'Needs at least one cell');
  }
  // Islands never sit side by side, so at most every other cell holds one.
  final maxIslands = (config.width * config.height + 1) ~/ 2;
  if (config.islandCount < 2 || config.islandCount > maxIslands) {
    throw ArgumentError.value(
      config,
      'config',
      'Needs 2 to $maxIslands islands',
    );
  }
}

/// Builds a puzzle and the tree of bridges it was numbered from, or returns
/// `null` if the islands cannot all be placed, leave an edge row or column of
/// the grid empty, or cannot all be linked.
(BridgesPuzzle, BridgeArrangement)? _buildCandidate(
  BridgesConfig config,
  SeededRandom random,
) {
  final layout = _placeIslands(config, random);
  if (layout == null || !layout.fillsGrid) {
    return null;
  }
  final tree = _spanningTree(layout, random);
  if (tree == null) {
    return null;
  }

  final solution = BridgeArrangement({
    for (final connection in tree)
      connection: random.nextInt(100) < _doubleBridgePercent ? 2 : 1,
  });
  final puzzle = BridgesPuzzle(
    width: config.width,
    height: config.height,
    islands: [
      for (final position in layout.islands)
        Island(position, solution.bridgesTouching(position)),
    ],
  );
  return (puzzle, solution);
}

/// Places the islands one at a time on random cells that keep a gap to
/// every island and face at least one along their row or column.
_Layout? _placeIslands(BridgesConfig config, SeededRandom random) {
  final layout = _Layout(config.width, config.height)
    ..place(
      Position(random.nextInt(config.width), random.nextInt(config.height)),
    );

  while (layout.islands.length < config.islandCount) {
    final candidates = [
      for (var y = 0; y < config.height; y++)
        for (var x = 0; x < config.width; x++)
          if (layout.canPlace(Position(x, y))) Position(x, y),
    ];
    if (candidates.isEmpty) {
      return null;
    }
    layout.place(candidates[random.nextInt(candidates.length)]);
  }
  return layout;
}

/// Links the islands with a random spanning tree of connections that never
/// cross, or returns `null` if the random order leaves an island out.
///
/// This is Kruskal's algorithm over the connections in random order,
/// skipping each connection that would close a loop or cross one already
/// chosen.
List<Connection>? _spanningTree(_Layout layout, SeededRandom random) {
  final islands = layout.islands;
  final indexes = {
    for (final (index, position) in islands.indexed) position: index,
  };
  final candidates = [
    for (final position in islands)
      for (final direction in const [Direction.right, Direction.down])
        if (layout.nearestIsland(position, direction) case final other?)
          Connection(position, other),
  ];
  random.shuffle(candidates);

  final groups = UnionFind(islands.length);
  final tree = <Connection>[];
  for (final connection in candidates) {
    final start = indexes[connection.start]!;
    final end = indexes[connection.end]!;
    if (groups.connects(start, end) || tree.any(connection.crosses)) {
      continue;
    }
    groups.union(start, end);
    tree.add(connection);
  }
  return tree.length == islands.length - 1 ? tree : null;
}

/// The islands placed so far, in the order they were placed.
final class _Layout {
  _Layout(this.width, this.height)
    : _occupied = List.filled(width * height, false),
      _islandsInRow = List.filled(height, 0),
      _islandsInColumn = List.filled(width, 0);

  final int width;
  final int height;
  final List<bool> _occupied;
  final List<int> _islandsInRow;
  final List<int> _islandsInColumn;
  final List<Position> islands = [];

  /// Whether every edge row and column of the grid holds an island, so the
  /// puzzle uses the whole board.
  bool get fillsGrid =>
      _islandsInRow.first > 0 &&
      _islandsInRow.last > 0 &&
      _islandsInColumn.first > 0 &&
      _islandsInColumn.last > 0;

  bool hasIsland(Position position) =>
      position.isWithin(width, height) &&
      _occupied[position.y * width + position.x];

  void place(Position position) {
    _occupied[position.y * width + position.x] = true;
    _islandsInRow[position.y]++;
    _islandsInColumn[position.x]++;
    islands.add(position);
  }

  /// The nearest island from [from] in [direction], or `null` if there is
  /// none before the edge.
  Position? nearestIsland(Position from, Direction direction) {
    for (
      var position = from.step(direction);
      position.isWithin(width, height);
      position = position.step(direction)
    ) {
      if (_occupied[position.y * width + position.x]) {
        return position;
      }
    }
    return null;
  }

  /// Whether an island at [position] would keep a gap to every island and
  /// face at least one of them, which it does whenever its row or column
  /// already holds an island.
  bool canPlace(Position position) =>
      (_islandsInRow[position.y] > 0 || _islandsInColumn[position.x] > 0) &&
      !hasIsland(position) &&
      !Direction.values.any(
        (direction) => hasIsland(position.step(direction)),
      );
}
