import 'package:klura/core/grid.dart';
import 'package:klura/play/puzzle_controller.dart';
import 'package:klura/puzzles/tents/logic/tents_game.dart';
import 'package:klura/puzzles/tents/logic/tents_generator.dart';

/// Holds one game of Tents, tells listeners about every move and times the
/// play up to the first solve.
final class TentsController extends PuzzleController<TentsLevel, TentsGame> {
  /// Holds [game], which has taken [playedTime] so far.
  ///
  /// A game that is solved, or [wasSolved] before, keeps its time: the timer
  /// does not run again.
  TentsController({
    required super.level,
    required super.seedKey,
    required super.game,
    super.playedTime,
    super.wasSolved,
    super.clock,
  });

  /// Moves [position] on to its next mark: grass, a tent, then empty.
  ///
  /// A solved game takes no moves.
  void cycleMark(Position position) => value = value.cycleMark(position);

  /// Puts grass on every empty cell of [positions], as one move.
  void fillGrass(Iterable<Position> positions) =>
      value = value.fillGrass(positions);

  /// Clears the grass from every cell of [positions], as one move.
  void clearGrass(Iterable<Position> positions) =>
      value = value.clearGrass(positions);

  @override
  void undo() => value = value.undo();

  /// Clears every tent and all grass, as a move that [undo] takes back.
  @override
  void reset() => value = value.reset();
}
