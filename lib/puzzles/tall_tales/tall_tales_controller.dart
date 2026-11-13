import 'package:klura/play/puzzle_controller.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_game.dart';
import 'package:klura/puzzles/tall_tales/logic/tall_tales_generator.dart';

/// Holds one game of Tall Tales, tells listeners about every move and times
/// the play up to the first solve.
final class TallTalesController
    extends PuzzleController<TallTalesLevel, TallTalesGame> {
  /// Holds [game], which has taken [playedTime] so far.
  ///
  /// A game that is solved, or [wasSolved] before, keeps its time: the timer
  /// does not run again.
  TallTalesController({
    required super.level,
    required super.seedKey,
    required super.game,
    super.playedTime,
    super.wasSolved,
    super.clock,
  });

  /// Moves [fisher] on to their next mark: the truth, tall tales, then
  /// unmarked.
  ///
  /// A solved game takes no moves.
  void cycleMark(int fisher) => value = value.cycleMark(fisher);

  @override
  void undo() => value = value.undo();

  /// Clears every mark, as a move that [undo] takes back.
  @override
  void reset() => value = value.reset();
}
