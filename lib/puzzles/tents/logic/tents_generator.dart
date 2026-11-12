import 'package:klura/core/daily_seed.dart';
import 'package:klura/core/grid.dart';
import 'package:klura/core/seeded_random.dart';
import 'package:klura/puzzles/tents/logic/tents_marks.dart';
import 'package:klura/puzzles/tents/logic/tents_puzzle.dart';
import 'package:klura/puzzles/tents/logic/tents_solver.dart';
import 'package:meta/meta.dart';

/// The version of the Tents generator in daily seed keys.
///
/// Increase it whenever a change would build a different puzzle for an
/// existing key, so saved games never refer to a puzzle that has silently
/// changed.
const int tentsGeneratorVersion = 1;

/// The daily difficulty levels, each with a puzzle of its own every day.
enum TentsLevel {
  normal(
    TentsConfig(
      width: 8,
      height: 8,
      tentCount: 12,
      minReasoning: TentsReasoning.advanced,
      maxReasoning: TentsReasoning.advanced,
      minOpenAfterBasic: 10,
    ),
  ),
  hard(
    TentsConfig(
      width: 10,
      height: 10,
      tentCount: 20,
      minReasoning: TentsReasoning.lookahead,
    ),
  );

  const TentsLevel(this.config);

  final TentsConfig config;
}

/// What to generate: the board size and the grades to accept.
@immutable
final class TentsConfig {
  const TentsConfig({
    required this.width,
    required this.height,
    required this.tentCount,
    this.minReasoning = TentsReasoning.basic,
    this.maxReasoning = TentsReasoning.lookahead,
    this.minOpenAfterBasic = 0,
  });

  final int width;
  final int height;

  /// The number of trees, which is also the number of tents.
  final int tentCount;

  /// The least reasoning an accepted puzzle may need.
  final TentsReasoning minReasoning;

  /// The most reasoning an accepted puzzle may need. It must be below
  /// [TentsReasoning.search], so every accepted puzzle is solvable by
  /// reasoning alone.
  final TentsReasoning maxReasoning;

  /// The fewest cells basic reasoning may leave open, so a puzzle offers
  /// enough choices to think about.
  final int minOpenAfterBasic;

  /// Whether a puzzle with [grade] suits this configuration.
  bool accepts(TentsGrade grade) =>
      grade.reasoning.index >= minReasoning.index &&
      grade.reasoning.index <= maxReasoning.index &&
      grade.openAfterBasic >= minOpenAfterBasic;

  @override
  String toString() =>
      'TentsConfig(${width}x$height, $tentCount tents, '
      '${minReasoning.name} to ${maxReasoning.name}, '
      'at least $minOpenAfterBasic open)';
}

/// A generated puzzle together with the solution it was built from.
final class GeneratedTents {
  const GeneratedTents._({
    required this.seedKey,
    required this.puzzle,
    required this.solution,
    required this.grade,
    required this.attempts,
  });

  /// The key the puzzle was generated from.
  final String seedKey;

  final TentsPuzzle puzzle;

  /// The tents the generator built the puzzle from, which are its only
  /// solution.
  ///
  /// The game judges the player with `checkTents`, never by comparing with
  /// these marks.
  final TentsMarks solution;

  /// How hard the puzzle is, as measured by `gradeTents`.
  final TentsGrade grade;

  /// The number of attempts made, including the one kept.
  final int attempts;
}

/// The seed key of the puzzle of the day at [level] for the calendar date of
/// [date], such as `tents-normal:v1:2026-11-12`.
String tentsDailySeedKey(TentsLevel level, DateTime date) => dailySeedKey(
  puzzleId: 'tents-${level.name}',
  generatorVersion: tentsGeneratorVersion,
  date: date,
);

/// Generates the puzzle of the day at [level] for the calendar date of
/// [date].
GeneratedTents generateDailyTents(TentsLevel level, DateTime date) =>
    generateTents(tentsDailySeedKey(level, date), level.config);

/// Generates a puzzle with exactly one solution from [seedKey].
///
/// Each attempt places the tents one at a time, each on a random free cell
/// that touches no other tent, with its tree on a random free cell directly
/// beside it, and numbers the rows and columns to match. The puzzle is kept
/// only if reasoning alone solves it, which proves it has exactly one
/// solution, and its grade suits [config]. Otherwise the next attempt starts
/// from the next seed derived from [seedKey].
///
/// The same key and [config] give the same puzzle on every platform.
/// Throws an [ArgumentError] if [config] cannot be met, and a [StateError] if
/// no attempt succeeds.
GeneratedTents generateTents(String seedKey, TentsConfig config) {
  _checkConfig(config);

  for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
    final random = SeededRandom.fromKey('$seedKey#$attempt');
    final candidate = _buildCandidate(config, random);
    if (candidate == null) {
      continue;
    }

    final (puzzle, solution) = candidate;
    final grade = gradeTents(puzzle);
    if (!config.accepts(grade)) {
      continue;
    }
    // Every accepted grade is below search, which already proves that the
    // puzzle has exactly one solution. The solver confirms it cheaply.
    final solutions = solveTents(puzzle);
    if (solutions.length != 1 || solutions.single != solution) {
      throw StateError('The grade and the solver disagree on $puzzle');
    }
    return GeneratedTents._(
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

void _checkConfig(TentsConfig config) {
  if (config.width < 1 || config.height < 1) {
    throw ArgumentError.value(config, 'config', 'Needs at least one cell');
  }
  // No tent touches another, so each keeps a block of 2 by 2 cells to
  // itself, and its tree needs a cell too: tents fill at most a quarter of
  // the board.
  final maxTents = (config.width * config.height) ~/ 4;
  if (config.tentCount < 1 || config.tentCount > maxTents) {
    throw ArgumentError.value(config, 'config', 'Needs 1 to $maxTents tents');
  }
  if (config.maxReasoning == TentsReasoning.search ||
      config.minReasoning.index > config.maxReasoning.index) {
    throw ArgumentError.value(
      config,
      'config',
      'Needs a reasoning range below search',
    );
  }
}

/// Builds a puzzle and the tents it was numbered from, or returns `null` if
/// the tents do not all fit.
(TentsPuzzle, TentsMarks)? _buildCandidate(
  TentsConfig config,
  SeededRandom random,
) {
  final width = config.width;
  final height = config.height;
  final tents = <Position>[];
  final trees = <Position>[];
  final isTree = List.filled(width * height, false);
  final isTent = List.filled(width * height, false);
  // A cell with a tent or touching one, where no new tent may go.
  final crowded = List.filled(width * height, false);

  for (var count = 0; count < config.tentCount; count++) {
    final moves = <(Position, Position)>[];
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final tent = Position(x, y);
        if (crowded[y * width + x] || isTree[y * width + x]) {
          continue;
        }
        for (final direction in Direction.values) {
          final tree = tent.step(direction);
          if (tree.isWithin(width, height) &&
              !isTree[tree.y * width + tree.x] &&
              !isTent[tree.y * width + tree.x]) {
            moves.add((tent, tree));
          }
        }
      }
    }
    if (moves.isEmpty) {
      return null;
    }

    final (tent, tree) = moves[random.nextInt(moves.length)];
    tents.add(tent);
    trees.add(tree);
    isTent[tent.y * width + tent.x] = true;
    isTree[tree.y * width + tree.x] = true;
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final cell = Position(tent.x + dx, tent.y + dy);
        if (cell.isWithin(width, height)) {
          crowded[cell.y * width + cell.x] = true;
        }
      }
    }
  }

  final rowTents = List.filled(height, 0);
  final columnTents = List.filled(width, 0);
  for (final tent in tents) {
    rowTents[tent.y]++;
    columnTents[tent.x]++;
  }
  final puzzle = TentsPuzzle(
    width: width,
    height: height,
    trees: trees,
    rowTents: rowTents,
    columnTents: columnTents,
  );
  final solution = TentsMarks({for (final tent in tents) tent: TentsMark.tent});
  return (puzzle, solution);
}
