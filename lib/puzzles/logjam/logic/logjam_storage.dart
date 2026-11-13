import 'package:klura/core/daily_storage.dart';
import 'package:klura/core/local_store.dart';
import 'package:klura/puzzles/logjam/logic/logjam_generator.dart';
import 'package:klura/puzzles/logjam/logic/logjam_save.dart';

/// Keeps saved Logjam games and the history of solves in a [LocalStore].
///
/// Each day's game at each level has a key of its own, such as
/// `klura.logjam.normal.2026-11-12`, and the history lives under
/// [historyKey].
final class LogjamStorage extends DailyStorage<LogjamLevel, LogjamSave> {
  LogjamStorage(super._store)
    : super(
        puzzleId: _puzzleId,
        levels: LogjamLevel.values,
        encode: encodeLogjamSave,
        decode: decodeLogjamSave,
      );

  static const String _puzzleId = 'logjam';

  /// The key of the history of solves.
  static final String historyKey = dailyHistoryKey(_puzzleId);

  /// The key of the game at [level] for the calendar date of [date].
  static String gameKey(LogjamLevel level, DateTime date) =>
      dailyGameKey(_puzzleId, level, date);
}
