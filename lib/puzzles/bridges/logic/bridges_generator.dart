import 'package:klura/core/daily_seed.dart';
import 'package:klura/core/grid.dart';
import 'package:klura/core/seeded_random.dart';
import 'package:klura/puzzles/bridges/logic/bridge_arrangement.dart';
import 'package:klura/puzzles/bridges/logic/bridges_puzzle.dart';
import 'package:klura/puzzles/bridges/logic/bridges_solver.dart';
import 'package:klura/puzzles/bridges/logic/geometry.dart';
import 'package:meta/meta.dart';

/// The version of the Bridges generator in daily seed keys.
///
/// Increase it whenever a change would build a different puzzle for an
/// existing key, so saved games never refer to a puzzle that has silently
/// changed.
const int bridgesGeneratorVersion = 2;

/// The daily difficulty levels, each with a puzzle of its own every day.
enum BridgesLevel {
  normal(
    BridgesConfig(
      width: 10,
      height: 10,
      islandCount: 30,
      maxReasoning: BridgesReasoning.advanced,
    ),
  ),
  hard(
    BridgesConfig(
      width: 10,
      height: 12,
      islandCount: 36,
      minReasoning: BridgesReasoning.lookahead,
      minOpenAfterBasic: 20,
    ),
  );

  const BridgesLevel(this.config);

  final BridgesConfig config;
}

/// What to generate: the board size and the grades to accept.
@immutable
final class BridgesConfig {
  const BridgesConfig({
    required this.width,
    required this.height,
    required this.islandCount,
    this.minReasoning = BridgesReasoning.basic,
    this.maxReasoning = BridgesReasoning.lookahead,
    this.minOpenAfterBasic = 0,
  });

  final int width;
  final int height;
  final int islandCount;

  /// The least reasoning an accepted puzzle may need.
  final BridgesReasoning minReasoning;

  /// The most reasoning an accepted puzzle may need. It must be below
  /// [BridgesReasoning.search], so every accepted puzzle is solvable by
  /// reasoning alone.
  final BridgesReasoning maxReasoning;

  /// The fewest connections basic moves may leave open, so a puzzle offers
  /// enough choices to think about.
  final int minOpenAfterBasic;

  /// Whether a puzzle with [grade] suits this configuration.
  bool accepts(BridgesGrade grade) =>
      grade.reasoning.index >= minReasoning.index &&
      grade.reasoning.index <= maxReasoning.index &&
      grade.openAfterBasic >= minOpenAfterBasic;

  @override
  String toString() =>
      'BridgesConfig(${width}x$height, $islandCount islands, '
      '${minReasoning.name} to ${maxReasoning.name}, '
      'at least $minOpenAfterBasic open)';
}

/// A generated puzzle together with the solution it was built from.
final class GeneratedBridges {
  const GeneratedBridges._({
    required this.seedKey,
    required this.puzzle,
    required this.solution,
    required this.grade,
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

  /// How hard the puzzle is, as measured by `gradeBridges`.
  final BridgesGrade grade;

  /// The number of attempts made, including the one kept.
  final int attempts;
}

/// The seed key of the puzzle of the day at [level] for the calendar date
/// of [date], such as `bridges-normal:v2:2026-11-11`.
String bridgesDailySeedKey(BridgesLevel level, DateTime date) => dailySeedKey(
  puzzleId: 'bridges-${level.name}',
  generatorVersion: bridgesGeneratorVersion,
  date: date,
);

/// Generates the puzzle of the day at [level] for the calendar date of
/// [date].
GeneratedBridges generateDailyBridges(BridgesLevel level, DateTime date) =>
    generateBridges(bridgesDailySeedKey(level, date), level.config);

/// Generates a puzzle with exactly one solution from [seedKey].
///
/// Each attempt grows the islands and a spanning tree of bridges together:
/// every new island is joined to the tree by a straight bridge that crosses
/// none, or splits an existing bridge in two. It then gives each bridge one
/// or two lines and numbers the islands to match. The puzzle is kept only if
/// reasoning alone solves it, which proves it has exactly one solution, and
/// its grade suits [config]. Otherwise the next attempt starts from the next
/// seed derived from [seedKey].
///
/// The same key and [config] give the same puzzle on every platform.
/// Throws an [ArgumentError] if [config] cannot be met, and a [StateError] if
/// no attempt succeeds.
GeneratedBridges generateBridges(String seedKey, BridgesConfig config) {
  _checkConfig(config);

  for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
    final random = SeededRandom.fromKey('$seedKey#$attempt');
    final candidate = _buildCandidate(config, random);
    if (candidate == null) {
      continue;
    }

    final (puzzle, solution) = candidate;
    final grade = gradeBridges(puzzle);
    if (!config.accepts(grade)) {
      continue;
    }
    // Every accepted grade is below search, which already proves that the
    // puzzle has exactly one solution. The solver confirms it cheaply.
    final solutions = solveBridges(puzzle);
    if (solutions.length != 1 || solutions.single != solution) {
      throw StateError('The grade and the solver disagree on $puzzle');
    }
    return GeneratedBridges._(
      seedKey: seedKey,
      puzzle: puzzle,
      solution: solution,
      grade: grade,
      attempts: attempt,
    );
  }

  throw StateError(
    'No puzzle for "$seedKey" with $config after $_maxAttempts attempts',
  );
}

/// The number of attempts before giving up. Daily puzzles need far fewer.
const int _maxAttempts = 1000;

/// The chance, in percent, that a bridge has two lines.
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
  if (config.maxReasoning == BridgesReasoning.search ||
      config.minReasoning.index > config.maxReasoning.index) {
    throw ArgumentError.value(
      config,
      'config',
      'Needs a reasoning range below search',
    );
  }
}

/// Builds a puzzle and the tree of bridges it was numbered from, or returns
/// `null` if the islands do not all fit or leave an edge row or column of the
/// grid empty.
(BridgesPuzzle, BridgeArrangement)? _buildCandidate(
  BridgesConfig config,
  SeededRandom random,
) {
  final board = _GrowingBoard(config.width, config.height)
    ..addFirstIsland(
      Position(random.nextInt(config.width), random.nextInt(config.height)),
    );
  while (board.islands.length < config.islandCount) {
    final moves = board.moves();
    if (moves.isEmpty) {
      return null;
    }
    board.apply(moves[random.nextInt(moves.length)]);
  }
  if (!board.fillsGrid) {
    return null;
  }

  final solution = BridgeArrangement({
    for (final connection in board.tree)
      connection: random.nextInt(100) < _doubleBridgePercent ? 2 : 1,
  });
  final puzzle = BridgesPuzzle(
    width: config.width,
    height: config.height,
    islands: [
      for (final position in board.islands)
        Island(position, solution.bridgesTouching(position)),
    ],
  );
  return (puzzle, solution);
}

/// A way to add an island at `island`: at the end of a new bridge from
/// `from`, or in the middle of the bridge it `splits`.
typedef _Move = ({Position island, Position? from, Connection? splits});

/// Islands and the spanning tree of bridges between them, grown one island
/// at a time.
///
/// The tree stays valid throughout: its bridges never cross, never pass over
/// an island and link every island. Islands never sit side by side.
final class _GrowingBoard {
  _GrowingBoard(this.width, this.height)
    : _islandAt = List.filled(width * height, false),
      _crowded = List.filled(width * height, false),
      _bridgeAt = List.filled(width * height, false),
      _islandsInRow = List.filled(height, 0),
      _islandsInColumn = List.filled(width, 0);

  final int width;
  final int height;

  /// The islands in the order they were added.
  final List<Position> islands = [];

  /// The bridges of the spanning tree.
  final List<Connection> tree = [];

  final List<bool> _islandAt;

  /// Whether each cell holds an island or sits beside one, so no new island
  /// may go there.
  final List<bool> _crowded;
  final List<bool> _bridgeAt;
  final List<int> _islandsInRow;
  final List<int> _islandsInColumn;

  /// Whether every edge row and column of the grid holds an island, so the
  /// puzzle uses the whole board.
  bool get fillsGrid =>
      _islandsInRow.first > 0 &&
      _islandsInRow.last > 0 &&
      _islandsInColumn.first > 0 &&
      _islandsInColumn.last > 0;

  void addFirstIsland(Position position) => _addIsland(position);

  /// Every way to add one island, in a fixed order.
  ///
  /// A new bridge runs straight from an island over at least one free cell
  /// to the new island, without crossing a bridge. A split puts the new
  /// island on a bridge at least two cells from either end.
  List<_Move> moves() {
    final moves = <_Move>[];
    for (final from in islands) {
      for (final direction in Direction.values) {
        var cell = from.step(direction);
        for (
          var distance = 1;
          cell.isWithin(width, height) && _isFree(cell);
          distance++
        ) {
          if (distance > 1 && !_crowded[_index(cell)]) {
            moves.add((island: cell, from: from, splits: null));
          }
          cell = cell.step(direction);
        }
      }
    }
    for (final bridge in tree) {
      final cells = bridge.cellsBetween.toList();
      for (var index = 1; index < cells.length - 1; index++) {
        if (!_crowded[_index(cells[index])]) {
          moves.add((island: cells[index], from: null, splits: bridge));
        }
      }
    }
    return moves;
  }

  void apply(_Move move) {
    final island = move.island;
    if (move.splits case final bridge?) {
      tree
        ..remove(bridge)
        ..add(Connection(bridge.start, island))
        ..add(Connection(island, bridge.end));
    } else {
      final bridge = Connection(move.from!, island);
      for (final cell in bridge.cellsBetween) {
        _bridgeAt[_index(cell)] = true;
      }
      tree.add(bridge);
    }
    _addIsland(island);
  }

  bool _isFree(Position cell) =>
      !_islandAt[_index(cell)] && !_bridgeAt[_index(cell)];

  void _addIsland(Position position) {
    _islandAt[_index(position)] = true;
    _crowded[_index(position)] = true;
    for (final direction in Direction.values) {
      final neighbor = position.step(direction);
      if (neighbor.isWithin(width, height)) {
        _crowded[_index(neighbor)] = true;
      }
    }
    _islandsInRow[position.y]++;
    _islandsInColumn[position.x]++;
    islands.add(position);
  }

  int _index(Position cell) => cell.y * width + cell.x;
}
