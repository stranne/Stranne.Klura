import 'package:klura/core/daily_seed.dart';
import 'package:klura/core/seeded_random.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_marks.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_puzzle.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_solver.dart';
import 'package:meta/meta.dart';

/// The version of the Tall Tales generator in daily seed keys.
///
/// Increase it whenever a change would build a different puzzle for an
/// existing key, so saved games never refer to a puzzle that has silently
/// changed.
const int tallTalesGeneratorVersion = 1;

/// The daily difficulty levels, each with a puzzle of its own every day.
enum TallTalesLevel {
  normal(
    TallTalesConfig(
      fishers: 7,
      minReasoning: TallTalesReasoning.advanced,
      maxReasoning: TallTalesReasoning.advanced,
      minOpenAfterBasic: 4,
    ),
  ),
  hard(
    TallTalesConfig(
      fishers: 8,
      minReasoning: TallTalesReasoning.lookahead,
      minSuppositions: 1,
      minOpenAfterBasic: 6,
    ),
  );

  const TallTalesLevel(this.config);

  final TallTalesConfig config;
}

/// What to generate: the number of fishers and the grades to accept.
@immutable
final class TallTalesConfig {
  const TallTalesConfig({
    required this.fishers,
    this.minReasoning = TallTalesReasoning.basic,
    this.maxReasoning = TallTalesReasoning.lookahead,
    this.minSuppositions = 0,
    this.minOpenAfterBasic = 0,
  });

  final int fishers;

  /// The least reasoning an accepted puzzle may need.
  final TallTalesReasoning minReasoning;

  /// The most reasoning an accepted puzzle may need. It must be below
  /// [TallTalesReasoning.search], so every accepted puzzle is solvable by
  /// reasoning alone.
  final TallTalesReasoning maxReasoning;

  /// The fewest times lookahead must suppose a fisher's kind.
  final int minSuppositions;

  /// The fewest fishers basic reasoning may leave open, so a puzzle offers
  /// enough to think about.
  final int minOpenAfterBasic;

  /// Whether a puzzle with [grade] suits this configuration.
  bool accepts(TallTalesGrade grade) =>
      grade.reasoning.index >= minReasoning.index &&
      grade.reasoning.index <= maxReasoning.index &&
      grade.suppositions >= minSuppositions &&
      grade.openAfterBasic >= minOpenAfterBasic;

  @override
  String toString() =>
      'TallTalesConfig($fishers fishers, '
      '${minReasoning.name} to ${maxReasoning.name}, '
      'at least $minSuppositions suppositions and $minOpenAfterBasic open)';
}

/// A generated puzzle together with the marking it was built from.
final class GeneratedTallTales {
  const GeneratedTallTales._({
    required this.seedKey,
    required this.puzzle,
    required this.solution,
    required this.grade,
    required this.attempts,
  });

  /// The key the puzzle was generated from.
  final String seedKey;

  final TallTalesPuzzle puzzle;

  /// The kind of every fisher the generator built the puzzle from, which is
  /// its only solution.
  ///
  /// The game judges the player with `checkTallTales`, never by comparing
  /// with these marks.
  final TallTalesMarks solution;

  /// How hard the puzzle is, as measured by [gradeTallTales].
  final TallTalesGrade grade;

  /// The number of attempts made, including the one kept.
  final int attempts;
}

/// The seed key of the puzzle of the day at [level] for the calendar date of
/// [date], such as `tall-tales-normal:v1:2026-11-13`.
String tallTalesDailySeedKey(TallTalesLevel level, DateTime date) =>
    dailySeedKey(
      puzzleId: 'tall-tales-${level.name}',
      generatorVersion: tallTalesGeneratorVersion,
      date: date,
    );

/// Generates the puzzle of the day at [level] for the calendar date of
/// [date].
GeneratedTallTales generateDailyTallTales(
  TallTalesLevel level,
  DateTime date,
) => generateTallTales(tallTalesDailySeedKey(level, date), level.config);

/// Generates a puzzle with exactly one solution from [seedKey].
///
/// Each attempt picks who tells the truth, with at least two fishers of
/// each kind, and then a statement for each fisher that is true for a
/// truth-teller and false for a teller of tall tales: first a claim at
/// random by its weight, then one of the statements of that claim. The
/// puzzle is kept only if reasoning alone solves it, which proves it has
/// exactly one solution, and its grade suits [config]. Otherwise the next
/// attempt starts from the next seed derived from [seedKey].
///
/// The same key and [config] give the same puzzle on every platform.
/// Throws an [ArgumentError] if [config] cannot be met, and a [StateError] if
/// no attempt succeeds.
GeneratedTallTales generateTallTales(String seedKey, TallTalesConfig config) {
  _checkConfig(config);

  for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
    final random = SeededRandom.fromKey('$seedKey#$attempt');
    final (puzzle, truthful) = _buildCandidate(config, random);
    final grade = gradeTallTales(puzzle);
    if (!config.accepts(grade)) {
      continue;
    }
    // Every accepted grade is below search, which already proves that the
    // puzzle has exactly one solution. The solver confirms it cheaply.
    final solution = TallTalesMarks.fromTruthful(config.fishers, truthful);
    final solutions = solveTallTales(puzzle);
    if (solutions.length != 1 || solutions.single != solution) {
      throw StateError('The grade and the solver disagree on $puzzle');
    }
    return GeneratedTallTales._(
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

/// The fewest fishers of each kind in a generated puzzle.
const int _minOfEachKind = 2;

/// The most statements in a puzzle that are about their speaker too, such
/// as `Bo and I are alike`. Each settles a fisher on its own once the player
/// knows the trick, so a few go a long way.
const int _maxAboutSpeaker = 2;

/// The most counts in a puzzle, such as `Exactly three of us tell the
/// truth`. Each depends on every fisher, so more would crowd the rest out.
const int _maxCounts = 2;

void _checkConfig(TallTalesConfig config) {
  if (config.fishers < 2 * _minOfEachKind ||
      config.fishers < TallTalesPuzzle.minFishers ||
      config.fishers > TallTalesPuzzle.maxFishers) {
    throw ArgumentError.value(
      config,
      'config',
      'Needs ${2 * _minOfEachKind} to ${TallTalesPuzzle.maxFishers} fishers',
    );
  }
  if (config.maxReasoning == TallTalesReasoning.search ||
      config.minReasoning.index > config.maxReasoning.index) {
    throw ArgumentError.value(
      config,
      'config',
      'Needs a reasoning range below search',
    );
  }
}

/// Builds a puzzle and the bit set of truth-tellers it was built from.
(TallTalesPuzzle, int) _buildCandidate(
  TallTalesConfig config,
  SeededRandom random,
) {
  final fishers = config.fishers;
  final order = [for (var fisher = 0; fisher < fishers; fisher++) fisher];
  random.shuffle(order);
  final truthCount =
      _minOfEachKind + random.nextInt(fishers - 2 * _minOfEachKind + 1);
  var truthful = 0;
  for (final fisher in order.take(truthCount)) {
    truthful |= 1 << fisher;
  }

  final statements = <TallTalesStatement>[];
  final meanings = <String>{};
  var aboutSpeaker = 0;
  var counts = 0;
  for (var speaker = 0; speaker < fishers; speaker++) {
    final tellsTruth = (truthful >> speaker) & 1 == 1;
    // Every statement the speaker can make that fits their kind, by claim,
    // leaving out any that says what another fisher has already said.
    final fitting = <TallTalesClaim, List<TallTalesStatement>>{};
    for (final statement in possibleStatements(speaker, fishers)) {
      final claim = statement.claim;
      if (claim.isAboutSpeaker && aboutSpeaker >= _maxAboutSpeaker ||
          claim.isCount && counts >= _maxCounts ||
          meanings.contains(_meaning(statement, fishers)) ||
          statement.isTrue(speaker, truthful, fishers) != tellsTruth) {
        continue;
      }
      (fitting[claim] ??= []).add(statement);
    }

    final claims = fitting.keys.toList();
    final totalWeight = claims.fold(0, (sum, claim) => sum + claim.weight);
    var pick = random.nextInt(totalWeight);
    final claim = claims.firstWhere((claim) {
      pick -= claim.weight;
      return pick < 0;
    });
    final options = fitting[claim]!;
    final statement = options[random.nextInt(options.length)];
    statements.add(statement);
    meanings.add(_meaning(statement, fishers));
    if (claim.isAboutSpeaker) {
      aboutSpeaker++;
    }
    if (claim.isCount) {
      counts++;
    }
  }
  return (TallTalesPuzzle(statements), truthful);
}

/// What [statement] says among [fishers] fishers, the same for two
/// statements that say the same thing in other words, so no two fishers
/// repeat each other.
///
/// Only counts can: among eight fishers, `Exactly three of us tell the
/// truth` says what `Exactly five of us tell tall tales` does. A claim about
/// the speaker means something else from each speaker, but reads the same,
/// so it counts as said once said by anyone.
String _meaning(TallTalesStatement statement, int fishers) =>
    switch (statement.claim) {
      TallTalesClaim.countTallTales =>
        '${TallTalesClaim.countTruthful.name} ${fishers - statement.count}',
      TallTalesClaim.countTruthful =>
        '${statement.claim.name} ${statement.count}',
      _ => '${statement.claim.name} ${statement.named.join(' ')}',
    };
