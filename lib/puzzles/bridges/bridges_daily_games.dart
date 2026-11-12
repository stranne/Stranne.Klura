import 'package:flutter/foundation.dart';
import 'package:klura/core/daily_streak.dart';
import 'package:klura/puzzles/bridges/bridges_controller.dart';
import 'package:klura/puzzles/bridges/logic/bridges_game.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
import 'package:klura/puzzles/bridges/logic/bridges_save.dart';
import 'package:klura/puzzles/bridges/logic/bridges_storage.dart';
import 'package:klura/puzzles/bridges/play_timer.dart';

/// The Bridges games of one day, one per level, saved as they are played.
///
/// On creation it clears away the games of earlier days, keeping their
/// solves in the history, and restores today's saved games. A game without
/// a save is generated when first opened. Every move and every start and
/// pause of a timer saves the game, and its first solve goes into the
/// history at once.
///
/// The date never changes. When the day moves on, the app stops these games
/// saving and replaces them with the new day's. Listeners hear about every
/// move in any of the games, not about the timers.
final class BridgesDailyGames extends ChangeNotifier {
  BridgesDailyGames(this.date, BridgesStorage storage, {this._clock})
    : _storage = storage,
      _history = storage.removeGamesBefore(date) {
    for (final level in BridgesLevel.values) {
      if (storage.loadGame(level, date) case final save?) {
        _add(_restore(save));
      }
    }
  }

  /// The day whose puzzles these are.
  final DateTime date;

  final BridgesStorage _storage;
  final MonotonicClock? _clock;
  BridgesHistory _history;
  final Map<BridgesLevel, BridgesController> _games = {};
  bool _isSaving = true;

  /// The game at [level], or `null` if it has neither been opened nor saved.
  BridgesController? started(BridgesLevel level) => _games[level];

  /// The game at [level], generating its puzzle on first use.
  BridgesController open(BridgesLevel level) =>
      _games[level] ?? _add(_generate(level));

  /// The time today's first solve at [level] took, or `null` before it.
  ///
  /// It stays after a start over.
  Duration? solveTime(BridgesLevel level) => _history.solveTime(level, date);

  /// The number of days in a row with at least one solved puzzle, of any
  /// level, up to today.
  ///
  /// Until today's first solve, the run up to yesterday still counts.
  int get streak => countDailyStreak(_history.solvedDays, date);

  /// Stops saving the games, once the app has moved on to another day.
  ///
  /// The new day's games clear these saves away, and a screen that closes
  /// afterwards still pauses its timer, which must not write them back.
  void stopSaving() => _isSaving = false;

  BridgesController _restore(BridgesSave save) => BridgesController(
    level: save.level,
    seedKey: save.seedKey,
    game: BridgesGame(save.puzzle, save.arrangement),
    playedTime: save.playedTime,
    wasSolved: save.wasSolved,
    clock: _clock,
  );

  BridgesController _generate(BridgesLevel level) {
    final generated = generateDailyBridges(level, date);
    // A solve recorded for a game whose save was lost still stands, so the
    // puzzle starts again untimed.
    final solveTime = _history.solveTime(level, date);
    return BridgesController(
      level: level,
      seedKey: generated.seedKey,
      game: BridgesGame(generated.puzzle),
      playedTime: solveTime ?? Duration.zero,
      wasSolved: solveTime != null,
      clock: _clock,
    );
  }

  BridgesController _add(BridgesController controller) {
    _games[controller.level] = controller;
    controller
      ..addListener(() {
        _save(controller);
        notifyListeners();
      })
      ..timer.addListener(() => _save(controller));
    _recordSolve(controller);
    return controller;
  }

  void _save(BridgesController controller) {
    if (!_isSaving) {
      return;
    }
    _storage.saveGame(
      BridgesSave(
        level: controller.level,
        date: date,
        seedKey: controller.seedKey,
        puzzle: controller.game.puzzle,
        arrangement: controller.game.arrangement,
        playedTime: controller.timer.elapsed,
        wasSolved: controller.wasSolved,
      ),
    );
    _recordSolve(controller);
  }

  void _recordSolve(BridgesController controller) {
    if (controller.wasSolved && solveTime(controller.level) == null) {
      _history = _storage.recordSolve(
        controller.level,
        date,
        controller.timer.elapsed,
      );
    }
  }

  @override
  void dispose() {
    for (final game in _games.values) {
      game.dispose();
    }
    super.dispose();
  }
}
