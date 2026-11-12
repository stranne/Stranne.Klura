import 'package:klura/core/daily_storage.dart';
import 'package:klura/core/local_store.dart';
import 'package:klura/puzzles/tents/logic/tents_generator.dart';
import 'package:klura/puzzles/tents/logic/tents_save.dart';

/// Keeps saved Tents games and the history of solves in a [LocalStore].
///
/// Each day's game at each level has a key of its own, such as
/// `klura.tents.normal.2026-11-12`, and the history lives under
/// [historyKey].
final class TentsStorage extends DailyStorage<TentsLevel, TentsSave> {
  TentsStorage(super._store)
    : super(
        puzzleId: _puzzleId,
        levels: TentsLevel.values,
        encode: encodeTentsSave,
        decode: decodeTentsSave,
      );

  static const String _puzzleId = 'tents';

  /// The key of the history of solves.
  static final String historyKey = dailyHistoryKey(_puzzleId);

  /// The key of the game at [level] for the calendar date of [date].
  static String gameKey(TentsLevel level, DateTime date) =>
      dailyGameKey(_puzzleId, level, date);
}
