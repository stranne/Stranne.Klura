import 'dart:convert';

import 'package:klura/core/calendar_date.dart';
import 'package:klura/core/daily_storage.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_generator.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_marks.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_puzzle.dart';
import 'package:meta/meta.dart';

/// The version of the Tall Tales save format, written into every saved
/// game.
///
/// Increase it whenever the format changes, so an older or newer save is
/// never misread. A save of any other version reads as missing.
const int tallTalesSaveFormat = 1;

/// A saved game of Tall Tales: everything needed to pick it up again.
///
/// It holds the puzzle itself, not only the [seedKey], so a later generator
/// version never changes a game in progress. Whether the game is solved
/// follows from [puzzle] and [marks]; [wasSolved] records whether it ever
/// was, since starting over after a solve clears the marks.
@immutable
final class TallTalesSave implements DailySave<TallTalesLevel> {
  /// Creates a save of a game at [level] on the calendar date of [date].
  ///
  /// Throws an [ArgumentError] if [marks] is not for as many fishers as
  /// [puzzle] has, or [playedTime] is negative.
  factory TallTalesSave({
    required TallTalesLevel level,
    required DateTime date,
    required String seedKey,
    required TallTalesPuzzle puzzle,
    required TallTalesMarks marks,
    Duration playedTime = Duration.zero,
    bool wasSolved = false,
  }) {
    if (marks.length != puzzle.fisherCount) {
      throw ArgumentError.value(
        marks,
        'marks',
        'Must mark the ${puzzle.fisherCount} fishers of the puzzle',
      );
    }
    if (playedTime.isNegative) {
      throw ArgumentError.value(
        playedTime,
        'playedTime',
        'Must not be negative',
      );
    }
    return TallTalesSave._(
      level: level,
      date: DateTime(date.year, date.month, date.day),
      seedKey: seedKey,
      puzzle: puzzle,
      marks: marks,
      playedTime: playedTime,
      wasSolved: wasSolved,
    );
  }

  const TallTalesSave._({
    required this.level,
    required this.date,
    required this.seedKey,
    required this.puzzle,
    required this.marks,
    required this.playedTime,
    required this.wasSolved,
  });

  @override
  final TallTalesLevel level;

  /// The day of the puzzle, at local midnight.
  @override
  final DateTime date;

  /// The key the puzzle was generated from.
  final String seedKey;

  final TallTalesPuzzle puzzle;

  /// The player's marks.
  final TallTalesMarks marks;

  /// The time spent playing, which stops at the first solve.
  @override
  final Duration playedTime;

  /// Whether the game has been solved at least once.
  @override
  final bool wasSolved;

  @override
  bool operator ==(Object other) =>
      other is TallTalesSave &&
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
      'TallTalesSave(${level.name}, ${formatCalendarDate(date)}, $seedKey, '
      '$playedTime${wasSolved ? ', solved' : ''})';
}

/// Writes [save] as JSON in the current [tallTalesSaveFormat].
///
/// Each statement is its claim with the fishers it names, such as
/// `{"claim": "alike", "named": [1, 3]}`, or its count, such as
/// `{"claim": "countTruthful", "count": 3}`. Each mark is `truth`,
/// `tallTales` or `null`.
String encodeTallTalesSave(TallTalesSave save) => jsonEncode({
  'format': tallTalesSaveFormat,
  'level': save.level.name,
  'date': formatCalendarDate(save.date),
  'seedKey': save.seedKey,
  'statements': [
    for (final statement in save.puzzle.statements)
      if (statement.claim.isCount)
        {'claim': statement.claim.name, 'count': statement.count}
      else
        {'claim': statement.claim.name, 'named': statement.named},
  ],
  'marks': [for (final mark in save.marks.marks) mark?.name],
  'playedMs': save.playedTime.inMilliseconds,
  'solved': save.wasSolved,
});

/// Reads a game written by [encodeTallTalesSave], or returns `null` if
/// [text] is damaged, of another format version or breaks a rule of the
/// puzzle.
TallTalesSave? decodeTallTalesSave(String text) {
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException {
    return null;
  }
  if (json case {
    'format': tallTalesSaveFormat,
    'level': final String levelName,
    'date': final String dateText,
    'seedKey': final String seedKey,
    'statements': final List<Object?> statementItems,
    'marks': final List<Object?> markItems,
    'playedMs': final int playedMs,
    'solved': final bool wasSolved,
  }) {
    final level = _levels[levelName];
    final date = parseCalendarDate(dateText);
    final marks = _readMarks(markItems);
    if (level == null || date == null || playedMs < 0 || marks == null) {
      return null;
    }

    try {
      final statements = _readStatements(statementItems);
      if (statements == null) {
        return null;
      }
      return TallTalesSave(
        level: level,
        date: date,
        seedKey: seedKey,
        puzzle: TallTalesPuzzle(statements),
        marks: TallTalesMarks(marks),
        playedTime: Duration(milliseconds: playedMs),
        wasSolved: wasSolved,
      );
      // The models reject the rest of a broken save, such as a statement
      // that names its speaker or marks for too few fishers, with an
      // ArgumentError.
      // ignore: avoid_catching_errors
    } on ArgumentError {
      return null;
    }
  }
  return null;
}

final Map<String, TallTalesLevel> _levels = TallTalesLevel.values.asNameMap();
final Map<String, TallTalesClaim> _claims = TallTalesClaim.values.asNameMap();
final Map<String, TallTalesMark> _marks = TallTalesMark.values.asNameMap();

/// Reads statements written by [encodeTallTalesSave], or returns `null` if
/// one is malformed.
///
/// Throws an [ArgumentError] if a statement names the wrong number of
/// fishers or counts too few, as [TallTalesStatement] does.
List<TallTalesStatement>? _readStatements(List<Object?> items) {
  final statements = <TallTalesStatement>[];
  for (final item in items) {
    switch (item) {
      case {'claim': final String claimName, 'count': final int count}
          when _claims[claimName] != null:
        statements.add(TallTalesStatement.count(_claims[claimName]!, count));
      case {'claim': final String claimName, 'named': final List<Object?> named}
          when _claims[claimName] != null && named.every((f) => f is int):
        statements.add(
          TallTalesStatement(_claims[claimName]!, named.cast<int>()),
        );
      default:
        return null;
    }
  }
  return statements;
}

/// Reads marks written by [encodeTallTalesSave], or returns `null` if one is
/// malformed.
List<TallTalesMark?>? _readMarks(List<Object?> items) {
  final marks = <TallTalesMark?>[];
  for (final item in items) {
    if (item == null) {
      marks.add(null);
    } else if (item is String && _marks[item] != null) {
      marks.add(_marks[item]);
    } else {
      return null;
    }
  }
  return marks;
}
