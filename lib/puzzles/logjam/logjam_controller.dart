import 'dart:math' as math;

import 'package:klura/play/puzzle_controller.dart';
import 'package:klura/puzzles/logjam/logic/logjam_board.dart';
import 'package:klura/puzzles/logjam/logic/logjam_game.dart';
import 'package:klura/puzzles/logjam/logic/logjam_generator.dart';

/// Holds one game of Logjam, tells listeners about every move, times the
/// play up to the first solve and keeps the fewest moves of any solve.
final class LogjamController extends PuzzleController<LogjamLevel, LogjamGame> {
  /// Holds [game], which has taken [playedTime] so far and was solved in
  /// [bestMoves] moves at best, if ever.
  ///
  /// A game that is solved, or [wasSolved] before, keeps its time: the timer
  /// does not run again.
  LogjamController({
    required super.level,
    required super.seedKey,
    required super.game,
    required this.fewestMoves,
    int? bestMoves,
    super.playedTime,
    super.wasSolved,
    super.clock,
  }) : _bestMoves = _fewer(bestMoves, game);

  /// The fewest moves that solve the puzzle.
  final int fewestMoves;

  int? _bestMoves;

  /// The fewest moves of any solve of this game, or `null` before the first.
  ///
  /// A replay that starts over and solves the puzzle again can lower it.
  int? get bestMoves => _bestMoves;

  /// The game becomes [newValue], which lowers [bestMoves] if it is solved
  /// in fewer moves.
  @override
  set value(LogjamGame newValue) {
    _bestMoves = _fewer(_bestMoves, newValue);
    super.value = newValue;
  }

  /// Slides a log as [move] says, joined to the last move if that slid the
  /// same log.
  ///
  /// A solved game takes no moves.
  void slide(LogjamMove move) => value = value.slide(move);

  @override
  void undo() => value = value.undo();

  /// Puts every log back where it started, as a move that [undo] takes
  /// back.
  @override
  void reset() => value = value.reset();

  /// The fewer of [best] and the moves of [game], if it is solved.
  static int? _fewer(int? best, LogjamGame game) {
    if (!game.isSolved) {
      return best;
    }
    final moves = game.moves.length;
    return best == null ? moves : math.min(best, moves);
  }
}
