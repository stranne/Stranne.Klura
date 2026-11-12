import 'dart:convert';

import 'package:klura/core/calendar_date.dart';
import 'package:klura/core/daily_storage.dart';
import 'package:klura/core/grid.dart';
import 'package:klura/puzzles/tents/logic/tents_generator.dart';
import 'package:klura/puzzles/tents/logic/tents_marks.dart';
import 'package:klura/puzzles/tents/logic/tents_puzzle.dart';
import 'package:meta/meta.dart';

/// The version of the Tents save format, written into every saved game.
///
/// Increase it whenever the format changes, so an older or newer save is
/// never misread. A save of any other version reads as missing.
const int tentsSaveFormat = 1;

/// The longest side of a puzzle a save may hold.
///
/// It guards against a damaged save with an enormous grid, which would take
/// long to load, while leaving room for larger levels later.
const int _maxSide = 40;

/// A saved game of Tents: everything needed to pick it up again.
///
/// It holds the puzzle itself, not only the [seedKey], so a later generator
/// version never changes a game in progress. Whether the game is solved
/// follows from [puzzle] and [marks]; [wasSolved] records whether it ever
/// was, since starting over after a solve clears the board.
@immutable
final class TentsSave implements DailySave<TentsLevel> {
  /// Creates a save of a game at [level] on the calendar date of [date].
  ///
  /// Throws an [ArgumentError] if a mark lies outside the board or on a
  /// tree, or [playedTime] is negative.
  factory TentsSave({
    required TentsLevel level,
    required DateTime date,
    required String seedKey,
    required TentsPuzzle puzzle,
    required TentsMarks marks,
    Duration playedTime = Duration.zero,
    bool wasSolved = false,
  }) {
    for (final position in marks.marks.keys) {
      if (!puzzle.contains(position) || puzzle.hasTree(position)) {
        throw ArgumentError.value(
          position,
          'marks',
          'Must be a free cell of the puzzle',
        );
      }
    }
    if (playedTime.isNegative) {
      throw ArgumentError.value(
        playedTime,
        'playedTime',
        'Must not be negative',
      );
    }
    return TentsSave._(
      level: level,
      date: DateTime(date.year, date.month, date.day),
      seedKey: seedKey,
      puzzle: puzzle,
      marks: marks,
      playedTime: playedTime,
      wasSolved: wasSolved,
    );
  }

  const TentsSave._({
    required this.level,
    required this.date,
    required this.seedKey,
    required this.puzzle,
    required this.marks,
    required this.playedTime,
    required this.wasSolved,
  });

  @override
  final TentsLevel level;

  /// The day of the puzzle, at local midnight.
  @override
  final DateTime date;

  /// The key the puzzle was generated from.
  final String seedKey;

  final TentsPuzzle puzzle;

  /// The player's tents and grass.
  final TentsMarks marks;

  /// The time spent playing, which stops at the first solve.
  @override
  final Duration playedTime;

  /// Whether the game has been solved at least once.
  @override
  final bool wasSolved;

  @override
  bool operator ==(Object other) =>
      other is TentsSave &&
      other.level == level &&
      other.date == date &&
      other.seedKey == seedKey &&
      other.puzzle == puzzle &&
      other.marks == marks &&
      other.playedTime == playedTime &&
      other.wasSolved == wasSolved;

  @override
  int get hashCode => Object.hash(
    level,
    date,
    seedKey,
    puzzle,
    marks,
    playedTime,
    wasSolved,
  );

  @override
  String toString() =>
      'TentsSave(${level.name}, ${formatCalendarDate(date)}, $seedKey, '
      '$playedTime${wasSolved ? ', solved' : ''})';
}

/// Writes [save] as JSON in the current [tentsSaveFormat].
String encodeTentsSave(TentsSave save) {
  final puzzle = save.puzzle;
  return jsonEncode({
    'format': tentsSaveFormat,
    'level': save.level.name,
    'date': formatCalendarDate(save.date),
    'seedKey': save.seedKey,
    'puzzle': {
      'width': puzzle.width,
      'height': puzzle.height,
      'trees': _cells(puzzle.trees),
      'rows': puzzle.rowTents,
      'columns': puzzle.columnTents,
    },
    'tents': _cells(save.marks.tents),
    'grass': _cells(save.marks.grass),
    'playedMs': save.playedTime.inMilliseconds,
    'solved': save.wasSolved,
  });
}

/// Reads a game written by [encodeTentsSave], or returns `null` if [text]
/// is damaged, of another format version or breaks a rule of the puzzle.
TentsSave? decodeTentsSave(String text) {
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException {
    return null;
  }
  if (json case {
    'format': tentsSaveFormat,
    'level': final String levelName,
    'date': final String dateText,
    'seedKey': final String seedKey,
    'puzzle': {
      'width': final int width,
      'height': final int height,
      'trees': final List<Object?> treeItems,
      'rows': final List<Object?> rowItems,
      'columns': final List<Object?> columnItems,
    },
    'tents': final List<Object?> tentItems,
    'grass': final List<Object?> grassItems,
    'playedMs': final int playedMs,
    'solved': final bool wasSolved,
  }) {
    final level = _levels[levelName];
    final date = parseCalendarDate(dateText);
    final trees = _readCells(treeItems);
    final rowTents = _readCounts(rowItems);
    final columnTents = _readCounts(columnItems);
    final tents = _readCells(tentItems);
    final grass = _readCells(grassItems);
    if (level == null ||
        date == null ||
        width > _maxSide ||
        height > _maxSide ||
        playedMs < 0 ||
        trees == null ||
        rowTents == null ||
        columnTents == null ||
        tents == null ||
        grass == null) {
      return null;
    }
    final marks = {
      for (final tent in tents) tent: TentsMark.tent,
      for (final cell in grass) cell: TentsMark.grass,
    };
    // A cell with both a tent and grass is as damaged as any other.
    if (marks.length != tents.length + grass.length) {
      return null;
    }

    try {
      return TentsSave(
        level: level,
        date: date,
        seedKey: seedKey,
        puzzle: TentsPuzzle(
          width: width,
          height: height,
          trees: trees,
          rowTents: rowTents,
          columnTents: columnTents,
        ),
        marks: TentsMarks(marks),
        playedTime: Duration(milliseconds: playedMs),
        wasSolved: wasSolved,
      );
      // The models reject the rest of a broken save, such as a tree off the
      // board or numbers that do not add up, with an ArgumentError.
      // ignore: avoid_catching_errors
    } on ArgumentError {
      return null;
    }
  }
  return null;
}

final Map<String, TentsLevel> _levels = TentsLevel.values.asNameMap();

List<List<int>> _cells(Iterable<Position> positions) => [
  for (final Position(:x, :y) in positions) [x, y],
];

/// Reads cells written by [_cells], or returns `null` if an item is
/// malformed or names a cell twice.
List<Position>? _readCells(List<Object?> items) {
  final cells = <Position>{};
  for (final item in items) {
    if (item case [final int x, final int y] when cells.add(Position(x, y))) {
      continue;
    }
    return null;
  }
  return cells.toList();
}

List<int>? _readCounts(List<Object?> items) {
  final counts = <int>[];
  for (final item in items) {
    if (item is! int) {
      return null;
    }
    counts.add(item);
  }
  return counts;
}
