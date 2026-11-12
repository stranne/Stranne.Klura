import 'package:klura/core/daily_storage.dart';
import 'package:klura/core/local_store.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
import 'package:klura/puzzles/bridges/logic/bridges_save.dart';

/// Keeps saved Bridges games and the history of solves in a [LocalStore].
///
/// Each day's game at each level has a key of its own, such as
/// `klura.bridges.normal.2026-11-12`, and the history lives under
/// [historyKey].
final class BridgesStorage extends DailyStorage<BridgesLevel, BridgesSave> {
  BridgesStorage(super._store)
    : super(
        puzzleId: _puzzleId,
        levels: BridgesLevel.values,
        encode: encodeBridgesSave,
        decode: decodeBridgesSave,
      );

  static const String _puzzleId = 'bridges';

  /// The key of the history of solves.
  static final String historyKey = dailyHistoryKey(_puzzleId);

  /// The key of the game at [level] for the calendar date of [date].
  static String gameKey(BridgesLevel level, DateTime date) =>
      dailyGameKey(_puzzleId, level, date);
}
