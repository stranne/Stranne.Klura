import 'package:flutter/foundation.dart';
import 'package:klura/puzzles/bridges/logic/bridges_game.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';
import 'package:klura/puzzles/bridges/logic/geometry.dart';
import 'package:klura/puzzles/bridges/play_timer.dart';

/// Holds one game of Bridges, tells listeners about every move and times
/// the play up to the first solve.
///
/// The game itself, with its undo history, is the immutable [value]; this
/// class names the puzzle, replaces the game on each move and remembers
/// whether it was ever solved.
final class BridgesController extends ValueNotifier<BridgesGame> {
  /// Holds [game], which has taken [playedTime] so far.
  ///
  /// A game that is solved, or [wasSolved] before, keeps its time: the timer
  /// does not run again.
  BridgesController({
    required this.level,
    required this.seedKey,
    required BridgesGame game,
    Duration playedTime = Duration.zero,
    bool wasSolved = false,
    MonotonicClock? clock,
  }) : _wasSolved = wasSolved || game.isSolved,
       timer = PlayTimer(elapsed: playedTime, clock: clock),
       super(game);

  final BridgesLevel level;

  /// The key the puzzle was generated from.
  final String seedKey;

  /// The time spent playing, which stops for good at the first solve.
  ///
  /// It runs only while the screen asks it to, between [resumeTiming] and
  /// [pauseTiming].
  final PlayTimer timer;

  bool _wasSolved;

  BridgesGame get game => value;

  /// Whether the game has been solved at least once.
  ///
  /// It stays true after a start over, which clears the board.
  bool get wasSolved => _wasSolved;

  /// Whether the player has begun this game: it has bridges, or it was
  /// solved, which still counts after a start over.
  bool get isStarted => _wasSolved || !value.arrangement.isEmpty;

  /// The game becomes [newValue], which stops the timer for good if it is the
  /// first solve.
  @override
  set value(BridgesGame newValue) {
    if (newValue.isSolved && !_wasSolved) {
      _wasSolved = true;
      timer.pause();
    }
    super.value = newValue;
  }

  /// Moves [connection] on to its next number of bridges, unless a first
  /// bridge there would cross others.
  ///
  /// Returns the bridges in the way, which is empty when the move was made.
  /// A solved game takes no moves.
  List<Connection> cycleBridges(Connection connection) {
    final blockers = value.blockersOf(connection);
    if (blockers.isEmpty) {
      value = value.cycleBridges(connection);
    }
    return blockers;
  }

  /// Takes back the last move.
  void undo() => value = value.undo();

  /// Clears every bridge, as a move that [undo] takes back.
  void reset() => value = value.reset();

  /// Runs the timer while the game is on screen, unless it was ever solved.
  void resumeTiming() {
    if (!_wasSolved) {
      timer.start();
    }
  }

  /// Pauses the timer while the game is off screen or the app is hidden.
  void pauseTiming() => timer.pause();

  @override
  void dispose() {
    timer.dispose();
    super.dispose();
  }
}
