import 'package:klura/core/calendar_date.dart';
import 'package:klura/core/local_store.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
import 'package:klura/puzzles/bridges/logic/bridges_save.dart';

/// Keeps saved Bridges games and the history of solves in a [LocalStore].
///
/// Each day's game at each level has a key of its own, such as
/// `klura.bridges.normal.2026-11-12`, so a tab left open overnight never
/// overwrites the next day's game. The history lives under [historyKey]. A
/// save that cannot be read counts as missing, and the next save replaces
/// it.
final class BridgesStorage {
  BridgesStorage(this._store);

  /// The key of the history of solves.
  static const String historyKey = 'klura.bridges.history';

  final LocalStore _store;

  /// The key of the game at [level] for the calendar date of [date].
  static String gameKey(BridgesLevel level, DateTime date) =>
      'klura.bridges.${level.name}.${formatCalendarDate(date)}';

  /// The saved game at [level] for the calendar date of [date], or `null` if
  /// there is none or it cannot be read.
  BridgesSave? loadGame(BridgesLevel level, DateTime date) {
    final text = _store.read(gameKey(level, date));
    final save = text == null ? null : decodeBridgesSave(text);
    // A save under another game's key is as unusable as a damaged one.
    return save != null &&
            save.level == level &&
            calendarDaysBetween(save.date, date) == 0
        ? save
        : null;
  }

  /// Stores [save], replacing any earlier save of the same game.
  void saveGame(BridgesSave save) =>
      _store.write(gameKey(save.level, save.date), encodeBridgesSave(save));

  /// The history of solves, empty if there is none or it cannot be read.
  BridgesHistory loadHistory() {
    final text = _store.read(historyKey);
    return (text == null ? null : decodeBridgesHistory(text)) ??
        const BridgesHistory.empty();
  }

  /// Records that the puzzle at [level] for the calendar date of [date] was
  /// solved in [time], unless a solve is already recorded, and returns the
  /// history.
  ///
  /// The history is read again first, so solves another tab has recorded
  /// meanwhile are kept.
  BridgesHistory recordSolve(
    BridgesLevel level,
    DateTime date,
    Duration time,
  ) {
    final history = loadHistory();
    final updated = history.withSolve(level, date, time);
    if (!identical(updated, history)) {
      _store.write(historyKey, encodeBridgesHistory(updated));
    }
    return updated;
  }

  /// Removes the saved games of days before [today], after recording their
  /// solves in the history, and returns the history.
  ///
  /// The app picks its puzzles once at start, so only today's games can be
  /// played; an older game matters only for whether it was solved. Games of
  /// later days, from a clock that was set ahead, are kept.
  BridgesHistory removeGamesBefore(DateTime today) {
    final history = loadHistory();
    var updated = history;
    for (final key in _store.keys) {
      final match = _gameKey.firstMatch(key);
      final level = _levels[match?[1]];
      final date = match == null ? null : parseCalendarDate(match[2]!);
      if (level == null ||
          date == null ||
          calendarDaysBetween(date, today) <= 0) {
        continue;
      }
      if (loadGame(level, date) case final save? when save.wasSolved) {
        updated = updated.withSolve(level, date, save.playedTime);
      }
      _store.remove(key);
    }
    if (!identical(updated, history)) {
      _store.write(historyKey, encodeBridgesHistory(updated));
    }
    return updated;
  }
}

final RegExp _gameKey = RegExp(
  r'^klura\.bridges\.([a-z]+)\.(\d{4}-\d{2}-\d{2})$',
);

final Map<String, BridgesLevel> _levels = BridgesLevel.values.asNameMap();
