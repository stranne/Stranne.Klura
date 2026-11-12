import 'dart:convert';

import 'package:klura/core/calendar_date.dart';
import 'package:meta/meta.dart';

/// The version of the solve history format, written into every history.
///
/// Increase it whenever the format changes, so an older or newer history is
/// never misread. A history of any other version reads as missing.
const int solveHistoryFormat = 1;

/// The puzzles of one kind solved on each day, by level of type [L], with
/// the time the first solve took.
///
/// The history outlives the saved games, which are removed after their day,
/// so it is the record of every day played to the end.
@immutable
final class SolveHistory<L extends Enum> {
  /// Creates a history without solves.
  const SolveHistory.empty() : _solves = const {};

  const SolveHistory._(this._solves);

  /// The solve times by level, then by calendar date as `yyyy-mm-dd`.
  final Map<L, Map<String, Duration>> _solves;

  /// The time the first solve of the puzzle at [level] for the calendar date
  /// of [date] took, or `null` if it has not been solved.
  Duration? solveTime(L level, DateTime date) =>
      _solves[level]?[formatCalendarDate(date)];

  /// Returns the history with the puzzle at [level] for the calendar date of
  /// [date] solved in [time], or this history if it already has that solve.
  ///
  /// The first solve stands, so starting over and solving again keeps its
  /// time.
  SolveHistory<L> withSolve(L level, DateTime date, Duration time) {
    final dateKey = formatCalendarDate(date);
    if (_solves[level]?.containsKey(dateKey) ?? false) {
      return this;
    }
    return SolveHistory._({
      ..._solves,
      level: {...?_solves[level], dateKey: time},
    });
  }
}

/// Writes [history] as JSON in the current [solveHistoryFormat], with the
/// levels in the order of [levels] and the dates in calendar order.
///
/// For example `{"format": 1, "solved": {"normal": {"2026-11-12": 252345}}}`,
/// with each time in milliseconds.
String encodeSolveHistory<L extends Enum>(
  SolveHistory<L> history,
  List<L> levels,
) => jsonEncode({
  'format': solveHistoryFormat,
  'solved': {
    for (final level in levels)
      if (history._solves[level] case final dates? when dates.isNotEmpty)
        level.name: {
          for (final date in dates.keys.toList()..sort())
            date: dates[date]!.inMilliseconds,
        },
  },
});

/// Reads a history written by [encodeSolveHistory] for the given [levels],
/// or returns `null` if [text] is damaged or of another format version.
///
/// A damaged entry or an unknown level is skipped rather than losing the
/// whole history.
SolveHistory<L>? decodeSolveHistory<L extends Enum>(
  String text,
  List<L> levels,
) {
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException {
    return null;
  }
  if (json case {
    'format': solveHistoryFormat,
    'solved': final Map<Object?, Object?> solved,
  }) {
    final levelsByName = levels.asNameMap();
    final solves = <L, Map<String, Duration>>{};
    for (final MapEntry(key: levelName, value: dates) in solved.entries) {
      final level = levelsByName[levelName];
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
    return SolveHistory._(solves);
  }
  return null;
}
