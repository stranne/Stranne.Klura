import 'package:klura/core/daily_storage.dart';
import 'package:klura/core/local_store.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_generator.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_save.dart';

/// Keeps saved Tall Tales games and the history of solves in a
/// [LocalStore].
///
/// Each day's game at each level has a key of its own, such as
/// `klura.tall-tales.normal.2026-11-13`, and the history lives under
/// [historyKey].
final class TallTalesStorage
    extends DailyStorage<TallTalesLevel, TallTalesSave> {
  TallTalesStorage(super._store)
    : super(
        puzzleId: _puzzleId,
        levels: TallTalesLevel.values,
        encode: encodeTallTalesSave,
        decode: decodeTallTalesSave,
      );

  static const String _puzzleId = 'tall-tales';

  /// The key of the history of solves.
  static final String historyKey = dailyHistoryKey(_puzzleId);

  /// The key of the game at [level] for the calendar date of [date].
  static String gameKey(TallTalesLevel level, DateTime date) =>
      dailyGameKey(_puzzleId, level, date);
}
