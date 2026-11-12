import 'dart:convert';

import 'package:klura/core/calendar_date.dart';
import 'package:klura/puzzles/bridges/logic/bridge_arrangement.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
import 'package:klura/puzzles/bridges/logic/bridges_puzzle.dart';
import 'package:klura/puzzles/bridges/logic/geometry.dart';
import 'package:meta/meta.dart';

/// The version of the Bridges save format, written into every saved game
/// and history.
///
/// Increase it whenever the format changes, so an older or newer save is
/// never misread. A save of any other version reads as missing.
const int bridgesSaveFormat = 1;

/// The longest side of a puzzle a save may hold.
///
/// It guards against a damaged save with an enormous grid, which would take
/// long to load, while leaving room for larger levels later.
const int _maxSide = 40;

/// A saved game of Bridges: everything needed to pick it up again.
///
/// It holds the puzzle itself, not only the [seedKey], so a later generator
/// version never changes a game in progress. Whether the game is solved
/// follows from [puzzle] and [arrangement]; [wasSolved] records whether it
/// ever was, since starting over after a solve clears the board.
@immutable
final class BridgesSave {
  /// Creates a save of a game at [level] on the calendar date of [date].
  ///
  /// Throws an [ArgumentError] if [arrangement] has bridges on a connection
  /// the puzzle does not offer, or [playedTime] is negative.
  factory BridgesSave({
    required BridgesLevel level,
    required DateTime date,
    required String seedKey,
    required BridgesPuzzle puzzle,
    required BridgeArrangement arrangement,
    Duration playedTime = Duration.zero,
    bool wasSolved = false,
  }) {
    for (final connection in arrangement.connections) {
      if (!puzzle.hasConnection(connection)) {
        throw ArgumentError.value(
          connection,
          'arrangement',
          'Is not a connection of the puzzle',
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
    return BridgesSave._(
      level: level,
      date: DateTime(date.year, date.month, date.day),
      seedKey: seedKey,
      puzzle: puzzle,
      arrangement: arrangement,
      playedTime: playedTime,
      wasSolved: wasSolved,
    );
  }

  const BridgesSave._({
    required this.level,
    required this.date,
    required this.seedKey,
    required this.puzzle,
    required this.arrangement,
    required this.playedTime,
    required this.wasSolved,
  });

  final BridgesLevel level;

  /// The day of the puzzle, at local midnight.
  final DateTime date;

  /// The key the puzzle was generated from.
  final String seedKey;

  final BridgesPuzzle puzzle;

  /// The player's bridges.
  final BridgeArrangement arrangement;

  /// The time spent playing, which stops at the first solve.
  final Duration playedTime;

  /// Whether the game has been solved at least once.
  final bool wasSolved;

  @override
  bool operator ==(Object other) =>
      other is BridgesSave &&
      other.level == level &&
      other.date == date &&
      other.seedKey == seedKey &&
      other.puzzle == puzzle &&
      other.arrangement == arrangement &&
      other.playedTime == playedTime &&
      other.wasSolved == wasSolved;

  @override
  int get hashCode => Object.hash(
    level,
    date,
    seedKey,
    puzzle,
    arrangement,
    playedTime,
    wasSolved,
  );

  @override
  String toString() =>
      'BridgesSave(${level.name}, ${formatCalendarDate(date)}, $seedKey, '
      '$playedTime${wasSolved ? ', solved' : ''})';
}

/// Writes [save] as JSON in the current [bridgesSaveFormat].
String encodeBridgesSave(BridgesSave save) {
  final puzzle = save.puzzle;
  return jsonEncode({
    'format': bridgesSaveFormat,
    'level': save.level.name,
    'date': formatCalendarDate(save.date),
    'seedKey': save.seedKey,
    'puzzle': {
      'width': puzzle.width,
      'height': puzzle.height,
      'islands': [
        for (final Island(:position, :requiredBridges) in puzzle.islands)
          [position.x, position.y, requiredBridges],
      ],
    },
    'bridges': [
      for (final MapEntry(key: Connection(:start, :end), value: count)
          in save.arrangement.bridges.entries)
        [start.x, start.y, end.x, end.y, count],
    ],
    'playedMs': save.playedTime.inMilliseconds,
    'solved': save.wasSolved,
  });
}

/// Reads a game written by [encodeBridgesSave], or returns `null` if [text]
/// is damaged, of another format version or breaks a rule of the puzzle.
BridgesSave? decodeBridgesSave(String text) {
  if (_decodeJson(text) case {
    'format': bridgesSaveFormat,
    'level': final String levelName,
    'date': final String dateText,
    'seedKey': final String seedKey,
    'puzzle': {
      'width': final int width,
      'height': final int height,
      'islands': final List<Object?> islandItems,
    },
    'bridges': final List<Object?> bridgeItems,
    'playedMs': final int playedMs,
    'solved': final bool wasSolved,
  }) {
    final level = _levels[levelName];
    final date = parseCalendarDate(dateText);
    if (level == null ||
        date == null ||
        width > _maxSide ||
        height > _maxSide ||
        playedMs < 0) {
      return null;
    }

    try {
      final islands = _readIslands(islandItems);
      final bridges = _readBridges(bridgeItems);
      if (islands == null || bridges == null) {
        return null;
      }
      return BridgesSave(
        level: level,
        date: date,
        seedKey: seedKey,
        puzzle: BridgesPuzzle(width: width, height: height, islands: islands),
        arrangement: BridgeArrangement(bridges),
        playedTime: Duration(milliseconds: playedMs),
        wasSolved: wasSolved,
      );
      // The models reject the rest of a broken save, such as islands side by
      // side or a diagonal bridge, with an ArgumentError.
      // ignore: avoid_catching_errors
    } on ArgumentError {
      return null;
    }
  }
  return null;
}

/// The puzzles solved on each day, with the time the first solve took.
///
/// The history outlives the saved games, which are removed after their day,
/// so it is the record of every day played to the end.
@immutable
final class BridgesHistory {
  /// Creates a history without solves.
  const BridgesHistory.empty() : _solves = const {};

  const BridgesHistory._(this._solves);

  /// The solve times by level, then by calendar date as `yyyy-mm-dd`.
  final Map<BridgesLevel, Map<String, Duration>> _solves;

  /// The time the first solve of the puzzle at [level] for the calendar date
  /// of [date] took, or `null` if it has not been solved.
  Duration? solveTime(BridgesLevel level, DateTime date) =>
      _solves[level]?[formatCalendarDate(date)];

  /// The days, at local midnight, with at least one solved puzzle.
  Set<DateTime> get solvedDays => {
    for (final dates in _solves.values)
      for (final date in dates.keys) parseCalendarDate(date)!,
  };

  /// Returns the history with the puzzle at [level] for the calendar date of
  /// [date] solved in [time], or this history if it already has that solve.
  ///
  /// The first solve stands, so starting over and solving again keeps its
  /// time.
  BridgesHistory withSolve(BridgesLevel level, DateTime date, Duration time) {
    final dateKey = formatCalendarDate(date);
    if (_solves[level]?.containsKey(dateKey) ?? false) {
      return this;
    }
    return BridgesHistory._({
      ..._solves,
      level: {...?_solves[level], dateKey: time},
    });
  }
}

/// Writes [history] as JSON in the current [bridgesSaveFormat].
String encodeBridgesHistory(BridgesHistory history) => jsonEncode({
  'format': bridgesSaveFormat,
  'solved': {
    for (final level in BridgesLevel.values)
      if (history._solves[level] case final dates? when dates.isNotEmpty)
        level.name: {
          for (final date in dates.keys.toList()..sort())
            date: dates[date]!.inMilliseconds,
        },
  },
});

/// Reads a history written by [encodeBridgesHistory], or returns `null` if
/// [text] is damaged or of another format version.
///
/// A damaged entry is skipped rather than losing the whole history.
BridgesHistory? decodeBridgesHistory(String text) {
  if (_decodeJson(text) case {
    'format': bridgesSaveFormat,
    'solved': final Map<Object?, Object?> solved,
  }) {
    final solves = <BridgesLevel, Map<String, Duration>>{};
    for (final MapEntry(key: levelName, value: dates) in solved.entries) {
      final level = _levels[levelName];
      if (level == null || dates is! Map<Object?, Object?>) {
        continue;
      }
      for (final MapEntry(key: dateText, value: milliseconds)
          in dates.entries) {
        final date = dateText is String ? parseCalendarDate(dateText) : null;
        if (date != null && milliseconds is int && milliseconds >= 0) {
          (solves[level] ??= {})[formatCalendarDate(date)] = Duration(
            milliseconds: milliseconds,
          );
        }
      }
    }
    return BridgesHistory._(solves);
  }
  return null;
}

final Map<String, BridgesLevel> _levels = BridgesLevel.values.asNameMap();

Object? _decodeJson(String text) {
  try {
    return jsonDecode(text);
  } on FormatException {
    return null;
  }
}

List<Island>? _readIslands(List<Object?> items) {
  final islands = <Island>[];
  for (final item in items) {
    if (item case [final int x, final int y, final int requiredBridges]) {
      islands.add(Island(Position(x, y), requiredBridges));
    } else {
      return null;
    }
  }
  return islands;
}

/// Reads the bridges, or returns `null` if an item is malformed or names a
/// connection twice.
///
/// Throws an [ArgumentError] for an item whose ends do not form a
/// connection.
Map<Connection, int>? _readBridges(List<Object?> items) {
  final bridges = <Connection, int>{};
  for (final item in items) {
    if (item case [
      final int x1,
      final int y1,
      final int x2,
      final int y2,
      final int count,
    ]) {
      final connection = Connection(Position(x1, y1), Position(x2, y2));
      if (bridges.containsKey(connection)) {
        return null;
      }
      bridges[connection] = count;
    } else {
      return null;
    }
  }
  return bridges;
}
