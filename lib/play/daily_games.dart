import 'package:flutter/foundation.dart';
import 'package:klura/core/daily_storage.dart';
import 'package:klura/core/puzzle_game.dart';
import 'package:klura/core/solve_history.dart';
import 'package:klura/play/puzzle_controller.dart';

/// The games of one day of one kind of puzzle, one per level of type [L],
/// saved as saves of type [S] as they are played in controllers of type
/// [C].
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
abstract base class DailyGames<
  L extends Enum,
  S extends DailySave<L>,
  C extends PuzzleController<L, PuzzleGame>
>
    extends ChangeNotifier {
  DailyGames(this.date, DailyStorage<L, S> storage)
    : _storage = storage,
      _history = storage.removeGamesBefore(date) {
    for (final level in storage.levels) {
      if (storage.loadGame(level, date) case final save?) {
        _add(restore(save));
      }
    }
  }

  /// The day whose puzzles these are.
  final DateTime date;

  final DailyStorage<L, S> _storage;
  SolveHistory<L> _history;
  final Map<L, C> _games = {};
  bool _isSaving = true;

  /// The game at [level], or `null` if it has neither been opened nor saved.
  C? started(L level) => _games[level];

  /// The game at [level], generating its puzzle on first use.
  C open(L level) {
    if (_games[level] case final game?) {
      return game;
    }
    // A solve recorded for a game whose save was lost still stands, so the
    // puzzle starts again untimed.
    final solveTime = this.solveTime(level);
    return _add(
      generate(
        level,
        playedTime: solveTime ?? Duration.zero,
        wasSolved: solveTime != null,
      ),
    );
  }

  /// The time today's first solve at [level] took, or `null` before it.
  ///
  /// It stays after a start over.
  Duration? solveTime(L level) => _history.solveTime(level, date);

  /// Stops saving the games, once the app has moved on to another day.
  ///
  /// The new day's games clear these saves away, and a screen that closes
  /// afterwards still pauses its timer, which must not write them back.
  void stopSaving() => _isSaving = false;

  /// Picks up the game in [save].
  @protected
  C restore(S save);

  /// Starts today's puzzle at [level], which has taken [playedTime] so far
  /// and [wasSolved] before.
  @protected
  C generate(L level, {required Duration playedTime, required bool wasSolved});

  /// The save of [game] as it is now.
  @protected
  S saveOf(C game);

  C _add(C controller) {
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

  void _save(C controller) {
    if (!_isSaving) {
      return;
    }
    _storage.saveGame(saveOf(controller));
    _recordSolve(controller);
  }

  void _recordSolve(C controller) {
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
