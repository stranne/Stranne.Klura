import 'dart:convert';

import 'package:klura/core/calendar_date.dart';
import 'package:klura/core/daily_storage.dart';
import 'package:klura/puzzles/logjam/logic/logjam_board.dart';
import 'package:klura/puzzles/logjam/logic/logjam_game.dart';
import 'package:klura/puzzles/logjam/logic/logjam_generator.dart';
import 'package:meta/meta.dart';

/// The version of the Logjam save format, written into every saved game.
///
/// Increase it whenever the format changes, so an older or newer save is
/// never misread. A save of any other version reads as missing.
const int logjamSaveFormat = 1;

/// A saved game of Logjam: everything needed to pick it up again.
///
/// It holds the puzzle itself, not only the [seedKey], so a later generator
/// version never changes a game in progress. The board follows from
/// [puzzle] and [moves], which also let undo reach back across a reload.
/// [wasSolved] records whether the game was ever solved, since starting
/// over after a solve clears the moves, and [bestMoves] the fewest moves of
/// any of its solves.
@immutable
final class LogjamSave implements DailySave<LogjamLevel> {
  /// Creates a save of a game at [level] on the calendar date of [date].
  ///
  /// Throws an [ArgumentError] if a move is not legal where it is played or
  /// comes after the solve, [fewestMoves] is negative, [bestMoves] is below
  /// it or [playedTime] is negative.
  factory LogjamSave({
    required LogjamLevel level,
    required DateTime date,
    required String seedKey,
    required LogjamBoard puzzle,
    required int fewestMoves,
    List<LogjamMove> moves = const [],
    int? bestMoves,
    Duration playedTime = Duration.zero,
    bool wasSolved = false,
  }) {
    // Playing the moves checks each of them.
    LogjamGame(puzzle, moves);
    if (fewestMoves < 0) {
      throw ArgumentError.value(
        fewestMoves,
        'fewestMoves',
        'Must not be negative',
      );
    }
    if (bestMoves != null && bestMoves < fewestMoves) {
      throw ArgumentError.value(
        bestMoves,
        'bestMoves',
        'Must not be below the fewest moves',
      );
    }
    if (playedTime.isNegative) {
      throw ArgumentError.value(
        playedTime,
        'playedTime',
        'Must not be negative',
      );
    }
    return LogjamSave._(
      level: level,
      date: DateTime(date.year, date.month, date.day),
      seedKey: seedKey,
      puzzle: puzzle,
      fewestMoves: fewestMoves,
      moves: List.unmodifiable(moves),
      bestMoves: bestMoves,
      playedTime: playedTime,
      wasSolved: wasSolved,
    );
  }

  const LogjamSave._({
    required this.level,
    required this.date,
    required this.seedKey,
    required this.puzzle,
    required this.fewestMoves,
    required this.moves,
    required this.bestMoves,
    required this.playedTime,
    required this.wasSolved,
  });

  @override
  final LogjamLevel level;

  /// The day of the puzzle, at local midnight.
  @override
  final DateTime date;

  /// The key the puzzle was generated from.
  final String seedKey;

  /// The board the puzzle starts from.
  final LogjamBoard puzzle;

  /// The fewest moves that solve [puzzle], shown after a solve.
  final int fewestMoves;

  /// The player's moves since the start or the last start over.
  final List<LogjamMove> moves;

  /// The fewest moves of any solve of this game, or `null` before the
  /// first solve this save has seen.
  final int? bestMoves;

  /// The time spent playing, which stops at the first solve.
  @override
  final Duration playedTime;

  /// Whether the game has been solved at least once.
  @override
  final bool wasSolved;

  @override
  bool operator ==(Object other) =>
      other is LogjamSave &&
      other.level == level &&
      other.date == date &&
      other.seedKey == seedKey &&
      other.puzzle == puzzle &&
      other.fewestMoves == fewestMoves &&
      _sameMoves(other.moves, moves) &&
      other.bestMoves == bestMoves &&
      other.playedTime == playedTime &&
      other.wasSolved == wasSolved;

  @override
  int get hashCode => Object.hash(
    level,
    date,
    seedKey,
    puzzle,
    fewestMoves,
    Object.hashAll(moves),
    bestMoves,
    playedTime,
    wasSolved,
  );

  @override
  String toString() =>
      'LogjamSave(${level.name}, ${formatCalendarDate(date)}, $seedKey, '
      '${moves.length} moves, $playedTime${wasSolved ? ', solved' : ''})';
}

/// Writes [save] as JSON in the current [logjamSaveFormat].
///
/// Each log is `[x, y, length, "row"]` or `[x, y, length, "column"]`, the
/// marked log first, and each move `[log, to]`, as in [LogjamMove].
String encodeLogjamSave(LogjamSave save) {
  final puzzle = save.puzzle;
  return jsonEncode({
    'format': logjamSaveFormat,
    'level': save.level.name,
    'date': formatCalendarDate(save.date),
    'seedKey': save.seedKey,
    'puzzle': {
      'width': puzzle.width,
      'height': puzzle.height,
      'logs': [
        for (final piece in puzzle.pieces)
          [
            piece.x,
            piece.y,
            piece.length,
            if (piece.isHorizontal) _row else _column,
          ],
      ],
    },
    'fewestMoves': save.fewestMoves,
    'moves': [
      for (final move in save.moves) [move.piece, move.to],
    ],
    'bestMoves': save.bestMoves,
    'playedMs': save.playedTime.inMilliseconds,
    'solved': save.wasSolved,
  });
}

/// Reads a game written by [encodeLogjamSave], or returns `null` if [text]
/// is damaged, of another format version or breaks a rule of the puzzle.
LogjamSave? decodeLogjamSave(String text) {
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException {
    return null;
  }
  if (json case {
    'format': logjamSaveFormat,
    'level': final String levelName,
    'date': final String dateText,
    'seedKey': final String seedKey,
    'puzzle': {
      'width': final int width,
      'height': final int height,
      'logs': final List<Object?> logItems,
    },
    'fewestMoves': final int fewestMoves,
    'moves': final List<Object?> moveItems,
    'bestMoves': final int? bestMoves,
    'playedMs': final int playedMs,
    'solved': final bool wasSolved,
  }) {
    final level = _levels[levelName];
    final date = parseCalendarDate(dateText);
    final pieces = _readPieces(logItems);
    final moves = _readMoves(moveItems);
    if (level == null ||
        date == null ||
        playedMs < 0 ||
        pieces == null ||
        moves == null) {
      return null;
    }

    try {
      return LogjamSave(
        level: level,
        date: date,
        seedKey: seedKey,
        puzzle: LogjamBoard(width: width, height: height, pieces: pieces),
        fewestMoves: fewestMoves,
        moves: moves,
        bestMoves: bestMoves,
        playedTime: Duration(milliseconds: playedMs),
        wasSolved: wasSolved,
      );
      // The models reject the rest of a broken save, such as overlapping
      // logs or a move through another log, with an ArgumentError.
      // ignore: avoid_catching_errors
    } on ArgumentError {
      return null;
    }
  }
  return null;
}

const String _row = 'row';
const String _column = 'column';

final Map<String, LogjamLevel> _levels = LogjamLevel.values.asNameMap();

/// Reads logs written by [encodeLogjamSave], or returns `null` if an item is
/// malformed.
List<LogjamPiece>? _readPieces(List<Object?> items) {
  final pieces = <LogjamPiece>[];
  for (final item in items) {
    switch (item) {
      case [final int x, final int y, final int length, _row]:
        pieces.add(LogjamPiece.horizontal(x, y, length));
      case [final int x, final int y, final int length, _column]:
        pieces.add(LogjamPiece.vertical(x, y, length));
      default:
        return null;
    }
  }
  return pieces;
}

/// Reads moves written by [encodeLogjamSave], or returns `null` if an item
/// is malformed.
List<LogjamMove>? _readMoves(List<Object?> items) {
  final moves = <LogjamMove>[];
  for (final item in items) {
    if (item case [final int piece, final int to]) {
      moves.add(LogjamMove(piece: piece, to: to));
    } else {
      return null;
    }
  }
  return moves;
}

bool _sameMoves(List<LogjamMove> first, List<LogjamMove> second) {
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
