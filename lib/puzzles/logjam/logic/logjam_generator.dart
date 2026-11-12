import 'package:klura/core/daily_seed.dart';
import 'package:klura/core/seeded_random.dart';
import 'package:klura/puzzles/logjam/logic/logjam_board.dart';
import 'package:klura/puzzles/logjam/logic/logjam_solver.dart';
import 'package:meta/meta.dart';

/// The version of the Logjam generator in daily seed keys.
///
/// Increase it whenever a change would build a different puzzle for an
/// existing key, so saved games never refer to a puzzle that has silently
/// changed.
const int logjamGeneratorVersion = 1;

/// The daily difficulty levels, each with a puzzle of its own every day.
enum LogjamLevel {
  normal(LogjamConfig(minMoves: 7, maxMoves: 9)),
  hard(LogjamConfig(minMoves: 10, maxMoves: 14));

  const LogjamLevel(this.config);

  final LogjamConfig config;
}

/// What to generate: the board, its pieces and the fewest moves to accept.
@immutable
final class LogjamConfig {
  const LogjamConfig({
    this.width = 6,
    this.height = 6,
    this.minPieces = 14,
    this.maxPieces = 16,
    this.longChance = 0.4,
    required this.minMoves,
    required this.maxMoves,
    this.maxPositions = 2000,
  });

  final int width;
  final int height;

  /// The fewest pieces an attempt places, the marked piece included.
  final int minPieces;

  /// The most pieces an attempt places, if they fit.
  final int maxPieces;

  /// The chance that a piece other than the marked one is three cells long.
  final double longChance;

  /// The fewest moves an accepted puzzle may need.
  final int minMoves;

  /// The most moves an accepted puzzle may need.
  final int maxMoves;

  /// The most positions an attempt explores before it gives up, which
  /// bounds the time and memory of one attempt.
  final int maxPositions;

  /// The row with the exit: the middle row, or the one just above it.
  int get exitRow => (height - 1) ~/ 2;

  /// Whether a puzzle that needs [moves] moves suits this configuration.
  bool accepts(int moves) => moves >= minMoves && moves <= maxMoves;

  @override
  String toString() =>
      'LogjamConfig(${width}x$height, $minPieces to $maxPieces pieces, '
      '$minMoves to $maxMoves moves, at most $maxPositions positions)';
}

/// A generated puzzle together with one shortest solution.
final class GeneratedLogjam {
  const GeneratedLogjam._({
    required this.seedKey,
    required this.puzzle,
    required this.solution,
    required this.positions,
    required this.attempts,
  });

  /// The key the puzzle was generated from.
  final String seedKey;

  /// The board the puzzle starts from.
  final LogjamBoard puzzle;

  /// One shortest way to solve the puzzle.
  ///
  /// The game accepts any moves that bring the marked piece to the exit,
  /// never only these.
  final List<LogjamMove> solution;

  /// The positions reachable from the puzzle's board, itself included.
  final int positions;

  /// The number of attempts made, including the one kept.
  final int attempts;

  /// The fewest moves the puzzle needs.
  int get fewestMoves => solution.length;
}

/// The seed key of the puzzle of the day at [level] for the calendar date of
/// [date], such as `logjam-normal:v1:2026-11-12`.
String logjamDailySeedKey(LogjamLevel level, DateTime date) => dailySeedKey(
  puzzleId: 'logjam-${level.name}',
  generatorVersion: logjamGeneratorVersion,
  date: date,
);

/// Generates the puzzle of the day at [level] for the calendar date of
/// [date].
GeneratedLogjam generateDailyLogjam(LogjamLevel level, DateTime date) =>
    generateLogjam(logjamDailySeedKey(level, date), level.config);

/// Generates a puzzle from [seedKey] whose fewest moves suit [config].
///
/// Each attempt places pieces at random and explores every position they
/// can reach by sliding, giving up beyond [LogjamConfig.maxPositions]. If
/// some of those positions are solved, the attempt takes the position
/// farthest from all of them, the one that needs the most moves, and keeps
/// it if that number suits [config]. Otherwise the next attempt starts from
/// the next seed derived from [seedKey].
///
/// The same key and [config] give the same puzzle on every platform.
/// Throws an [ArgumentError] if [config] cannot be met, and a [StateError] if
/// no attempt succeeds.
GeneratedLogjam generateLogjam(String seedKey, LogjamConfig config) {
  _checkConfig(config);

  for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
    final random = SeededRandom.fromKey('$seedKey#$attempt');
    final candidate = _buildCandidate(config, random);
    final cluster = exploreLogjam(
      candidate,
      maxPositions: config.maxPositions,
    );
    final moves = cluster?.mostMoves;
    if (cluster == null || moves == null || !config.accepts(moves)) {
      continue;
    }

    final puzzle = _inReadingOrder(cluster.farthest!);
    final solution = solveLogjam(puzzle);
    if (solution == null || solution.length != moves) {
      throw StateError('The cluster and the solver disagree on $puzzle');
    }
    return GeneratedLogjam._(
      seedKey: seedKey,
      puzzle: puzzle,
      solution: solution,
      positions: cluster.size,
      attempts: attempt,
    );
  }

  throw StateError(
    'No puzzle for "$seedKey" with $config after $_maxAttempts attempts',
  );
}

/// The number of attempts before giving up. Daily puzzles need far fewer.
const int _maxAttempts = 2000;

void _checkConfig(LogjamConfig config) {
  // A marked piece on a board two cells wide would start at the exit.
  if (config.width < 3 ||
      config.width > LogjamBoard.maxSide ||
      config.height < 2 ||
      config.height > LogjamBoard.maxSide) {
    throw ArgumentError.value(
      config,
      'config',
      'Needs a width of 3 to ${LogjamBoard.maxSide} and a height of 2 to '
          '${LogjamBoard.maxSide}',
    );
  }
  if (config.minPieces < 1 || config.minPieces > config.maxPieces) {
    throw ArgumentError.value(config, 'config', 'Needs a range of pieces');
  }
  if (config.minMoves < 1 || config.minMoves > config.maxMoves) {
    throw ArgumentError.value(config, 'config', 'Needs a range of moves');
  }
  if (config.longChance < 0 || config.longChance > 1) {
    throw ArgumentError.value(config, 'config', 'Needs a chance of 0 to 1');
  }
  if (config.maxPositions < 1) {
    throw ArgumentError.value(config, 'config', 'Needs positions to explore');
  }
}

/// Places the marked piece on the exit row and then other pieces, each on a
/// random free place, until the attempt's number of pieces is reached or no
/// piece fits.
///
/// No other piece lies along the exit row: one to the right of the marked
/// piece would block it for good, and one to its left would only shorten
/// its row.
LogjamBoard _buildCandidate(LogjamConfig config, SeededRandom random) {
  final width = config.width;
  final height = config.height;
  final exitRow = config.exitRow;
  final occupied = List.filled(width * height, false);
  final pieces = <LogjamPiece>[];

  void place(LogjamPiece piece) {
    pieces.add(piece);
    for (final cell in piece.cells) {
      occupied[cell.y * width + cell.x] = true;
    }
  }

  bool fits(LogjamPiece piece) => piece.cells.every(
    (cell) => !occupied[cell.y * width + cell.x],
  );

  List<LogjamPiece> placements(int length) => [
    for (var y = 0; y < height; y++)
      for (var x = 0; x < width; x++) ...[
        if (y != exitRow && x + length <= width)
          if (LogjamPiece.horizontal(x, y, length) case final piece
              when fits(piece))
            piece,
        if (y + length <= height)
          if (LogjamPiece.vertical(x, y, length) case final piece
              when fits(piece))
            piece,
      ],
  ];

  place(
    LogjamPiece.horizontal(
      random.nextInt(width - LogjamPiece.minLength + 1),
      exitRow,
      LogjamPiece.minLength,
    ),
  );
  final pieceCount =
      config.minPieces +
      random.nextInt(config.maxPieces - config.minPieces + 1);
  while (pieces.length < pieceCount) {
    final long = random.nextChance(config.longChance);
    var options = placements(long ? 3 : 2);
    if (options.isEmpty) {
      options = placements(long ? 2 : 3);
    }
    if (options.isEmpty) {
      break;
    }
    place(options[random.nextInt(options.length)]);
  }
  return LogjamBoard(width: width, height: height, pieces: pieces);
}

/// The same board with the pieces after the marked one in the reading order
/// of their first cells, so their letters in the text notation read from
/// the top left.
LogjamBoard _inReadingOrder(LogjamBoard board) => LogjamBoard(
  width: board.width,
  height: board.height,
  pieces: [
    board.marked,
    ...board.pieces.skip(1).toList()
      ..sort((a, b) => a.cells.first.compareTo(b.cells.first)),
  ],
);
