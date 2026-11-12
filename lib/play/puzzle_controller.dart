import 'package:flutter/foundation.dart';
import 'package:klura/core/puzzle_game.dart';
import 'package:klura/play/play_timer.dart';

/// Holds one game of the day at a level of type [L], tells listeners about
/// every move and times the play up to the first solve.
///
/// The game itself, with its undo history, is the immutable [value] of type
/// [G]; this class names the puzzle, replaces the game on each move and
/// remembers whether it was ever solved. Each puzzle adds its own moves.
abstract base class PuzzleController<L extends Enum, G extends PuzzleGame>
    extends ValueNotifier<G> {
  /// Holds [game], which has taken [playedTime] so far.
  ///
  /// A game that is solved, or [wasSolved] before, keeps its time: the timer
  /// does not run again.
  PuzzleController({
    required this.level,
    required this.seedKey,
    required G game,
    Duration playedTime = Duration.zero,
    bool wasSolved = false,
    MonotonicClock? clock,
  }) : _wasSolved = wasSolved || game.isSolved,
       timer = PlayTimer(elapsed: playedTime, clock: clock),
       super(game);

  final L level;

  /// The key the puzzle was generated from.
  final String seedKey;

  /// The time spent playing, which stops for good at the first solve.
  ///
  /// It runs only while the screen asks it to, between [resumeTiming] and
  /// [pauseTiming].
  final PlayTimer timer;

  bool _wasSolved;

  G get game => value;

  /// Whether the game has been solved at least once.
  ///
  /// It stays true after a start over, which clears the board.
  bool get wasSolved => _wasSolved;

  /// Whether the player has begun this game: the board has marks, or it was
  /// solved, which still counts after a start over.
  bool get isStarted => _wasSolved || !value.isBlank;

  /// The game becomes [newValue], which stops the timer for good if it is the
  /// first solve.
  @override
  set value(G newValue) {
    if (newValue.isSolved && !_wasSolved) {
      _wasSolved = true;
      timer.pause();
    }
    super.value = newValue;
  }

  /// Takes back the last move.
  void undo();

  /// Clears the board, as a move that [undo] takes back.
  void reset();

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
