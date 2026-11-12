import 'package:klura/core/calendar_date.dart';
import 'package:klura/core/local_store.dart';
import 'package:klura/core/solve_history.dart';

/// What [DailyStorage] needs to know about a saved game of the day.
abstract interface class DailySave<L extends Enum> {
  L get level;

  /// The day of the puzzle, at local midnight.
  DateTime get date;

  /// The time spent playing, which stops at the first solve.
  Duration get playedTime;

  /// Whether the game has been solved at least once.
  bool get wasSolved;
}

/// The key of the saved game of the puzzle kind [puzzleId] at [level] for
/// the calendar date of [date], such as `klura.bridges.normal.2026-11-12`.
String dailyGameKey(String puzzleId, Enum level, DateTime date) =>
    'klura.$puzzleId.${level.name}.${formatCalendarDate(date)}';

/// The key of the history of solves of the puzzle kind [puzzleId], such as
/// `klura.bridges.history`.
String dailyHistoryKey(String puzzleId) => 'klura.$puzzleId.history';

/// Keeps the saved games of one kind of puzzle, with levels of type [L] and
/// saves of type [S], and the history of their solves in a [LocalStore].
///
/// Each day's game at each level has a key of its own, from
/// [dailyGameKey], so a tab left open overnight never overwrites the next
/// day's game. The history lives under [dailyHistoryKey]. A save that cannot
/// be read counts as missing, and the next save replaces it.
base class DailyStorage<L extends Enum, S extends DailySave<L>> {
  DailyStorage(
    this._store, {
    required this.puzzleId,
    required this.levels,
    required this._encode,
    required this._decode,
  }) : _gameKey = RegExp(
         '^klura\\.${RegExp.escape(puzzleId)}\\.([a-z]+)\\.'
         r'(\d{4}-\d{2}-\d{2})$',
       );

  /// The kind of puzzle in the keys, such as `bridges`.
  final String puzzleId;

  /// Every level, in the order the history lists them.
  final List<L> levels;

  final LocalStore _store;
  final String Function(S save) _encode;
  final S? Function(String text) _decode;
  final RegExp _gameKey;

  late final Map<String, L> _levelsByName = levels.asNameMap();

  /// The saved game at [level] for the calendar date of [date], or `null` if
  /// there is none or it cannot be read.
  S? loadGame(L level, DateTime date) {
    final text = _store.read(dailyGameKey(puzzleId, level, date));
    final save = text == null ? null : _decode(text);
    // A save under another game's key is as unusable as a damaged one.
    return save != null &&
            save.level == level &&
            calendarDaysBetween(save.date, date) == 0
        ? save
        : null;
  }

  /// Stores [save], replacing any earlier save of the same game.
  void saveGame(S save) => _store.write(
    dailyGameKey(puzzleId, save.level, save.date),
    _encode(save),
  );

  /// The history of solves, empty if there is none or it cannot be read.
  SolveHistory<L> loadHistory() {
    final text = _store.read(dailyHistoryKey(puzzleId));
    return (text == null ? null : decodeSolveHistory(text, levels)) ??
        SolveHistory<L>.empty();
  }

  /// Records that the puzzle at [level] for the calendar date of [date] was
  /// solved in [time], unless a solve is already recorded, and returns the
  /// history.
  ///
  /// The history is read again first, so solves another tab has recorded
  /// meanwhile are kept.
  SolveHistory<L> recordSolve(L level, DateTime date, Duration time) {
    final history = loadHistory();
    final updated = history.withSolve(level, date, time);
    if (!identical(updated, history)) {
      _saveHistory(updated);
    }
    return updated;
  }

  /// Removes the saved games of days before [today], after recording their
  /// solves in the history, and returns the history.
  ///
  /// Only today's games can be played; an older game matters only for
  /// whether it was solved. Games of later days, from a clock that was set
  /// ahead, are kept.
  SolveHistory<L> removeGamesBefore(DateTime today) {
    final history = loadHistory();
    var updated = history;
    for (final key in _store.keys) {
      final match = _gameKey.firstMatch(key);
      final level = _levelsByName[match?[1]];
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
      _saveHistory(updated);
    }
    return updated;
  }

  void _saveHistory(SolveHistory<L> history) => _store.write(
    dailyHistoryKey(puzzleId),
    encodeSolveHistory(history, levels),
  );
}
